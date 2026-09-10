import AppKit
import UserNotifications
import XCTest
@testable import Muskometer

@MainActor
final class GainsViewModelHoldingsSyncBackoffTests: XCTestCase {
    private func makeSettings() -> AppSettings {
        let suiteName = "MuskometerTests-holdings-backoff-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppSettings(defaults: defaults)
    }

    func testFailedSyncRecordsAttemptAndSuppressesAutoRetry() async {
        let settings = makeSettings()
        XCTAssertTrue(settings.needsHoldingsSync)

        let mock = MockHoldingsSyncService(
            result: .failure(HoldingsSyncError.invalidResponse)
        )
        let viewModel = GainsViewModel(
            settings: settings,
            stockService: MockStockService(quotes: []),
            holdingsSyncServiceFactory: { _ in mock },
            outstandingSyncServiceFactory: { MockIssuerOutstandingSyncService(result: [:]) }
        )

        await viewModel.syncHoldingsFromSEC()

        XCTAssertEqual(mock.callCount, 1)
        XCTAssertNotNil(settings.lastHoldingsSyncAttemptAt)
        XCTAssertNil(settings.lastHoldingsSyncDate)
        XCTAssertFalse(settings.needsHoldingsSync)
        XCTAssertTrue(viewModel.holdingsSyncMessage?.contains("SEC sync failed") == true)

        // Auto path must not re-crawl while within the interval.
        await viewModel.syncHoldingsIfNeeded()
        XCTAssertEqual(mock.callCount, 1)
    }

    func testForceSyncRunsWhenWithinInterval() async {
        let settings = makeSettings()
        settings.recordHoldingsSyncAttempt(at: Date.now)
        XCTAssertFalse(settings.needsHoldingsSync)

        let syncedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let mock = MockHoldingsSyncService(
            result: .success(
                HoldingsSyncResult(
                    sharesBySymbol: ["TSLA": 111, "SPCX": 222],
                    syncedAt: syncedAt,
                    sourceDescription: "SEC EDGAR Form 4"
                )
            )
        )
        let viewModel = GainsViewModel(
            settings: settings,
            stockService: MockStockService(quotes: []),
            holdingsSyncServiceFactory: { _ in mock },
            outstandingSyncServiceFactory: { MockIssuerOutstandingSyncService(result: [:]) }
        )

        // Non-force respects backoff.
        await viewModel.syncHoldingsIfNeeded(force: false)
        XCTAssertEqual(mock.callCount, 0)

        // Force (and manual Sync from SEC) bypasses backoff.
        await viewModel.syncHoldingsIfNeeded(force: true)
        XCTAssertEqual(mock.callCount, 1)
        XCTAssertEqual(settings.lastHoldingsSyncDate, syncedAt)
        XCTAssertEqual(settings.shareCount(for: "TSLA"), 111)
        XCTAssertEqual(settings.shareCount(for: "SPCX"), 222)
    }
}

@MainActor
final class GainsViewModelMergerParityPresentationTests: XCTestCase {
    private func makeSettings() -> AppSettings {
        let suiteName = "MuskometerTests-merger-parity-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppSettings(defaults: defaults)
    }

    func testPresentationNilWithoutSnapshot() {
        let settings = makeSettings()
        let viewModel = GainsViewModel(
            settings: settings,
            stockService: MockStockService(quotes: []),
            outstandingSyncServiceFactory: { MockIssuerOutstandingSyncService(result: [:]) }
        )
        XCTAssertNil(viewModel.mergerParityPresentation)
    }

    func testPresentationUsesSnapshotPricesAndSettingsOutstanding() async throws {
        let settings = makeSettings()
        settings.setSharesOutstanding(2, for: "TSLA")
        settings.setSharesOutstanding(4, for: "SPCX")

        let quotes = [
            StockQuote(symbol: "TSLA", displayName: "Tesla", currentPrice: 100, previousClose: 90, currency: "USD"),
            StockQuote(symbol: "SPCX", displayName: "SpaceX", currentPrice: 50, previousClose: 40, currency: "USD"),
        ]
        let viewModel = GainsViewModel(
            settings: settings,
            stockService: MockStockService(quotes: quotes),
            outstandingSyncServiceFactory: { MockIssuerOutstandingSyncService(result: [:]) }
        )

        await viewModel.refresh(force: true)

        let presentation = try XCTUnwrap(viewModel.mergerParityPresentation)
        // spcx mcap 200 / tsla shares 2 → implied 100; tsla mcap 200
        XCTAssertEqual(presentation.impliedTSLAPrice, 100, accuracy: 1e-9)
        XCTAssertEqual(presentation.spcxMarketCap, 200, accuracy: 1e-9)
        XCTAssertEqual(presentation.tslaMarketCap, 200, accuracy: 1e-9)
    }

    func testPresentationUsesDefaultOutstandingWhenUnset() async throws {
        let settings = makeSettings()
        let tslaPrice = 250.0
        let spcxPrice = 80.0
        let quotes = [
            StockQuote(symbol: "TSLA", displayName: "Tesla", currentPrice: tslaPrice, previousClose: 240, currency: "USD"),
            StockQuote(symbol: "SPCX", displayName: "SpaceX", currentPrice: spcxPrice, previousClose: 70, currency: "USD"),
        ]
        let viewModel = GainsViewModel(
            settings: settings,
            stockService: MockStockService(quotes: quotes),
            outstandingSyncServiceFactory: { MockIssuerOutstandingSyncService(result: [:]) }
        )

        await viewModel.refresh(force: true)

        let presentation = try XCTUnwrap(viewModel.mergerParityPresentation)
        let expected = MergerMarketCapParity.presentation(
            tslaPrice: tslaPrice,
            spcxPrice: spcxPrice,
            tslaOutstanding: IssuerSharesOutstanding.defaultTSLA,
            spcxOutstanding: IssuerSharesOutstanding.defaultSPCX
        )
        XCTAssertEqual(presentation, expected)
    }
}

@MainActor
final class GainsViewModelIssuerOutstandingSyncTests: XCTestCase {
    private func makeSettings() -> AppSettings {
        let suiteName = "MuskometerTests-issuer-outstanding-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppSettings(defaults: defaults)
    }

    func testOutstandingAppliedAfterForm4FailureWithoutChangingMessage() async {
        let settings = makeSettings()
        let holdingsMock = MockHoldingsSyncService(result: .failure(HoldingsSyncError.invalidResponse))
        let outstandingMock = MockIssuerOutstandingSyncService(
            result: ["TSLA": 3_000_000_000, "SPCX": 12_000_000_000]
        )
        let viewModel = GainsViewModel(
            settings: settings,
            stockService: MockStockService(quotes: []),
            holdingsSyncServiceFactory: { _ in holdingsMock },
            outstandingSyncServiceFactory: { outstandingMock }
        )

        await viewModel.syncHoldingsFromSEC()

        XCTAssertEqual(holdingsMock.callCount, 1)
        XCTAssertEqual(outstandingMock.callCount, 1)
        XCTAssertTrue(viewModel.holdingsSyncMessage?.contains("SEC sync failed") == true)
        XCTAssertEqual(settings.sharesOutstanding(for: "TSLA"), 3_000_000_000)
        XCTAssertEqual(settings.sharesOutstanding(for: "SPCX"), 12_000_000_000)
        // Ownership counts unchanged by outstanding sync
        XCTAssertEqual(settings.shareCount(for: "TSLA"), 710_172_677)
        XCTAssertEqual(settings.shareCount(for: "SPCX"), 5_116_475_230)
    }

    func testOutstandingEmptyResultDoesNotChangeDefaultsOrForm4SuccessMessage() async {
        let settings = makeSettings()
        let syncedAt = Date(timeIntervalSince1970: 1_700_000_200)
        let holdingsMock = MockHoldingsSyncService(
            result: .success(
                HoldingsSyncResult(
                    sharesBySymbol: ["TSLA": 111, "SPCX": 222],
                    syncedAt: syncedAt,
                    sourceDescription: "SEC EDGAR Form 4"
                )
            )
        )
        let outstandingMock = MockIssuerOutstandingSyncService(result: [:])
        let viewModel = GainsViewModel(
            settings: settings,
            stockService: MockStockService(quotes: []),
            holdingsSyncServiceFactory: { _ in holdingsMock },
            outstandingSyncServiceFactory: { outstandingMock }
        )

        await viewModel.syncHoldingsFromSEC()

        XCTAssertEqual(holdingsMock.callCount, 1)
        XCTAssertEqual(outstandingMock.callCount, 1)
        XCTAssertTrue(viewModel.holdingsSyncMessage?.contains("Holdings updated from SEC") == true)
        XCTAssertEqual(settings.shareCount(for: "TSLA"), 111)
        XCTAssertEqual(settings.shareCount(for: "SPCX"), 222)
        XCTAssertEqual(settings.sharesOutstanding(for: "TSLA"), IssuerSharesOutstanding.defaultTSLA)
        XCTAssertEqual(settings.sharesOutstanding(for: "SPCX"), IssuerSharesOutstanding.defaultSPCX)
    }
}

