import AppKit
import UserNotifications
import XCTest
@testable import Muskometer

final class CurrencyFormatterTests: XCTestCase {
    func testFormatCurrencyBillionsPositive() {
        XCTAssertEqual(CurrencyFormatter.formatCurrency(46_605_540_451), "+$46.6B")
    }

    func testFormatCurrencyBillionsNegative() {
        XCTAssertEqual(CurrencyFormatter.formatCurrency(-1_500_000_000), "-$1.5B")
    }

    func testFormatPercentPositive() {
        XCTAssertEqual(CurrencyFormatter.formatPercent(2.127), "+2.13%")
    }

    func testFormatPercentNegative() {
        XCTAssertEqual(CurrencyFormatter.formatPercent(-1.5), "-1.50%")
    }

    func testFormatPrice() {
        XCTAssertEqual(CurrencyFormatter.formatPrice(420.6), "$420.60")
    }

    func testFormatShareCountUsesUSGrouping() {
        XCTAssertEqual(CurrencyFormatter.formatShareCount(699_580_882), "699,580,882")
    }

    func testFormatPercentNegativeKeepsMinusWithPOSIXLocale() {
        // formatPercent passes the signed value into formatNumber; en_US_POSIX must still emit `-`.
        XCTAssertEqual(CurrencyFormatter.formatPercent(-3.456), "-3.46%")
        XCTAssertEqual(CurrencyFormatter.formatPercent(-0.01), "-0.01%")
    }

    func testFormattersUsePeriodDecimalNotLocaleComma() {
        // Ensures compact currency / percent never produce ambiguous "1,2B" / "1,234,5B" styles.
        XCTAssertEqual(CurrencyFormatter.formatCurrency(1_234_500_000), "+$1.2B")
        XCTAssertEqual(CurrencyFormatter.formatMarketValue(1_234_500_000), "$1.2B")
        XCTAssertEqual(CurrencyFormatter.formatPercent(12.345), "+12.35%")
        XCTAssertEqual(CurrencyFormatter.formatPrice(1_234.5), "$1,234.50")
    }
}

final class StockQuoteTests: XCTestCase {
    func testPaperGainUsesShareCount() {
        let quote = StockQuote(
            symbol: "TSLA",
            displayName: "Tesla",
            currentPrice: 420.6,
            previousClose: 411.84,
            currency: "USD"
        )

        let gain = quote.paperGain(shareCount: 699_580_882)
        XCTAssertEqual(gain, 699_580_882 * 8.76, accuracy: 1.0)
    }

    func testPercentChange() {
        let quote = StockQuote(
            symbol: "TSLA",
            displayName: "Tesla",
            currentPrice: 420.6,
            previousClose: 411.84,
            currency: "USD"
        )

        XCTAssertEqual(quote.percentChange, 2.127, accuracy: 0.01)
    }
}

final class MarketStatusFormatterTests: XCTestCase {
    func testAsOfCloseLabelUsesLocalTimeZone() throws {
        let eastern = TimeZone(identifier: "America/New_York")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = eastern

        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 2
        components.hour = 16
        components.minute = 0
        components.timeZone = eastern
        let closeDate = try XCTUnwrap(calendar.date(from: components))

        let easternLabel = MarketStatusFormatter.asOfCloseLabel(
            closeDate: closeDate,
            timeZone: eastern,
            locale: Locale(identifier: "en_US_POSIX")
        )
        XCTAssertEqual(easternLabel, "As of 4:00 PM EDT on July 2")

        let pacific = TimeZone(identifier: "America/Los_Angeles")!
        let pacificLabel = MarketStatusFormatter.asOfCloseLabel(
            closeDate: closeDate,
            timeZone: pacific,
            locale: Locale(identifier: "en_US_POSIX")
        )
        XCTAssertEqual(pacificLabel, "As of 1:00 PM PDT on July 2")
    }
}

final class QuotePriceResolverTests: XCTestCase {
    private let meta = QuotePriceResolver.Meta(
        regularMarketPrice: 100,
        preMarketPrice: 101,
        postMarketPrice: 102,
        chartPreviousClose: 95,
        previousClose: 94
    )

    func testAlwaysUsesRegularMarketPriceRegardlessOfSession() {
        for symbol in ["TSLA", "SPCX"] {
            for session: TradingSession in [.regular, .preMarket, .postMarket, .closed] {
                XCTAssertEqual(
                    QuotePriceResolver.currentPrice(from: meta, session: session),
                    100,
                    "\(symbol) \(session) should use regularMarketPrice"
                )
            }
            XCTAssertEqual(QuotePriceResolver.previousClose(from: meta), 95, "\(symbol) previous close")
        }
    }

    func testReturnsNilWhenRegularPriceMissing() {
        let sparseMeta = QuotePriceResolver.Meta(
            regularMarketPrice: nil,
            preMarketPrice: 101,
            postMarketPrice: 102,
            chartPreviousClose: nil,
            previousClose: 190
        )

        for session: TradingSession in [.regular, .preMarket, .postMarket, .closed] {
            XCTAssertNil(
                QuotePriceResolver.currentPrice(from: sparseMeta, session: session),
                "\(session) must not fall back to extended-hours prices"
            )
        }
        XCTAssertEqual(QuotePriceResolver.previousClose(from: sparseMeta), 190)
    }
}

final class YahooMarketStateMapperTests: XCTestCase {
    func testMapsKnownMarketStatesRTHOnly() {
        // Only REGULAR is open; PRE/POST map to closed so extended prices are never selected.
        XCTAssertEqual(YahooMarketStateMapper.tradingSession(from: "PRE"), .closed)
        XCTAssertEqual(YahooMarketStateMapper.tradingSession(from: "REGULAR"), .regular)
        XCTAssertEqual(YahooMarketStateMapper.tradingSession(from: "POST"), .closed)
        XCTAssertEqual(YahooMarketStateMapper.tradingSession(from: "CLOSED"), .closed)
        XCTAssertEqual(YahooMarketStateMapper.tradingSession(from: "PREPRE"), .closed)
        XCTAssertEqual(YahooMarketStateMapper.tradingSession(from: "POSTPOST"), .closed)
        XCTAssertEqual(YahooMarketStateMapper.tradingSession(from: "HOLIDAY"), .closed)
        XCTAssertEqual(YahooMarketStateMapper.tradingSession(from: "BREAK"), .closed)
    }

    func testMappingIsCaseInsensitiveAndTrimsWhitespace() {
        XCTAssertEqual(YahooMarketStateMapper.tradingSession(from: "pre"), .closed)
        XCTAssertEqual(YahooMarketStateMapper.tradingSession(from: "Regular"), .regular)
        XCTAssertEqual(YahooMarketStateMapper.tradingSession(from: " post "), .closed)
        XCTAssertEqual(YahooMarketStateMapper.tradingSession(from: "\tCLOSED\n"), .closed)
    }

    func testNilEmptyAndUnknownReturnNilForLocalFallback() {
        XCTAssertNil(YahooMarketStateMapper.tradingSession(from: nil))
        XCTAssertNil(YahooMarketStateMapper.tradingSession(from: ""))
        XCTAssertNil(YahooMarketStateMapper.tradingSession(from: "   "))
        XCTAssertNil(YahooMarketStateMapper.tradingSession(from: "OPEN"))
        XCTAssertNil(YahooMarketStateMapper.tradingSession(from: "AFTERHOURS"))
        XCTAssertNil(YahooMarketStateMapper.tradingSession(from: "unknown"))
    }
}

final class QuoteBatchMergerTests: XCTestCase {
    private let tsla = StockQuote(
        symbol: "TSLA",
        displayName: "Tesla",
        currentPrice: 250,
        previousClose: 245,
        currency: "USD"
    )
    private let spcx = StockQuote(
        symbol: "SPCX",
        displayName: "SpaceX",
        currentPrice: 55,
        previousClose: 50,
        currency: "USD"
    )

    func testPartialSuccessReturnsSuccessfulQuotesInRequestedOrder() throws {
        let results: [Result<StockQuote, Error>] = [
            .success(spcx),
            .failure(StockPriceServiceError.missingSymbol("TSLA")),
            .success(tsla),
        ]

        let quotes = try QuoteBatchMerger.merge(
            results: results,
            symbolOrder: ["TSLA", "SPCX"]
        )

        XCTAssertEqual(quotes.map(\.symbol), ["TSLA", "SPCX"])
    }

    func testOneFailureDoesNotDropPeerSuccess() throws {
        // Regression: SPCX flake must not wipe TSLA from the batch.
        let results: [Result<StockQuote, Error>] = [
            .success(tsla),
            .failure(StockPriceServiceError.invalidResponse),
        ]

        let quotes = try QuoteBatchMerger.merge(
            results: results,
            symbolOrder: ["TSLA", "SPCX"]
        )

        XCTAssertEqual(quotes, [tsla])
    }

    func testAllFailuresThrow() {
        let results: [Result<StockQuote, Error>] = [
            .failure(StockPriceServiceError.missingSymbol("TSLA")),
            .failure(StockPriceServiceError.invalidResponse),
        ]

        XCTAssertThrowsError(
            try QuoteBatchMerger.merge(results: results, symbolOrder: ["TSLA", "SPCX"])
        ) { error in
            guard case StockPriceServiceError.missingSymbol("TSLA") = error else {
                return XCTFail("Expected first non-network error, got \(error)")
            }
        }
    }

    func testAllFailuresPreferNetworkError() {
        let network = StockPriceServiceError.networkError(underlying: URLError(.timedOut))
        let results: [Result<StockQuote, Error>] = [
            .failure(StockPriceServiceError.missingSymbol("TSLA")),
            .failure(network),
        ]

        XCTAssertThrowsError(
            try QuoteBatchMerger.merge(results: results, symbolOrder: ["TSLA", "SPCX"])
        ) { error in
            guard let serviceError = error as? StockPriceServiceError,
                  case .networkError = serviceError else {
                return XCTFail("Expected network error preference, got \(error)")
            }
        }
    }

    func testEmptyRequestReturnsEmptyWithoutThrowing() throws {
        let quotes = try QuoteBatchMerger.merge(results: [], symbolOrder: [])
        XCTAssertTrue(quotes.isEmpty)
    }
}

final class YahooFinanceStockPriceServiceTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        MockURLProtocol.requestHandler = nil
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        session = nil
        super.tearDown()
    }

    func testPartialSymbolFailureReturnsSuccessfulQuotes() async throws {
        MockURLProtocol.requestHandler = { request in
            let symbol = request.url?.pathComponents.last ?? ""
            if symbol == "SPCX" {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data())
            }

            let body = Self.chartJSON(
                shortName: "Tesla, Inc.",
                regularMarketPrice: 250,
                chartPreviousClose: 245
            )
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }

        let service = YahooFinanceStockPriceService(
            session: session,
            marketHours: FixedMarketHours(session: .regular)
        )
        let quotes = try await service.fetchQuotes(for: ["TSLA", "SPCX"])

        XCTAssertEqual(quotes.map(\.symbol), ["TSLA"])
        XCTAssertEqual(quotes.first?.currentPrice, 250)
        XCTAssertEqual(quotes.first?.previousClose, 245)
    }

    func testAllSymbolFailuresThrow() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let service = YahooFinanceStockPriceService(
            session: session,
            marketHours: FixedMarketHours(session: .regular)
        )

        do {
            _ = try await service.fetchQuotes(for: ["TSLA", "SPCX"])
            XCTFail("Expected fetchQuotes to throw when every symbol fails")
        } catch let error as StockPriceServiceError {
            guard case .invalidResponse = error else {
                return XCTFail("Expected invalidResponse, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testEmptySymbolsReturnsEmpty() async throws {
        let service = YahooFinanceStockPriceService(
            session: session,
            marketHours: FixedMarketHours(session: .regular)
        )
        let quotes = try await service.fetchQuotes(for: [])
        XCTAssertTrue(quotes.isEmpty)
    }

    func testYahooPostStateStillUsesRegularMarketPrice() async throws {
        // RTH-only: Yahoo POST maps to closed; extended postMarketPrice is never selected.
        MockURLProtocol.requestHandler = { request in
            let body = Self.chartJSON(
                shortName: "Tesla, Inc.",
                regularMarketPrice: 250,
                preMarketPrice: 248,
                postMarketPrice: 252,
                chartPreviousClose: 245,
                marketState: "POST"
            )
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }

        let service = YahooFinanceStockPriceService(
            session: session,
            marketHours: FixedMarketHours(session: .regular)
        )
        let quotes = try await service.fetchQuotes(for: ["TSLA"])

        XCTAssertEqual(quotes.first?.currentPrice, 250)
    }

    func testFallsBackToLocalSessionWhenMarketStateMissing() async throws {
        // Missing marketState → local session; RTH-only still uses regularMarketPrice.
        MockURLProtocol.requestHandler = { request in
            let body = Self.chartJSON(
                shortName: "Tesla, Inc.",
                regularMarketPrice: 250,
                preMarketPrice: 248,
                postMarketPrice: 252,
                chartPreviousClose: 245,
                marketState: nil
            )
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }

        let service = YahooFinanceStockPriceService(
            session: session,
            marketHours: FixedMarketHours(session: .closed)
        )
        let quotes = try await service.fetchQuotes(for: ["TSLA"])

        XCTAssertEqual(quotes.first?.currentPrice, 250)
    }

    private static func chartJSON(
        shortName: String,
        regularMarketPrice: Double,
        preMarketPrice: Double? = nil,
        postMarketPrice: Double? = nil,
        chartPreviousClose: Double,
        marketState: String? = nil
    ) -> Data {
        var metaFields = [
            "\"shortName\": \"\(shortName)\"",
            "\"currency\": \"USD\"",
            "\"regularMarketPrice\": \(regularMarketPrice)",
            "\"chartPreviousClose\": \(chartPreviousClose)"
        ]
        if let preMarketPrice {
            metaFields.append("\"preMarketPrice\": \(preMarketPrice)")
        }
        if let postMarketPrice {
            metaFields.append("\"postMarketPrice\": \(postMarketPrice)")
        }
        if let marketState {
            metaFields.append("\"marketState\": \"\(marketState)\"")
        }

        return """
        {
          "chart": {
            "result": [{
              "meta": {
                \(metaFields.joined(separator: ",\n                "))
              }
            }]
          }
        }
        """.data(using: .utf8)!
    }
}

final class MockHoldingsSyncService: HoldingsSyncServiceProtocol, @unchecked Sendable {
    private(set) var callCount = 0
    private let result: Result<HoldingsSyncResult, Error>

    init(result: Result<HoldingsSyncResult, Error>) {
        self.result = result
    }

    func syncHoldings() async throws -> HoldingsSyncResult {
        callCount += 1
        return try result.get()
    }
}

final class AppSettingsTests: XCTestCase {
    func testRefreshIntervalClampsTo120() {
        let defaults = UserDefaults(suiteName: "MuskometerTests")!
        defaults.removePersistentDomain(forName: "MuskometerTests")

        let settings = AppSettings(defaults: defaults)
        settings.refreshIntervalSeconds = 999

        XCTAssertEqual(settings.refreshIntervalSeconds, 120)
    }

    func testDefaultShareCounts() {
        let defaults = UserDefaults(suiteName: "MuskometerTests-defaults")!
        defaults.removePersistentDomain(forName: "MuskometerTests-defaults")

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.shareCount(for: "TSLA"), 710_172_677)
        XCTAssertEqual(settings.shareCount(for: "SPCX"), 5_116_475_230)
        XCTAssertEqual(settings.selectedPersonID, TrackedPersonProfile.musk.id)
        XCTAssertTrue(settings.showMenuBarIcon)
        XCTAssertTrue(settings.showMergerParityCard)
    }

    func testShowMenuBarIconPersists() {
        let defaults = UserDefaults(suiteName: "MuskometerTests-menubar-icon")!
        defaults.removePersistentDomain(forName: "MuskometerTests-menubar-icon")

        let settings = AppSettings(defaults: defaults)
        let initialEpoch = settings.menuBarLabelEpoch
        settings.showMenuBarIcon = false

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertFalse(reloaded.showMenuBarIcon)
        XCTAssertGreaterThan(settings.menuBarLabelEpoch, initialEpoch)
    }

    func testShowMergerParityCardDefaultsOnAndPersists() {
        let suiteName = "MuskometerTests-merger-parity-toggle-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.showMergerParityCard)

        settings.showMergerParityCard = false
        let reloaded = AppSettings(defaults: defaults)
        XCTAssertFalse(reloaded.showMergerParityCard)

        reloaded.showMergerParityCard = true
        let reloadedOn = AppSettings(defaults: defaults)
        XCTAssertTrue(reloadedOn.showMergerParityCard)
    }

    func testResetToDefaultsTurnsMergerParityCardBackOn() {
        let suiteName = "MuskometerTests-merger-parity-reset-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let settings = AppSettings(defaults: defaults)
        settings.showMergerParityCard = false
        settings.resetToDefaults()
        XCTAssertTrue(settings.showMergerParityCard)
    }

    func testTotalWorthDisplayModePersists() {
        let defaults = UserDefaults(suiteName: "MuskometerTests-total-worth")!
        defaults.removePersistentDomain(forName: "MuskometerTests-total-worth")

        let settings = AppSettings(defaults: defaults)
        settings.menuBarDisplayMode = .totalWorth

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.menuBarDisplayMode, .totalWorth)
    }
}

final class IssuerSharesOutstandingTests: XCTestCase {
    private func makeSettings(suiteName: String = "MuskometerTests-outstanding-\(UUID().uuidString)") -> (AppSettings, UserDefaults) {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (AppSettings(defaults: defaults), defaults)
    }

    func testBundledDefaultsAndKeys() {
        XCTAssertEqual(IssuerSharesOutstanding.defaultTSLA, 3_949_547_394)
        XCTAssertEqual(IssuerSharesOutstanding.defaultSPCX, 13_571_069_199)
        XCTAssertEqual(IssuerSharesOutstanding.defaultOutstanding(for: "TSLA"), IssuerSharesOutstanding.defaultTSLA)
        XCTAssertEqual(IssuerSharesOutstanding.defaultOutstanding(for: "tsla"), IssuerSharesOutstanding.defaultTSLA)
        XCTAssertEqual(IssuerSharesOutstanding.defaultOutstanding(for: "SPCX"), IssuerSharesOutstanding.defaultSPCX)
        XCTAssertNil(IssuerSharesOutstanding.defaultOutstanding(for: "AAPL"))
        XCTAssertEqual(IssuerSharesOutstanding.userDefaultsKey(for: "tsla"), "sharesOutstanding_TSLA")
        XCTAssertEqual(IssuerSharesOutstanding.userDefaultsKey(for: "SPCX"), "sharesOutstanding_SPCX")
    }

    func testMuskHoldingsHaveIssuerCIKs() {
        let tsla = TrackedPersonProfile.musk.holdingSpecs.first { $0.symbol == "TSLA" }
        let spcx = TrackedPersonProfile.musk.holdingSpecs.first { $0.symbol == "SPCX" }
        XCTAssertEqual(tsla?.issuerCIKPadded, "0001318605")
        XCTAssertEqual(spcx?.issuerCIKPadded, "0001181412")
    }

    func testDefaultsReturnedWhenNoKeySet() {
        let (settings, _) = makeSettings()

        XCTAssertEqual(settings.sharesOutstanding(for: "TSLA"), IssuerSharesOutstanding.defaultTSLA)
        XCTAssertEqual(settings.sharesOutstanding(for: "SPCX"), IssuerSharesOutstanding.defaultSPCX)
        XCTAssertEqual(settings.sharesOutstanding(for: "UNKNOWN"), 0)
        XCTAssertEqual(settings.outstandingProvenance(for: "TSLA"), .bundledDefault)
        XCTAssertTrue(settings.outstandingProvenanceCaption(for: "TSLA").contains("bundled default"))
        XCTAssertTrue(settings.outstandingProvenanceCaption(for: "TSLA").contains("2026-07-16"))
    }

