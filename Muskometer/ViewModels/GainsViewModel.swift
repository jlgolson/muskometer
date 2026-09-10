import Foundation
import Observation

@Observable
@MainActor
final class GainsViewModel {
    private(set) var snapshot: GainsSnapshot?
    private(set) var isLoading = false
    private(set) var hasStaleData = false
    private(set) var errorMessage: String?

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
        updateCoordinator: UpdateCoordinator? = nil
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
        self.dateProvider = dateProvider
        self.enabledNotificationThresholdIDs = self.gainThresholdNotificationService.enabledThresholdIDs(
            for: settings.selectedPersonID
        )
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await self?.syncHoldingsIfNeeded()
            await self?.refresh()

            // After the initial refresh, treat current quotability as "already refreshed this session"
            // so the first open-session loop iteration sleeps between refreshes (no double-refresh).
            // When off-market sleep ends into a quotable session, wasQuotable is false and we
            // refresh immediately instead of sleeping another full open-session interval.
            var wasQuotable = false
            if let self {
                wasQuotable = self.marketHours.isQuotable(at: self.dateProvider())
            }

            while !Task.isCancelled {
                let timing: OpenSessionRefreshTiming
                let sleepSeconds: TimeInterval?

                // Scope strong `self` so it is not retained across `Task.sleep`.
                do {
                    guard let self else { return }
                    let isQuotable = self.marketHours.isQuotable(at: self.dateProvider())
                    timing = Self.openSessionRefreshTiming(isQuotable: isQuotable, wasQuotable: wasQuotable)

                    if timing == .waitOffMarket {
                        wasQuotable = false
                        self.syncIntradaySamplesFromStore()
                        sleepSeconds = self.offMarketSleepInterval()
                    } else if timing == .sleepThenRefresh {
                        sleepSeconds = self.refreshSleepInterval()
                    } else {
                        sleepSeconds = nil
                    }
                }

                if let sleepSeconds {
                    try? await Task.sleep(for: .seconds(sleepSeconds))
                    guard !Task.isCancelled else { break }
                }

                if timing == .waitOffMarket {
                    // Still off-market: store keeps prior RTH samples until the next session appends.
                    self?.syncIntradaySamplesFromStore()
                    continue
                }

                wasQuotable = true
                guard let self else { return }

                if self.settings.needsHoldingsSync {
                    await self.syncHoldingsIfNeeded()
                }

                await self.refresh()
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        hasStarted = false
    }

    func refresh(force: Bool = false) async {
        if isLoading, !force { return }

        refreshGeneration += 1
        let generation = refreshGeneration

        isLoading = true
        errorMessage = nil

        defer {
            if generation == refreshGeneration {
                isLoading = false
            }
        }

        let holdings = settings.holdings
        let symbols = holdings.map(\.symbol)

        do {
            let quotes = try await stockService.fetchQuotes(for: symbols)
            let quoteBySymbol = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })

            let holdingGains = holdings.compactMap { holding -> HoldingGain? in
                guard let quote = quoteBySymbol[holding.symbol] else { return nil }
                return HoldingGain(
                    id: holding.id,
                    symbol: holding.symbol,
                    displayName: holding.displayName,
                    shareCount: holding.shareCount,
                    quote: quote
                )
            }

            guard generation == refreshGeneration else { return }

            guard holdingGains.count == holdings.count else {
                errorMessage = "Incomplete quote data received."
                if snapshot != nil {
                    hasStaleData = true
                }
                return
            }