@MainActor
final class GainsViewModelExtendedHoursTests: XCTestCase {
    private func makeSettings() -> AppSettings {
        let suiteName = "MuskometerTests-extended-hours-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppSettings(defaults: defaults)
    }

    func testSnapshotUsesTradingSessionFromMarketHours() async {
        let settings = makeSettings()
        let quotes = [
            StockQuote(symbol: "TSLA", displayName: "Tesla", currentPrice: 110, previousClose: 100, currency: "USD"),
            StockQuote(symbol: "SPCX", displayName: "SpaceX", currentPrice: 55, previousClose: 50, currency: "USD"),
        ]
        // RTH-only: non-regular sessions are not quotable (treated like closed).
        let marketHours = FixedMarketHours(session: .closed)
        let viewModel = GainsViewModel(
            settings: settings,
            stockService: MockStockService(quotes: quotes),
            marketHours: marketHours
        )

        await viewModel.refresh(force: true)

        XCTAssertEqual(viewModel.snapshot?.tradingSession, .closed)
        XCTAssertFalse(viewModel.snapshot?.marketIsOpen ?? true)
        XCTAssertFalse(viewModel.snapshot?.isQuotable ?? true)
        XCTAssertEqual(viewModel.marketStatusLabel, "Market closed")
        XCTAssertTrue(viewModel.shouldDimMenuBarLabel)
    }

    func testClosedSessionShowsAsOfCloseLabel() async {
        let settings = makeSettings()
        let quotes = [
            StockQuote(symbol: "TSLA", displayName: "Tesla", currentPrice: 110, previousClose: 100, currency: "USD"),
            StockQuote(symbol: "SPCX", displayName: "SpaceX", currentPrice: 55, previousClose: 50, currency: "USD"),
        ]
        let eastern = TimeZone(identifier: "America/New_York")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = eastern
        let marketHours = MarketHoursService(calendar: calendar, timeZone: eastern)
        var closedComponents = DateComponents()
        closedComponents.timeZone = eastern
        closedComponents.year = 2026
        closedComponents.month = 6
        closedComponents.day = 30
        closedComponents.hour = 21
        closedComponents.minute = 0
        let closedDate = calendar.date(from: closedComponents)!
        let viewModel = GainsViewModel(
            settings: settings,
            stockService: MockStockService(quotes: quotes),
            marketHours: marketHours,
            dateProvider: { closedDate }
        )

        await viewModel.refresh(force: true)

        XCTAssertEqual(viewModel.snapshot?.tradingSession, .closed)
        XCTAssertNotNil(viewModel.marketCloseStatusLabel)
        XCTAssertTrue(viewModel.shouldDimMenuBarLabel)
    }
}

@MainActor
final class GainsViewModelMenuBarTitleTests: XCTestCase {
    func testSplitMenuBarTitleTruncatesLongValues() {
        let title = GainsViewModel.formatSplitMenuBarTitle(["+$46.605B", "+$12.345B"], maxLength: 16)

        XCTAssertEqual(title.count, 16)
        XCTAssertTrue(title.contains("…"))
    }
}

final class GainsViewModelOpenSessionRefreshTimingTests: XCTestCase {
    func testOffMarketAlwaysWaits() {
        XCTAssertEqual(
            GainsViewModel.openSessionRefreshTiming(isQuotable: false, wasQuotable: false),
            .waitOffMarket
        )
        XCTAssertEqual(
            GainsViewModel.openSessionRefreshTiming(isQuotable: false, wasQuotable: true),
            .waitOffMarket
        )
    }

    func testFirstQuotableCycleRefreshesImmediately() {
        // After off-market sleep ends into regular open, or always-open overnight wake at open.
        XCTAssertEqual(
            GainsViewModel.openSessionRefreshTiming(isQuotable: true, wasQuotable: false),
            .refreshImmediately
        )
    }

    func testSubsequentOpenSessionCyclesSleepThenRefresh() {
        XCTAssertEqual(
            GainsViewModel.openSessionRefreshTiming(isQuotable: true, wasQuotable: true),
            .sleepThenRefresh
        )
    }

    func testSessionTransitionSequence() {
        // Simulate: closed → open first cycle → open subsequent → closed again → re-open
        var wasQuotable = false

        XCTAssertEqual(
            GainsViewModel.openSessionRefreshTiming(isQuotable: false, wasQuotable: wasQuotable),
            .waitOffMarket
        )
        wasQuotable = false

        XCTAssertEqual(
            GainsViewModel.openSessionRefreshTiming(isQuotable: true, wasQuotable: wasQuotable),
            .refreshImmediately
        )
        wasQuotable = true

        XCTAssertEqual(
            GainsViewModel.openSessionRefreshTiming(isQuotable: true, wasQuotable: wasQuotable),
            .sleepThenRefresh
        )
        wasQuotable = true

        XCTAssertEqual(
            GainsViewModel.openSessionRefreshTiming(isQuotable: false, wasQuotable: wasQuotable),
            .waitOffMarket
        )
        wasQuotable = false

        XCTAssertEqual(
            GainsViewModel.openSessionRefreshTiming(isQuotable: true, wasQuotable: wasQuotable),
            .refreshImmediately
        )
    }
}

@MainActor
final class GainsViewModelCopyShareTests: XCTestCase {
    private func makeSettings() -> AppSettings {
        let suiteName = "MuskometerTests-copy-share-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let settings = AppSettings(defaults: defaults)
        settings.shareFormat = .text
        return settings
    }

    func testCopyShareReturnsFalseWithoutSnapshot() {
        let viewModel = GainsViewModel(
            settings: makeSettings(),
            stockService: MockStockService(quotes: [])
        )

        XCTAssertFalse(viewModel.copyShareToPasteboard())
    }

    func testCopyShareReturnsTrueAndWritesPasteboard() async {
        let settings = makeSettings()
        let quotes = [
            StockQuote(
                symbol: "TSLA",
                displayName: "Tesla",
                currentPrice: 110,
                previousClose: 100,
                currency: "USD"
            ),
            StockQuote(
                symbol: "SPCX",
                displayName: "SpaceX",
                currentPrice: 55,
                previousClose: 50,
                currency: "USD"
            ),
        ]
        let viewModel = GainsViewModel(
            settings: settings,
            stockService: MockStockService(quotes: quotes)
        )

        await viewModel.refresh(force: true)

        guard let snapshot = viewModel.snapshot else {
            return XCTFail("Expected snapshot after refresh")
        }

        XCTAssertTrue(viewModel.copyShareToPasteboard())
        XCTAssertEqual(
            NSPasteboard.general.string(forType: .string),
            GainSummaryFormatter.format(snapshot, parity: viewModel.mergerParityPresentation)
        )

        settings.showMergerParityCard = false
        XCTAssertTrue(viewModel.copyShareToPasteboard())
        XCTAssertEqual(
            NSPasteboard.general.string(forType: .string),
            GainSummaryFormatter.format(snapshot)
        )
        XCTAssertFalse(
            (NSPasteboard.general.string(forType: .string) ?? "")
                .contains("If Tesla had SpaceX's market cap")
        )
    }
}

@MainActor
final class GainsViewModelDayCloseNotificationTests: XCTestCase {
    private final class SucceedingDeliverer: DayCloseSummaryNotificationDelivering, @unchecked Sendable {
        private(set) var requests: [UNNotificationRequest] = []
        func add(_ request: UNNotificationRequest) async throws {
            requests.append(request)
        }
    }

    private final class FailingDeliverer: DayCloseSummaryNotificationDelivering, @unchecked Sendable {
        private(set) var attempts = 0
        func add(_ request: UNNotificationRequest) async throws {
            attempts += 1
            throw URLError(.notConnectedToInternet)
        }
    }

    private func quotes(producingCombinedGain gain: Double) -> [StockQuote] {
        let tslaShares = 100.0
        let tslaDelta = gain / tslaShares
        return [
            StockQuote(
                symbol: "TSLA",
                displayName: "Tesla",
                currentPrice: 100 + tslaDelta,
                previousClose: 100,
                currency: "USD"
            ),
            StockQuote(
                symbol: "SPCX",
                displayName: "SpaceX",
                currentPrice: 50,
                previousClose: 50,
                currency: "USD"
            ),
        ]
    }