    func testCompanyfactsProvenancePersistsAsOf() {
        let (settings, defaults) = makeSettings()
        settings.setSharesOutstanding(
            4_111_000_000,
            for: "TSLA",
            provenance: .companyfacts(periodEnd: "2026-09-01", filed: "2026-09-05")
        )
        XCTAssertEqual(
            settings.outstandingProvenance(for: "TSLA"),
            .companyfacts(periodEnd: "2026-09-01", filed: "2026-09-05")
        )
        XCTAssertTrue(settings.outstandingProvenanceCaption(for: "TSLA").contains("SEC companyfacts"))
        XCTAssertTrue(settings.outstandingProvenanceCaption(for: "TSLA").contains("2026-09-01"))

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(
            reloaded.outstandingProvenance(for: "TSLA"),
            .companyfacts(periodEnd: "2026-09-01", filed: "2026-09-05")
        )
    }

    func testResetToDefaultsRestoresBundledProvenance() {
        let (settings, _) = makeSettings()
        settings.setSharesOutstanding(
            9_999_999_999,
            for: "TSLA",
            provenance: .companyfacts(periodEnd: "2026-09-01", filed: "2026-09-05")
        )
        settings.resetToDefaults()
        XCTAssertEqual(settings.outstandingProvenance(for: "TSLA"), .bundledDefault)
        XCTAssertEqual(settings.sharesOutstanding(for: "TSLA"), IssuerSharesOutstanding.defaultTSLA)
    }

    func testSetGetRoundTripIndependentOfShareCount() {
        let (settings, defaults) = makeSettings()

        let customTSLAOutstanding: Int64 = 4_000_000_000
        let customSPCXOutstanding: Int64 = 14_000_000_000
        let ownershipTSLA: Int64 = 111
        let ownershipSPCX: Int64 = 222

        settings.setShareCount(ownershipTSLA, for: "TSLA")
        settings.setShareCount(ownershipSPCX, for: "SPCX")
        settings.setSharesOutstanding(customTSLAOutstanding, for: "TSLA")
        settings.setSharesOutstanding(customSPCXOutstanding, for: "SPCX")

        XCTAssertEqual(settings.sharesOutstanding(for: "TSLA"), customTSLAOutstanding)
        XCTAssertEqual(settings.sharesOutstanding(for: "SPCX"), customSPCXOutstanding)
        XCTAssertEqual(settings.shareCount(for: "TSLA"), ownershipTSLA)
        XCTAssertEqual(settings.shareCount(for: "SPCX"), ownershipSPCX)

        XCTAssertEqual(
            defaults.string(forKey: IssuerSharesOutstanding.userDefaultsKey(for: "TSLA")),
            String(customTSLAOutstanding)
        )
        XCTAssertEqual(
            defaults.string(forKey: "shareCount_TSLA"),
            String(ownershipTSLA)
        )
        XCTAssertNotEqual(
            IssuerSharesOutstanding.userDefaultsKey(for: "TSLA"),
            "shareCount_TSLA"
        )

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.sharesOutstanding(for: "TSLA"), customTSLAOutstanding)
        XCTAssertEqual(reloaded.sharesOutstanding(for: "SPCX"), customSPCXOutstanding)
        XCTAssertEqual(reloaded.shareCount(for: "TSLA"), ownershipTSLA)
        XCTAssertEqual(reloaded.shareCount(for: "SPCX"), ownershipSPCX)
    }

    func testSetSharesOutstandingIgnoresNonPositive() {
        let (settings, defaults) = makeSettings()

        settings.setSharesOutstanding(0, for: "TSLA")
        settings.setSharesOutstanding(-1, for: "SPCX")

        XCTAssertNil(defaults.string(forKey: IssuerSharesOutstanding.userDefaultsKey(for: "TSLA")))
        XCTAssertNil(defaults.string(forKey: IssuerSharesOutstanding.userDefaultsKey(for: "SPCX")))
        XCTAssertEqual(settings.sharesOutstanding(for: "TSLA"), IssuerSharesOutstanding.defaultTSLA)
        XCTAssertEqual(settings.sharesOutstanding(for: "SPCX"), IssuerSharesOutstanding.defaultSPCX)
    }

    func testResetToDefaultsReseedsOutstanding() {
        let (settings, _) = makeSettings()

        settings.setSharesOutstanding(9_999_999_999, for: "TSLA")
        settings.setSharesOutstanding(8_888_888_888, for: "SPCX")
        settings.setShareCount(123, for: "TSLA")
        settings.setShareCount(456, for: "SPCX")

        XCTAssertEqual(settings.sharesOutstanding(for: "TSLA"), 9_999_999_999)
        XCTAssertEqual(settings.sharesOutstanding(for: "SPCX"), 8_888_888_888)

        settings.resetToDefaults()

        XCTAssertEqual(settings.sharesOutstanding(for: "TSLA"), IssuerSharesOutstanding.defaultTSLA)
        XCTAssertEqual(settings.sharesOutstanding(for: "SPCX"), IssuerSharesOutstanding.defaultSPCX)
        XCTAssertEqual(settings.shareCount(for: "TSLA"), 710_172_677)
        XCTAssertEqual(settings.shareCount(for: "SPCX"), 5_116_475_230)
    }

    func testMigrateStoredOutstandingRewritesPriorSPCXCoverDefault() {
        XCTAssertEqual(
            IssuerSharesOutstanding.migrateStoredOutstanding(13_181_779_945, symbol: "SPCX"),
            13_571_069_199
        )
        XCTAssertEqual(
            IssuerSharesOutstanding.migrateStoredOutstanding(13_181_779_945, symbol: "spcx"),
            13_571_069_199
        )
    }

    func testMigrateStoredOutstandingLeavesOtherValues() {
        XCTAssertEqual(
            IssuerSharesOutstanding.migrateStoredOutstanding(8_888_888_888, symbol: "SPCX"),
            8_888_888_888
        )
        XCTAssertEqual(
            IssuerSharesOutstanding.migrateStoredOutstanding(13_571_069_199, symbol: "SPCX"),
            13_571_069_199
        )
        XCTAssertEqual(
            IssuerSharesOutstanding.migrateStoredOutstanding(13_181_779_945, symbol: "TSLA"),
            13_181_779_945
        )
    }

    func testLoadRemigratesPriorSPCXCoverOutstandingAndPersists() {
        let suiteName = "MuskometerTests-outstanding-migrate-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(String(13_181_779_945), forKey: IssuerSharesOutstanding.userDefaultsKey(for: "SPCX"))
        defaults.set(String(8_888_888_888), forKey: IssuerSharesOutstanding.userDefaultsKey(for: "TSLA"))

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.sharesOutstanding(for: "SPCX"), 13_571_069_199)
        XCTAssertEqual(settings.sharesOutstanding(for: "TSLA"), 8_888_888_888)
        XCTAssertEqual(
            defaults.string(forKey: IssuerSharesOutstanding.userDefaultsKey(for: "SPCX")),
            String(13_571_069_199)
        )
        XCTAssertEqual(
            defaults.string(forKey: IssuerSharesOutstanding.userDefaultsKey(for: "TSLA")),
            String(8_888_888_888)
        )
    }

    func testMissingOutstandingKeyReturnsNewBundledDefault() {
        let (settings, defaults) = makeSettings()

        XCTAssertNil(defaults.string(forKey: IssuerSharesOutstanding.userDefaultsKey(for: "SPCX")))
        XCTAssertNil(defaults.string(forKey: IssuerSharesOutstanding.userDefaultsKey(for: "TSLA")))
        XCTAssertEqual(settings.sharesOutstanding(for: "SPCX"), 13_571_069_199)
        XCTAssertEqual(settings.sharesOutstanding(for: "TSLA"), 3_949_547_394)
    }
}

final class MergerMarketCapParityTests: XCTestCase {
    func testHappyPathImpliedEqualsSPCXMarketCapOverTSLAShares() throws {
        // tslaPrice 100, spcxPrice 50, outstanding 2 / 4
        // → spcx mcap 200, tsla mcap 200, implied TSLA 100
        let result = MergerMarketCapParity.presentation(
            tslaPrice: 100,
            spcxPrice: 50,
            tslaOutstanding: 2,
            spcxOutstanding: 4
        )

        let presentation = try XCTUnwrap(result)
        XCTAssertEqual(presentation.spcxMarketCap, 200, accuracy: 1e-9)
        XCTAssertEqual(presentation.tslaMarketCap, 200, accuracy: 1e-9)
        XCTAssertEqual(presentation.impliedTSLAPrice, 100, accuracy: 1e-9)
    }

    func testZeroOrNegativeInputsReturnNil() {
        XCTAssertNil(
            MergerMarketCapParity.presentation(
                tslaPrice: 0,
                spcxPrice: 50,
                tslaOutstanding: 2,
                spcxOutstanding: 4
            )
        )
        XCTAssertNil(
            MergerMarketCapParity.presentation(
                tslaPrice: 100,
                spcxPrice: 0,
                tslaOutstanding: 2,
                spcxOutstanding: 4
            )
        )
        XCTAssertNil(
            MergerMarketCapParity.presentation(
                tslaPrice: -1,
                spcxPrice: 50,
                tslaOutstanding: 2,
                spcxOutstanding: 4
            )
        )
        XCTAssertNil(
            MergerMarketCapParity.presentation(
                tslaPrice: 100,
                spcxPrice: -1,
                tslaOutstanding: 2,
                spcxOutstanding: 4
            )
        )
        XCTAssertNil(
            MergerMarketCapParity.presentation(
                tslaPrice: 100,
                spcxPrice: 50,
                tslaOutstanding: 0,
                spcxOutstanding: 4
            )
        )
        XCTAssertNil(
            MergerMarketCapParity.presentation(
                tslaPrice: 100,
                spcxPrice: 50,
                tslaOutstanding: 2,
                spcxOutstanding: 0
            )
        )
        XCTAssertNil(
            MergerMarketCapParity.presentation(
                tslaPrice: 100,
                spcxPrice: 50,
                tslaOutstanding: -1,
                spcxOutstanding: 4
            )
        )
        XCTAssertNil(
            MergerMarketCapParity.presentation(
                tslaPrice: 100,
                spcxPrice: 50,
                tslaOutstanding: 2,
                spcxOutstanding: -1
            )
        )
    }