            let newSnapshot = GainsSnapshot(
                holdings: holdingGains,
                lastUpdated: dateProvider(),
                tradingSession: marketHours.currentSession(at: dateProvider())
            )
            snapshot = newSnapshot
            hasStaleData = false
            await processSnapshotSideEffects(newSnapshot)
        } catch {
            guard generation == refreshGeneration else { return }

            errorMessage = error.localizedDescription
            if snapshot != nil {
                hasStaleData = true
            }
        }
    }

    func syncHoldingsIfNeeded(force: Bool = false) async {
        if isSyncingHoldings { return }
        if !force, !settings.needsHoldingsSync { return }

        await syncHoldingsFromSEC()
    }

    func syncHoldingsFromSEC() async {
        guard !isSyncingHoldings else { return }

        isSyncingHoldings = true
        holdingsSyncMessage = nil
        holdingsOwnershipChangeMessage = nil

        defer { isSyncingHoldings = false }

        let profile = settings.selectedProfile
        let expectedSymbols = profile.expectedSymbols
        let priorCounts = Dictionary(
            uniqueKeysWithValues: expectedSymbols.map { ($0, settings.shareCount(for: $0)) }
        )

        do {
            let service = holdingsSyncServiceFactory(profile)
            let result = try await service.syncHoldings()
            // applyHoldingsSync records lastHoldingsSyncAttemptAt for complete and partial.
            let syncComplete = settings.applyHoldingsSync(result)

            if syncComplete {
                let symbols = expectedSymbols.sorted().joined(separator: ", ")
                holdingsSyncMessage = "Holdings updated from SEC (\(symbols))."
                holdingsOwnershipChangeMessage = Self.ownershipChangeToast(
                    prior: priorCounts,
                    current: Dictionary(
                        uniqueKeysWithValues: expectedSymbols.map { ($0, settings.shareCount(for: $0)) }
                    )
                )

                if snapshot != nil {
                    await refresh(force: true)
                }
            } else {
                // Partial sync does not change share counts — message only, no refresh.
                // Attempt is recorded so auto-retry waits holdingsSyncInterval (not every quote cycle).
                let found = result.sharesBySymbol.keys
                    .filter { expectedSymbols.contains($0) }
                    .sorted()

                if found.isEmpty {
                    holdingsSyncMessage = "SEC sync incomplete — will retry later."
                } else {
                    holdingsSyncMessage = "SEC sync incomplete — will retry later (\(found.joined(separator: ", ")) found)."
                }
            }
        } catch {
            // Record failed attempts so network errors also back off for 24h.
            settings.recordHoldingsSyncAttempt()
            holdingsSyncMessage = "SEC sync failed: \(error.localizedDescription)"
        }

        // Best-effort issuer outstanding (companyfacts). Independent of Form 4 outcome;
        // never alters holdingsSyncMessage on failure.
        await syncIssuerOutstanding(for: profile)
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

    /// Fetches companyfacts outstanding for the profile's holding specs and persists positive results.
    private func syncIssuerOutstanding(for profile: TrackedPersonProfile) async {
        let service = outstandingSyncServiceFactory()
        let outstanding = await service.fetchOutstanding(for: profile.holdingSpecs)
        for (symbol, fact) in outstanding where fact.shares > 0 {
            settings.setSharesOutstanding(
                fact.shares,
                for: symbol,
                provenance: .companyfacts(periodEnd: fact.periodEnd, filed: fact.filed)
            )
        }
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
        return MarketStatusFormatter.asOfCloseLabel(
            for: snapshot.lastUpdated,
            marketHours: marketHours
        )
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
        guard let nextOpen = marketHours.nextOpenDate(from: snapshot.lastUpdated) else { return nil }
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

    private func processSnapshotSideEffects(_ snapshot: GainsSnapshot) async {
        let personID = settings.selectedPersonID
        let profile = settings.selectedProfile

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

        if let finalized = dailyRecordTracker.consumePendingFinalizedDay(for: personID) {
            _ = await dayCloseSummaryNotificationService.deliverIfNeeded(
                finalized: finalized,
                personID: personID,
                possessiveName: profile.possessiveName,
                enabled: settings.notifyDayCloseSummary
            )
        }

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

        await gainThresholdNotificationService.processUpdate(
            paperGain: snapshot.combinedPaperGain,
            personID: personID,
            possessiveName: profile.possessiveName,
            at: snapshot.lastUpdated,
            isQuotable: snapshot.isQuotable
        )
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