    private func makeViewModel(
        deliverer: any DayCloseSummaryNotificationDelivering,
        notifyEnabled: Bool,
        dateProvider: @escaping () -> Date
    ) -> (GainsViewModel, DailyRecordTracker) {
        let suite = "MuskometerTests-gains-day-close-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let settings = AppSettings(defaults: defaults)
        settings.setShareCount(100, for: "TSLA")
        settings.setShareCount(100, for: "SPCX")
        settings.notifyDayCloseSummary = notifyEnabled

        let calendar = EasternTestDates.calendar()
        let marketHours = MarketHoursService(calendar: calendar, timeZone: EasternTestDates.eastern)
        let tradingCalendar = TradingDayCalendar(calendar: calendar, timeZone: EasternTestDates.eastern)
        let tracker = DailyRecordTracker(
            defaults: defaults,
            calendar: tradingCalendar,
            marketHours: marketHours
        )
        let dayCloseService = DayCloseSummaryNotificationService(defaults: defaults, deliverer: deliverer)

        let viewModel = GainsViewModel(
            settings: settings,
            stockService: MockStockService(quotes: quotes(producingCombinedGain: 5_000_000_000)),
            marketHours: marketHours,
            dailyRecordTracker: tracker,
            dayCloseSummaryNotificationService: dayCloseService,
            dateProvider: dateProvider
        )
        return (viewModel, tracker)
    }

    func testFailedDayCloseDeliveryKeepsPending() async throws {
        var now = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let deliverer = FailingDeliverer()
        let (viewModel, tracker) = makeViewModel(
            deliverer: deliverer,
            notifyEnabled: true,
            dateProvider: { now }
        )

        await viewModel.refresh(force: true)
        XCTAssertNil(tracker.peekPendingFinalizedDay(for: "musk"))

        now = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 20)
        await viewModel.refresh(force: true)

        XCTAssertEqual(deliverer.attempts, 1)
        XCTAssertEqual(tracker.peekPendingFinalizedDay(for: "musk")?.dayKey, "2026-06-30")
        XCTAssertEqual(tracker.peekPendingFinalizedDay(for: "musk")?.closeGain, 5_000_000_000)
    }

    func testSuccessfulDayCloseDeliveryConsumesPending() async throws {
        var now = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let deliverer = SucceedingDeliverer()
        let (viewModel, tracker) = makeViewModel(
            deliverer: deliverer,
            notifyEnabled: true,
            dateProvider: { now }
        )

        await viewModel.refresh(force: true)
        XCTAssertNil(tracker.peekPendingFinalizedDay(for: "musk"))

        now = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 20)
        await viewModel.refresh(force: true)

        XCTAssertEqual(deliverer.requests.count, 1)
        XCTAssertNil(tracker.peekPendingFinalizedDay(for: "musk"))
    }

    func testSkippedDayCloseDeliveryConsumesPending() async throws {
        var now = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let deliverer = SucceedingDeliverer()
        let (viewModel, tracker) = makeViewModel(
            deliverer: deliverer,
            notifyEnabled: false,
            dateProvider: { now }
        )

        await viewModel.refresh(force: true)
        now = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 20)
        await viewModel.refresh(force: true)

        XCTAssertTrue(deliverer.requests.isEmpty)
        XCTAssertNil(tracker.peekPendingFinalizedDay(for: "musk"))
    }
}

@MainActor
final class GainsViewModelResetTests: XCTestCase {
    private func makeSettings(suiteName: String = "MuskometerTests-reset-\(UUID().uuidString)") -> (AppSettings, UserDefaults) {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (AppSettings(defaults: defaults), defaults)
    }

    private func quotes(producingCombinedGain gain: Double) -> [StockQuote] {
        let tslaShares = 100.0
        let tslaDelta = gain / tslaShares

        return [
            StockQuote(
                symbol: "TSLA",
                displayName: "Tesla",
                currentPrice: 100 + tslaDelta,
                previousClose: 100,
                currency: "USD"
            ),
            StockQuote(
                symbol: "SPCX",
                displayName: "SpaceX",
                currentPrice: 50,
                previousClose: 50,
                currency: "USD"
            ),
        ]
    }

    func testResetToDefaultsClearsIntradaySamplesInViewModel() async throws {
        let (settings, defaults) = makeSettings()
        settings.setShareCount(100, for: "TSLA")
        settings.setShareCount(100, for: "SPCX")

        let date = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let calendar = EasternTestDates.calendar()
        let intradayStore = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: FixedMarketHours(isOpen: true),
            now: { date }
        )

        let viewModel = GainsViewModel(
            settings: settings,
            stockService: MutableMockStockService(quotes: quotes(producingCombinedGain: 1_000_000_000)),
            intradayGainSampleStore: intradayStore,
            dateProvider: { date }
        )

        await viewModel.refresh(force: true)
        XCTAssertFalse(viewModel.intradaySamples.isEmpty)

        settings.resetToDefaults()
        viewModel.reloadPersistedDisplayState()

        XCTAssertTrue(viewModel.intradaySamples.isEmpty)
    }
}

@MainActor
final class GainsViewModelOffMarketSparklineTests: XCTestCase {
    private func makeSettings(suiteName: String = "MuskometerTests-offmarket-spark-\(UUID().uuidString)") -> (AppSettings, UserDefaults) {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (AppSettings(defaults: defaults), defaults)
    }

    private func quotes(producingCombinedGain gain: Double) -> [StockQuote] {
        let tslaShares = 100.0
        let tslaDelta = gain / tslaShares
        return [
            StockQuote(
                symbol: "TSLA",
                displayName: "Tesla",
                currentPrice: 100 + tslaDelta,
                previousClose: 100,
                currency: "USD"
            ),
            StockQuote(
                symbol: "SPCX",
                displayName: "SpaceX",
                currentPrice: 50,
                previousClose: 50,
                currency: "USD"
            ),
        ]
    }

    /// Off-market overnight: store sync keeps last RTH session sparkline after ET day rollover
    /// (share card still shows yesterday's session curve until the next RTH append).
    func testSyncIntradaySamplesFromStoreKeepsPriorRTHAfterETDayRollover() async throws {
        let (settings, defaults) = makeSettings()
        settings.setShareCount(100, for: "TSLA")
        settings.setShareCount(100, for: "SPCX")

        let monday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let tuesdayOvernight = try EasternTestDates.date(year: 2026, month: 7, day: 1, hour: 2)
        let calendar = EasternTestDates.calendar()

        var now = monday
        let intradayStore = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: FixedMarketHours(isOpen: true),
            now: { now }
        )

        let viewModel = GainsViewModel(
            settings: settings,
            stockService: MutableMockStockService(quotes: quotes(producingCombinedGain: 1_000_000_000)),
            marketHours: FixedMarketHours(isOpen: true),
            intradayGainSampleStore: intradayStore,
            dateProvider: { now }
        )

        await viewModel.refresh(force: true)
        let samplesAfterOpen = viewModel.intradaySamples
        XCTAssertFalse(samplesAfterOpen.isEmpty, "expected samples after open-session refresh")

        // Wall clock advances past ET midnight; off-market sync must retain prior RTH samples.
        now = tuesdayOvernight
        viewModel.syncIntradaySamplesFromStore()

        XCTAssertEqual(viewModel.intradaySamples.count, samplesAfterOpen.count)
        XCTAssertEqual(
            viewModel.intradaySamples.map(\.combinedPaperGain),
            samplesAfterOpen.map(\.combinedPaperGain)
        )
    }

    func testSyncIntradaySamplesFromStorePreservesSameDaySamples() async throws {
        let (settings, defaults) = makeSettings()
        settings.setShareCount(100, for: "TSLA")
        settings.setShareCount(100, for: "SPCX")

        let morning = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let evening = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 21)
        let calendar = EasternTestDates.calendar()

        var now = morning
        let intradayStore = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: FixedMarketHours(isOpen: true),
            now: { now }
        )

        let viewModel = GainsViewModel(
            settings: settings,
            stockService: MutableMockStockService(quotes: quotes(producingCombinedGain: 2_000_000_000)),
            marketHours: FixedMarketHours(isOpen: true),
            intradayGainSampleStore: intradayStore,
            dateProvider: { now }
        )

        await viewModel.refresh(force: true)
        let samplesAfterOpen = viewModel.intradaySamples
        XCTAssertFalse(samplesAfterOpen.isEmpty)

        // Same ET day after close: sparkline should remain (user still wants today's curve).
        now = evening
        viewModel.syncIntradaySamplesFromStore()

        XCTAssertEqual(viewModel.intradaySamples.count, samplesAfterOpen.count)
        XCTAssertEqual(
            viewModel.intradaySamples.map(\.combinedPaperGain),
            samplesAfterOpen.map(\.combinedPaperGain)
        )
    }
}