    func testNonFiniteInputsReturnNil() {
        let nonFinite: [Double] = [.nan, .infinity, -.infinity]
        for bad in nonFinite {
            XCTAssertNil(
                MergerMarketCapParity.presentation(
                    tslaPrice: bad,
                    spcxPrice: 50,
                    tslaOutstanding: 2,
                    spcxOutstanding: 4
                ),
                "tslaPrice \(bad) should yield nil"
            )
            XCTAssertNil(
                MergerMarketCapParity.presentation(
                    tslaPrice: 100,
                    spcxPrice: bad,
                    tslaOutstanding: 2,
                    spcxOutstanding: 4
                ),
                "spcxPrice \(bad) should yield nil"
            )
        }
    }

    func testRealishOrdersOfMagnitude() throws {
        let tslaOutstanding = IssuerSharesOutstanding.defaultTSLA
        let spcxOutstanding = IssuerSharesOutstanding.defaultSPCX
        let tslaPrice = 250.0
        let spcxPrice = 80.0

        let result = MergerMarketCapParity.presentation(
            tslaPrice: tslaPrice,
            spcxPrice: spcxPrice,
            tslaOutstanding: tslaOutstanding,
            spcxOutstanding: spcxOutstanding
        )

        let presentation = try XCTUnwrap(result)
        let expectedSPCXMcap = spcxPrice * Double(spcxOutstanding)
        let expectedTSLAMcap = tslaPrice * Double(tslaOutstanding)
        let expectedImplied = expectedSPCXMcap / Double(tslaOutstanding)

        XCTAssertEqual(presentation.spcxMarketCap, expectedSPCXMcap, accuracy: 1.0)
        XCTAssertEqual(presentation.tslaMarketCap, expectedTSLAMcap, accuracy: 1.0)
        XCTAssertEqual(presentation.impliedTSLAPrice, expectedImplied, accuracy: 1e-6)

        // Sanity: with ~3.3× more SPCX shares at $80 vs TSLA at $250, implied is in hundreds–thousands.
        XCTAssertGreaterThan(presentation.impliedTSLAPrice, 100)
        XCTAssertLessThan(presentation.impliedTSLAPrice, 10_000)
        XCTAssertGreaterThan(presentation.spcxMarketCap, 1e11)
        XCTAssertGreaterThan(presentation.tslaMarketCap, 1e11)
    }
}

final class MockIssuerOutstandingSyncService: IssuerOutstandingSyncServiceProtocol, @unchecked Sendable {
    private(set) var callCount = 0
    private let result: [String: IssuerOutstandingFact]

    init(result: [String: Int64]) {
        self.result = result.mapValues { shares in
            IssuerOutstandingFact(shares: shares, periodEnd: "2026-01-01", filed: "2026-01-02")
        }
    }

    init(facts: [String: IssuerOutstandingFact]) {
        self.result = facts
    }

    func fetchOutstanding(for specs: [TrackedHoldingSpec]) async -> [String: IssuerOutstandingFact] {
        callCount += 1
        return result
    }
}

final class MenuBarDisplayModeTests: XCTestCase {
    func testTotalWorthLabel() {
        XCTAssertEqual(MenuBarDisplayMode.totalWorth.label, "Total worth")
    }
}

final class StringTruncationTests: XCTestCase {
    func testTruncatedMiddleLeavesShortStringsUntouched() {
        XCTAssertEqual("+$46.6B/+$12.3B".truncatedMiddle(maxLength: 28), "+$46.6B/+$12.3B")
    }

    func testTruncatedMiddleUsesMiddleEllipsis() {
        let input = "+$46.605B/+$12.345B"
        let truncated = input.truncatedMiddle(maxLength: 16)

        XCTAssertEqual(truncated.count, 16)
        XCTAssertTrue(truncated.contains("…"))
        XCTAssertTrue(truncated.hasPrefix("+$46"))
        XCTAssertTrue(truncated.hasSuffix(".345B"))
    }
}

final class ShareCountTextInputTests: XCTestCase {
    private let stored: Int64 = 699_580_882

    func testEmptyFieldRestoresStoredCountWithoutError() {
        let result = ShareCountTextInput.resolve(rawText: "", storedCount: stored)
        XCTAssertEqual(result, .restore(storedCount: stored, errorMessage: nil))
    }

    func testValidPositiveCountIsAccepted() {
        let result = ShareCountTextInput.resolve(rawText: "12345", storedCount: stored)
        XCTAssertEqual(result, .accepted(12_345))
    }

    func testCommasAreStrippedBeforeParsing() {
        let result = ShareCountTextInput.resolve(rawText: "1,000,000", storedCount: stored)
        XCTAssertEqual(result, .accepted(1_000_000))
    }

    func testInvalidNonEmptyRestoresStoredCountWithError() {
        let result = ShareCountTextInput.resolve(rawText: "abc", storedCount: stored)
        XCTAssertEqual(
            result,
            .restore(storedCount: stored, errorMessage: ShareCountTextInput.invalidInputMessage)
        )
    }

    func testZeroAndNegativeAreRejected() {
        XCTAssertEqual(
            ShareCountTextInput.resolve(rawText: "0", storedCount: stored),
            .restore(storedCount: stored, errorMessage: ShareCountTextInput.invalidInputMessage)
        )
        XCTAssertEqual(
            ShareCountTextInput.resolve(rawText: "-5", storedCount: stored),
            .restore(storedCount: stored, errorMessage: ShareCountTextInput.invalidInputMessage)
        )
    }

    func testEmptyDoesNotOverwriteStoredCountIdentity() {
        // Clearing a field must never be treated as an apply of zero/nil holdings.
        switch ShareCountTextInput.resolve(rawText: "", storedCount: stored) {
        case .accepted:
            XCTFail("Empty input must not be accepted as a new share count")
        case .restore(let restored, let error):
            XCTAssertEqual(restored, stored)
            XCTAssertNil(error)
        }
    }
}

final class GainsSnapshotTests: XCTestCase {
    func testCombinedMarketValue() {
        let tsla = HoldingGain(
            id: "tsla",
            symbol: "TSLA",
            displayName: "Tesla",
            shareCount: 100,
            quote: StockQuote(symbol: "TSLA", displayName: "Tesla", currentPrice: 110, previousClose: 100, currency: "USD")
        )
        let spcx = HoldingGain(
            id: "spcx",
            symbol: "SPCX",
            displayName: "SpaceX",
            shareCount: 200,
            quote: StockQuote(symbol: "SPCX", displayName: "SpaceX", currentPrice: 55, previousClose: 50, currency: "USD")
        )

        let snapshot = GainsSnapshot(holdings: [tsla, spcx], lastUpdated: .now, tradingSession: .regular)

        XCTAssertEqual(snapshot.combinedMarketValue, 22_000)
    }

    func testFormatMarketValueTrillions() {
        XCTAssertEqual(CurrencyFormatter.formatMarketValue(1_331_000_000_000), "$1.33T")
    }

    func testCombinedPercentChange() {
        let tsla = HoldingGain(
            id: "tsla",
            symbol: "TSLA",
            displayName: "Tesla",
            shareCount: 100,
            quote: StockQuote(symbol: "TSLA", displayName: "Tesla", currentPrice: 110, previousClose: 100, currency: "USD")
        )
        let snapshot = GainsSnapshot(holdings: [tsla], lastUpdated: .now, tradingSession: .regular)

        XCTAssertEqual(snapshot.combinedPercentChange, 10.0, accuracy: 0.01)
    }

    func testCombinedPaperGain() {
        let tsla = HoldingGain(
            id: "tsla",
            symbol: "TSLA",
            displayName: "Tesla",
            shareCount: 100,
            quote: StockQuote(symbol: "TSLA", displayName: "Tesla", currentPrice: 110, previousClose: 100, currency: "USD")
        )
        let spcx = HoldingGain(
            id: "spcx",
            symbol: "SPCX",
            displayName: "SpaceX",
            shareCount: 200,
            quote: StockQuote(symbol: "SPCX", displayName: "SpaceX", currentPrice: 55, previousClose: 50, currency: "USD")
        )

        let snapshot = GainsSnapshot(holdings: [tsla, spcx], lastUpdated: .now, tradingSession: .regular)

        XCTAssertEqual(snapshot.combinedPaperGain, 2_000)
    }
}

@MainActor
final class MockStockService: StockPriceServiceProtocol {
    let quotes: [StockQuote]

    init(quotes: [StockQuote]) {
        self.quotes = quotes
    }

    func fetchQuotes(for symbols: [String]) async throws -> [StockQuote] {
        quotes
    }
}

@MainActor
final class ShareImageExporterTests: XCTestCase {
    private func sampleSnapshot() -> GainsSnapshot {
        let tsla = HoldingGain(
            id: "tsla",
            symbol: "TSLA",
            displayName: "Tesla",
            shareCount: 699_580_882,
            quote: StockQuote(symbol: "TSLA", displayName: "Tesla", currentPrice: 342, previousClose: 338, currency: "USD")
        )
        let spcx = HoldingGain(
            id: "spcx",
            symbol: "SPCX",
            displayName: "SpaceX",
            shareCount: 6_068_734_060,
            quote: StockQuote(symbol: "SPCX", displayName: "SpaceX", currentPrice: 28.5, previousClose: 28.4, currency: "USD")
        )
        return GainsSnapshot(holdings: [tsla, spcx], lastUpdated: .now, tradingSession: .regular)
    }

    func testRendersNonEmptyPNG() {
        let png = ShareImageExporter.renderPNGData(snapshot: sampleSnapshot(), profile: .musk)

        XCTAssertNotNil(png)
        XCTAssertGreaterThan(png?.count ?? 0, 1_000)
    }

