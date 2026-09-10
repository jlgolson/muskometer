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