@MainActor
final class GainsViewModelTrillionEasterEggTests: XCTestCase {
    private let personID = TrackedPersonProfile.musk.id

    private func makeSettings(defaults: UserDefaults) -> AppSettings {
        AppSettings(defaults: defaults)
    }

    private func quotes(netWorth: Double) -> [StockQuote] {
        let shareCount = 1.0
        return [
            StockQuote(
                symbol: "TSLA",
                displayName: "Tesla",
                currentPrice: netWorth / shareCount,
                previousClose: (netWorth / shareCount) - 1,
                currency: "USD"
            ),
            StockQuote(
                symbol: "SPCX",
                displayName: "SpaceX",
                currentPrice: 1,
                previousClose: 1,
                currency: "USD"
            ),
        ]
    }

    func testClearsTrillionEasterEggWhenNetWorthRecoversAboveOneTrillion() async {
        let suiteName = "MuskometerTests-trillion-easter-egg-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let settings = makeSettings(defaults: defaults)
        settings.setShareCount(1, for: "TSLA")
        settings.setShareCount(0, for: "SPCX")

        let tracker = NetWorthMilestoneTracker(defaults: defaults)
        let stockService = MutableMockStockService(quotes: quotes(netWorth: 1_100_000_000_000))
        let viewModel = GainsViewModel(
            settings: settings,
            stockService: stockService,
            netWorthMilestoneTracker: tracker
        )

        await viewModel.refresh(force: true)
        XCTAssertNil(viewModel.trillionEasterEggMessage)

        stockService.quotes = quotes(netWorth: 900_000_000_000)
        await viewModel.refresh(force: true)
        XCTAssertNotNil(viewModel.trillionEasterEggMessage)

        defaults.set(
            NetWorthZone.aboveOneTrillion.rawValue,
            forKey: "netWorthMilestoneZone_\(personID)"
        )

        stockService.quotes = quotes(netWorth: 1_050_000_000_000)
        await viewModel.refresh(force: true)

        XCTAssertNil(viewModel.trillionEasterEggMessage)
        XCTAssertEqual(tracker.currentZone(for: personID), .aboveOneTrillion)
    }
}

import Observation

// Gated boundaries intentionally ignore cancellation so late completions are exercised.
private actor LifecycleQuotes: StockPriceServiceProtocol {
    var calls = 0
    var price = 101.0
    var previous = 100.0
    var fail = false
    var partial = false
    var gated = false
    var waits: [Int: CheckedContinuation<Void, Never>] = [:]
    func configure(price: Double? = nil, previous: Double? = nil, fail: Bool = false, partial: Bool = false, gated: Bool = false) {
        if let price { self.price = price }; if let previous { self.previous = previous }
        self.fail = fail; self.partial = partial; self.gated = gated
    }
    func fetchQuotes(for symbols: [String]) async throws -> [StockQuote] {
        calls += 1
        let id = calls, value = price, prior = previous, fails = fail, incomplete = partial
        if gated { await withCheckedContinuation { waits[id] = $0 } }
        if fails { throw URLError(.notConnectedToInternet) }
        return (incomplete ? Array(symbols.prefix(1)) : symbols).map {
            StockQuote(symbol: $0, displayName: $0, currentPrice: value, previousClose: prior, currency: "USD")
        }
    }
    func release(_ id: Int) { waits.removeValue(forKey: id)?.resume() }
}

private actor LifecycleHoldings: HoldingsSyncServiceProtocol {
    var calls = 0
    var waits: [Int: CheckedContinuation<HoldingsSyncResult, Error>] = [:]
    func syncHoldings() async throws -> HoldingsSyncResult {
        calls += 1
        let id = calls
        return try await withCheckedThrowingContinuation { waits[id] = $0 }
    }
    func release(_ id: Int, count: Int64 = 2, fails: Bool = false) {
        let wait = waits.removeValue(forKey: id)
        if fails { wait?.resume(throwing: HoldingsSyncError.invalidResponse) }
        else { wait?.resume(returning: HoldingsSyncResult(sharesBySymbol: ["TSLA": count, "SPCX": 0], syncedAt: .now, sourceDescription: "Fixture")) }
    }
}

private actor LifecycleNotifications: DayCloseSummaryNotificationDelivering, GainThresholdNotificationDelivering {
    var requests: [UNNotificationRequest] = []
    var waits: [Int: CheckedContinuation<Void, Error>] = [:]
    func add(_ request: UNNotificationRequest) async throws {
        requests.append(request)
        let id = requests.count
        try await withCheckedThrowingContinuation { waits[id] = $0 }
    }
    func release(_ id: Int, fails: Bool = false) {
        let wait = waits.removeValue(forKey: id)
        if fails { wait?.resume(throwing: URLError(.notConnectedToInternet)) } else { wait?.resume() }
    }
}

private actor LifecycleOutstanding: IssuerOutstandingSyncServiceProtocol {
    var started = false
    var continuation: CheckedContinuation<Void, Never>?
    func fetchOutstanding(for specs: [TrackedHoldingSpec]) async -> [String: IssuerOutstandingFact] {
        started = true
        await withCheckedContinuation { continuation = $0 }
        return [:]
    }
    func release() { continuation?.resume(); continuation = nil }
}

private actor LifecycleSleeper {
    var intervals: [TimeInterval] = []
    var waits: [Int: CheckedContinuation<Void, Error>] = [:]
    func sleep(_ seconds: TimeInterval) async throws {
        intervals.append(seconds)
        let id = intervals.count
        try await withCheckedThrowingContinuation { waits[id] = $0 }
    }
    func wake(_ id: Int, cancelled: Bool = false) {
        let wait = waits.removeValue(forKey: id)
        if cancelled { wait?.resume(throwing: CancellationError()) } else { wait?.resume() }
    }
}

@MainActor
final class GainsViewModelLifecycleRegressionTests: XCTestCase {
    private final class Clock { var now: Date; init(_ now: Date) { self.now = now } }
    private struct Fixture {
        let vm: GainsViewModel
        let settings: AppSettings
        let defaults: UserDefaults
        let tracker: DailyRecordTracker
        let milestones: NetWorthMilestoneTracker
        let stock: LifecycleQuotes
        let holdings: LifecycleHoldings
        let notifications: LifecycleNotifications
        let sleeper: LifecycleSleeper
        let clock: Clock
    }
    private func date(_ day: Int = 30, _ hour: Int = 11, _ minute: Int = 0, month: Int = 6) -> Date {
        try! EasternTestDates.date(year: 2026, month: month, day: day, hour: hour, minute: minute)
    }
    private func fixture(at now: Date? = nil, notify: Bool = false, due: Bool = false, thresholds: Set<String> = [], outstanding: any IssuerOutstandingSyncServiceProtocol = MockIssuerOutstandingSyncService(result: [:])) -> Fixture {
        let defaults = UserDefaults(suiteName: "Task5-\(UUID().uuidString)")!
        let settings = AppSettings(defaults: defaults)
        settings.setShareCount(1, for: "TSLA"); settings.setShareCount(0, for: "SPCX")
        settings.notifyDayCloseSummary = notify
        if !due { settings.recordHoldingsSyncAttempt() }
        let clock = Clock(now ?? date()), stock = LifecycleQuotes(), holdings = LifecycleHoldings()
        let notifications = LifecycleNotifications(), sleeper = LifecycleSleeper()
        let tracker = DailyRecordTracker(defaults: defaults), milestones = NetWorthMilestoneTracker(defaults: defaults)
        let gains = GainThresholdNotificationService(defaults: defaults, deliverer: notifications)
        gains.setEnabledThresholdIDs(thresholds, for: "musk")
        let vm = GainsViewModel(settings: settings, stockService: stock,
            holdingsSyncServiceFactory: { _ in holdings },
            outstandingSyncServiceFactory: { outstanding },
            dailyRecordTracker: tracker,
            gainThresholdNotificationService: gains,
            dayCloseSummaryNotificationService: DayCloseSummaryNotificationService(defaults: defaults, deliverer: notifications),
            intradayGainSampleStore: IntradayGainSampleStore(defaults: defaults),
            netWorthMilestoneTracker: milestones, dateProvider: { clock.now },
            sleeper: { try await sleeper.sleep($0) })
        return Fixture(vm: vm, settings: settings, defaults: defaults, tracker: tracker, milestones: milestones,
                       stock: stock, holdings: holdings, notifications: notifications, sleeper: sleeper, clock: clock)
    }
    private func settle(_ predicate: () async -> Bool) async {
        for _ in 0..<10000 { if await predicate() { return }; await Task.yield() }
    }