    func testRendersLargerPNGWhenParityIncluded() {
        let snapshot = sampleSnapshot()
        let parity = MergerMarketCapParity.presentation(
            tslaPrice: 342,
            spcxPrice: 28.5,
            tslaOutstanding: 3_200_000_000,
            spcxOutstanding: 6_068_734_060
        )
        let without = ShareImageExporter.renderPNGData(snapshot: snapshot, profile: .musk)
        let with = ShareImageExporter.renderPNGData(snapshot: snapshot, profile: .musk, parity: parity)

        XCTAssertNotNil(without)
        XCTAssertNotNil(with)
        XCTAssertGreaterThan(with?.count ?? 0, without?.count ?? 0)
    }

    func testCopiesTextSummaryToPasteboard() {
        let snapshot = sampleSnapshot()

        XCTAssertTrue(
            ShareImageExporter.copyToPasteboard(snapshot: snapshot, profile: .musk, format: .text)
        )
        XCTAssertEqual(
            NSPasteboard.general.string(forType: .string),
            GainSummaryFormatter.format(snapshot)
        )
    }

    func testShareItemsTextContainsSummary() {
        let snapshot = sampleSnapshot()
        let items = ShareImageExporter.shareItems(snapshot: snapshot, profile: .musk, format: .text)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first as? String, GainSummaryFormatter.format(snapshot))
    }

    func testShareItemsImageReturnsNSImage() {
        let items = ShareImageExporter.shareItems(snapshot: sampleSnapshot(), profile: .musk, format: .image)
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items.first is NSImage)
    }

    func testCopiesTextSummaryWithParityPunchline() {
        let snapshot = sampleSnapshot()
        let parity = MergerParityPresentation(
            impliedTSLAPrice: 1_250.40,
            tslaMarketCap: 1_100_000_000_000,
            spcxMarketCap: 1_400_000_000_000
        )

        XCTAssertTrue(
            ShareImageExporter.copyToPasteboard(
                snapshot: snapshot,
                profile: .musk,
                format: .text,
                parity: parity
            )
        )
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        XCTAssertTrue(text.contains("If Tesla had SpaceX's market cap"))
        XCTAssertTrue(text.contains(CurrencyFormatter.formatPrice(parity.impliedTSLAPrice)))
    }
}

final class GainSummaryFormatterTests: XCTestCase {
    func testTodaysGainLossLabel() {
        XCTAssertEqual(GainSummaryFormatter.todaysGainLossLabel(for: 1), "Today's Gain")
        XCTAssertEqual(GainSummaryFormatter.todaysGainLossLabel(for: -1), "Today's Loss")
        XCTAssertEqual(GainSummaryFormatter.todaysGainLossLabel(for: 0), "Today's Gain/Loss")
    }

    func testFormatOmitsLegalDisclaimer() {
        let tsla = HoldingGain(
            id: "tsla",
            symbol: "TSLA",
            displayName: "Tesla",
            shareCount: 100,
            quote: StockQuote(symbol: "TSLA", displayName: "Tesla", currentPrice: 110, previousClose: 100, currency: "USD")
        )
        let snapshot = GainsSnapshot(holdings: [tsla], lastUpdated: .now, tradingSession: .regular)

        let formatted = GainSummaryFormatter.format(snapshot)

        XCTAssertFalse(formatted.contains("financial advice"))
        XCTAssertFalse(formatted.contains("Illustrative"))
        XCTAssertTrue(formatted.contains("Muskometer —"))
    }
}

struct FixedMarketHours: MarketHoursServiceProtocol {
    let session: TradingSession

    init(isOpen: Bool) {
        self.session = isOpen ? .regular : .closed
    }

    init(session: TradingSession) {
        self.session = session
    }

    func currentSession(at date: Date) -> TradingSession {
        session
    }

    func isQuotable(at date: Date) -> Bool {
        session.isQuotable
    }

    func isMarketOpen(at date: Date) -> Bool {
        session == .regular
    }

    func nextOpenDate(from date: Date) -> Date? {
        session.isQuotable ? nil : nil
    }

    func lastMarketClose(from date: Date) -> Date? {
        nil
    }
}

@MainActor
final class IntradayGainSampleStoreTests: XCTestCase {
    private var eastern: TimeZone!
    private var calendar: Calendar!

    override func setUp() {
        eastern = TimeZone(identifier: "America/New_York")!
        calendar = IntradayGainSampleStore.easternCalendar()
    }

    private func makeStore(
        isMarketOpen: Bool,
        suiteName: String = "MuskometerTests-intraday-\(UUID().uuidString)",
        now: @escaping () -> Date = { .now }
    ) -> (IntradayGainSampleStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: FixedMarketHours(isOpen: isMarketOpen),
            now: now
        )
        return (store, defaults)
    }

    private func easternDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0
    ) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = eastern
        return try XCTUnwrap(calendar.date(from: components))
    }

    func testAppendWhenMarketOpen() throws {
        let (store, _) = makeStore(isMarketOpen: true)
        let date = try easternDate(year: 2026, month: 6, day: 30, hour: 11)

        store.append(personID: "musk", combinedPaperGain: 1_000_000_000, at: date)

        XCTAssertEqual(store.samples.count, 1)
        XCTAssertEqual(store.samples.first?.combinedPaperGain, 1_000_000_000)
        XCTAssertEqual(store.samples.first?.timestamp, date)
    }

    func testDoesNotAppendWhenMarketClosed() throws {
        let (store, _) = makeStore(isMarketOpen: false)
        let date = try easternDate(year: 2026, month: 6, day: 30, hour: 11)

        store.append(personID: "musk", combinedPaperGain: 1_000_000_000, at: date)

        XCTAssertTrue(store.samples.isEmpty)
    }

    func testDoesNotAppendDuringPostMarketHours() throws {
        // RTH-only: post-market is not quotable, so sparkline samples are not taken.
        let suiteName = "MuskometerTests-intraday-post-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: FixedMarketHours(session: .closed)
        )
        let date = try easternDate(year: 2026, month: 6, day: 30, hour: 17)

        store.append(personID: "musk", combinedPaperGain: 1_000_000_000, at: date)

        XCTAssertTrue(store.samples.isEmpty)
    }

    func testETDayRolloverClearsPriorSamples() throws {
        let suiteName = "MuskometerTests-intraday-rollover-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let marketHours = FixedMarketHours(isOpen: true)
        let store = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: marketHours
        )

        let monday = try easternDate(year: 2026, month: 6, day: 30, hour: 11)
        let tuesday = try easternDate(year: 2026, month: 7, day: 1, hour: 11)

        store.append(personID: "musk", combinedPaperGain: 100, at: monday)
        store.append(personID: "musk", combinedPaperGain: 200, at: tuesday)

        XCTAssertEqual(store.samples.count, 1)
        XCTAssertEqual(store.samples.first?.combinedPaperGain, 200)
        XCTAssertEqual(store.samples.first?.timestamp, tuesday)
    }

    func testCapsAt400Samples() throws {
        let (store, _) = makeStore(isMarketOpen: true)
        let start = try easternDate(year: 2026, month: 6, day: 30, hour: 10)

        for index in 0..<450 {
            let date = start.addingTimeInterval(TimeInterval(index * 60))
            store.append(personID: "musk", combinedPaperGain: Double(index), at: date)
        }

        XCTAssertEqual(store.samples.count, 400)
        XCTAssertEqual(store.samples.first?.combinedPaperGain, 50)
        XCTAssertEqual(store.samples.last?.combinedPaperGain, 449)
    }

    func testPersistsAcrossReload() throws {
        let suiteName = "MuskometerTests-intraday-persist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let date = try easternDate(year: 2026, month: 6, day: 30, hour: 11)
        let marketHours = FixedMarketHours(isOpen: true)
        let now = { date }

        let store = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: marketHours,
            now: now
        )
        store.append(personID: "musk", combinedPaperGain: 42_000_000_000, at: date)

        let reloaded = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: marketHours,
            now: now
        )
        let samples = reloaded.loadSamples(for: "musk")

        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples.first?.combinedPaperGain, 42_000_000_000)
        XCTAssertEqual(samples.first?.timestamp, date)
    }

    func testLoadYesterdaysSamplesDuringClosedSessionKeepsPriorRTHSamples() throws {
        let suiteName = "MuskometerTests-intraday-stale-load-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let monday = try easternDate(year: 2026, month: 6, day: 30, hour: 11)
        let tuesdayClosed = try easternDate(year: 2026, month: 7, day: 1, hour: 3)

        let openStore = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: FixedMarketHours(isOpen: true),
            now: { monday }
        )
        openStore.append(personID: "musk", combinedPaperGain: 99_000_000_000, at: monday)
        XCTAssertEqual(openStore.samples.count, 1)

        // Mid-closed session next ET day: keep Monday's sparkline for overnight share/display.
        let closedStore = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: FixedMarketHours(isOpen: false),
            now: { tuesdayClosed }
        )
        let samples = closedStore.loadSamples(for: "musk")

        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples.first?.combinedPaperGain, 99_000_000_000)
        XCTAssertEqual(samples.first?.timestamp, monday)

        // Later same-day closed reload still shows the prior RTH session.
        let reloaded = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: FixedMarketHours(isOpen: false),
            now: { tuesdayClosed }
        )
        let reloadedSamples = reloaded.loadSamples(for: "musk")
        XCTAssertEqual(reloadedSamples.count, 1)
        XCTAssertEqual(reloadedSamples.first?.combinedPaperGain, 99_000_000_000)
    }

    func testOvernightLoadKeepsPriorRTHSamples() throws {
        let suiteName = "MuskometerTests-intraday-overnight-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let mondayClose = try easternDate(year: 2026, month: 6, day: 30, hour: 15, minute: 45)
        let tuesdayPreOpen = try easternDate(year: 2026, month: 7, day: 1, hour: 8)

        let openStore = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: FixedMarketHours(isOpen: true),
            now: { mondayClose }
        )
        openStore.append(personID: "musk", combinedPaperGain: 12_000_000_000, at: mondayClose)
        openStore.append(
            personID: "musk",
            combinedPaperGain: 15_000_000_000,
            at: mondayClose.addingTimeInterval(60)
        )

        let overnightStore = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: FixedMarketHours(isOpen: false),
            now: { tuesdayPreOpen }
        )
        let samples = overnightStore.loadSamples(for: "musk")

        XCTAssertEqual(samples.count, 2)
        XCTAssertEqual(samples.map(\.combinedPaperGain), [12_000_000_000, 15_000_000_000])
    }

    func testFirstRTHAppendNextDayClearsPriorSessionSamples() throws {
        let suiteName = "MuskometerTests-intraday-next-rth-clear-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let monday = try easternDate(year: 2026, month: 6, day: 30, hour: 11)
        let tuesdayOvernight = try easternDate(year: 2026, month: 7, day: 1, hour: 2)
        let tuesdayOpen = try easternDate(year: 2026, month: 7, day: 1, hour: 10)

        let openStore = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: FixedMarketHours(isOpen: true),
            now: { monday }
        )
        openStore.append(personID: "musk", combinedPaperGain: 100, at: monday)

        // Overnight load keeps Monday.
        let overnightStore = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: FixedMarketHours(isOpen: false),
            now: { tuesdayOvernight }
        )
        XCTAssertEqual(overnightStore.loadSamples(for: "musk").count, 1)

        // First quotable append on the new RTH day replaces the prior session.
        let nextSessionStore = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: FixedMarketHours(isOpen: true),
            now: { tuesdayOpen }
        )
        nextSessionStore.append(personID: "musk", combinedPaperGain: 250, at: tuesdayOpen)

        XCTAssertEqual(nextSessionStore.samples.count, 1)
        XCTAssertEqual(nextSessionStore.samples.first?.combinedPaperGain, 250)
        XCTAssertEqual(nextSessionStore.samples.first?.timestamp, tuesdayOpen)
        XCTAssertEqual(nextSessionStore.loadSamples(for: "musk").count, 1)
    }

    func testDayRolloverOnQuotableAppendStillWorks() throws {
        let suiteName = "MuskometerTests-intraday-quotable-rollover-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let monday = try easternDate(year: 2026, month: 6, day: 30, hour: 11)
        let tuesday = try easternDate(year: 2026, month: 7, day: 1, hour: 11)
        let store = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: FixedMarketHours(isOpen: true),
            now: { monday }
        )

        store.append(personID: "musk", combinedPaperGain: 100, at: monday)
        store.append(personID: "musk", combinedPaperGain: 200, at: tuesday)

        XCTAssertEqual(store.samples.count, 1)
        XCTAssertEqual(store.samples.first?.combinedPaperGain, 200)
        XCTAssertEqual(store.samples.first?.timestamp, tuesday)
    }

    func testSameDayLoadPreservesSamples() throws {
        let suiteName = "MuskometerTests-intraday-same-day-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let morning = try easternDate(year: 2026, month: 6, day: 30, hour: 10)
        let afternoon = try easternDate(year: 2026, month: 6, day: 30, hour: 15)
        let marketHours = FixedMarketHours(isOpen: true)

        let store = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: marketHours,
            now: { morning }
        )
        store.append(personID: "musk", combinedPaperGain: 1_000_000_000, at: morning)
        store.append(personID: "musk", combinedPaperGain: 2_000_000_000, at: afternoon)

        let reloaded = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: marketHours,
            now: { afternoon }
        )
        let samples = reloaded.loadSamples(for: "musk")

        XCTAssertEqual(samples.count, 2)
        XCTAssertEqual(samples.map(\.combinedPaperGain), [1_000_000_000, 2_000_000_000])
    }

    func testNonQuotableAppendAfterMidnightKeepsYesterdaysSamples() throws {
        let suiteName = "MuskometerTests-intraday-closed-rollover-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let monday = try easternDate(year: 2026, month: 6, day: 30, hour: 11)
        let tuesdayOvernight = try easternDate(year: 2026, month: 7, day: 1, hour: 2)

        let openStore = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: FixedMarketHours(isOpen: true),
            now: { monday }
        )
        openStore.append(personID: "musk", combinedPaperGain: 50_000_000_000, at: monday)

        // Closed refresh after ET midnight must not append and must not wipe prior RTH samples.
        let closedHours = FixedMarketHours(isOpen: false)
        let closedStore = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: closedHours,
            now: { tuesdayOvernight }
        )
        closedStore.append(personID: "musk", combinedPaperGain: 50_000_000_000, at: tuesdayOvernight)

        let samples = closedStore.loadSamples(for: "musk")
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples.first?.combinedPaperGain, 50_000_000_000)
        XCTAssertEqual(samples.first?.timestamp, monday)
    }
}

