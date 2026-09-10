import Foundation
import Observation

@Observable
@MainActor
final class GainsViewModel {
    private(set) var snapshot: GainsSnapshot?
    private(set) var isLoading = false
    private(set) var hasStaleData = false
    private(set) var errorMessage: String?
    private(set) var marketClock: Date

    private(set) var isSyncingHoldings = false
    private(set) var holdingsSyncMessage: String?
    /// Ephemeral popover toast when Form 4 sync changes ownership counts.
    private(set) var holdingsOwnershipChangeMessage: String?

    private(set) var dailyRecordsSnapshot = DailyRecordTracker.Snapshot(
        bestRecord: nil,
        worstRecord: nil,
        hasCompletedFirstTradingDay: false
    )
    private(set) var intradaySamples: [GainSample] = []
    private(set) var activeMilestone: NetWorthMilestone?
    private(set) var trillionEasterEggMessage: String?
    private(set) var enabledNotificationThresholdIDs: Set<String>
    /// Shown when the user enables a gain threshold but notification auth is denied.
    private(set) var notificationAuthorizationMessage: String?

    let settings: AppSettings
    let updateCoordinator: UpdateCoordinator

    private let stockService: any StockPriceServiceProtocol
    private let holdingsSyncServiceFactory: (TrackedPersonProfile) -> any HoldingsSyncServiceProtocol
    private let outstandingSyncServiceFactory: () -> any IssuerOutstandingSyncServiceProtocol
    private let marketHours: any MarketHoursServiceProtocol
    private let dailyRecordTracker: DailyRecordTracker
    private let gainThresholdNotificationService: GainThresholdNotificationService
    private let dayCloseSummaryNotificationService: DayCloseSummaryNotificationService
    private let intradayGainSampleStore: IntradayGainSampleStore
    private let netWorthMilestoneTracker: NetWorthMilestoneTracker
    private var refreshTask: Task<Void, Never>?
    private var refreshGeneration = 0
    private struct ClosingRecovery {
        let generation: Int
        var windowElapsed = false
        var retryUsed = false
    }
    private var closingRecovery: ClosingRecovery?
    private var pendingClosingDate: Date?
    private var closingWindowElapsed = false
    private var closingRetryTask: Task<Void, Never>?
    private var lifecycle = UUID()
    private var holdingsToken: UUID?
    private var holdingsTasks: [UUID: Task<Void, Never>] = [:]
    // One current request plus one superseded transport may occupy each boundary.
    // Physical slots survive stop/reset until cancellation-unaware services return.
    private static let maximumPhysicalRequests = 2
    private var quoteTasks: [Int: Task<Task<Void, Never>?, Never>] = [:]
    private var summaryTasks: [UUID: Task<Void, Never>] = [:]
    private let sleeper: @Sendable (TimeInterval) async throws -> Void
    private var hasStarted = false
    private var lastSideEffectPersonID: String?
    private let dateProvider: () -> Date