    func testGatedSECDoesNotBlockInitialQuotesAndChangedCountsRefreshOnce() async {
        let f = fixture(due: true)
        f.vm.start()
        await settle { await f.holdings.calls == 1 }
        await settle { f.vm.snapshot != nil }
        XCTAssertNotNil(f.vm.snapshot, "Quotes must arrive while SEC is suspended")
        await f.holdings.release(1)
        await settle { !f.vm.isSyncingHoldings && f.vm.snapshot?.holdings.first?.shareCount == 2 }
        let calls = await f.stock.calls
        XCTAssertEqual(calls, 2, "Initial quote plus exactly one changed-holdings refresh")
        f.vm.stop()
        await f.sleeper.wake(1, cancelled: true)
    }

    func testUnchangedSECSyncDoesNotAddQuoteRefresh() async {
        let f = fixture(due: true)
        await f.vm.refresh()
        let sync = Task { await f.vm.syncHoldingsFromSEC() }
        await settle { await f.holdings.calls == 1 }
        await f.holdings.release(1, count: 1)
        await sync.value
        let calls = await f.stock.calls
        XCTAssertEqual(calls, 1, "Unchanged accepted counts require no quote refresh")
    }

    private func overlap(fails: Bool) async {
        let f = fixture(at: date(1, 10, month: 7), notify: true)
        _ = f.tracker.update(personID: "musk", paperGain: 1e9, at: date(), isQuotable: true)
        await f.stock.configure(price: 989e9, previous: 980e9)
        let older = Task { await f.vm.refresh(force: true) }
        await settle { await f.notifications.requests.count == 1 }
        XCTAssertEqual(f.vm.intradaySamples.map(\.combinedPaperGain), [9e9], "First sample is committed before summary delivery")
        f.clock.now = f.clock.now.addingTimeInterval(1)
        await f.stock.configure(price: 1001e9, previous: 980e9)
        await f.vm.refresh(force: true)
        XCTAssertNotNil(f.tracker.peekPendingFinalizedDay(for: "musk"), "In-flight summary is not an acknowledgment")
        await f.notifications.release(1, fails: fails)
        await older.value
        XCTAssertEqual(f.vm.intradaySamples.map(\.combinedPaperGain), [9e9, 21e9])
        XCTAssertEqual(f.milestones.currentZone(for: "musk"), .aboveOneTrillion)
        XCTAssertNil(f.vm.trillionEasterEggMessage)
        XCTAssertEqual(f.tracker.peekPendingFinalizedDay(for: "musk") != nil, fails)
    }
    func testOlderSuccessfulSummaryCannotOverwriteNewSamplesOrMilestone() async { await overlap(fails: false) }
    func testOlderFailedSummaryRetainsPendingAndNewSamplesOrMilestone() async { await overlap(fails: true) }

    func testFailedClosingFetchFinalizesLastRealObservationAndUpdatesSession() async {
        let f = fixture(at: date(30, 15, 59), notify: true)
        await f.vm.refresh()
        let observed = f.vm.snapshot!.lastUpdated
        f.clock.now = date(30, 16, 1)
        await f.stock.configure(fail: true)
        let closing = Task { await f.vm.refresh(force: true) }
        await settle { await f.notifications.requests.count == 1 }
        XCTAssertTrue(f.vm.dailyRecordsSnapshot.hasCompletedFirstTradingDay)
        XCTAssertEqual(f.vm.snapshot?.tradingSession, .closed)
        XCTAssertEqual(f.vm.snapshot?.lastUpdated, observed)
        XCTAssertTrue(f.vm.hasStaleData)
        let requests = await f.notifications.requests
        XCTAssertTrue(requests.first?.content.body.contains("Last observed session") == true)
        XCTAssertTrue(requests.first?.content.body.contains("3:59 PM") == true)
        XCTAssertEqual(f.vm.intradaySamples.count, 1)
        await f.notifications.release(1, fails: true)
        await closing.value
        XCTAssertEqual(f.tracker.peekPendingFinalizedDay(for: "musk")?.date, observed)
    }

    func testPartialClosingQuotesAdvanceClockWithoutReplacingObservation() async {
        let f = fixture(at: date(30, 15, 59))
        await f.vm.refresh()
        let observed = f.vm.snapshot!.lastUpdated
        f.clock.now = date(30, 16)
        await f.stock.configure(partial: true)
        await f.vm.refresh()
        XCTAssertTrue(f.vm.dailyRecordsSnapshot.hasCompletedFirstTradingDay)
        XCTAssertEqual(f.vm.snapshot?.tradingSession, .closed)
        XCTAssertEqual(f.vm.snapshot?.lastUpdated, observed)
        XCTAssertTrue(f.vm.hasStaleData)
    }

    func testCountChangeDuringFetchUsesCurrentHoldings() async {
        let f = fixture()
        await f.stock.configure(gated: true)
        let refresh = Task { await f.vm.refresh() }
        await settle { await f.stock.calls == 1 }
        f.settings.setShareCount(7, for: "TSLA")
        await f.stock.release(1)
        await refresh.value
        XCTAssertEqual(f.vm.snapshot?.holdings.first?.shareCount, 7)
        XCTAssertEqual(f.vm.snapshot?.combinedPaperGain, 7)
    }

    func testStopInvalidatesLateQuoteSuccessAndFailure() async {
        for fail in [false, true] {
            let f = fixture()
            await f.stock.configure(fail: fail, gated: true)
            let refresh = Task { await f.vm.refresh() }
            await settle { await f.stock.calls == 1 }
            f.vm.stop()
            await f.stock.release(1)
            await refresh.value
            XCTAssertNil(f.vm.snapshot)
            XCTAssertNil(f.vm.errorMessage)
            XCTAssertFalse(f.vm.isLoading)
        }
    }

    func testStopRestartOldSECCannotApplyOrClearNewSync() async {
        let f = fixture(due: true)
        f.vm.start()
        await settle { await f.holdings.calls == 1 }
        f.vm.stop(); f.vm.start()
        await settle { await f.holdings.calls == 2 }
        let calls = await f.holdings.calls
        XCTAssertEqual(calls, 2)
        await f.holdings.release(1, count: 99)
        await settle { f.settings.shareCount(for: "TSLA") == 99 || f.vm.isSyncingHoldings }
        XCTAssertEqual(f.settings.shareCount(for: "TSLA"), 1)
        XCTAssertTrue(f.vm.isSyncingHoldings)
        await f.holdings.release(2, count: 3)
        await settle { !f.vm.isSyncingHoldings }
        XCTAssertEqual(f.settings.shareCount(for: "TSLA"), 3)
        f.vm.stop(); await f.sleeper.wake(1, cancelled: true); await f.sleeper.wake(2, cancelled: true)
    }

    func testResetAndStopInvalidateOldSummaryWithoutConsumingReplacement() async {
        for reset in [false, true] {
            let f = fixture(at: date(1, 10, month: 7), notify: true)
            _ = f.tracker.update(personID: "musk", paperGain: 1e9, at: date(), isQuotable: true)
            let old = Task { await f.vm.refresh() }
            await settle { await f.notifications.requests.count == 1 }
            if reset { f.vm.reloadPersistedDisplayState() } else { f.vm.stop() }
            let replacement = Task { await f.vm.refresh(force: true) }
            await settle { await f.notifications.requests.count == 2 }
            let count = await f.notifications.requests.count
            XCTAssertEqual(count, 2)
            await f.notifications.release(1)
            await old.value
            XCTAssertNil(f.defaults.string(forKey: "dayCloseSummaryNotifiedDay_musk"))
            XCTAssertNotNil(f.tracker.peekPendingFinalizedDay(for: "musk"))
            await f.notifications.release(2, fails: true)
            await replacement.value
            XCTAssertNotNil(f.tracker.peekPendingFinalizedDay(for: "musk"))
        }
    }