// MARK: - Foundation services

enum EasternTestDates {
    static let eastern = TimeZone(identifier: "America/New_York")!

    static func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = eastern
        return calendar
    }

    static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0
    ) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = eastern
        return try XCTUnwrap(calendar().date(from: components))
    }
}

final class TradingDayCalendarTests: XCTestCase {
    private var tradingCalendar: TradingDayCalendar!
    private var marketHours: MarketHoursService!

    override func setUp() {
        let eastern = EasternTestDates.eastern
        let calendar = EasternTestDates.calendar()
        tradingCalendar = TradingDayCalendar(calendar: calendar, timeZone: eastern)
        marketHours = MarketHoursService(calendar: calendar, timeZone: eastern)
    }

    func testDefaultCalendarIsGregorianEastern() {
        let defaults = TradingDayCalendar()
        XCTAssertEqual(defaults.calendar.identifier, .gregorian)
        XCTAssertEqual(defaults.timeZone.identifier, "America/New_York")
        XCTAssertEqual(defaults.calendar.timeZone.identifier, "America/New_York")
    }

    func testDayKeyUsesEasternCalendarDay() throws {
        let lateEveningUTC = try EasternTestDates.date(year: 2026, month: 7, day: 1, hour: 23)
        XCTAssertEqual(tradingCalendar.dayKey(for: lateEveningUTC), "2026-07-01")
    }

    func testIsSameTradingDayAcrossMidnightEastern() throws {
        let late = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 23, minute: 30)
        let early = try EasternTestDates.date(year: 2026, month: 7, day: 1, hour: 0, minute: 15)
        XCTAssertFalse(tradingCalendar.isSameTradingDay(late, early))
    }

    func testHasTradingDayCompletedAfterRegularClose() throws {
        // RTH ends at 16:00 ET; day is complete once regular close has passed.
        let afterRegularClose = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 16)
        XCTAssertTrue(
            tradingCalendar.hasTradingDayCompleted(
                dayKey: "2026-06-30",
                at: afterRegularClose,
                marketHours: marketHours
            )
        )

        let fivePM = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 17)
        XCTAssertTrue(
            tradingCalendar.hasTradingDayCompleted(
                dayKey: "2026-06-30",
                at: fivePM,
                marketHours: marketHours
            )
        )
    }

    func testHasTradingDayNotCompletedBeforeRegularClose() throws {
        let beforeClose = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 15, minute: 59)
        XCTAssertFalse(
            tradingCalendar.hasTradingDayCompleted(
                dayKey: "2026-06-30",
                at: beforeClose,
                marketHours: marketHours
            )
        )
    }

    func testHasTradingDayNotCompletedDuringSession() throws {
        let midday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        XCTAssertFalse(
            tradingCalendar.hasTradingDayCompleted(
                dayKey: "2026-06-30",
                at: midday,
                marketHours: marketHours
            )
        )
    }

    func testHasTradingDayCompletedAfterEarlyClose() throws {
        // Day after Thanksgiving 2026 early-closes at 13:00 ET.
        let afterEarlyClose = try EasternTestDates.date(year: 2026, month: 11, day: 27, hour: 13)
        XCTAssertTrue(
            tradingCalendar.hasTradingDayCompleted(
                dayKey: "2026-11-27",
                at: afterEarlyClose,
                marketHours: marketHours
            )
        )

        let beforeEarlyClose = try EasternTestDates.date(year: 2026, month: 11, day: 27, hour: 12, minute: 30)
        XCTAssertFalse(
            tradingCalendar.hasTradingDayCompleted(
                dayKey: "2026-11-27",
                at: beforeEarlyClose,
                marketHours: marketHours
            )
        )
    }
}

final class GainNotificationThresholdTests: XCTestCase {
    func testPresetsIncludeSignedFiveTenTwentyFiftyBillions() {
        XCTAssertEqual(GainNotificationThreshold.presets.count, 8)

        let amounts = Set(GainNotificationThreshold.presets.map(\.amount))
        XCTAssertEqual(
            amounts,
            Set([
                5_000_000_000, 10_000_000_000, 20_000_000_000, 50_000_000_000,
                -5_000_000_000, -10_000_000_000, -20_000_000_000, -50_000_000_000
            ])
        )
    }

    func testPresetLookupByID() {
        XCTAssertEqual(GainNotificationThreshold.preset(id: "gain-10b")?.label, "+$10B")
        XCTAssertEqual(GainNotificationThreshold.preset(id: "loss-20b")?.amount, -20_000_000_000)
    }
}

@MainActor
final class NetWorthMilestoneTrackerTests: XCTestCase {
    private func makeTracker(suiteName: String = "MuskometerTests-milestone-\(UUID().uuidString)") -> NetWorthMilestoneTracker {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return NetWorthMilestoneTracker(defaults: defaults)
    }

    private let personID = TrackedPersonProfile.musk.id

    func testCelebratesCrossingOneTrillion() {
        let tracker = makeTracker()
        let event = tracker.update(netWorth: NetWorthMilestoneTracker.oneTrillion, personID: personID)

        guard case .celebration(let milestone) = event else {
            return XCTFail("Expected celebration")
        }
        XCTAssertEqual(milestone.title, "One trillion dollars!")
        XCTAssertEqual(tracker.currentZone(for: personID), .aboveOneTrillion)
    }

    func testCelebratesCrossingTwoTrillion() {
        let tracker = makeTracker()
        _ = tracker.update(netWorth: NetWorthMilestoneTracker.oneTrillion + 1, personID: personID)
        let event = tracker.update(netWorth: NetWorthMilestoneTracker.twoTrillion, personID: personID)

        guard case .celebration(let milestone) = event else {
            return XCTFail("Expected celebration")
        }
        XCTAssertEqual(milestone.title, "Two trillion club!")
        XCTAssertEqual(tracker.currentZone(for: personID), .aboveTwoTrillion)
    }