    init(
        settings: AppSettings = .shared,
        stockService: any StockPriceServiceProtocol = YahooFinanceStockPriceService(),
        holdingsSyncServiceFactory: @escaping (TrackedPersonProfile) -> any HoldingsSyncServiceProtocol = { SECHoldingsSyncService(profile: $0) },
        outstandingSyncServiceFactory: @escaping () -> any IssuerOutstandingSyncServiceProtocol = { IssuerOutstandingSyncService() },
        marketHours: any MarketHoursServiceProtocol = MarketHoursService(),
        dailyRecordTracker: DailyRecordTracker? = nil,
        gainThresholdNotificationService: GainThresholdNotificationService? = nil,
        dayCloseSummaryNotificationService: DayCloseSummaryNotificationService? = nil,
        intradayGainSampleStore: IntradayGainSampleStore? = nil,
        netWorthMilestoneTracker: NetWorthMilestoneTracker? = nil,
        dateProvider: @escaping () -> Date = { .now },
        updateCoordinator: UpdateCoordinator? = nil,
        sleeper: @escaping @Sendable (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }
    ) {
        self.settings = settings
        self.updateCoordinator = updateCoordinator ?? UpdateCoordinator(settings: settings)
        self.stockService = stockService
        self.holdingsSyncServiceFactory = holdingsSyncServiceFactory
        self.outstandingSyncServiceFactory = outstandingSyncServiceFactory
        self.marketHours = marketHours
        self.dailyRecordTracker = dailyRecordTracker ?? DailyRecordTracker()
        self.gainThresholdNotificationService = gainThresholdNotificationService ?? GainThresholdNotificationService()
        self.dayCloseSummaryNotificationService = dayCloseSummaryNotificationService ?? DayCloseSummaryNotificationService()
        self.intradayGainSampleStore = intradayGainSampleStore ?? IntradayGainSampleStore()
        self.netWorthMilestoneTracker = netWorthMilestoneTracker ?? NetWorthMilestoneTracker()
        self.marketClock = dateProvider()
        self.dateProvider = dateProvider
        self.sleeper = sleeper
        self.enabledNotificationThresholdIDs = self.gainThresholdNotificationService.enabledThresholdIDs(
            for: settings.selectedPersonID
        )
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        let token = lifecycle
        let sleep = sleeper
        // Capture the observed session before any network suspension. The timer owns
        // session transitions; even a cancellation-unaware quote cannot hold the clock.
        var sessionClose = currentRegularClose()
        var closeWindowStarted = false
        var closeWindowFinished = false
        beginHoldingsSync(force: false)
        beginRefresh(force: false)
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard self?.lifecycle == token else { return }
                self?.advanceTradingClock()
                let now = self?.marketClock ?? .distantPast
                let isOpen = self?.marketHours.isQuotable(at: now) ?? false
                if isOpen {
                    let newClose = self?.marketHours.regularCloseDate(on: now)
                    if newClose != sessionClose {
                        sessionClose = newClose
                        closeWindowStarted = false
                        closeWindowFinished = false
                        self?.clearClosingRecovery()
                        self?.beginHoldingsSync(force: false)
                        self?.beginRefresh(force: true)
                    }
                    let interval = self?.refreshSleepInterval() ?? 30
                    let untilClose = sessionClose?.timeIntervalSince(now) ?? interval
                    do { try await sleep(max(0.5, min(interval, untilClose))) }
                    catch { return }
                    guard !Task.isCancelled, self?.lifecycle == token else { return }
                    if self?.marketHours.isQuotable(at: self?.dateProvider() ?? now) == true {
                        self?.beginHoldingsSync(force: false)
                        self?.beginRefresh(force: false)
                    }
                    continue
                }

                if let close = sessionClose, now >= close, !closeWindowStarted {
                    closeWindowStarted = true
                    self?.beginClosingRefresh(on: close)
                    // One bounded recovery window. The timer keeps advancing even
                    // when either the pre-close or the closing request never returns.
                    do { try await sleep(30) } catch { return }
                    continue
                }
                if closeWindowStarted, !closeWindowFinished {
                    closeWindowFinished = true
                    self?.finishClosingWindow()
                }
                self?.beginPendingSummary()
                let interval = self?.offMarketSleepInterval() ?? 300
                do { try await sleep(interval) } catch { return }
            }
        }
    }

    private func beginClosingRefresh(on close: Date) {
        // Admission can wait behind the initial and holdings-triggered requests.
        // Keep one obligation; physical completions retry admission without polling.
        pendingClosingDate = close
        admitPendingClosingRefreshIfPossible()
    }

    private func admitPendingClosingRefreshIfPossible() {
        guard let close = pendingClosingDate, hasStarted else { return }
        let now = dateProvider()
        guard now >= close else { return }
        if marketHours.isQuotable(at: now)
            || marketHours.nextOpenDate(from: close).map({ now >= $0 }) == true {
            pendingClosingDate = nil
            return
        }
        guard beginRefresh(force: true) != nil else { return }
        pendingClosingDate = nil
        closingRecovery = ClosingRecovery(generation: refreshGeneration, windowElapsed: closingWindowElapsed)
    }

    private func finishClosingWindow() {
        closingWindowElapsed = true
        guard var recovery = closingRecovery, recovery.generation == refreshGeneration else { return }
        recovery.windowElapsed = true
        if errorMessage != nil {
            recovery.retryUsed = true
            closingRecovery = recovery
            beginRefresh(force: true)
        } else {
            closingRecovery = recovery
        }
    }

    private func scheduleLateClosingRetryIfNeeded(generation: Int) {
        guard var recovery = closingRecovery, recovery.generation == generation,
              recovery.windowElapsed, !recovery.retryUsed else { return }
        recovery.retryUsed = true
        closingRecovery = recovery
        let token = lifecycle, sleep = sleeper
        closingRetryTask = Task { [weak self] in
            defer {
                if self?.closingRecovery?.generation == generation { self?.closingRetryTask = nil }
            }
            do { try await sleep(30) } catch { return }
            guard !Task.isCancelled, self?.lifecycle == token,
                  self?.refreshGeneration == generation,
                  self?.marketHours.isQuotable(at: self?.dateProvider() ?? .now) == false else { return }
            self?.beginRefresh(force: true)
        }
    }

    private func clearClosingRecovery() {
        closingRetryTask?.cancel()
        closingRetryTask = nil
        closingRecovery = nil
        pendingClosingDate = nil
        closingWindowElapsed = false
    }

    private func currentRegularClose() -> Date? {
        let now = dateProvider()
        return marketHours.isQuotable(at: now) ? marketHours.regularCloseDate(on: now) : nil
    }

    func stop() {
        clearClosingRecovery()
        lifecycle = UUID()
        refreshGeneration += 1
        refreshTask?.cancel()
        refreshTask = nil
        holdingsTasks.values.forEach { $0.cancel() }
        holdingsToken = nil
        quoteTasks.values.forEach { $0.cancel() }
        summaryTasks.values.forEach { $0.cancel() }
        isLoading = false
        isSyncingHoldings = false
        hasStarted = false
        let people = Set([settings.selectedPersonID, lastSideEffectPersonID].compactMap { $0 })
        for personID in people {
            gainThresholdNotificationService.resetRuntimeState(for: personID)
            dayCloseSummaryNotificationService.resetRuntimeState(for: personID)
        }
    }

    func refresh(force: Bool = false) async {
        guard let task = beginRefresh(force: force) else { return }
        let summary = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        // Preserve awaitable day-close completion for explicit refresh callers,
        // without retaining a quote worker throughout that delivery.
        await withTaskCancellationHandler {
            await summary?.value
        } onCancel: {
            summary?.cancel()
        }
    }

    @discardableResult
    private func beginScheduledRefresh(force: Bool) -> AsyncStream<Void> {
        let (completion, continuation) = AsyncStream<Void>.makeStream()
        if beginRefresh(force: force, quotesCompleted: { continuation.finish() }) == nil {
            continuation.finish()
        }
        return completion
    }

    @discardableResult
    private func beginRefresh(force: Bool, quotesCompleted: (() -> Void)? = nil) -> Task<Task<Void, Never>?, Never>? {
        if isLoading, !force { return nil }
        guard quoteTasks.count < Self.maximumPhysicalRequests else { return nil }
        refreshGeneration += 1
        let generation = refreshGeneration, token = lifecycle
        let personID = settings.selectedPersonID
        let symbols = settings.holdings.map(\.symbol)
        let stock = stockService, thresholds = gainThresholdNotificationService
        let name = settings.selectedProfile.possessiveName
        isLoading = true
        errorMessage = nil
        let task = Task { [weak self] () -> Task<Void, Never>? in
            defer {
                quotesCompleted?()
                self?.finishQuoteTask(generation: generation, token: token)
            }
            guard !Task.isCancelled else { return nil }
            do {
                let quotes = try await stock.fetchQuotes(for: symbols)
                guard !Task.isCancelled,
                      let accepted = self?.acceptQuotes(quotes, generation: generation, token: token, personID: personID) else { return nil }
                quotesCompleted?()
                let summary = self?.beginPendingSummary()
                // Synchronous observations preserve acceptance order. The service owns
                // bounded coalesced delivery workers, so polling never awaits a gain alert.
                thresholds.observeUpdate(paperGain: accepted.combinedPaperGain,
                    personID: personID, possessiveName: name, at: accepted.lastUpdated,
                    isQuotable: accepted.isQuotable)
                return summary
            } catch {
                guard !Task.isCancelled else { return nil }
                let summary = self?.acceptQuoteFailure(error, generation: generation, token: token, personID: personID)
                quotesCompleted?()
                return summary
            }
        }
        quoteTasks[generation] = task
        return task
    }

    private func finishQuoteTask(generation: Int, token: UUID) {
        quoteTasks.removeValue(forKey: generation)
        if lifecycle == token, generation == refreshGeneration { isLoading = false }
        // Even a superseded transport releases capacity for the current lifecycle's
        // obligation. stop/reset clears that obligation before any old tail resumes.
        admitPendingClosingRefreshIfPossible()
    }

    private func acceptQuotes(_ quotes: [StockQuote], generation: Int, token: UUID, personID: String) -> GainsSnapshot? {
        guard lifecycle == token, generation == refreshGeneration,
              settings.selectedPersonID == personID else { return nil }
        // Counts may have changed while Yahoo was suspended. Use the current accepted settings.
        let holdings = settings.holdings
        let quoteBySymbol = Dictionary(quotes.map { ($0.symbol, $0) }, uniquingKeysWith: { _, newer in newer })
        let gains = holdings.compactMap { holding -> HoldingGain? in
            guard let quote = quoteBySymbol[holding.symbol] else { return nil }
            return HoldingGain(id: holding.id, symbol: holding.symbol, displayName: holding.displayName,
                               shareCount: holding.shareCount, quote: quote)
        }
        guard gains.count == holdings.count else {
            errorMessage = "Incomplete quote data received."
            scheduleLateClosingRetryIfNeeded(generation: generation)
            hasStaleData = snapshot != nil
            isLoading = false
            advanceTradingClock()
            beginPendingSummary()
            return nil
        }
        let now = dateProvider()
        marketClock = now
        let accepted = GainsSnapshot(holdings: gains, lastUpdated: now, tradingSession: marketHours.currentSession(at: now))
        snapshot = accepted
        hasStaleData = false
        isLoading = false
        processSnapshotSideEffects(accepted)
        return accepted
    }

    private func acceptQuoteFailure(_ error: Error, generation: Int, token: UUID, personID: String) -> Task<Void, Never>? {
        guard lifecycle == token, generation == refreshGeneration,
              settings.selectedPersonID == personID else { return nil }
        errorMessage = error.localizedDescription
        scheduleLateClosingRetryIfNeeded(generation: generation)
        hasStaleData = snapshot != nil
        isLoading = false
        advanceTradingClock()
        return beginPendingSummary()
    }

    func syncHoldingsIfNeeded(force: Bool = false) async {
        let task = beginHoldingsSync(force: force)
        await withTaskCancellationHandler { await task?.value } onCancel: { task?.cancel() }
    }

    func syncHoldingsFromSEC() async {
        await syncHoldingsIfNeeded(force: true)
    }

    @discardableResult
    private func beginHoldingsSync(force: Bool) -> Task<Void, Never>? {
        guard !isSyncingHoldings, force || settings.needsHoldingsSync,
              holdingsTasks.count < Self.maximumPhysicalRequests else { return nil }
        let token = UUID(), epoch = lifecycle
        holdingsToken = token
        isSyncingHoldings = true
        holdingsSyncMessage = nil
        holdingsOwnershipChangeMessage = nil
        let profile = settings.selectedProfile
        let service = holdingsSyncServiceFactory(profile)
        let outstanding = outstandingSyncServiceFactory()
        let task = Task { [weak self] in
            defer { self?.finishHoldingsTask(token: token, epoch: epoch) }
            guard !Task.isCancelled else { return }
            do {
                let result = try await service.syncHoldings()
                guard !Task.isCancelled else { return }
                let refresh = self?.acceptHoldings(result, profile: profile, token: token, epoch: epoch)
                if let refresh { for await _ in refresh {} }
            } catch {
                guard !Task.isCancelled, self?.holdingsToken == token, self?.lifecycle == epoch else { return }
                self?.settings.recordHoldingsSyncAttempt()
                self?.holdingsSyncMessage = "SEC sync failed: \(error.localizedDescription)"
            }
            guard !Task.isCancelled, self?.holdingsToken == token, self?.lifecycle == epoch else { return }
            let facts = await outstanding.fetchOutstanding(for: profile.holdingSpecs)
            guard !Task.isCancelled, self?.holdingsToken == token, self?.lifecycle == epoch,
                  self?.settings.selectedPersonID == profile.id else { return }
            for (symbol, fact) in facts where fact.shares > 0 {
                self?.settings.setSharesOutstanding(fact.shares, for: symbol,
                    provenance: .companyfacts(periodEnd: fact.periodEnd, filed: fact.filed))
            }
        }
        holdingsTasks[token] = task
        return task
    }

    private func finishHoldingsTask(token: UUID, epoch: UUID) {
        holdingsTasks.removeValue(forKey: token)
        guard lifecycle == epoch, holdingsToken == token else { return }
        holdingsToken = nil
        isSyncingHoldings = false
    }

    private func acceptHoldings(_ result: HoldingsSyncResult, profile: TrackedPersonProfile, token: UUID, epoch: UUID) -> AsyncStream<Void>? {
        guard lifecycle == epoch, holdingsToken == token, settings.selectedPersonID == profile.id else { return nil }
        let symbols = profile.expectedSymbols
        let prior = Dictionary(uniqueKeysWithValues: symbols.map { ($0, settings.shareCount(for: $0)) })
        if settings.applyHoldingsSync(result) {
            holdingsSyncMessage = "Holdings updated from SEC (\(symbols.sorted().joined(separator: ", ")))."
            let current = Dictionary(uniqueKeysWithValues: symbols.map { ($0, settings.shareCount(for: $0)) })
            holdingsOwnershipChangeMessage = Self.ownershipChangeToast(prior: prior, current: current)
            // A changed accepted result has one refresh owner, including during the initial fetch.
            return prior != current ? beginScheduledRefresh(force: true) : nil
        }
        let found = result.sharesBySymbol.keys.filter { symbols.contains($0) }.sorted()
        holdingsSyncMessage = found.isEmpty ? "SEC sync incomplete — will retry later."
            : "SEC sync incomplete — will retry later (\(found.joined(separator: ", ")) found)."
        return nil
    }

    static func ownershipChangeToast(
        prior: [String: Int64],
        current: [String: Int64]
    ) -> String? {
        let symbols = Set(prior.keys).union(current.keys).sorted()
        var parts: [String] = []
        for symbol in symbols {
            let before = prior[symbol] ?? 0
            let after = current[symbol] ?? 0
            guard before != after else { continue }
            parts.append(
                "\(symbol) \(CurrencyFormatter.formatShareCount(before)) → \(CurrencyFormatter.formatShareCount(after))"
            )
        }
        guard !parts.isEmpty else { return nil }
        return "Ownership updated: " + parts.joined(separator: " · ")
    }

    /// Market-cap parity presentation for the TSLA/SPCX merger card.
    /// Uses live snapshot quotes + settings outstanding (bundled defaults when never synced).
    var mergerParityPresentation: MergerParityPresentation? {
        guard let snapshot else { return nil }
        guard let tsla = snapshot.holdings.first(where: { $0.symbol == "TSLA" }),
              let spcx = snapshot.holdings.first(where: { $0.symbol == "SPCX" }) else {
            return nil
        }
        return MergerMarketCapParity.presentation(
            tslaPrice: tsla.quote.currentPrice,
            spcxPrice: spcx.quote.currentPrice,
            tslaOutstanding: settings.sharesOutstanding(for: "TSLA"),
            spcxOutstanding: settings.sharesOutstanding(for: "SPCX")
        )
    }

    /// Outstanding provenance line for the parity card (“TSLA … · SPCX …”).
    var mergerParityOutstandingCaption: String {
        let tsla = settings.outstandingProvenanceCaption(for: "TSLA")
        let spcx = settings.outstandingProvenanceCaption(for: "SPCX")
        return "TSLA \(tsla) · SPCX \(spcx)"
    }

    var menuBarTitle: String {
        guard let snapshot else {
            return isLoading ? "…" : "—"
        }

        switch settings.menuBarDisplayMode {
        case .combinedDollars:
            return CurrencyFormatter.formatCurrency(snapshot.combinedPaperGain)
        case .combinedPercent:
            return CurrencyFormatter.formatPercent(snapshot.combinedPercentChange)
        case .splitDollars:
            return Self.formatSplitMenuBarTitle(
                snapshot.holdings.map { CurrencyFormatter.formatCurrency($0.paperGain) }
            )
        case .splitPercent:
            return Self.formatSplitMenuBarTitle(
                snapshot.holdings.map { CurrencyFormatter.formatPercent($0.quote.percentChange) }
            )
        case .totalWorth:
            return CurrencyFormatter.formatMarketValue(snapshot.combinedMarketValue)
        }
    }

    var gainColor: GainColor {
        guard let snapshot else { return .neutral }
        if settings.menuBarDisplayMode == .totalWorth { return .neutral }
        if snapshot.combinedPaperGain > 0 { return .positive }
        if snapshot.combinedPaperGain < 0 { return .negative }
        return .neutral
    }

    var marketCloseStatusLabel: String? {
        guard let snapshot, snapshot.tradingSession == .closed else { return nil }
        if hasStaleData || marketHours.isQuotable(at: snapshot.lastUpdated) {
            return MarketStatusFormatter.asOfLiveLabel(date: snapshot.lastUpdated)
        }
        return MarketStatusFormatter.asOfCloseLabel(for: snapshot.lastUpdated, marketHours: marketHours)
    }

    var marketStatusLabel: String? {
        guard let snapshot else { return nil }
        if snapshot.tradingSession == .closed {
            return marketCloseStatusLabel ?? MarketStatusFormatter.sessionStatusLabel(for: .closed)
        }
        return MarketStatusFormatter.sessionStatusLabel(for: snapshot.tradingSession)
    }

    var marketStatusDetail: String? {
        guard let snapshot, snapshot.tradingSession == .closed else { return nil }
        guard let nextOpen = marketHours.nextOpenDate(from: marketClock) else { return nil }
        return MarketStatusFormatter.nextOpenLabel(for: nextOpen)
    }

    var menuBarTooltip: String {
        guard let snapshot else {
            return isLoading ? "Muskometer — loading…" : "Muskometer"
        }

        var lines = ["Muskometer", "⌥-click to cycle display · \(settings.menuBarDisplayMode.label)"]
        if settings.menuBarDisplayMode == .totalWorth {
            lines.append("Total worth: \(CurrencyFormatter.formatMarketValue(snapshot.combinedMarketValue))")
        }
        for holding in snapshot.holdings {
            let gain = CurrencyFormatter.formatCurrency(holding.paperGain)
            let percent = CurrencyFormatter.formatPercent(holding.quote.percentChange)
            lines.append("\(holding.symbol): \(gain) (\(percent))")
        }
        lines.append("Combined: \(CurrencyFormatter.formatCurrency(snapshot.combinedPaperGain))")
        lines.append("Updated \(snapshot.lastUpdated.formatted(date: .omitted, time: .shortened))")
        if hasStaleData {
            lines.append("Stale — last good quotes; open Muskometer and Refresh")
        }
        if let closeLabel = marketCloseStatusLabel {
            lines.append(closeLabel)
        }
        if let detail = marketStatusDetail {
            lines.append(detail)
        }
        return lines.joined(separator: "\n")
    }

    var shouldDimMenuBarLabel: Bool {
        guard let snapshot else { return false }
        if settings.menuBarDisplayMode == .totalWorth { return false }
        return snapshot.tradingSession == .closed
    }

    func copyShareToPasteboard() -> Bool {
        guard let snapshot else { return false }

        let parity = settings.showMergerParityCard ? mergerParityPresentation : nil
        return ShareImageExporter.copyToPasteboard(
            snapshot: snapshot,
            profile: settings.selectedProfile,
            format: settings.shareFormat,
            intradaySamples: intradaySamples,
            parity: parity
        )
    }

    /// Opens the system share sheet with the current share format (image or text).
    @discardableResult
    func presentSystemShare() -> Bool {
        guard let snapshot else { return false }
        let parity = settings.showMergerParityCard ? mergerParityPresentation : nil
        let items = ShareImageExporter.shareItems(
            snapshot: snapshot,
            profile: settings.selectedProfile,
            format: settings.shareFormat,
            intradaySamples: intradaySamples,
            parity: parity
        )
        return ShareSheetPresenter.present(items: items)
    }

    func clearActiveMilestone() {
        activeMilestone = nil
    }

    func reloadPersistedDisplayState() {
        let restart = hasStarted
        stop()
        defer { if restart { start() } }
        let personID = settings.selectedPersonID
        enabledNotificationThresholdIDs = gainThresholdNotificationService.enabledThresholdIDs(for: personID)
        intradayGainSampleStore.reloadFromDefaults(for: personID)
        intradaySamples = intradayGainSampleStore.loadSamples(for: personID)
        gainThresholdNotificationService.resetRuntimeState(for: personID)
        dailyRecordTracker.resetRuntimeState(for: personID)
        activeMilestone = nil
        trillionEasterEggMessage = nil
        dailyRecordsSnapshot = dailyRecordTracker.snapshot(for: personID)
    }

    func setNotificationThresholdEnabled(_ thresholdID: String, enabled: Bool) {
        var ids = gainThresholdNotificationService.enabledThresholdIDs(for: settings.selectedPersonID)
        if enabled {
            ids.insert(thresholdID)
            Task { @MainActor in
                let granted = await NotificationAuthorization.requestIfNeeded()
                // Clear any prior denied hint when permission is granted.
                notificationAuthorizationMessage = granted ? nil : NotificationAuthorization.deniedHint
            }
        } else {
            ids.remove(thresholdID)
            // Clear denied-authorization hint only when no thresholds remain enabled.
            // If others stay on and auth is still denied, keep the existing hint.
            if ids.isEmpty {
                notificationAuthorizationMessage = nil
            }
        }
        gainThresholdNotificationService.setEnabledThresholdIDs(ids, for: settings.selectedPersonID)
        enabledNotificationThresholdIDs = ids
    }

    func setNotifyDayCloseSummaryEnabled(_ enabled: Bool) {
        settings.notifyDayCloseSummary = enabled
        if enabled {
            Task { @MainActor in
                let granted = await NotificationAuthorization.requestIfNeeded()
                notificationAuthorizationMessage = granted ? nil : NotificationAuthorization.deniedHint
            }
        } else if enabledNotificationThresholdIDs.isEmpty {
            notificationAuthorizationMessage = nil
        }
    }

    /// Refreshes the denied-auth hint when any gain threshold is enabled (e.g. Alerts tab appear).
    /// Uses `requestIfNeeded`, which only prompts when status is notDetermined.
    func refreshNotificationAuthorizationMessageIfNeeded() {
        guard !enabledNotificationThresholdIDs.isEmpty || settings.notifyDayCloseSummary else {
            notificationAuthorizationMessage = nil
            return
        }
        Task { @MainActor in
            let granted = await NotificationAuthorization.requestIfNeeded()
            // Thresholds may have been cleared while awaiting auth status.
            guard !enabledNotificationThresholdIDs.isEmpty || settings.notifyDayCloseSummary else {
                notificationAuthorizationMessage = nil
                return
            }
            notificationAuthorizationMessage = granted ? nil : NotificationAuthorization.deniedHint
        }
    }

    private func processSnapshotSideEffects(_ snapshot: GainsSnapshot) {
        let personID = settings.selectedPersonID

        if let lastPersonID = lastSideEffectPersonID, lastPersonID != personID {
            reloadPersonScopedDisplayState(for: personID)
        }
        lastSideEffectPersonID = personID

        dailyRecordsSnapshot = dailyRecordTracker.update(
            personID: personID,
            paperGain: snapshot.combinedPaperGain,
            at: snapshot.lastUpdated,
            isQuotable: snapshot.isQuotable
        )

        intradayGainSampleStore.append(
            personID: personID,
            combinedPaperGain: snapshot.combinedPaperGain,
            at: snapshot.lastUpdated
        )
        intradaySamples = intradayGainSampleStore.loadSamples(for: personID)

        if let event = netWorthMilestoneTracker.update(
            netWorth: snapshot.combinedMarketValue,
            personID: personID,
            at: snapshot.lastUpdated
        ) {
            switch event {
            case .celebration(let milestone):
                activeMilestone = milestone
                trillionEasterEggMessage = nil
            case .fellBelowTrillion(let message):
                trillionEasterEggMessage = message
            }
        }

        let zone = netWorthMilestoneTracker.currentZone(for: personID)
        if zone == .aboveOneTrillion || zone == .aboveTwoTrillion {
            trillionEasterEggMessage = nil
        }

    }

    private func advanceTradingClock() {
        let now = dateProvider()
        marketClock = now
        dailyRecordsSnapshot = dailyRecordTracker.advanceClock(personID: settings.selectedPersonID, at: now)
        // Clock-only observations invalidate yesterday's pending gain alerts without
        // claiming a fresh price or creating a threshold crossing.
        gainThresholdNotificationService.observeUpdate(paperGain: snapshot?.combinedPaperGain ?? 0,
            personID: settings.selectedPersonID, possessiveName: settings.selectedProfile.possessiveName,
            at: now, isQuotable: false)
        if let previous = snapshot {
            snapshot = GainsSnapshot(holdings: previous.holdings, lastUpdated: previous.lastUpdated,
                                     tradingSession: marketHours.currentSession(at: now))
        }
        syncIntradaySamplesFromStore()
    }

    @discardableResult
    private func beginPendingSummary() -> Task<Void, Never>? {
        guard summaryTasks.count < Self.maximumPhysicalRequests else { return nil }
        let personID = settings.selectedPersonID
        guard let finalized = dailyRecordTracker.peekPendingFinalizedDay(for: personID) else { return nil }
        let service = dayCloseSummaryNotificationService
        let tracker = dailyRecordTracker
        let name = settings.selectedProfile.possessiveName
        let enabled = settings.notifyDayCloseSummary
        let token = lifecycle, id = UUID()
        let task = Task { [weak self] in
            defer { self?.summaryTasks.removeValue(forKey: id) }
            guard !Task.isCancelled, self?.lifecycle == token else { return }
            let outcome = await service.deliverIfNeeded(finalized: finalized, personID: personID,
                                                       possessiveName: name, enabled: enabled)
            guard !Task.isCancelled, self?.lifecycle == token else { return }
            if outcome == .delivered || outcome == .skipped {
                tracker.consumePendingFinalizedDay(for: personID, matching: finalized)
            }
        }
        summaryTasks[id] = task
        return task
    }

    private func reloadPersonScopedDisplayState(for personID: String) {
        intradayGainSampleStore.reloadFromDefaults(for: personID)
        intradaySamples = intradayGainSampleStore.loadSamples(for: personID)
    }

    /// Reloads display samples from the store for the selected person.
    /// Retains the last completed RTH session overnight; new-day clear happens on the first RTH append.
    func syncIntradaySamplesFromStore() {
        let personID = settings.selectedPersonID
        intradaySamples = intradayGainSampleStore.loadSamples(for: personID)
    }

    private func offMarketSleepInterval() -> TimeInterval {
        let now = dateProvider()
        if let nextOpen = marketHours.nextOpenDate(from: now) {
            // Sleep until open (tiny epsilon only). A 60s floor delayed first RTH refresh.
            return max(nextOpen.timeIntervalSince(now), 0.5)
        }
        return 300
    }

    /// Settings interval during the regular session. Pre/post are not quotable (RTH-only).
    private func refreshSleepInterval() -> TimeInterval {
        TimeInterval(settings.refreshIntervalSeconds)
    }

    /// Timing for one iteration of the live refresh loop after evaluating market quotability.
    nonisolated enum OpenSessionRefreshTiming: Equatable {
        /// Market not quotable — wait off-market, then re-evaluate (do not refresh).
        case waitOffMarket
        /// First cycle of a quotable session — refresh without pre-sleep.
        case refreshImmediately
        /// Subsequent open-session cycles — sleep the interval, then refresh.
        case sleepThenRefresh
    }

    /// Decides whether to sleep before the next open-session refresh.
    /// Skip the pre-refresh sleep when first entering a quotable session (e.g. after
    /// off-market wait ends at regular open, or always-open overnight wake at open).
    nonisolated static func openSessionRefreshTiming(isQuotable: Bool, wasQuotable: Bool) -> OpenSessionRefreshTiming {
        guard isQuotable else { return .waitOffMarket }
        return wasQuotable ? .sleepThenRefresh : .refreshImmediately
    }

    enum GainColor {
        case positive
        case negative
        case neutral
    }

    static func formatSplitMenuBarTitle(_ parts: [String], maxLength: Int = 28) -> String {
        let joined = parts.joined(separator: "/")
        return joined.truncatedMiddle(maxLength: maxLength)
    }

}