    func testLoopBoundsCloseRetryAndRefreshesImmediatelyNextOpen() async {
        let f = fixture(at: date(30, 15, 59))
        f.vm.start()
        await settle { await f.sleeper.intervals.count == 1 }
        f.clock.now = date(30, 16)
        await f.stock.configure(fail: true)
        await f.sleeper.wake(1)
        await settle { await f.sleeper.intervals.count == 2 }
        await f.sleeper.wake(2)
        await settle { await f.sleeper.intervals.count == 3 }
        let closeCalls = await f.stock.calls, sleeps = await f.sleeper.intervals
        XCTAssertEqual(closeCalls, 3, "Initial, close, and one bounded retry")
        XCTAssertTrue((sleeps.last ?? 0) > 3600, "No overnight quote polling")
        XCTAssertTrue(f.vm.dailyRecordsSnapshot.hasCompletedFirstTradingDay)
        f.clock.now = date(1, 9, 30, month: 7)
        await f.stock.configure()
        await f.sleeper.wake(3)
        await settle { f.vm.snapshot?.lastUpdated == f.clock.now }
        XCTAssertEqual(f.vm.snapshot?.lastUpdated, f.clock.now)
        XCTAssertEqual(f.vm.snapshot?.tradingSession, .regular)
        f.vm.stop(); await f.sleeper.wake(4, cancelled: true)
    }

    func testEarlyCloseSleepAndStopCancellationDoNotFetchAgain() async {
        let f = fixture(at: date(27, 12, 59, month: 11))
        f.settings.refreshIntervalSeconds = 300
        f.vm.start()
        await settle { await f.sleeper.intervals.count == 1 }
        let intervals = await f.sleeper.intervals
        XCTAssertEqual(intervals.first, 60, "Refresh sleep must stop at the early close")
        f.vm.stop()
        await f.sleeper.wake(1)
        for _ in 0..<100 { await Task.yield() }
        let calls = await f.stock.calls
        XCTAssertEqual(calls, 1)
    }

    func testStoppedOwnedServicesDoNotRetainViewModel() async {
        var f: Fixture? = fixture(due: true)
        let holdings = f!.holdings, stock = f!.stock
        await stock.configure(gated: true)
        weak var weakVM = f!.vm
        f!.vm.start()
        await settle { let h = await holdings.calls; let q = await stock.calls; return h == 1 && q == 1 }
        f!.vm.stop()
        f = nil
        for _ in 0..<100 { await Task.yield() }
        XCTAssertNil(weakVM, "Cancellation-unaware SEC and quote work cannot own the model")
        await holdings.release(1)
        await stock.release(1)
    }
    func testGatedThresholdDoesNotSuspendScheduledQuotesOrClosingClock() async {
        let f = fixture(at: date(30, 15, 59), thresholds: ["gain-10b"])
        await f.stock.configure(price: 989e9, previous: 980e9)
        await f.vm.refresh()
        await f.stock.configure(price: 991e9, previous: 980e9)
        f.vm.start()
        await settle { await f.notifications.requests.count == 1 }
        await settle { await f.sleeper.intervals.count == 1 }
        let sleepCount = await f.sleeper.intervals.count
        XCTAssertEqual(sleepCount, 1, "The schedule must continue while threshold delivery waits")
        f.clock.now = date(30, 16)
        await f.stock.configure(fail: true)
        await f.sleeper.wake(1)
        await settle { f.vm.dailyRecordsSnapshot.hasCompletedFirstTradingDay }
        XCTAssertTrue(f.vm.dailyRecordsSnapshot.hasCompletedFirstTradingDay)
        f.vm.stop()
        await f.notifications.release(1)
        await f.sleeper.wake(2, cancelled: true)
    }

    func testThresholdObservationsFollowAcceptedSnapshotsWhileOldSummaryWaits() async {
        let f = fixture(at: date(1, 10, month: 7), notify: true, thresholds: ["gain-10b"])
        _ = f.tracker.update(personID: "musk", paperGain: 1e9, at: date(), isQuotable: true)
        await f.stock.configure(price: 989e9, previous: 980e9)
        let old = Task { await f.vm.refresh() }
        await settle { await f.notifications.requests.count == 1 }
        f.clock.now = f.clock.now.addingTimeInterval(1)
        await f.stock.configure(price: 991e9, previous: 980e9)
        let crossing = Task { await f.vm.refresh(force: true) }
        await settle { await f.notifications.requests.count == 2 }
        let requests = await f.notifications.requests
        XCTAssertEqual(requests.count, 2, "9→11 must cross even while yesterday's summary is pending")
        await f.notifications.release(2)
        await crossing.value
        await f.notifications.release(1)
        await old.value
    }

    func testLateQuoteSuccessAndFailureCannotReplaceNewGeneration() async {
        for fails in [false, true] {
            let f = fixture()
            await f.stock.configure(price: 105, fail: fails, gated: true)
            let old = Task { await f.vm.refresh() }
            await settle { await f.stock.calls == 1 }
            f.settings.setShareCount(8, for: "TSLA")
            await f.stock.configure(price: 110)
            await f.vm.refresh(force: true)
            await f.stock.release(1)
            await old.value
            XCTAssertEqual(f.vm.snapshot?.combinedPaperGain, 80)
            XCTAssertNil(f.vm.errorMessage)
            XCTAssertFalse(f.vm.hasStaleData)
        }
    }

    func testSECCanFinishAfterPartialQuotesAndStillRefreshAcceptedCountsOnce() async {
        let f = fixture(due: true)
        await f.stock.configure(partial: true)
        f.vm.start()
        await settle { f.vm.errorMessage != nil && f.vm.isSyncingHoldings }
        await f.stock.configure()
        await f.holdings.release(1, count: 4)
        await settle { !f.vm.isSyncingHoldings }
        XCTAssertEqual(f.vm.snapshot?.combinedPaperGain, 4)
        let calls = await f.stock.calls
        XCTAssertEqual(calls, 2)
        f.vm.stop(); await f.sleeper.wake(1, cancelled: true)
    }

    func testConsecutiveDaysEachHaveOneClosingRequest() async {
        let f = fixture(at: date(30, 15, 59))
        f.vm.start()
        await settle { await f.sleeper.intervals.count == 1 }
        f.clock.now = date(30, 16)
        await f.sleeper.wake(1)
        await settle { await f.sleeper.intervals.count == 2 }
        f.clock.now = date(1, 9, 30, month: 7)
        await f.sleeper.wake(2)
        await settle { await f.sleeper.intervals.count == 3 }
        f.clock.now = date(1, 16, month: 7)
        await f.sleeper.wake(3)
        await settle { await f.sleeper.intervals.count == 4 }
        let calls = await f.stock.calls
        XCTAssertEqual(calls, 4)
        XCTAssertEqual(f.vm.snapshot?.lastUpdated, f.clock.now)
        f.vm.stop(); await f.sleeper.wake(4, cancelled: true)
    }

    func testCancelledRefreshDiscardsCancellationUnawareResult() async {
        let f = fixture()
        await f.stock.configure(gated: true)
        let task = Task { await f.vm.refresh() }
        await settle { await f.stock.calls == 1 }
        task.cancel()
        await f.stock.release(1)
        await task.value
        XCTAssertNil(f.vm.snapshot)
        XCTAssertFalse(f.vm.isLoading)
    }

    func testRestartedQuoteLoadingCannotBeClearedByOldCompletion() async {
        let f = fixture()
        await f.stock.configure(gated: true)
        f.vm.start()
        await settle { await f.stock.calls == 1 }
        f.vm.stop(); f.vm.start()
        await settle { await f.stock.calls == 2 }
        await f.stock.release(1)
        for _ in 0..<100 { await Task.yield() }
        XCTAssertNil(f.vm.snapshot)
        XCTAssertTrue(f.vm.isLoading)
        await f.stock.release(2)
        await settle { f.vm.snapshot != nil }
        XCTAssertFalse(f.vm.isLoading)
        f.vm.stop(); await f.sleeper.wake(1, cancelled: true)
    }

    func testOldSECFailureCannotOverwriteRestartedSyncStatus() async {
        let f = fixture(due: true)
        f.vm.start()
        await settle { await f.holdings.calls == 1 }
        f.vm.stop(); f.vm.start()
        await settle { await f.holdings.calls == 2 }
        await f.holdings.release(1, fails: true)
        for _ in 0..<100 { await Task.yield() }
        XCTAssertNil(f.vm.holdingsSyncMessage)
        XCTAssertNil(f.settings.lastHoldingsSyncAttemptAt)
        XCTAssertTrue(f.vm.isSyncingHoldings)
        await f.holdings.release(2, count: 1)
        await settle { !f.vm.isSyncingHoldings }
        f.vm.stop(); await f.sleeper.wake(1, cancelled: true); await f.sleeper.wake(2, cancelled: true)
    }