    func testJumpFromBelowOneTrillionToAboveTwoTrillionCelebratesTwoTrillion() {
        let tracker = makeTracker()
        XCTAssertEqual(tracker.currentZone(for: personID), .belowOneTrillion)

        let event = tracker.update(netWorth: NetWorthMilestoneTracker.twoTrillion, personID: personID)

        guard case .celebration(let milestone) = event else {
            return XCTFail("Expected celebration")
        }
        XCTAssertEqual(milestone.title, "Two trillion club!")
        XCTAssertEqual(tracker.currentZone(for: personID), .aboveTwoTrillion)
    }

    func testHysteresisPreventsFlickerAroundOneTrillion() {
        let tracker = makeTracker()
        _ = tracker.update(netWorth: NetWorthMilestoneTracker.oneTrillion + 5_000_000_000, personID: personID)

        XCTAssertNil(tracker.update(netWorth: NetWorthMilestoneTracker.oneTrillion * 0.995, personID: personID))
        XCTAssertEqual(tracker.currentZone(for: personID), .aboveOneTrillion)

        let event = tracker.update(netWorth: NetWorthMilestoneTracker.oneTrillion * 0.98, personID: personID)
        guard case .fellBelowTrillion(let message) = event else {
            return XCTFail("Expected fellBelowTrillion")
        }
        XCTAssertEqual(message, NetWorthMilestoneTracker.belowTrillionMessage)
        XCTAssertEqual(tracker.currentZone(for: personID), .belowOneTrillion)
    }

    func testSadMessageUsesLoneliestNumberCopy() {
        let tracker = makeTracker()
        _ = tracker.update(netWorth: 1_100_000_000_000, personID: personID)
        let event = tracker.update(netWorth: 900_000_000_000, personID: personID)

        guard case .fellBelowTrillion(let message) = event else {
            return XCTFail("Expected fellBelowTrillion")
        }
        XCTAssertEqual(message, "One Trillion Is the Loneliest Number")
        XCTAssertEqual(message, NetWorthMilestoneTracker.belowTrillionMessage)
    }

    func testNoCelebrationWhenAlreadyAboveTrillion() {
        let tracker = makeTracker()
        _ = tracker.update(netWorth: 1_100_000_000_000, personID: personID)
        XCTAssertNil(tracker.update(netWorth: 1_200_000_000_000, personID: personID))
    }

    func testZonesAreScopedPerPerson() {
        let tracker = makeTracker()
        _ = tracker.update(netWorth: NetWorthMilestoneTracker.oneTrillion, personID: "musk")
        _ = tracker.update(netWorth: 500_000_000_000, personID: "other")

        XCTAssertEqual(tracker.currentZone(for: "musk"), .aboveOneTrillion)
        XCTAssertEqual(tracker.currentZone(for: "other"), .belowOneTrillion)
    }
}



final class OwnershipChangeToastTests: XCTestCase {
    @MainActor
    func testOwnershipChangeToastFormatsDeltas() {
        let message = GainsViewModel.ownershipChangeToast(
            prior: ["TSLA": 100, "SPCX": 200],
            current: ["TSLA": 150, "SPCX": 200]
        )
        XCTAssertEqual(message, "Ownership updated: TSLA 100 → 150")
    }

    @MainActor
    func testOwnershipChangeToastNilWhenUnchanged() {
        XCTAssertNil(
            GainsViewModel.ownershipChangeToast(
                prior: ["TSLA": 100],
                current: ["TSLA": 100]
            )
        )
    }
}

final class MenuBarDisplayModeCycleTests: XCTestCase {
    func testNextCyclesThroughAllCasesInOrder() {
        var mode = MenuBarDisplayMode.allCases[0]
        var seen: [MenuBarDisplayMode] = [mode]
        for _ in 1..<MenuBarDisplayMode.allCases.count {
            mode = mode.next
            seen.append(mode)
        }
        XCTAssertEqual(seen, MenuBarDisplayMode.allCases)
        XCTAssertEqual(mode.next, MenuBarDisplayMode.allCases[0])
    }

    @MainActor
    func testCycleMenuBarDisplayModePersists() {
        let suite = "MuskometerTests-menuBarCycle-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.menuBarDisplayMode, .combinedDollars)
        settings.cycleMenuBarDisplayMode()
        XCTAssertEqual(settings.menuBarDisplayMode, .combinedPercent)
        XCTAssertEqual(defaults.string(forKey: "menuBarDisplayMode"), MenuBarDisplayMode.combinedPercent.rawValue)
    }
}

final class NotificationResponseRouterTests: XCTestCase {
    func testGainThresholdTapOpensPopover() {
        let destination = NotificationResponseRouter.destination(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            categoryIdentifier: NotificationAuthorization.gainThresholdCategoryID,
            userInfo: [
                NotificationAuthorization.notificationKindKey: NotificationAuthorization.gainThresholdKind
            ]
        )
        XCTAssertEqual(destination, .openPopover)
    }

    func testDayCloseTapOpensPopover() {
        let destination = NotificationResponseRouter.destination(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            categoryIdentifier: NotificationAuthorization.dayCloseCategoryID,
            userInfo: [
                NotificationAuthorization.notificationKindKey: NotificationAuthorization.dayCloseKind
            ]
        )
        XCTAssertEqual(destination, .openPopover)
    }

    func testUpdateTapOpensTrustedReleaseURL() {
        let url = URL(string: "https://github.com/jlgolson/muskometer/releases/tag/v1.0.0")!
        let destination = NotificationResponseRouter.destination(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            categoryIdentifier: NotificationAuthorization.updateCategoryID,
            userInfo: ["releaseURL": url.absoluteString]
        )
        XCTAssertEqual(destination, .openURL(url))
    }

    func testUntrustedReleaseURLIsIgnored() {
        let destination = NotificationResponseRouter.destination(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            categoryIdentifier: NotificationAuthorization.updateCategoryID,
            userInfo: ["releaseURL": "https://github.com/jlgolson/muskometer/releases/../../evil"]
        )
        XCTAssertEqual(destination, .ignore)
    }

    func testDismissActionIsIgnored() {
        let destination = NotificationResponseRouter.destination(
            actionIdentifier: UNNotificationDismissActionIdentifier,
            categoryIdentifier: NotificationAuthorization.gainThresholdCategoryID,
            userInfo: [
                NotificationAuthorization.notificationKindKey: NotificationAuthorization.gainThresholdKind
            ]
        )
        XCTAssertEqual(destination, .ignore)
    }
}

@MainActor
final class MenuBarDisplayModeCycleMatcherTests: XCTestCase {
    func testOptionClickOnStatusBarWindowShouldCycle() {
        XCTAssertTrue(
            MenuBarDisplayModeCycleMatcher.shouldCycle(
                modifierFlags: .option,
                windowClassName: "NSStatusBarWindow"
            )
        )
        XCTAssertTrue(
            MenuBarDisplayModeCycleMatcher.shouldCycle(
                modifierFlags: .option,
                windowClassName: "NSStatusItemWindow"
            )
        )
    }

    func testRejectsCommandOptionShiftAndPlainClick() {
        XCTAssertFalse(
            MenuBarDisplayModeCycleMatcher.shouldCycle(
                modifierFlags: [.option, .command],
                windowClassName: "NSStatusBarWindow"
            )
        )
        XCTAssertFalse(
            MenuBarDisplayModeCycleMatcher.shouldCycle(
                modifierFlags: [.option, .shift],
                windowClassName: "NSStatusBarWindow"
            )
        )
        XCTAssertFalse(
            MenuBarDisplayModeCycleMatcher.shouldCycle(
                modifierFlags: .shift,
                windowClassName: "NSStatusBarWindow"
            )
        )
        XCTAssertFalse(
            MenuBarDisplayModeCycleMatcher.shouldCycle(
                modifierFlags: [],
                windowClassName: "NSStatusBarWindow"
            )
        )
    }

    func testNilOrOrdinaryWindowDoesNotCycle() {
        XCTAssertFalse(
            MenuBarDisplayModeCycleMatcher.shouldCycle(
                modifierFlags: .option,
                windowClassName: nil
            )
        )
        XCTAssertFalse(
            MenuBarDisplayModeCycleMatcher.shouldCycle(
                modifierFlags: .option,
                windowClassName: "NSWindow"
            )
        )
    }
}

@MainActor
final class ShareShortcutMatcherTests: XCTestCase {
    func testMatchesCommandShiftC() {
        XCTAssertTrue(
            ShareShortcutMatcher.matches(
                modifierFlags: [.command, .shift],
                charactersIgnoringModifiers: "C"
            )
        )
    }

    func testRejectsCommandOnly() {
        XCTAssertFalse(
            ShareShortcutMatcher.matches(
                modifierFlags: [.command],
                charactersIgnoringModifiers: "C"
            )
        )
    }

    func testRejectsWrongKey() {
        XCTAssertFalse(
            ShareShortcutMatcher.matches(
                modifierFlags: [.command, .shift],
                charactersIgnoringModifiers: "V"
            )
        )
    }

    func testShouldConsumeEventOnSucceededAndDebounced() {
        XCTAssertTrue(ShareShortcutController.shouldConsumeEvent(.succeeded))
        XCTAssertTrue(ShareShortcutController.shouldConsumeEvent(.debounced))
        XCTAssertFalse(ShareShortcutController.shouldConsumeEvent(.failed))
    }
}

@MainActor
final class MutableMockStockService: StockPriceServiceProtocol {
    var quotes: [StockQuote]

    init(quotes: [StockQuote]) {
        self.quotes = quotes
    }

    func fetchQuotes(for symbols: [String]) async throws -> [StockQuote] {
        quotes
    }
}

final class SemanticVersionTests: XCTestCase {
    func testNewerPatchVersion() {
        XCTAssertTrue(SemanticVersion.isNewer("0.1.1", than: "0.1.0"))
    }

    func testNewerMinorVersion() {
        XCTAssertTrue(SemanticVersion.isNewer("0.2.0", than: "0.1.9"))
    }

