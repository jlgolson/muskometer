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

    let settings: AppSettings

    private let stockService: any StockPriceServiceProtocol
    private let holdingsSyncServiceFactory: (TrackedPersonProfile) -> any HoldingsSyncServiceProtocol
    private let marketHours: any MarketHoursServiceProtocol
    private var refreshTask: Task<Void, Never>?
    private var refreshGeneration = 0
    private var hasStarted = false

    init(
        settings: AppSettings = .shared,
        stockService: any StockPriceServiceProtocol = YahooFinanceStockPriceService(),
        holdingsSyncServiceFactory: @escaping (TrackedPersonProfile) -> any HoldingsSyncServiceProtocol = { SECHoldingsSyncService(profile: $0) },
        marketHours: any MarketHoursServiceProtocol = MarketHoursService()
    ) {
        self.settings = settings
        self.stockService = stockService
        self.holdingsSyncServiceFactory = holdingsSyncServiceFactory
        self.marketHours = marketHours
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }

            await self.syncHoldingsIfNeeded()

            await self.refresh()

            while !Task.isCancelled {
                let interval = self.settings.refreshIntervalSeconds
                let sleepSeconds: TimeInterval

                if self.marketHours.isMarketOpen() {
                    sleepSeconds = interval
                } else {
                    sleepSeconds = max(interval, 300)
                }

                try? await Task.sleep(for: .seconds(sleepSeconds))
                guard !Task.isCancelled else { break }

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

            snapshot = GainsSnapshot(
                holdings: holdingGains,
                lastUpdated: .now,
                marketIsOpen: marketHours.isMarketOpen()
            )
            hasStaleData = false
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

        defer { isSyncingHoldings = false }

        let profile = settings.selectedProfile
        let expectedSymbols = profile.expectedSymbols

        do {
            let service = holdingsSyncServiceFactory(profile)
            let result = try await service.syncHoldings()
            let syncComplete = settings.applyHoldingsSync(result)

            if syncComplete {
                let symbols = expectedSymbols.sorted().joined(separator: ", ")
                holdingsSyncMessage = "Holdings updated from SEC (\(symbols))."

                if snapshot != nil {
                    await refresh(force: true)
                }
            } else {
                let found = result.sharesBySymbol.keys
                    .filter { expectedSymbols.contains($0) }
                    .sorted()

                if found.isEmpty {
                    holdingsSyncMessage = "SEC sync incomplete — will retry later."
                } else {
                    holdingsSyncMessage = "SEC sync incomplete — will retry later (\(found.joined(separator: ", ")) found)."
                }

                if !found.isEmpty, snapshot != nil {
                    await refresh(force: true)
                }
            }
        } catch {
            holdingsSyncMessage = "SEC sync failed: \(error.localizedDescription)"
        }
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

    var marketStatusDetail: String? {
        guard let snapshot, !snapshot.marketIsOpen else { return nil }

        if let nextOpen = marketHours.nextOpenDate() {
            return "Based on prior close · \(formatNextOpen(nextOpen))"
        }
        return "Based on prior close"
    }

    var menuBarTooltip: String {
        guard let snapshot else {
            return isLoading ? "Muskometer — loading…" : "Muskometer"
        }

        var lines = ["Muskometer"]
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
        if let detail = marketStatusDetail {
            lines.append(detail)
        }
        return lines.joined(separator: "\n")
    }

    var shouldDimMenuBarLabel: Bool {
        guard let snapshot else { return false }
        if settings.menuBarDisplayMode == .totalWorth { return false }
        return !snapshot.marketIsOpen
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

    private func formatNextOpen(_ date: Date) -> String {
        let eastern = TimeZone(identifier: "America/New_York") ?? .current

        let dayFormatter = DateFormatter()
        dayFormatter.timeZone = eastern
        dayFormatter.dateFormat = "EEE"

        let timeFormatter = DateFormatter()
        timeFormatter.timeZone = eastern
        timeFormatter.dateFormat = "h:mm a"

        let day = dayFormatter.string(from: date)
        let time = timeFormatter.string(from: date)
        return "Opens \(day) \(time) ET"
    }
}