    func testStoppedOutstandingServiceDoesNotRetainViewModel() async {
        let outstanding = LifecycleOutstanding()
        var f: Fixture? = fixture(due: true, outstanding: outstanding)
        let holdings = f!.holdings, sleeper = f!.sleeper
        weak var model = f!.vm
        f!.vm.start()
        await settle { await holdings.calls == 1 }
        await holdings.release(1, count: 1)
        await settle { await outstanding.started }
        f!.vm.stop(); f = nil
        for _ in 0..<100 { await Task.yield() }
        XCTAssertNil(model)
        await outstanding.release(); await sleeper.wake(1, cancelled: true)
    }

    func testStoppedSummaryDeliveryDoesNotRetainViewModel() async {
        var f: Fixture? = fixture(at: date(1, 10, month: 7), notify: true)
        let notifications = f!.notifications, sleeper = f!.sleeper
        _ = f!.tracker.update(personID: "musk", paperGain: 1e9, at: date(), isQuotable: true)
        weak var model = f!.vm
        f!.vm.start()
        await settle { await notifications.requests.count == 1 }
        f!.vm.stop(); f = nil
        for _ in 0..<100 { await Task.yield() }
        XCTAssertNil(model)
        await notifications.release(1); await sleeper.wake(1, cancelled: true)
    }

    func testOlderDaySummaryCannotAcknowledgeNewPendingDay() async {
        for fails in [false, true] {
            let f = fixture(notify: true)
            _ = f.tracker.update(personID: "musk", paperGain: 1e9, at: date(29), isQuotable: true)
            let old = Task { await f.vm.refresh() }
            await settle { await f.notifications.requests.count == 1 }
            f.clock.now = date(1, 10, month: 7)
            let newer = Task { await f.vm.refresh(force: true) }
            await settle { await f.notifications.requests.count == 2 }
            await f.notifications.release(1, fails: fails)
            await old.value
            XCTAssertEqual(f.tracker.peekPendingFinalizedDay(for: "musk")?.dayKey, "2026-06-30")
            await f.notifications.release(2, fails: true)
            await newer.value
            XCTAssertEqual(f.tracker.peekPendingFinalizedDay(for: "musk")?.dayKey, "2026-06-30")
        }
    }

    func testLatePreSECFetchCannotResurrectPreviousCounts() async {
        let f = fixture(due: true)
        await f.stock.configure(gated: true)
        f.vm.start()
        await settle { let h = await f.holdings.calls; let q = await f.stock.calls; return h == 1 && q == 1 }
        await f.holdings.release(1, count: 7)
        await settle { await f.stock.calls == 2 }
        await f.stock.release(2)
        await settle { f.vm.snapshot?.holdings.first?.shareCount == 7 }
        await f.stock.release(1)
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(f.vm.snapshot?.holdings.first?.shareCount, 7)
        XCTAssertEqual(f.vm.snapshot?.combinedPaperGain, 7)
        let calls = await f.stock.calls
        XCTAssertEqual(calls, 2)
        f.vm.stop(); await f.sleeper.wake(1, cancelled: true)
    }

    func testStaleStatusUsesObservationTimeAndObservableCurrentClock() async {
        let observed = date(10, 15, 59, month: 9)
        let f = fixture(at: observed)
        await f.vm.refresh()
        f.clock.now = date(10, 16, 1, month: 9)
        await f.stock.configure(fail: true)
        await f.vm.refresh()
        XCTAssertEqual(f.vm.marketCloseStatusLabel, MarketStatusFormatter.asOfLiveLabel(date: observed))
        let fridayOpen = date(11, 9, 30, month: 9)
        XCTAssertEqual(f.vm.marketStatusDetail, MarketStatusFormatter.nextOpenLabel(for: fridayOpen))
        let retained = f.vm.snapshot
        final class ObservationFlag: @unchecked Sendable { var changed = false }
        let flag = ObservationFlag()
        withObservationTracking {
            _ = f.vm.marketStatusDetail
        } onChange: {
            flag.changed = true
        }
        f.clock.now = date(11, 16, 1, month: 9)
        await f.vm.refresh()
        XCTAssertEqual(f.vm.snapshot, retained, "Quote and current session remain identical while the market clock advances")
        XCTAssertTrue(flag.changed, "Current-clock changes must invalidate observed next-open text")
        XCTAssertEqual(f.vm.marketCloseStatusLabel, MarketStatusFormatter.asOfLiveLabel(date: observed))
        XCTAssertEqual(f.vm.marketStatusDetail, MarketStatusFormatter.nextOpenLabel(for: date(14, 9, 30, month: 9)))
    }

    func testPartialClosingQuoteUsesTrueObservedStatus() async {
        let observed = date(30, 15, 59)
        let f = fixture(at: observed)
        await f.vm.refresh()
        f.clock.now = date(30, 16, 1)
        await f.stock.configure(partial: true)
        await f.vm.refresh()
        XCTAssertEqual(f.vm.marketCloseStatusLabel, MarketStatusFormatter.asOfLiveLabel(date: observed))
        XCTAssertEqual(f.vm.marketStatusDetail, MarketStatusFormatter.nextOpenLabel(for: date(1, 9, 30, month: 7)))
    }

    private func initialSpanningClose(fails: Bool, early: Bool, restart: Bool) async {
        let day = early ? 27 : 30, month = early ? 11 : 6, closeHour = early ? 13 : 16
        let observed = date(day, closeHour - 1, 58, month: month)
        let f = fixture(at: observed)
        await f.vm.refresh()
        if restart { f.vm.start(); await settle { await f.sleeper.intervals.count == 1 }; f.vm.stop(); await f.sleeper.wake(1, cancelled: true) }
        f.clock.now = date(day, closeHour - 1, 59, month: month)
        await f.stock.configure(fail: fails, gated: true)
        let priorCalls = await f.stock.calls
        let priorSleeps = await f.sleeper.intervals.count
        f.vm.start()
        await settle { await f.stock.calls == priorCalls + 1 }
        await settle { await f.sleeper.intervals.count > priorSleeps }
        let beforeCloseSleeps = await f.sleeper.intervals
        XCTAssertEqual(beforeCloseSleeps.count, priorSleeps + 1, "Clock scheduling cannot wait for the initial Yahoo request")
        f.clock.now = date(day, closeHour, 1, month: month)
        await f.stock.configure(fail: true)
        await f.sleeper.wake(priorSleeps + 1)
        await settle { f.vm.dailyRecordsSnapshot.hasCompletedFirstTradingDay }
        XCTAssertTrue(f.vm.dailyRecordsSnapshot.hasCompletedFirstTradingDay, "The real day must finalize while the initial request still waits")
        XCTAssertEqual(f.vm.snapshot?.tradingSession, .closed)
        await settle { await f.stock.calls >= priorCalls + 2 }
        let closeCalls = await f.stock.calls
        XCTAssertEqual(closeCalls, priorCalls + 2, "One closing request is required after the observed session")
        await f.stock.release(priorCalls + 1)
        await settle { await f.sleeper.intervals.count >= priorSleeps + 2 }
        await f.sleeper.wake(priorSleeps + 2)
        await settle { await f.stock.calls >= priorCalls + 3 }
        let retryCalls = await f.stock.calls
        XCTAssertEqual(retryCalls, priorCalls + 3, "One bounded recovery request follows the failed close")
        await settle { await f.sleeper.intervals.count >= priorSleeps + 3 }
        let sleeps = await f.sleeper.intervals
        XCTAssertTrue((sleeps.last ?? 0) > 3600)
        XCTAssertEqual(f.vm.snapshot?.lastUpdated, observed, "An invalidated pre-close result cannot replace the real session observation")
        f.vm.stop(); await f.sleeper.wake(priorSleeps + 3, cancelled: true)
    }
    func testInitialSuccessSpanningClosePreservesClockAndClosingRecovery() async { await initialSpanningClose(fails: false, early: false, restart: false) }
    func testInitialFailureSpanningClosePreservesClockAndClosingRecovery() async { await initialSpanningClose(fails: true, early: false, restart: false) }
    func testRestartInitialFailureSpanningEarlyClosePreservesClosingRecovery() async { await initialSpanningClose(fails: true, early: true, restart: true) }

    private func retainedQuoteTaskCount(_ vm: GainsViewModel) -> Int {
        Mirror(reflecting: vm).children.first { $0.label?.contains("quoteTasks") == true }
            .map { Mirror(reflecting: $0.value).children.count } ?? 0
    }