    func testEqualVersions() {
        XCTAssertFalse(SemanticVersion.isNewer("0.1.0", than: "0.1.0"))
        XCTAssertEqual(SemanticVersion.compare("1.0", "1.0.0"), 0)
    }

    func testOlderVersionIsNotNewer() {
        XCTAssertFalse(SemanticVersion.isNewer("0.1.0", than: "0.2.0"))
    }
}

final class GitHubReleaseUpdateCheckerTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        MockURLProtocol.requestHandler = nil
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        session = nil
        super.tearDown()
    }

    func testReturnsUpdateWhenRemoteVersionIsNewer() async throws {
        let apiURL = URL(string: "https://api.github.com/repos/jlgolson/muskometer/releases/latest")!
        let releaseURL = URL(string: "https://github.com/jlgolson/muskometer/releases/tag/v0.2.0")!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("Muskometer/"), true)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")

            let body = """
            {
              "tag_name": "v0.2.0",
              "html_url": "\(releaseURL.absoluteString)",
              "published_at": "2026-07-02T12:00:00Z",
              "prerelease": false
            }
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }

        let checker = GitHubReleaseUpdateChecker(session: session, apiURL: apiURL)
        let result = try await checker.checkForUpdate(currentVersion: "0.1.0")

        XCTAssertEqual(result?.availableVersion, "0.2.0")
        XCTAssertEqual(result?.releasePageURL, releaseURL)
        XCTAssertNotNil(result?.publishedAt)
    }

    func testSkipsPrerelease() async throws {
        let apiURL = URL(string: "https://api.github.com/repos/jlgolson/muskometer/releases/latest")!

        MockURLProtocol.requestHandler = { request in
            let body = """
            {
              "tag_name": "v0.2.0",
              "html_url": "https://github.com/jlgolson/muskometer/releases/tag/v0.2.0",
              "published_at": null,
              "prerelease": true
            }
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }

        let checker = GitHubReleaseUpdateChecker(session: session, apiURL: apiURL)
        let result = try await checker.checkForUpdate(currentVersion: "0.1.0")
        XCTAssertNil(result)
    }

    func testReturnsNilWhenCurrentVersionIsUpToDate() async throws {
        let apiURL = URL(string: "https://api.github.com/repos/jlgolson/muskometer/releases/latest")!

        MockURLProtocol.requestHandler = { request in
            let body = """
            {
              "tag_name": "v0.1.0",
              "html_url": "https://github.com/jlgolson/muskometer/releases/tag/v0.1.0",
              "published_at": null,
              "prerelease": false
            }
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }

        let checker = GitHubReleaseUpdateChecker(session: session, apiURL: apiURL)
        let result = try await checker.checkForUpdate(currentVersion: "0.1.0")
        XCTAssertNil(result)
    }

    func testThrowsOnNon200Response() async {
        let apiURL = URL(string: "https://api.github.com/repos/jlgolson/muskometer/releases/latest")!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 403,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let checker = GitHubReleaseUpdateChecker(session: session, apiURL: apiURL)

        do {
            _ = try await checker.checkForUpdate(currentVersion: "0.1.0")
            XCTFail("Expected UpdateCheckError")
        } catch let error as UpdateCheckError {
            XCTAssertEqual(error, .invalidResponse(statusCode: 403))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

@MainActor
final class UpdateCoordinatorTests: XCTestCase {
    private func makeCoordinator(
        defaults: UserDefaults,
        settings: AppSettings,
        checkerResult: UpdateCheckResult?,
        deliverer: MockUpdateNotificationDeliverer = MockUpdateNotificationDeliverer()
    ) -> UpdateCoordinator {
        let checker = MockUpdateChecker(result: checkerResult)
        return UpdateCoordinator(
            settings: settings,
            defaults: defaults,
            notificationDeliverer: deliverer,
            githubChecker: checker
        )
    }

    func testDoesNotNotifyWhenDisabled() async {
        let suiteName = "MuskometerTests-update-disabled-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let settings = AppSettings(defaults: defaults)
        settings.notifyOfAvailableUpdates = false

        let deliverer = MockUpdateNotificationDeliverer()
        let releaseURL = URL(string: "https://github.com/jlgolson/muskometer/releases/tag/v0.2.0")!
        let coordinator = makeCoordinator(
            defaults: defaults,
            settings: settings,
            checkerResult: UpdateCheckResult(
                availableVersion: "0.2.0",
                releasePageURL: releaseURL,
                publishedAt: nil
            ),
            deliverer: deliverer
        )

        coordinator.checkNow()
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(coordinator.availableUpdate?.availableVersion, "0.2.0")
        XCTAssertTrue(deliverer.addedRequests.isEmpty)
        XCTAssertEqual(coordinator.manualCheckSummary, "Version 0.2.0 is available.")
    }

    func testManualCheckReportsUpToDate() async {
        let suiteName = "MuskometerTests-update-uptodate-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let settings = AppSettings(defaults: defaults)
        let coordinator = makeCoordinator(
            defaults: defaults,
            settings: settings,
            checkerResult: nil
        )

        coordinator.checkNow()
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertNil(coordinator.availableUpdate)
        XCTAssertTrue(coordinator.manualCheckSummary?.contains("latest version") ?? false)
        XCTAssertNotNil(coordinator.lastCheckDate)
    }

    func testNotifiesWhenEnabledAndNewerVersionFound() async {
        let suiteName = "MuskometerTests-update-enabled-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let settings = AppSettings(defaults: defaults)
        settings.notifyOfAvailableUpdates = true

        let deliverer = MockUpdateNotificationDeliverer()
        let releaseURL = URL(string: "https://github.com/jlgolson/muskometer/releases/tag/v0.2.0")!
        let coordinator = makeCoordinator(
            defaults: defaults,
            settings: settings,
            checkerResult: UpdateCheckResult(
                availableVersion: "0.2.0",
                releasePageURL: releaseURL,
                publishedAt: nil
            ),
            deliverer: deliverer
        )

        coordinator.checkNow()
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(coordinator.availableUpdate?.availableVersion, "0.2.0")
        XCTAssertEqual(deliverer.addedRequests.count, 1)
        XCTAssertEqual(
            deliverer.addedRequests.first?.content.userInfo["releaseURL"] as? String,
            releaseURL.absoluteString
        )
    }

    func testManualCheckSurfacesHTTPErrorAndClearsStaleUpdate() async {
        let suiteName = "MuskometerTests-update-error-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let settings = AppSettings(defaults: defaults)
        settings.notifyOfAvailableUpdates = true

        let releaseURL = URL(string: "https://github.com/jlgolson/muskometer/releases/tag/v0.2.0")!
        let checker = MockUpdateChecker()
        checker.responses = [
            .success(UpdateCheckResult(
                availableVersion: "0.2.0",
                releasePageURL: releaseURL,
                publishedAt: nil
            )),
            .failure(UpdateCheckError.invalidResponse(statusCode: 403))
        ]

        let coordinator = UpdateCoordinator(
            settings: settings,
            defaults: defaults,
            githubChecker: checker
        )

        coordinator.checkNow()
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(coordinator.availableUpdate?.availableVersion, "0.2.0")

        coordinator.checkNow()
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertNil(coordinator.availableUpdate)
        XCTAssertEqual(
            coordinator.lastCheckError,
            UpdateCheckError.invalidResponse(statusCode: 403).localizedDescription
        )
    }

    func testIgnoresUntrustedReleasePageURL() async {
        let suiteName = "MuskometerTests-update-untrusted-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let settings = AppSettings(defaults: defaults)
        settings.notifyOfAvailableUpdates = true

        let deliverer = MockUpdateNotificationDeliverer()
        let evilURL = URL(string: "https://evil.example/phish")!
        let coordinator = makeCoordinator(
            defaults: defaults,
            settings: settings,
            checkerResult: UpdateCheckResult(
                availableVersion: "0.2.0",
                releasePageURL: evilURL,
                publishedAt: nil
            ),
            deliverer: deliverer
        )

        coordinator.checkNow()
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(coordinator.availableUpdate?.availableVersion, "0.2.0")
        XCTAssertTrue(deliverer.addedRequests.isEmpty)
        XCTAssertFalse(AppURLs.isTrustedReleasePageURL(evilURL))
        XCTAssertFalse(
            AppURLs.isTrustedReleasePageURL(
                URL(string: "https://github.com/jlgolson/muskometer/releases/../../evil")!
            )
        )
        XCTAssertFalse(
            AppURLs.isTrustedReleasePageURL(
                URL(string: "https://github.com/jlgolson/muskometer/releases")!
            )
        )
        XCTAssertFalse(
            AppURLs.isTrustedReleasePageURL(
                URL(string: "https://github.com/jlgolson/muskometer/releases/download/v0.2.0/app.zip")!
            )
        )
        XCTAssertTrue(
            AppURLs.isTrustedReleasePageURL(
                URL(string: "https://github.com/jlgolson/muskometer/releases/latest")!
            )
        )
        XCTAssertTrue(
            AppURLs.isTrustedReleasePageURL(
                URL(string: "https://github.com/jlgolson/muskometer/releases/tag/v0.2.0")!
            )
        )
        XCTAssertTrue(
            AppURLs.isTrustedReleasePageURL(
                URL(string: "https://github.com/jlgolson/muskometer/releases/tag/v1.0.0")!
            )
        )
    }
}

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class MockUpdateChecker: UpdateChecking, @unchecked Sendable {
    var responses: [Result<UpdateCheckResult?, Error>] = []
    private var callIndex = 0

    convenience init(result: UpdateCheckResult?) {
        self.init()
        responses = [.success(result)]
    }

    func checkForUpdate(currentVersion: String) async throws -> UpdateCheckResult? {
        guard !responses.isEmpty else { return nil }
        let index = min(callIndex, responses.count - 1)
        callIndex += 1
        switch responses[index] {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

private final class MockUpdateNotificationDeliverer: UpdateNotificationDelivering, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [UNNotificationRequest] = []

    var addedRequests: [UNNotificationRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    func add(_ request: UNNotificationRequest) async throws {
        lock.lock()
        requests.append(request)
        lock.unlock()
    }
}