    func testRepeatedRecrossingsBoundActualSuspendedDeliveriesAndRetainedWork() async {
        let f = fixture(thresholds: ["gain-10b"])
        await f.stock.configure(price: 9e9, previous: 0)
        f.vm.start()
        await settle { await f.sleeper.intervals.count == 1 }
        await settle { f.vm.snapshot?.combinedPaperGain == 9e9 }
        for step in 1...40 {
            await f.stock.configure(price: step.isMultiple(of: 2) ? 9e9 : 11e9, previous: 0)
            f.clock.now = f.clock.now.addingTimeInterval(30)
            await f.sleeper.wake(step)
            await settle { await f.sleeper.intervals.count == step + 1 }
            await settle { f.vm.snapshot?.lastUpdated == f.clock.now }
            XCTAssertEqual(f.vm.snapshot?.combinedPaperGain, step.isMultiple(of: 2) ? 9e9 : 11e9)
        }
        let calls = await f.notifications.requests.count
        XCTAssertLessThanOrEqual(calls, 1, "One enabled preset may hold only one real delivery while later crossings coalesce")
        XCTAssertLessThanOrEqual(retainedQuoteTaskCount(f.vm), 1, "Accepted quotes must not retain one suspended tail per crossing")
        // A below observation is still retained even while delivery is blocked.
        let state = try? JSONSerialization.jsonObject(with: f.defaults.data(forKey: "gainNotificationThresholdState_musk-gain-10b") ?? Data()) as? [String: Any]
        XCTAssertEqual(state?["lastGain"] as? Double, 9e9)
        XCTAssertEqual(state?["armed"] as? Bool, true)
        for id in 1...max(calls, 1) { await f.notifications.release(id, fails: true) }
        f.vm.stop(); await f.sleeper.wake(41, cancelled: true)
    }

    func testFailedNextDayQuoteInvalidatesPendingPriorDayGainDelivery() async {
        let f = fixture(thresholds: ["gain-10b"])
        await f.stock.configure(price: 9e9, previous: 0)
        await f.vm.refresh()
        await f.stock.configure(price: 11e9, previous: 0)
        let crossing = Task { await f.vm.refresh() }
        await settle { await f.notifications.requests.count == 1 }
        f.clock.now = date(1, 2, month: 7)
        await f.stock.configure(fail: true)
        await f.vm.refresh(force: true)
        await f.notifications.release(1)
        await crossing.value
        await settle {
            let data = f.defaults.data(forKey: "gainNotificationThresholdState_musk-gain-10b") ?? Data()
            let value = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            return value?["tradingDayKey"] as? String == "2026-07-01"
        }
        let data = f.defaults.data(forKey: "gainNotificationThresholdState_musk-gain-10b") ?? Data()
        let value = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        XCTAssertEqual(value?["tradingDayKey"] as? String, "2026-07-01")
        XCTAssertEqual(value?["armed"] as? Bool, true)
        XCTAssertNil(value?["lastGain"])
        f.vm.stop()
    }

    func testRepeatedModelResetsBoundPhysicalGainDeliveryAndAllowDeallocation() async {
        var f: Fixture? = fixture(thresholds: ["gain-10b"])
        let stock = f!.stock, notifications = f!.notifications
        await stock.configure(price: 9e9, previous: 0)
        await f!.vm.refresh()
        await stock.configure(price: 11e9, previous: 0)
        await f!.vm.refresh()
        await settle { await notifications.requests.count == 1 }
        for value in 12...30 {
            f!.vm.reloadPersistedDisplayState()
            await stock.configure(price: 9e9, previous: 0); await f!.vm.refresh()
            await stock.configure(price: Double(value) * 1e9, previous: 0); await f!.vm.refresh()
        }
        let calls = await notifications.requests.count
        XCTAssertEqual(calls, 1, "Reset cannot abandon an occupied physical delivery slot")
        XCTAssertLessThanOrEqual(retainedQuoteTaskCount(f!.vm), 1)
        weak var model = f!.vm
        f!.vm.stop(); f = nil
        for _ in 0..<100 { await Task.yield() }
        XCTAssertNil(model)
        await notifications.release(1)
        for _ in 0..<100 { await Task.yield() }
        let afterStop = await notifications.requests.count
        XCTAssertEqual(afterStop, 1, "Stopped pending claims cannot drain after model release")
    }

    func testRestartStormBoundsCancellationUnawareQuoteAndSECRequests() async {
        let f = fixture(due: true)
        await f.stock.configure(gated: true)
        for _ in 0..<12 {
            f.vm.start()
            for _ in 0..<100 { await Task.yield() }
            f.vm.stop()
        }
        let quotes = await f.stock.calls, holdings = await f.holdings.calls
        XCTAssertLessThanOrEqual(quotes, 2, "Canceled transports keep physical capacity until they actually return")
        XCTAssertLessThanOrEqual(holdings, 2)
        for id in 1...max(quotes, 1) { await f.stock.release(id) }
        for id in 1...max(holdings, 1) { await f.holdings.release(id) }
        let sleeps = await f.sleeper.intervals.count
        for id in 1...max(sleeps, 1) { await f.sleeper.wake(id, cancelled: true) }
    }

    func testRepeatedResetBoundsDayClosePhysicalWorkWithoutBlockingQuotes() async {
        let f = fixture(at: date(1, 10, month: 7), notify: true)
        _ = f.tracker.update(personID: "musk", paperGain: 1e9, at: date(), isQuotable: true)
        var refreshes: [Task<Void, Never>] = []
        for price in 101...112 {
            f.vm.reloadPersistedDisplayState()
            await f.stock.configure(price: Double(price))
            refreshes.append(Task { await f.vm.refresh(force: true) })
            await settle { f.vm.snapshot?.combinedMarketValue == Double(price) }
            // Let the actual delivery boundary enter before the next reset.
            for _ in 0..<100 { await Task.yield() }
        }
        let count = await f.notifications.requests.count
        XCTAssertLessThanOrEqual(count, 2, "A reset cannot abandon unlimited physical day-close deliveries")
        XCTAssertEqual(f.vm.snapshot?.combinedMarketValue, 112)
        XCTAssertLessThanOrEqual(retainedQuoteTaskCount(f.vm), 1, "Summary waits must not retain quote workers")
        f.vm.stop()
        for id in 1...max(count, 1) { await f.notifications.release(id) }
        for refresh in refreshes { await refresh.value }
        XCTAssertNotNil(f.tracker.peekPendingFinalizedDay(for: "musk"))
    }

    func testLateClosingFailureStillGetsOneBoundedRecovery() async {
        let f = fixture(at: date(30, 15, 59))
        f.vm.start()
        await settle { f.vm.snapshot != nil }
        await settle { await f.sleeper.intervals.count == 1 }
        f.clock.now = date(30, 16)
        await f.stock.configure(fail: true, gated: true)
        await f.sleeper.wake(1)
        await settle { await f.stock.calls == 2 }
        await settle { await f.sleeper.intervals.count == 2 }
        f.clock.now = date(30, 16, 1)
        await f.sleeper.wake(2)
        await settle { await f.sleeper.intervals.count == 3 }
        await f.stock.configure()
        await f.stock.release(2)
        await settle { await f.sleeper.intervals.count == 4 }
        let intervals = await f.sleeper.intervals
        XCTAssertEqual(intervals.count, 4, "A failure after the first recovery window still schedules one retry")
        XCTAssertEqual(intervals.last, 30)
        await f.sleeper.wake(4)
        await settle { await f.stock.calls == 3 }
        let calls = await f.stock.calls
        XCTAssertEqual(calls, 3)
        f.vm.stop(); await f.sleeper.wake(3, cancelled: true)
    }

    func testNextOpenSupersedesPendingClosingQuoteImmediately() async {
        let f = fixture(at: date(30, 15, 59))
        f.vm.start()
        await settle { f.vm.snapshot != nil }
        await settle { await f.sleeper.intervals.count == 1 }
        f.clock.now = date(30, 16)
        await f.stock.configure(price: 102, gated: true)
        await f.sleeper.wake(1)
        await settle { await f.stock.calls == 2 }
        await settle { await f.sleeper.intervals.count == 2 }
        f.clock.now = date(30, 16, 1)
        await f.sleeper.wake(2)
        await settle { await f.sleeper.intervals.count == 3 }
        f.clock.now = date(1, 9, 30, month: 7)
        await f.stock.configure(price: 110)
        await f.sleeper.wake(3)
        await settle { f.vm.snapshot?.combinedPaperGain == 10 }
        XCTAssertEqual(f.vm.snapshot?.combinedPaperGain, 10)
        await f.stock.release(2)
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(f.vm.snapshot?.combinedPaperGain, 10)
        f.vm.stop(); await f.sleeper.wake(4, cancelled: true)
    }

}
