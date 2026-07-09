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

final class MarketHoursServiceTests: XCTestCase {
    private var calendar: Calendar!
    private var eastern: TimeZone!

    override func setUp() {
        eastern = TimeZone(identifier: "America/New_York")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = eastern
        calendar = cal
    }

    func testWeekdayDuringMarketHoursIsOpen() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 30
        components.hour = 11
        components.minute = 0
        components.timeZone = eastern

        let monday = try XCTUnwrap(calendar.date(from: components))
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)

        XCTAssertTrue(service.isMarketOpen(at: monday))
    }

    func testWeekendIsClosed() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 28
        components.hour = 11
        components.minute = 0
        components.timeZone = eastern

        let saturday = try XCTUnwrap(calendar.date(from: components))
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)

        XCTAssertFalse(service.isMarketOpen(at: saturday))
    }

    func testHolidayIsClosed() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 3
        components.hour = 11
        components.minute = 0
        components.timeZone = eastern

        let holiday = try XCTUnwrap(calendar.date(from: components))
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)

        XCTAssertFalse(service.isMarketOpen(at: holiday))
    }

    func test2027HolidayIsClosed() throws {
        var components = DateComponents()
        components.year = 2027
        components.month = 1
        components.day = 18
        components.hour = 11
        components.minute = 0
        components.timeZone = eastern

        let holiday = try XCTUnwrap(calendar.date(from: components))
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)

        XCTAssertFalse(service.isMarketOpen(at: holiday))
    }

    func test2027GoodFridayIsClosed() throws {
        // Easter 2027 is March 28 → NYSE Good Friday is March 26
        var components = DateComponents()
        components.year = 2027
        components.month = 3
        components.day = 26
        components.hour = 11
        components.minute = 0
        components.timeZone = eastern

        let holiday = try XCTUnwrap(calendar.date(from: components))
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)

        XCTAssertFalse(service.isMarketOpen(at: holiday))

        // Regression: April 2 2027 is a regular Friday, not Good Friday
        components.month = 4
        components.day = 2
        let notHoliday = try XCTUnwrap(calendar.date(from: components))
        XCTAssertTrue(service.isMarketOpen(at: notHoliday))
    }

    func testNextOpenAfterHoursIsRegularOpenNotPreMarket() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 30
        components.hour = 20
        components.minute = 0
        components.timeZone = eastern

        let tuesdayEvening = try XCTUnwrap(calendar.date(from: components))
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)

        let nextOpen = try XCTUnwrap(service.nextOpenDate(from: tuesdayEvening))

        XCTAssertEqual(calendar.component(.hour, from: nextOpen), 9)
        XCTAssertEqual(calendar.component(.minute, from: nextOpen), 30)
        XCTAssertEqual(calendar.component(.day, from: nextOpen), 1)
        XCTAssertEqual(calendar.component(.month, from: nextOpen), 7)
    }

    func testLastMarketCloseAfterHoursSameDay() throws {
        let afterClose = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 17)
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)

        let close = try XCTUnwrap(service.lastMarketClose(from: afterClose))

        XCTAssertEqual(calendar.component(.year, from: close), 2026)
        XCTAssertEqual(calendar.component(.month, from: close), 6)
        XCTAssertEqual(calendar.component(.day, from: close), 30)
        XCTAssertEqual(calendar.component(.hour, from: close), 16)
        XCTAssertEqual(calendar.component(.minute, from: close), 0)
    }

    func testLastMarketCloseBeforeOpenUsesPreviousTradingDay() throws {
        let wednesdayMorning = try EasternTestDates.date(year: 2026, month: 7, day: 1, hour: 7)
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)

        let close = try XCTUnwrap(service.lastMarketClose(from: wednesdayMorning))

        XCTAssertEqual(calendar.component(.month, from: close), 6)
        XCTAssertEqual(calendar.component(.day, from: close), 30)
        XCTAssertEqual(calendar.component(.hour, from: close), 16)
    }

    func testLastMarketCloseOnHolidayUsesPreviousTradingDay() throws {
        let holidayMorning = try EasternTestDates.date(year: 2026, month: 7, day: 3, hour: 11)
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)

        let close = try XCTUnwrap(service.lastMarketClose(from: holidayMorning))

        XCTAssertEqual(calendar.component(.month, from: close), 7)
        XCTAssertEqual(calendar.component(.day, from: close), 2)
        XCTAssertEqual(calendar.component(.hour, from: close), 16)
    }

    func testPreMarketHoursAreClosedAndNotQuotable() throws {
        // 8:00 AM ET weekday — formerly pre-market; RTH-only treats as closed
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 1
        components.hour = 8
        components.minute = 0
        components.timeZone = eastern

        let wednesdayMorning = try XCTUnwrap(calendar.date(from: components))
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)

        XCTAssertEqual(service.currentSession(at: wednesdayMorning), .closed)
        XCTAssertFalse(service.isQuotable(at: wednesdayMorning))
        XCTAssertFalse(service.isMarketOpen(at: wednesdayMorning))

        let nextOpen = try XCTUnwrap(service.nextOpenDate(from: wednesdayMorning))
        XCTAssertEqual(calendar.component(.hour, from: nextOpen), 9)
        XCTAssertEqual(calendar.component(.minute, from: nextOpen), 30)
        XCTAssertEqual(calendar.component(.day, from: nextOpen), 1)
    }

    func testTradingSessionBoundariesAreRTHOnly() throws {
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)
        let day = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 0)

        let preMarket = try XCTUnwrap(calendar.date(bySettingHour: 5, minute: 0, second: 0, of: day))
        let eightAM = try XCTUnwrap(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day))
        let regular = try XCTUnwrap(calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day))
        let fivePM = try XCTUnwrap(calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day))
        let overnight = try XCTUnwrap(calendar.date(bySettingHour: 2, minute: 0, second: 0, of: day))
        let afterPost = try XCTUnwrap(calendar.date(bySettingHour: 21, minute: 0, second: 0, of: day))

        XCTAssertEqual(service.currentSession(at: preMarket), .closed)
        XCTAssertEqual(service.currentSession(at: eightAM), .closed)
        XCTAssertEqual(service.currentSession(at: regular), .regular)
        XCTAssertEqual(service.currentSession(at: fivePM), .closed)
        XCTAssertEqual(service.currentSession(at: overnight), .closed)
        XCTAssertEqual(service.currentSession(at: afterPost), .closed)

        XCTAssertFalse(service.isQuotable(at: preMarket))
        XCTAssertFalse(service.isQuotable(at: eightAM))
        XCTAssertTrue(service.isQuotable(at: regular))
        XCTAssertFalse(service.isQuotable(at: fivePM))
        XCTAssertFalse(service.isQuotable(at: overnight))
        XCTAssertFalse(service.isQuotable(at: afterPost))
    }

    func testNextOpenBeforeRegularOpenSameDayIs930AM() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 1
        components.hour = 3
        components.minute = 0
        components.timeZone = eastern

        let earlyMorning = try XCTUnwrap(calendar.date(from: components))
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)

        let nextOpen = try XCTUnwrap(service.nextOpenDate(from: earlyMorning))

        XCTAssertEqual(calendar.component(.hour, from: nextOpen), 9)
        XCTAssertEqual(calendar.component(.minute, from: nextOpen), 30)
        XCTAssertEqual(calendar.component(.day, from: nextOpen), 1)
    }

    /// Day after Thanksgiving 2026 is an NYSE early close at 13:00 ET.
    func testEarlyCloseAfternoonIsClosed() throws {
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)

        // 12:30 ET — still regular (before 13:00 early close)
        let beforeEarlyClose = try EasternTestDates.date(year: 2026, month: 11, day: 27, hour: 12, minute: 30)
        XCTAssertEqual(service.currentSession(at: beforeEarlyClose), .regular)
        XCTAssertTrue(service.isMarketOpen(at: beforeEarlyClose))

        // 14:00 ET — regular already ended; RTH-only treats as closed (not post-market)
        let afternoon = try EasternTestDates.date(year: 2026, month: 11, day: 27, hour: 14)
        XCTAssertEqual(service.currentSession(at: afternoon), .closed)
        XCTAssertFalse(service.isMarketOpen(at: afternoon))
        XCTAssertFalse(service.isQuotable(at: afternoon))

        // 21:00 ET — still closed
        let evening = try EasternTestDates.date(year: 2026, month: 11, day: 27, hour: 21)
        XCTAssertEqual(service.currentSession(at: evening), .closed)
        XCTAssertFalse(service.isQuotable(at: evening))
    }

    func testEarlyCloseChristmasEve2026() throws {
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)
        let afternoon = try EasternTestDates.date(year: 2026, month: 12, day: 24, hour: 14)

        XCTAssertEqual(service.currentSession(at: afternoon), .closed)
        XCTAssertFalse(service.isMarketOpen(at: afternoon))
        XCTAssertFalse(service.isQuotable(at: afternoon))
    }

    func testLastMarketCloseOnEarlyCloseDayIs1PM() throws {
        let afterEarlyClose = try EasternTestDates.date(year: 2026, month: 11, day: 27, hour: 14)
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)

        let close = try XCTUnwrap(service.lastMarketClose(from: afterEarlyClose))

        XCTAssertEqual(calendar.component(.year, from: close), 2026)
        XCTAssertEqual(calendar.component(.month, from: close), 11)
        XCTAssertEqual(calendar.component(.day, from: close), 27)
        XCTAssertEqual(calendar.component(.hour, from: close), 13)
        XCTAssertEqual(calendar.component(.minute, from: close), 0)
    }

    func testEarlyCloseDayAfterThanksgiving2027() throws {
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)
        let afternoon = try EasternTestDates.date(year: 2027, month: 11, day: 26, hour: 14)

        XCTAssertEqual(service.currentSession(at: afternoon), .closed)
        XCTAssertFalse(service.isMarketOpen(at: afternoon))
        XCTAssertFalse(service.isQuotable(at: afternoon))
    }

    func testRegularCloseDateUsesEarlyCloseWhenApplicable() throws {
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)
        let earlyCloseDay = try EasternTestDates.date(year: 2026, month: 11, day: 27, hour: 10)
        let normalDay = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 10)

        let earlyClose = try XCTUnwrap(service.regularCloseDate(on: earlyCloseDay))
        XCTAssertEqual(calendar.component(.hour, from: earlyClose), 13)
        XCTAssertEqual(calendar.component(.minute, from: earlyClose), 0)

        let normalClose = try XCTUnwrap(service.regularCloseDate(on: normalDay))
        XCTAssertEqual(calendar.component(.hour, from: normalClose), 16)
        XCTAssertEqual(calendar.component(.minute, from: normalClose), 0)
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

final class AppSettingsHoldingsSyncTests: XCTestCase {
    private func makeSettings() -> AppSettings {
        let suiteName = "MuskometerTests-holdings-sync-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppSettings(defaults: defaults)
    }

    func testEmptyResultDoesNotSetLastHoldingsSyncDate() {
        let settings = makeSettings()
        let syncedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let complete = settings.applyHoldingsSync(
            HoldingsSyncResult(
                sharesBySymbol: [:],
                syncedAt: syncedAt,
                sourceDescription: "SEC EDGAR Form 4"
            )
        )

        XCTAssertFalse(complete)
        XCTAssertNil(settings.lastHoldingsSyncDate)
        XCTAssertNil(settings.holdingsSyncSource)
        // Attempt is still recorded so auto-retry backs off.
        XCTAssertEqual(settings.lastHoldingsSyncAttemptAt, syncedAt)
    }

    func testPartialResultDoesNotSetLastHoldingsSyncDate() {
        let settings = makeSettings()
        let syncedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let priorTSLA = settings.shareCount(for: "TSLA")
        let priorSPCX = settings.shareCount(for: "SPCX")

        let complete = settings.applyHoldingsSync(
            HoldingsSyncResult(
                sharesBySymbol: ["TSLA": 123],
                syncedAt: syncedAt,
                sourceDescription: "SEC EDGAR Form 4"
            )
        )

        XCTAssertFalse(complete)
        // Partial sync must not overwrite any share counts — keep prior values.
        XCTAssertEqual(settings.shareCount(for: "TSLA"), priorTSLA)
        XCTAssertEqual(settings.shareCount(for: "SPCX"), priorSPCX)
        XCTAssertNil(settings.lastHoldingsSyncDate)
        XCTAssertNil(settings.holdingsSyncSource)
        XCTAssertEqual(settings.lastHoldingsSyncAttemptAt, syncedAt)
    }

    func testPartialApplySuppressesNeedsHoldingsSyncUntilIntervalElapses() {
        let settings = makeSettings()
        XCTAssertTrue(settings.needsHoldingsSync)

        // Whole-second Date avoids flaky equality after UserDefaults Double round-trip.
        let recentAttempt = Date(timeIntervalSince1970: floor(Date.now.timeIntervalSince1970) - 60)
        let complete = settings.applyHoldingsSync(
            HoldingsSyncResult(
                sharesBySymbol: ["TSLA": 123],
                syncedAt: recentAttempt,
                sourceDescription: "SEC EDGAR Form 4"
            )
        )

        XCTAssertFalse(complete)
        XCTAssertNil(settings.lastHoldingsSyncDate)
        XCTAssertEqual(
            settings.lastHoldingsSyncAttemptAt?.timeIntervalSince1970 ?? 0,
            recentAttempt.timeIntervalSince1970,
            accuracy: 0.001
        )
        // Partial apply must not re-trigger auto-sync on the next quote cycle.
        XCTAssertFalse(settings.needsHoldingsSync)

        // Once the daily interval elapses, auto-sync is allowed again.
        settings.recordHoldingsSyncAttempt(
            at: Date(timeIntervalSince1970: floor(Date.now.timeIntervalSince1970) - (AppSettings.holdingsSyncInterval + 1))
        )
        XCTAssertTrue(settings.needsHoldingsSync)
    }

    func testFullResultSetsLastHoldingsSyncDate() {
        let settings = makeSettings()
        let syncedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let complete = settings.applyHoldingsSync(
            HoldingsSyncResult(
                sharesBySymbol: ["TSLA": 123, "SPCX": 456],
                syncedAt: syncedAt,
                sourceDescription: "SEC EDGAR Form 4"
            )
        )

        XCTAssertTrue(complete)
        XCTAssertEqual(settings.shareCount(for: "TSLA"), 123)
        XCTAssertEqual(settings.shareCount(for: "SPCX"), 456)
        XCTAssertEqual(settings.lastHoldingsSyncDate, syncedAt)
        XCTAssertEqual(settings.lastHoldingsSyncAttemptAt, syncedAt)
        XCTAssertEqual(settings.holdingsSyncSource, "SEC EDGAR Form 4")
        // Successful complete within the interval also suppresses auto-sync.
        settings.recordHoldingsSyncAttempt(at: Date.now)
        XCTAssertFalse(settings.needsHoldingsSync)
    }

    func testCompleteResultWithZeroSharesAppliesFullDisposal() {
        let settings = makeSettings()
        let syncedAt = Date(timeIntervalSince1970: 1_700_000_000)
        // Establish non-zero prior so we can prove zero is applied (not left as default/prior).
        settings.setShareCount(999_999, for: "TSLA")
        settings.setShareCount(888_888, for: "SPCX")

        let complete = settings.applyHoldingsSync(
            HoldingsSyncResult(
                sharesBySymbol: ["TSLA": 0, "SPCX": 456],
                syncedAt: syncedAt,
                sourceDescription: "SEC EDGAR Form 4"
            )
        )

        XCTAssertTrue(complete)
        XCTAssertEqual(settings.shareCount(for: "TSLA"), 0)
        XCTAssertEqual(settings.shareCount(for: "SPCX"), 456)
        XCTAssertEqual(settings.lastHoldingsSyncDate, syncedAt)
        XCTAssertEqual(settings.holdingsSyncSource, "SEC EDGAR Form 4")
    }

    func testPartialResultWithOnlyZeroForOneSymbolRemainsIncomplete() {
        let settings = makeSettings()
        let syncedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let priorTSLA = settings.shareCount(for: "TSLA")
        let priorSPCX = settings.shareCount(for: "SPCX")

        // Only one expected symbol present (as zero). Missing SPCX means incomplete —
        // zero alone must not be treated as a complete sync that clears prior counts.
        let complete = settings.applyHoldingsSync(
            HoldingsSyncResult(
                sharesBySymbol: ["TSLA": 0],
                syncedAt: syncedAt,
                sourceDescription: "SEC EDGAR Form 4"
            )
        )

        XCTAssertFalse(complete)
        XCTAssertEqual(settings.shareCount(for: "TSLA"), priorTSLA)
        XCTAssertEqual(settings.shareCount(for: "SPCX"), priorSPCX)
        XCTAssertNil(settings.lastHoldingsSyncDate)
        XCTAssertNil(settings.holdingsSyncSource)
        XCTAssertEqual(settings.lastHoldingsSyncAttemptAt, syncedAt)
    }

    func testUnknownPersonIDFallsBackToMusk() {
        let settings = makeSettings()
        settings.selectedPersonID = "zuckerberg"

        XCTAssertEqual(settings.selectedPersonID, "zuckerberg")
        XCTAssertEqual(settings.selectedProfile.id, TrackedPersonProfile.musk.id)
        XCTAssertEqual(settings.selectedProfile.expectedSymbols, Set(["TSLA", "SPCX"]))
    }

}

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
            holdingsSyncServiceFactory: { _ in mock }
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
            holdingsSyncServiceFactory: { _ in mock }
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

private final class MockHoldingsSyncService: HoldingsSyncServiceProtocol, @unchecked Sendable {
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

        XCTAssertEqual(settings.shareCount(for: "TSLA"), 699_580_882)
        XCTAssertEqual(settings.shareCount(for: "SPCX"), 6_068_734_060)
        XCTAssertEqual(settings.selectedPersonID, TrackedPersonProfile.musk.id)
        XCTAssertTrue(settings.showMenuBarIcon)
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

    func testTotalWorthDisplayModePersists() {
        let defaults = UserDefaults(suiteName: "MuskometerTests-total-worth")!
        defaults.removePersistentDomain(forName: "MuskometerTests-total-worth")

        let settings = AppSettings(defaults: defaults)
        settings.menuBarDisplayMode = .totalWorth

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.menuBarDisplayMode, .totalWorth)
    }
}

final class AppSettingsLaunchAtLoginTests: XCTestCase {
    private func makeDefaults(suiteName: String = "MuskometerTests-launch-\(UUID().uuidString)") -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeSettings(
        defaults: UserDefaults? = nil,
        manager: MockLaunchAtLoginManager = MockLaunchAtLoginManager()
    ) -> (AppSettings, MockLaunchAtLoginManager, UserDefaults) {
        let defaults = defaults ?? makeDefaults()
        let settings = AppSettings(defaults: defaults, launchAtLoginManager: manager)
        return (settings, manager, defaults)
    }

    func testEnableSuccessClearsErrorAndPersistsTrue() {
        let (settings, manager, defaults) = makeSettings()

        settings.launchAtLogin = true

        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertNil(settings.launchAtLoginError)
        XCTAssertTrue(defaults.bool(forKey: "launchAtLogin"))
        XCTAssertEqual(manager.setEnabledCalls, [true])
        XCTAssertTrue(manager.isEnabled)
    }

    func testEnableFailureRevertsToggleAndSurfacesError() {
        let manager = MockLaunchAtLoginManager(isEnabled: false)
        manager.setEnabledHandler = { _ in
            throw NSError(
                domain: "MuskometerTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "registration failed"]
            )
        }
        let (settings, _, defaults) = makeSettings(manager: manager)

        settings.launchAtLogin = true

        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertEqual(
            settings.launchAtLoginError,
            "Couldn't enable launch at login: registration failed"
        )
        XCTAssertFalse(defaults.bool(forKey: "launchAtLogin"))
        XCTAssertEqual(manager.setEnabledCalls, [true])
        XCTAssertFalse(manager.isEnabled)
    }

    func testDisableFailureRevertsToggleAndSurfacesError() {
        let manager = MockLaunchAtLoginManager(isEnabled: true)
        manager.setEnabledHandler = { _ in
            throw NSError(
                domain: "MuskometerTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "unregister failed"]
            )
        }
        let defaults = makeDefaults()
        defaults.set(true, forKey: "launchAtLogin")
        let (settings, _, _) = makeSettings(defaults: defaults, manager: manager)

        settings.launchAtLogin = false

        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertEqual(
            settings.launchAtLoginError,
            "Couldn't disable launch at login: unregister failed"
        )
        XCTAssertTrue(defaults.bool(forKey: "launchAtLogin"))
        XCTAssertEqual(manager.setEnabledCalls, [false])
    }

    func testSuccessfulToggleClearsPreviousError() {
        let manager = MockLaunchAtLoginManager(isEnabled: false)
        var shouldFail = true
        manager.setEnabledHandler = { enabled in
            if shouldFail {
                throw NSError(
                    domain: "MuskometerTests",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "registration failed"]
                )
            }
            manager.isEnabled = enabled
        }
        let (settings, _, _) = makeSettings(manager: manager)

        settings.launchAtLogin = true
        XCTAssertNotNil(settings.launchAtLoginError)

        shouldFail = false
        settings.launchAtLogin = true

        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertNil(settings.launchAtLoginError)
        XCTAssertTrue(manager.isEnabled)
    }

    func testSyncAppliesDesiredAndResolvesFromServiceOnFailure() {
        let manager = MockLaunchAtLoginManager(isEnabled: false)
        manager.setEnabledHandler = { _ in
            throw NSError(
                domain: "MuskometerTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "registration failed"]
            )
        }
        let defaults = makeDefaults()
        defaults.set(true, forKey: "launchAtLogin")
        let (settings, _, _) = makeSettings(defaults: defaults, manager: manager)

        settings.syncLaunchAtLoginFromService()

        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertEqual(
            settings.launchAtLoginError,
            "Couldn't enable launch at login: registration failed"
        )
        XCTAssertFalse(defaults.bool(forKey: "launchAtLogin"))
        XCTAssertEqual(manager.setEnabledCalls, [true])
    }

    func testSyncSucceedsWhenServiceAcceptsDesiredState() {
        let manager = MockLaunchAtLoginManager(isEnabled: false)
        let defaults = makeDefaults()
        defaults.set(true, forKey: "launchAtLogin")
        let (settings, _, _) = makeSettings(defaults: defaults, manager: manager)

        settings.syncLaunchAtLoginFromService()

        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertNil(settings.launchAtLoginError)
        XCTAssertTrue(defaults.bool(forKey: "launchAtLogin"))
        XCTAssertEqual(manager.setEnabledCalls, [true])
        XCTAssertTrue(manager.isEnabled)
    }

    func testSyncWhenAlreadyMatchedClearsErrorWithoutCallingSet() {
        let manager = MockLaunchAtLoginManager(isEnabled: false)
        manager.setEnabledHandler = { _ in
            throw NSError(
                domain: "MuskometerTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "registration failed"]
            )
        }
        let (settings, _, _) = makeSettings(manager: manager)

        settings.launchAtLogin = true
        XCTAssertNotNil(settings.launchAtLoginError)
        XCTAssertFalse(settings.launchAtLogin)
        let callsAfterFailure = manager.setEnabledCalls.count

        // Preference and service already agree (both off); sync should clear the stale error.
        settings.syncLaunchAtLoginFromService()

        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertNil(settings.launchAtLoginError)
        XCTAssertEqual(manager.setEnabledCalls.count, callsAfterFailure)
    }

    func testSoftEnableKeepsDesiredTrueAndSurfacesPendingApproval() {
        let manager = MockLaunchAtLoginManager(isEnabled: false)
        manager.setEnabledHandler = { _ in
            // Pretend registration "succeeds" without flipping isEnabled
            // (SMAppService often stays .requiresApproval after register()).
        }
        let (settings, _, defaults) = makeSettings(manager: manager)

        settings.launchAtLogin = true

        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertEqual(
            settings.launchAtLoginError,
            "Launch at login is waiting for approval in System Settings → General → Login Items."
        )
        XCTAssertTrue(defaults.bool(forKey: "launchAtLogin"))
        XCTAssertEqual(manager.setEnabledCalls, [true])
        XCTAssertFalse(manager.isEnabled)
    }

    func testSoftEnableSyncReattemptsWithoutWipingDesiredTrue() {
        let manager = MockLaunchAtLoginManager(isEnabled: false)
        manager.setEnabledHandler = { _ in
            // Soft: no throw, still disabled.
        }
        let (settings, _, defaults) = makeSettings(manager: manager)

        settings.launchAtLogin = true
        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertNotNil(settings.launchAtLoginError)
        XCTAssertEqual(manager.setEnabledCalls, [true])

        settings.syncLaunchAtLoginFromService()

        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertEqual(
            settings.launchAtLoginError,
            "Launch at login is waiting for approval in System Settings → General → Login Items."
        )
        XCTAssertTrue(defaults.bool(forKey: "launchAtLogin"))
        XCTAssertEqual(manager.setEnabledCalls, [true, true])
        XCTAssertFalse(manager.isEnabled)
    }

    func testSoftEnableSyncClearsErrorWhenServiceBecomesEnabled() {
        let manager = MockLaunchAtLoginManager(isEnabled: false)
        manager.setEnabledHandler = { _ in
            // Soft: no throw, still disabled until approval.
        }
        let (settings, _, defaults) = makeSettings(manager: manager)

        settings.launchAtLogin = true
        XCTAssertNotNil(settings.launchAtLoginError)

        // User approved in System Settings; service is now enabled.
        manager.isEnabled = true
        manager.setEnabledHandler = { enabled in
            manager.isEnabled = enabled
        }

        settings.syncLaunchAtLoginFromService()

        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertNil(settings.launchAtLoginError)
        XCTAssertTrue(defaults.bool(forKey: "launchAtLogin"))
        // Matched path: no setEnabled call needed once service is already enabled.
        XCTAssertEqual(manager.setEnabledCalls, [true])
    }

    func testSoftDisableMismatchAdoptsServiceReality() {
        let manager = MockLaunchAtLoginManager(isEnabled: true)
        manager.setEnabledHandler = { _ in
            // Unregister "succeeds" but service remains enabled.
        }
        let defaults = makeDefaults()
        defaults.set(true, forKey: "launchAtLogin")
        let (settings, _, _) = makeSettings(defaults: defaults, manager: manager)

        settings.launchAtLogin = false

        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertEqual(
            settings.launchAtLoginError,
            "Couldn't disable launch at login. Check System Settings → General → Login Items."
        )
        XCTAssertTrue(defaults.bool(forKey: "launchAtLogin"))
        XCTAssertEqual(manager.setEnabledCalls, [false])
        XCTAssertTrue(manager.isEnabled)
    }

    func testResetToDefaultsDisablesLaunchAtLoginAndClearsError() {
        let (settings, manager, defaults) = makeSettings()

        settings.launchAtLogin = true
        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertTrue(manager.isEnabled)
        XCTAssertEqual(manager.setEnabledCalls, [true])

        settings.resetToDefaults()

        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertNil(settings.launchAtLoginError)
        XCTAssertFalse(defaults.bool(forKey: "launchAtLogin"))
        XCTAssertEqual(manager.setEnabledCalls, [true, false])
        XCTAssertFalse(manager.isEnabled)
    }

    func testResetToDefaultsClearsStaleLaunchAtLoginErrorWhenAlreadyOff() {
        let manager = MockLaunchAtLoginManager(isEnabled: false)
        manager.setEnabledHandler = { _ in
            throw NSError(
                domain: "MuskometerTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "registration failed"]
            )
        }
        let (settings, _, defaults) = makeSettings(manager: manager)

        settings.launchAtLogin = true
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertNotNil(settings.launchAtLoginError)
        let callsAfterFailure = manager.setEnabledCalls.count

        // Successful re-apply on reset should clear the stale error even though
        // the toggle was already false (didSet would not fire).
        manager.setEnabledHandler = { enabled in
            manager.isEnabled = enabled
        }

        settings.resetToDefaults()

        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertNil(settings.launchAtLoginError)
        XCTAssertFalse(defaults.bool(forKey: "launchAtLogin"))
        XCTAssertEqual(manager.setEnabledCalls.count, callsAfterFailure + 1)
        XCTAssertEqual(manager.setEnabledCalls.last, false)
        XCTAssertFalse(manager.isEnabled)
    }
}

private final class MockLaunchAtLoginManager: LaunchAtLoginManaging {
    var isEnabled: Bool
    var setEnabledHandler: ((Bool) throws -> Void)?
    private(set) var setEnabledCalls: [Bool] = []

    init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    func setEnabled(_ enabled: Bool) throws {
        setEnabledCalls.append(enabled)
        if let setEnabledHandler {
            try setEnabledHandler(enabled)
        } else {
            isEnabled = enabled
        }
    }
}

final class MenuBarDisplayModeTests: XCTestCase {
    func testTotalWorthLabel() {
        XCTAssertEqual(MenuBarDisplayMode.totalWorth.label, "Total worth")
    }
}

final class SPCXHoldingsTests: XCTestCase {
    func testMigratesLegacyScaledDefault() {
        XCTAssertEqual(SPCXHoldings.migrateStoredShareCount(60_685_475), 6_068_734_060)
    }

    func testMigratesLegacySingleRowParse() {
        XCTAssertEqual(SPCXHoldings.migrateStoredShareCount(842_091_670), 6_068_734_060)
    }

    func testMigratesLegacyPartialAggregateDefault() {
        XCTAssertEqual(SPCXHoldings.migrateStoredShareCount(6_068_547_515), 6_068_734_060)
    }

    func testLeavesAggregatedShareCountUntouched() {
        XCTAssertEqual(SPCXHoldings.migrateStoredShareCount(6_068_734_060), 6_068_734_060)
        XCTAssertEqual(SPCXHoldings.migrateStoredShareCount(6_068_547_514), 6_068_547_514)
    }

    /// Legacy fingerprints already under `shareCount_SPCX` must be rewritten on load.
    func testAppSettingsRewritesLegacyFingerprintUnderNewKey() {
        let suiteName = "MuskometerTests-spcx-newkey-legacy-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Partial aggregate already stored under the new key (never re-migrated before this fix).
        defaults.set(String(6_068_547_515), forKey: "shareCount_SPCX")

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.shareCount(for: "SPCX"), SPCXHoldings.defaultShareCount)
        XCTAssertEqual(defaults.string(forKey: "shareCount_SPCX"), String(SPCXHoldings.defaultShareCount))
    }

    /// Non-fingerprint values under the new key must not be rewritten.
    func testAppSettingsLeavesUnknownSPCXShareCountUnderNewKey() {
        let suiteName = "MuskometerTests-spcx-newkey-unknown-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let customCount: Int64 = 6_068_547_514
        defaults.set(String(customCount), forKey: "shareCount_SPCX")

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.shareCount(for: "SPCX"), customCount)
        XCTAssertEqual(defaults.string(forKey: "shareCount_SPCX"), String(customCount))
    }
}

final class SPCXOwnershipCalculatorTests: XCTestCase {
    func testAggregatesJune2026Form4Holdings() {
        let xml = """
        <ownershipDocument>
            <issuer><issuerTradingSymbol>SPCX</issuerTradingSymbol></issuer>
            <nonDerivativeTable>
                <nonDerivativeHolding>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>842091670</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Elon Musk Revocable Trust</value></natureOfOwnership></ownershipNature>
                </nonDerivativeHolding>
                <nonDerivativeHolding>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>7402770</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By EM 2024 GRAT-A</value></natureOfOwnership></ownershipNature>
                </nonDerivativeHolding>
                <nonDerivativeHolding>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>186545</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Trust</value></natureOfOwnership></ownershipNature>
                </nonDerivativeHolding>
            </nonDerivativeTable>
            <derivativeTable>
                <derivativeHolding>
                    <securityTitle><value>Class B Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>3788654145</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Elon Musk Revocable Trust</value></natureOfOwnership></ownershipNature>
                </derivativeHolding>
                <derivativeHolding>
                    <securityTitle><value>Class B Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>127426150</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Mission Trust</value></natureOfOwnership></ownershipNature>
                </derivativeHolding>
                <derivativeHolding>
                    <securityTitle><value>Class B Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>900495</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Musk 2017 Sprinkling Trust</value></natureOfOwnership></ownershipNature>
                </derivativeHolding>
            </derivativeTable>
            <remarks>does not include 1302072285 shares of restricted Class B Common Stock</remarks>
        </ownershipDocument>
        """

        XCTAssertEqual(SPCXOwnershipCalculator.totalPublicShares(from: xml), 6_068_734_060)
    }

    func testUsesLatestRowNotMaxWhenLaterRowHasLowerShares() {
        // Same (title, nature) appears twice; later post-transaction amount is lower (sale).
        let xml = """
        <ownershipDocument>
            <issuer><issuerTradingSymbol>SPCX</issuerTradingSymbol></issuer>
            <nonDerivativeTable>
                <nonDerivativeTransaction>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>1000000</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Elon Musk Revocable Trust</value></natureOfOwnership></ownershipNature>
                </nonDerivativeTransaction>
                <nonDerivativeTransaction>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>400000</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Elon Musk Revocable Trust</value></natureOfOwnership></ownershipNature>
                </nonDerivativeTransaction>
                <nonDerivativeHolding>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>100000</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Other Trust</value></natureOfOwnership></ownershipNature>
                </nonDerivativeHolding>
            </nonDerivativeTable>
        </ownershipDocument>
        """

        // Latest for Revocable Trust is 400_000 (not max 1_000_000) + 100_000 other = 500_000
        XCTAssertEqual(SPCXOwnershipCalculator.totalPublicShares(from: xml), 500_000)
    }

    func testUsesLatestZeroRowWhenTrustFullyDisposed() {
        // Full disposal: same (title, nature) goes 1_000_000 → 0; disposed line must not contribute.
        let xml = """
        <ownershipDocument>
            <issuer><issuerTradingSymbol>SPCX</issuerTradingSymbol></issuer>
            <nonDerivativeTable>
                <nonDerivativeTransaction>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>1000000</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Elon Musk Revocable Trust</value></natureOfOwnership></ownershipNature>
                </nonDerivativeTransaction>
                <nonDerivativeTransaction>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>0</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Elon Musk Revocable Trust</value></natureOfOwnership></ownershipNature>
                </nonDerivativeTransaction>
                <nonDerivativeHolding>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>100000</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Other Trust</value></natureOfOwnership></ownershipNature>
                </nonDerivativeHolding>
            </nonDerivativeTable>
        </ownershipDocument>
        """

        // Latest for Revocable Trust is 0 (not 1_000_000) + 100_000 other = 100_000
        XCTAssertEqual(SPCXOwnershipCalculator.totalPublicShares(from: xml), 100_000)
    }

    func testConvertsSeriesAPreferredToClassAEquivalentTimes50() {
        let xml = """
        <ownershipDocument>
            <issuer><issuerTradingSymbol>SPCX</issuerTradingSymbol></issuer>
            <derivativeTable>
                <derivativeHolding>
                    <securityTitle><value>Series A Preferred Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>1000</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Elon Musk Revocable Trust</value></natureOfOwnership></ownershipNature>
                </derivativeHolding>
                <derivativeHolding>
                    <securityTitle><value>Series B Preferred Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>200</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Mission Trust</value></natureOfOwnership></ownershipNature>
                </derivativeHolding>
            </derivativeTable>
        </ownershipDocument>
        """

        // 1000 × 50 + 200 × 50 = 60_000 Class A-equivalent
        XCTAssertEqual(SPCXOwnershipCalculator.totalPublicShares(from: xml), 60_000)
    }
}

final class SECHoldingsSyncServiceFormTypeTests: XCTestCase {
    func testAcceptsForm4AndAmendment() {
        XCTAssertTrue(SECHoldingsSyncService.isForm4Filing("4"))
        XCTAssertTrue(SECHoldingsSyncService.isForm4Filing("4/A"))
    }

    func testRejectsOtherFormTypes() {
        XCTAssertFalse(SECHoldingsSyncService.isForm4Filing("3"))
        XCTAssertFalse(SECHoldingsSyncService.isForm4Filing("3/A"))
        XCTAssertFalse(SECHoldingsSyncService.isForm4Filing("5"))
        XCTAssertFalse(SECHoldingsSyncService.isForm4Filing("5/A"))
        XCTAssertFalse(SECHoldingsSyncService.isForm4Filing("8-K"))
        XCTAssertFalse(SECHoldingsSyncService.isForm4Filing("13F-HR"))
        XCTAssertFalse(SECHoldingsSyncService.isForm4Filing(""))
        XCTAssertFalse(SECHoldingsSyncService.isForm4Filing("4A"))
        XCTAssertFalse(SECHoldingsSyncService.isForm4Filing("4 /A"))
    }

    /// Guard against regressing to a short scan window that misses rarer issuers (e.g. SPCX under a TSLA-heavy stream).
    func testMaxForm4AccessionsToScanIsDeepEnoughForMultiIssuerProfiles() {
        XCTAssertGreaterThanOrEqual(SECHoldingsSyncService.maxForm4AccessionsToScan, 100)
    }
}

final class Form4OwnershipParserTests: XCTestCase {
    func testUsesLastDirectTransactionNotMaxAcrossRows() {
        let xml = """
        <ownershipDocument>
            <issuer>
                <issuerTradingSymbol>TSLA</issuerTradingSymbol>
            </issuer>
            <nonDerivativeTable>
                <nonDerivativeTransaction>
                    <postTransactionAmounts>
                        <sharesOwnedFollowingTransaction>
                            <value>800000000</value>
                        </sharesOwnedFollowingTransaction>
                    </postTransactionAmounts>
                    <ownershipNature>
                        <directOrIndirectOwnership>
                            <value>D</value>
                        </directOrIndirectOwnership>
                    </ownershipNature>
                </nonDerivativeTransaction>
                <nonDerivativeTransaction>
                    <postTransactionAmounts>
                        <sharesOwnedFollowingTransaction>
                            <value>699580882</value>
                        </sharesOwnedFollowingTransaction>
                    </postTransactionAmounts>
                    <ownershipNature>
                        <directOrIndirectOwnership>
                            <value>D</value>
                        </directOrIndirectOwnership>
                    </ownershipNature>
                </nonDerivativeTransaction>
            </nonDerivativeTable>
        </ownershipDocument>
        """

        let parser = Form4OwnershipParser(data: Data(xml.utf8))
        let result = parser.parse()

        XCTAssertEqual(result["TSLA"], 699_580_882)
        XCTAssertNil(result["SPCX"])
    }

    func testPrefersDirectOwnershipOverHigherIndirectRows() {
        let xml = """
        <ownershipDocument>
            <issuer>
                <issuerTradingSymbol>TSLA</issuerTradingSymbol>
            </issuer>
            <nonDerivativeTable>
                <nonDerivativeTransaction>
                    <postTransactionAmounts>
                        <sharesOwnedFollowingTransaction>
                            <value>1000000000</value>
                        </sharesOwnedFollowingTransaction>
                    </postTransactionAmounts>
                    <ownershipNature>
                        <directOrIndirectOwnership>
                            <value>I</value>
                        </directOrIndirectOwnership>
                    </ownershipNature>
                </nonDerivativeTransaction>
                <nonDerivativeHolding>
                    <postTransactionAmounts>
                        <sharesOwnedFollowingTransaction>
                            <value>699580882</value>
                        </sharesOwnedFollowingTransaction>
                    </postTransactionAmounts>
                    <ownershipNature>
                        <directOrIndirectOwnership>
                            <value>D</value>
                        </directOrIndirectOwnership>
                    </ownershipNature>
                </nonDerivativeHolding>
            </nonDerivativeTable>
        </ownershipDocument>
        """

        let parser = Form4OwnershipParser(data: Data(xml.utf8))
        let result = parser.parse()

        XCTAssertEqual(result["TSLA"], 699_580_882)
    }

    func testSPCXUsesOwnershipAggregatorNotSingleRow() {
        let xml = """
        <ownershipDocument>
            <issuer><issuerTradingSymbol>SPCX</issuerTradingSymbol></issuer>
            <nonDerivativeTable>
                <nonDerivativeHolding>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts>
                        <sharesOwnedFollowingTransaction><value>7402770</value></sharesOwnedFollowingTransaction>
                    </postTransactionAmounts>
                    <ownershipNature>
                        <directOrIndirectOwnership><value>I</value></directOrIndirectOwnership>
                        <natureOfOwnership><value>By EM 2024 GRAT-A</value></natureOfOwnership>
                    </ownershipNature>
                </nonDerivativeHolding>
            </nonDerivativeTable>
            <derivativeTable>
                <derivativeHolding>
                    <securityTitle><value>Class B Common Stock</value></securityTitle>
                    <underlyingSecurityShares><value>1000000000</value></underlyingSecurityShares>
                    <ownershipNature>
                        <directOrIndirectOwnership><value>I</value></directOrIndirectOwnership>
                        <natureOfOwnership><value>By Elon Musk Revocable Trust</value></natureOfOwnership>
                    </ownershipNature>
                </derivativeHolding>
            </derivativeTable>
            <remarks>
                does not include 500000000 shares of restricted Class B Common Stock
            </remarks>
        </ownershipDocument>
        """

        let parser = Form4OwnershipParser(data: Data(xml.utf8))
        let result = parser.parse()

        XCTAssertNil(result["TSLA"])
        XCTAssertEqual(result["SPCX"], 1_507_402_770)
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
            GainSummaryFormatter.format(snapshot)
        )
    }
}

@MainActor
private final class MockStockService: StockPriceServiceProtocol {
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

private struct FixedMarketHours: MarketHoursServiceProtocol {
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

private enum EasternTestDates {
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

@MainActor
final class DailyRecordTrackerTests: XCTestCase {
    private var easternCalendar: TradingDayCalendar!
    private var marketHours: MarketHoursService!

    override func setUp() {
        let eastern = EasternTestDates.eastern
        let calendar = EasternTestDates.calendar()
        easternCalendar = TradingDayCalendar(calendar: calendar, timeZone: eastern)
        marketHours = MarketHoursService(calendar: calendar, timeZone: eastern)
    }

    private func makeTracker(suiteName: String = "MuskometerTests-daily-records-\(UUID().uuidString)") -> DailyRecordTracker {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return DailyRecordTracker(
            defaults: defaults,
            calendar: easternCalendar,
            marketHours: marketHours
        )
    }

    func testNoRecordsUntilFirstTradingDayCompletes() throws {
        let tracker = makeTracker()
        let midday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)

        let snapshot = tracker.update(
            personID: "musk",
            paperGain: 12_000_000_000,
            at: midday,
            isQuotable: true
        )

        XCTAssertFalse(snapshot.hasCompletedFirstTradingDay)
        XCTAssertNil(snapshot.bestRecord)
        XCTAssertNil(snapshot.worstRecord)
    }

    func testTracksBestAndWorstAfterFirstDayCompletes() throws {
        let tracker = makeTracker()
        let midday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let afterPostMarketClose = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 20)

        _ = tracker.update(personID: "musk", paperGain: 12_000_000_000, at: midday, isQuotable: true)
        _ = tracker.update(personID: "musk", paperGain: -4_000_000_000, at: midday.addingTimeInterval(3_600), isQuotable: true)
        let snapshot = tracker.update(personID: "musk", paperGain: -4_000_000_000, at: afterPostMarketClose, isQuotable: false)

        XCTAssertTrue(snapshot.hasCompletedFirstTradingDay)
        XCTAssertEqual(snapshot.bestRecord?.amount, 12_000_000_000)
        XCTAssertEqual(snapshot.worstRecord?.amount, -4_000_000_000)
    }

    func testRecordsAreScopedPerPersonID() throws {
        let tracker = makeTracker()
        let midday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let afterPostMarketClose = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 20)

        _ = tracker.update(personID: "musk", paperGain: 20_000_000_000, at: midday, isQuotable: true)
        _ = tracker.update(personID: "musk", paperGain: 20_000_000_000, at: afterPostMarketClose, isQuotable: false)

        let other = tracker.update(personID: "other", paperGain: 1_000_000_000, at: afterPostMarketClose, isQuotable: false)

        XCTAssertEqual(tracker.snapshot(for: "musk").bestRecord?.amount, 20_000_000_000)
        XCTAssertFalse(other.hasCompletedFirstTradingDay)
        XCTAssertNil(other.bestRecord)
    }

    func testPersistsAcrossReload() throws {
        let suiteName = "MuskometerTests-daily-records-persist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let midday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let afterPostMarketClose = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 20)

        let tracker = DailyRecordTracker(defaults: defaults, calendar: easternCalendar, marketHours: marketHours)
        _ = tracker.update(personID: "musk", paperGain: 8_000_000_000, at: midday, isQuotable: true)
        _ = tracker.update(personID: "musk", paperGain: 8_000_000_000, at: afterPostMarketClose, isQuotable: false)

        let reloaded = DailyRecordTracker(defaults: defaults, calendar: easternCalendar, marketHours: marketHours)
        let snapshot = reloaded.snapshot(for: "musk")

        XCTAssertTrue(snapshot.hasCompletedFirstTradingDay)
        XCTAssertEqual(snapshot.bestRecord?.amount, 8_000_000_000)
    }

    func testNonQuotableSampleDoesNotSeedPeakOrTroughForNewDay() throws {
        let tracker = makeTracker()
        // Overnight / closed-session paper gain from the prior session magnitude.
        let overnight = try EasternTestDates.date(year: 2026, month: 7, day: 1, hour: 2)
        let midday = try EasternTestDates.date(year: 2026, month: 7, day: 1, hour: 11)
        let afterPostMarketClose = try EasternTestDates.date(year: 2026, month: 7, day: 1, hour: 20)

        _ = tracker.update(personID: "musk", paperGain: 50_000_000_000, at: overnight, isQuotable: false)
        _ = tracker.update(personID: "musk", paperGain: 3_000_000_000, at: midday, isQuotable: true)
        let snapshot = tracker.update(personID: "musk", paperGain: 50_000_000_000, at: afterPostMarketClose, isQuotable: false)

        XCTAssertTrue(snapshot.hasCompletedFirstTradingDay)
        XCTAssertEqual(snapshot.bestRecord?.amount, 3_000_000_000)
        XCTAssertEqual(snapshot.worstRecord?.amount, 3_000_000_000)
    }

    func testNonQuotableAfterCloseDoesNotUpdatePeakOrTrough() throws {
        let tracker = makeTracker()
        let midday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let afterPostMarketClose = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 20)

        _ = tracker.update(personID: "musk", paperGain: 5_000_000_000, at: midday, isQuotable: true)
        // Stale/closed-session magnitude must not inflate best after the quotable sample.
        let snapshot = tracker.update(personID: "musk", paperGain: 40_000_000_000, at: afterPostMarketClose, isQuotable: false)

        XCTAssertTrue(snapshot.hasCompletedFirstTradingDay)
        XCTAssertEqual(snapshot.bestRecord?.amount, 5_000_000_000)
        XCTAssertEqual(snapshot.worstRecord?.amount, 5_000_000_000)
    }

    func testQuotableSamplesStillUpdatePeakAndTrough() throws {
        let tracker = makeTracker()
        let morning = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 10)
        let midday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 12)
        let afternoon = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 14)
        let afterPostMarketClose = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 20)

        _ = tracker.update(personID: "musk", paperGain: 2_000_000_000, at: morning, isQuotable: true)
        _ = tracker.update(personID: "musk", paperGain: 15_000_000_000, at: midday, isQuotable: true)
        _ = tracker.update(personID: "musk", paperGain: -6_000_000_000, at: afternoon, isQuotable: true)
        let snapshot = tracker.update(personID: "musk", paperGain: -1_000_000_000, at: afterPostMarketClose, isQuotable: false)

        XCTAssertTrue(snapshot.hasCompletedFirstTradingDay)
        XCTAssertEqual(snapshot.bestRecord?.amount, 15_000_000_000)
        XCTAssertEqual(snapshot.worstRecord?.amount, -6_000_000_000)
    }

    func testPostMarketSamplesDoNotUpdateExtremesAfterRTHFinalize() throws {
        // RTH-only: day finalizes at regular close (16:00); post-market isQuotable:false samples are ignored.
        let tracker = makeTracker()
        let midday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let lateRTH = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 15, minute: 30)
        let afterRegularClose = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 16)
        let postMarket = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 17)

        _ = tracker.update(personID: "musk", paperGain: 5_000_000_000, at: midday, isQuotable: true)
        _ = tracker.update(personID: "musk", paperGain: 12_000_000_000, at: lateRTH, isQuotable: true)

        // Still during RTH — not finalized yet.
        let duringRTH = tracker.update(
            personID: "musk",
            paperGain: -3_000_000_000,
            at: lateRTH.addingTimeInterval(60),
            isQuotable: true
        )
        XCTAssertFalse(duringRTH.hasCompletedFirstTradingDay)
        XCTAssertNil(duringRTH.bestRecord)

        // After regular close, day finalizes with RTH extremes only.
        let finalized = tracker.update(
            personID: "musk",
            paperGain: 99_000_000_000,
            at: afterRegularClose,
            isQuotable: false
        )
        XCTAssertTrue(finalized.hasCompletedFirstTradingDay)
        XCTAssertEqual(finalized.bestRecord?.amount, 12_000_000_000)
        XCTAssertEqual(finalized.worstRecord?.amount, -3_000_000_000)

        // Post-market sample with isQuotable:false must not rewrite records.
        let afterPost = tracker.update(
            personID: "musk",
            paperGain: 99_000_000_000,
            at: postMarket,
            isQuotable: false
        )
        XCTAssertEqual(afterPost.bestRecord?.amount, 12_000_000_000)
        XCTAssertEqual(afterPost.worstRecord?.amount, -3_000_000_000)
    }

    func testNonQuotableOvernightDoesNotPolluteNextDayAfterRollover() throws {
        let tracker = makeTracker()
        let day1Midday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let day1AfterPostMarketClose = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 20)
        let day2Overnight = try EasternTestDates.date(year: 2026, month: 7, day: 1, hour: 1)
        let day2Midday = try EasternTestDates.date(year: 2026, month: 7, day: 1, hour: 11)
        let day2AfterPostMarketClose = try EasternTestDates.date(year: 2026, month: 7, day: 1, hour: 20)

        _ = tracker.update(personID: "musk", paperGain: 10_000_000_000, at: day1Midday, isQuotable: true)
        _ = tracker.update(personID: "musk", paperGain: 10_000_000_000, at: day1AfterPostMarketClose, isQuotable: false)

        // Prior-session magnitude on a new ET day must not seed that day's extremes.
        _ = tracker.update(personID: "musk", paperGain: 10_000_000_000, at: day2Overnight, isQuotable: false)
        _ = tracker.update(personID: "musk", paperGain: 1_000_000_000, at: day2Midday, isQuotable: true)
        let snapshot = tracker.update(personID: "musk", paperGain: 1_000_000_000, at: day2AfterPostMarketClose, isQuotable: false)

        XCTAssertTrue(snapshot.hasCompletedFirstTradingDay)
        // Day 1 peak remains the all-time best; day 2 trough is the milder +1B, not overnight seed.
        XCTAssertEqual(snapshot.bestRecord?.amount, 10_000_000_000)
        XCTAssertEqual(snapshot.worstRecord?.amount, 1_000_000_000)
    }

    func testUnfinishedDayExtremesPersistAcrossRestartAndFinalizeOnNextDay() throws {
        let suiteName = "MuskometerTests-daily-records-unfinished-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let day1Morning = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 10)
        let day1Midday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 13)
        let day2Midday = try EasternTestDates.date(year: 2026, month: 7, day: 1, hour: 11)

        // Day 1: sample mid-session then "quit" before post-market close (no finalize).
        let tracker1 = DailyRecordTracker(defaults: defaults, calendar: easternCalendar, marketHours: marketHours)
        _ = tracker1.update(personID: "musk", paperGain: 12_000_000_000, at: day1Morning, isQuotable: true)
        _ = tracker1.update(personID: "musk", paperGain: -4_000_000_000, at: day1Midday, isQuotable: true)

        let midDaySnapshot = tracker1.snapshot(for: "musk")
        XCTAssertFalse(midDaySnapshot.hasCompletedFirstTradingDay)
        XCTAssertNil(midDaySnapshot.bestRecord)

        // New process: same UserDefaults, no in-memory extremes.
        let tracker2 = DailyRecordTracker(defaults: defaults, calendar: easternCalendar, marketHours: marketHours)
        let nextDaySnapshot = tracker2.update(
            personID: "musk",
            paperGain: 1_000_000_000,
            at: day2Midday,
            isQuotable: true
        )

        // Prior unfinished day should finalize into best/worst from persisted peak/trough.
        XCTAssertTrue(nextDaySnapshot.hasCompletedFirstTradingDay)
        XCTAssertEqual(nextDaySnapshot.bestRecord?.amount, 12_000_000_000)
        XCTAssertEqual(nextDaySnapshot.worstRecord?.amount, -4_000_000_000)
    }

    func testMidDayRestartContinuesPeakAndTroughFromPersistedExtremes() throws {
        let suiteName = "MuskometerTests-daily-records-midday-restart-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let morning = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 10)
        let midday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 12)
        let afternoon = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 14)
        let afterPostMarketClose = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 20)

        let tracker1 = DailyRecordTracker(defaults: defaults, calendar: easternCalendar, marketHours: marketHours)
        _ = tracker1.update(personID: "musk", paperGain: 5_000_000_000, at: morning, isQuotable: true)
        _ = tracker1.update(personID: "musk", paperGain: 18_000_000_000, at: midday, isQuotable: true)

        // Restart same ET day before post-market close — must continue prior peak/trough.
        let tracker2 = DailyRecordTracker(defaults: defaults, calendar: easternCalendar, marketHours: marketHours)
        _ = tracker2.update(personID: "musk", paperGain: -7_000_000_000, at: afternoon, isQuotable: true)
        let snapshot = tracker2.update(
            personID: "musk",
            paperGain: -1_000_000_000,
            at: afterPostMarketClose,
            isQuotable: false
        )

        XCTAssertTrue(snapshot.hasCompletedFirstTradingDay)
        // Peak from pre-restart midday (+18B) and trough from post-restart afternoon (-7B).
        XCTAssertEqual(snapshot.bestRecord?.amount, 18_000_000_000)
        XCTAssertEqual(snapshot.worstRecord?.amount, -7_000_000_000)
    }

    func testUnfinishedDayExtremesFinalizeAfterRestartPastPostMarketClose() throws {
        let suiteName = "MuskometerTests-daily-records-unfinished-close-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let midday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let afterPostMarketClose = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 20)

        let tracker1 = DailyRecordTracker(defaults: defaults, calendar: easternCalendar, marketHours: marketHours)
        _ = tracker1.update(personID: "musk", paperGain: 9_000_000_000, at: midday, isQuotable: true)

        let tracker2 = DailyRecordTracker(defaults: defaults, calendar: easternCalendar, marketHours: marketHours)
        let snapshot = tracker2.update(
            personID: "musk",
            paperGain: 9_000_000_000,
            at: afterPostMarketClose,
            isQuotable: false
        )

        XCTAssertTrue(snapshot.hasCompletedFirstTradingDay)
        XCTAssertEqual(snapshot.bestRecord?.amount, 9_000_000_000)
        XCTAssertEqual(snapshot.worstRecord?.amount, 9_000_000_000)
    }

    func testResetPersistedStateClearsUnfinishedDayExtremes() throws {
        let suiteName = "MuskometerTests-daily-records-reset-unfinished-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let midday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let day2 = try EasternTestDates.date(year: 2026, month: 7, day: 1, hour: 11)

        let tracker1 = DailyRecordTracker(defaults: defaults, calendar: easternCalendar, marketHours: marketHours)
        _ = tracker1.update(personID: "musk", paperGain: 15_000_000_000, at: midday, isQuotable: true)

        DailyRecordTracker.resetPersistedState(for: "musk", defaults: defaults)

        let tracker2 = DailyRecordTracker(defaults: defaults, calendar: easternCalendar, marketHours: marketHours)
        let snapshot = tracker2.update(personID: "musk", paperGain: 1_000_000_000, at: day2, isQuotable: true)

        // Cleared unfinished state must not resurrect day-1 peak as best/worst.
        XCTAssertFalse(snapshot.hasCompletedFirstTradingDay)
        XCTAssertNil(snapshot.bestRecord)
        XCTAssertNil(snapshot.worstRecord)
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

private final class MockGainThresholdNotificationDeliverer: GainThresholdNotificationDelivering, @unchecked Sendable {
    private(set) var requests: [UNNotificationRequest] = []

    func add(_ request: UNNotificationRequest) async throws {
        requests.append(request)
    }
}

@MainActor
final class GainThresholdNotificationServiceTests: XCTestCase {
    private var easternCalendar: TradingDayCalendar!

    override func setUp() {
        let eastern = EasternTestDates.eastern
        easternCalendar = TradingDayCalendar(calendar: EasternTestDates.calendar(), timeZone: eastern)
    }

    private func makeService(
        deliverer: MockGainThresholdNotificationDeliverer = MockGainThresholdNotificationDeliverer(),
        suiteName: String = "MuskometerTests-gain-notify-\(UUID().uuidString)"
    ) -> (GainThresholdNotificationService, MockGainThresholdNotificationDeliverer) {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let service = GainThresholdNotificationService(
            defaults: defaults,
            calendar: easternCalendar,
            deliverer: deliverer
        )
        return (service, deliverer)
    }

    func testFiresWhenCrossingEnabledGainThreshold() async throws {
        let (service, deliverer) = makeService()
        service.setEnabledThresholdIDs(["gain-10b"], for: "musk")
        let date = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)

        _ = await service.processUpdate(
            paperGain: 9_000_000_000,
            personID: "musk",
            possessiveName: "Elon's",
            at: date,
            isQuotable: true
        )
        let events = await service.processUpdate(
            paperGain: 11_000_000_000,
            personID: "musk",
            possessiveName: "Elon's",
            at: date.addingTimeInterval(60),
            isQuotable: true
        )

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.threshold.id, "gain-10b")
        XCTAssertEqual(deliverer.requests.count, 1)
        XCTAssertTrue(deliverer.requests.first?.content.title.contains("+$10B") ?? false)
    }

    func testDoesNotFireWhenMarketClosed() async throws {
        let (service, deliverer) = makeService()
        service.setEnabledThresholdIDs(["gain-10b"], for: "musk")
        let date = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 17)

        _ = await service.processUpdate(
            paperGain: 9_000_000_000,
            personID: "musk",
            possessiveName: "Elon's",
            at: date,
            isQuotable: false
        )
        let events = await service.processUpdate(
            paperGain: 11_000_000_000,
            personID: "musk",
            possessiveName: "Elon's",
            at: date.addingTimeInterval(60),
            isQuotable: false
        )

        XCTAssertTrue(events.isEmpty)
        XCTAssertTrue(deliverer.requests.isEmpty)
    }

    func testRearmsAfterDroppingBelowThreshold() async throws {
        let (service, deliverer) = makeService()
        service.setEnabledThresholdIDs(["gain-10b"], for: "musk")
        let date = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)

        _ = await service.processUpdate(paperGain: 9_000_000_000, personID: "musk", possessiveName: "Elon's", at: date, isQuotable: true)
        _ = await service.processUpdate(paperGain: 11_000_000_000, personID: "musk", possessiveName: "Elon's", at: date.addingTimeInterval(60), isQuotable: true)
        _ = await service.processUpdate(paperGain: 8_000_000_000, personID: "musk", possessiveName: "Elon's", at: date.addingTimeInterval(120), isQuotable: true)
        let secondCross = await service.processUpdate(
            paperGain: 12_000_000_000,
            personID: "musk",
            possessiveName: "Elon's",
            at: date.addingTimeInterval(180),
            isQuotable: true
        )

        XCTAssertEqual(secondCross.count, 1)
        XCTAssertEqual(deliverer.requests.count, 2)
    }

    func testFiresLossThresholdOnDownwardCross() async throws {
        let (service, deliverer) = makeService()
        service.setEnabledThresholdIDs(["loss-10b"], for: "musk")
        let date = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)

        _ = await service.processUpdate(paperGain: -8_000_000_000, personID: "musk", possessiveName: "Elon's", at: date, isQuotable: true)
        let events = await service.processUpdate(
            paperGain: -12_000_000_000,
            personID: "musk",
            possessiveName: "Elon's",
            at: date.addingTimeInterval(60),
            isQuotable: true
        )

        XCTAssertEqual(events.first?.threshold.id, "loss-10b")
        XCTAssertEqual(deliverer.requests.count, 1)
    }

    func testPersistsStateAcrossServiceReload() async throws {
        let deliverer = MockGainThresholdNotificationDeliverer()
        let suiteName = "MuskometerTests-gain-notify-persist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let date = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)

        let service1 = GainThresholdNotificationService(
            defaults: defaults,
            calendar: easternCalendar,
            deliverer: deliverer
        )
        service1.setEnabledThresholdIDs(["gain-10b"], for: "musk")
        _ = await service1.processUpdate(
            paperGain: 9_000_000_000,
            personID: "musk",
            possessiveName: "Elon's",
            at: date,
            isQuotable: true
        )

        let service2 = GainThresholdNotificationService(
            defaults: defaults,
            calendar: easternCalendar,
            deliverer: deliverer
        )
        let events = await service2.processUpdate(
            paperGain: 11_000_000_000,
            personID: "musk",
            possessiveName: "Elon's",
            at: date.addingTimeInterval(60),
            isQuotable: true
        )

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.threshold.id, "gain-10b")
        XCTAssertEqual(deliverer.requests.count, 1)
        XCTAssertTrue(deliverer.requests.first?.content.title.contains("+$10B") ?? false)
    }
}

final class ComparisonLibraryTests: XCTestCase {
    func testLibraryHasAtLeastFiveHundredEntries() {
        XCTAssertGreaterThanOrEqual(ComparisonLibrary.entries.count, 500)
    }

    func testEntriesUseTenBillionBuckets() {
        let bucketStarts = Set(ComparisonLibrary.entries.map { Int($0.minMagnitude / 1_000_000_000) })
        XCTAssertTrue(bucketStarts.contains(0))
        XCTAssertTrue(bucketStarts.contains(10))
        XCTAssertTrue(bucketStarts.contains(20))
        XCTAssertTrue(bucketStarts.contains(30))
        XCTAssertTrue(bucketStarts.contains(40))
        XCTAssertTrue(bucketStarts.contains(50))
        XCTAssertTrue(bucketStarts.contains(60))
        XCTAssertTrue(bucketStarts.contains(70))
    }

    func testEachBucketHasAtLeastFiftyEntries() {
        let buckets: [(min: Double, max: Double)] = [
            (0, 10), (10, 20), (20, 30), (30, 40),
            (40, 50), (50, 60), (60, 70), (70, 1_000),
        ]
        for bucket in buckets {
            let minMag = bucket.min * 1_000_000_000
            let maxMag = bucket.max * 1_000_000_000
            let count = ComparisonLibrary.entries.filter {
                $0.minMagnitude == minMag && $0.maxMagnitude == maxMag
            }.count
            XCTAssertGreaterThanOrEqual(
                count,
                50,
                "Bucket \(Int(bucket.min))–\(Int(bucket.max))B too thin (\(count))"
            )
        }
    }

    func testCandidatesMatchMagnitudeBucket() {
        let candidates = ComparisonLibrary.candidates(forMagnitude: 15_000_000_000)
        XCTAssertFalse(candidates.isEmpty)
        XCTAssertTrue(candidates.allSatisfy { $0.minMagnitude == 10_000_000_000 && $0.maxMagnitude == 20_000_000_000 })
    }

    func testLinePrefixesGainAndLoss() {
        let entry = ComparisonLibrary.entries.first!
        XCTAssertTrue(entry.line(forGain: 5_000_000_000).text.hasPrefix("Today's gain "))
        XCTAssertTrue(entry.line(forGain: -5_000_000_000).text.hasPrefix("Today's loss "))
        XCTAssertTrue(entry.line(forGain: 0).text.hasPrefix("Today's move "))
    }

    func testPolarityAwareBodiesForSpendMetaphors() throws {
        let debt = try XCTUnwrap(ComparisonLibrary.entries.first { $0.id == "econ-11" })
        let gainLine = debt.line(forGain: 15_000_000_000)
        let lossLine = debt.line(forGain: -15_000_000_000)

        XCTAssertTrue(gainLine.text.contains("could wipe out the student debt"))
        XCTAssertTrue(lossLine.text.contains("equals the student debt"))
        XCTAssertFalse(lossLine.text.contains("could wipe out"))
        XCTAssertEqual(gainLine.highlight, "400,000")
        XCTAssertEqual(lossLine.highlight, "400,000")
    }

    func testStreamingEntryHasLossSafeCopy() throws {
        let entry = try XCTUnwrap(ComparisonLibrary.entries.first { $0.id == "ent-60" })
        let gainLine = entry.line(forGain: 65_000_000_000)
        let lossLine = entry.line(forGain: -65_000_000_000)

        XCTAssertTrue(gainLine.text.contains("could run every major streaming service at a loss"))
        XCTAssertTrue(lossLine.text.contains("matches a quarter of operating losses"))
        XCTAssertFalse(lossLine.text.contains("could run every major streaming service at a loss"))
    }

    func testPolaritySafeEntriesShareBody() throws {
        let entry = try XCTUnwrap(ComparisonLibrary.entries.first { $0.id == "econ-01" })
        XCTAssertEqual(entry.gainText, entry.lossText)
        let gainBody = entry.line(forGain: 5_000_000_000).text
        let lossBody = entry.line(forGain: -5_000_000_000).text
        XCTAssertTrue(gainBody.hasSuffix(entry.gainText))
        XCTAssertTrue(lossBody.hasSuffix(entry.lossText))
    }

    func testLossBodiesAvoidSpendVerbsWhenGainUsesThem() {
        let spendPatterns = [
            "could wipe out", "could fund", "could pay", "could buy", "could bankroll",
            "would buy", "would pay for", "would fund", "would cover", "could acquire",
            "could produce", "could launch", "could build", "could modernize", "could rebuild",
            "could vaccinate", "could reforest", "could rewild", "could restore", "could tunnel",
            "could bury", "could lay", "could repave", "could fuel", "could seed",
            "could underwrite", "could zero out", "could erase", "could end", "could run every",
        ]
        for entry in ComparisonLibrary.entries where entry.gainText != entry.lossText {
            for pattern in spendPatterns {
                XCTAssertFalse(
                    entry.lossText.contains(pattern),
                    "\(entry.id) lossText still spends: \(entry.lossText)"
                )
            }
        }
    }

    func testHighlightsAppearInCorrespondingBodies() {
        for entry in ComparisonLibrary.entries {
            if let h = entry.gainHighlight {
                XCTAssertTrue(entry.gainText.contains(h), "\(entry.id) gainHighlight missing from gainText")
            }
            if let h = entry.lossHighlight {
                XCTAssertTrue(entry.lossText.contains(h), "\(entry.id) lossHighlight missing from lossText")
            }
        }
    }

    func testEntryIDsAreUnique() {
        let ids = ComparisonLibrary.entries.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testSports01UsesSportsCategory() {
        let entry = ComparisonLibrary.entries.first { $0.id == "sports-01" }
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.category, .sports)
    }
}

final class ComparisonHistoryStoreTests: XCTestCase {
    private var easternCalendar: TradingDayCalendar!

    override func setUp() {
        let eastern = EasternTestDates.eastern
        easternCalendar = TradingDayCalendar(calendar: EasternTestDates.calendar(), timeZone: eastern)
    }

    func testExcludesEntriesUsedWithinSevenDays() throws {
        let suiteName = "MuskometerTests-comparison-history-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        var store = ComparisonHistoryStore(defaults: defaults, calendar: easternCalendar)
        let dayOne = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let dayThree = try EasternTestDates.date(year: 2026, month: 7, day: 2, hour: 11)

        store.recordUse(entryID: "econ-10", personID: "musk", on: dayOne)

        XCTAssertTrue(store.recentlyUsedEntryIDs(personID: "musk", on: dayThree).contains("econ-10"))
    }

    func testDropsEntriesOlderThanSevenDays() throws {
        let suiteName = "MuskometerTests-comparison-history-old-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        var store = ComparisonHistoryStore(defaults: defaults, calendar: easternCalendar)
        let oldDay = try EasternTestDates.date(year: 2026, month: 6, day: 20, hour: 11)
        let currentDay = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)

        store.recordUse(entryID: "econ-10", personID: "musk", on: oldDay)

        XCTAssertFalse(store.recentlyUsedEntryIDs(personID: "musk", on: currentDay).contains("econ-10"))
    }
}

@MainActor
final class ComparisonLineSelectorTests: XCTestCase {
    func testReturnsNilForZeroGain() {
        let selector = ComparisonLineSelector(randomizer: SeededComparisonRandomizer(seed: 1))
        XCTAssertNil(selector.selectLine(for: 0, personID: "musk"))
    }

    func testSelectsLineFromMatchingBucket() {
        let suiteName = "MuskometerTests-comparison-select-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let eastern = EasternTestDates.eastern
        let calendar = TradingDayCalendar(calendar: EasternTestDates.calendar(), timeZone: eastern)
        let store = ComparisonHistoryStore(defaults: defaults, calendar: calendar)
        let selector = ComparisonLineSelector(
            historyStore: store,
            randomizer: SeededComparisonRandomizer(seed: 42)
        )

        let line = selector.selectLine(for: 15_000_000_000, personID: "musk")

        XCTAssertNotNil(line)
        XCTAssertTrue(line?.text.hasPrefix("Today's gain ") ?? false)
    }

    func testAvoidsRecentlyUsedEntries() throws {
        let suiteName = "MuskometerTests-comparison-avoid-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let eastern = EasternTestDates.eastern
        let calendar = TradingDayCalendar(calendar: EasternTestDates.calendar(), timeZone: eastern)
        var store = ComparisonHistoryStore(defaults: defaults, calendar: calendar)
        let date = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)

        let bucketEntries = ComparisonLibrary.candidates(forMagnitude: 15_000_000_000)
        for entry in bucketEntries {
            store.recordUse(entryID: entry.id, personID: "musk", on: date)
        }

        let selector = ComparisonLineSelector(
            historyStore: store,
            randomizer: SeededComparisonRandomizer(seed: 7)
        )

        let line = selector.selectLine(for: 15_000_000_000, personID: "musk", on: date)
        XCTAssertNotNil(line)
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

    func testSadMessageUsesLonliestNumberCopy() {
        let tracker = makeTracker()
        _ = tracker.update(netWorth: 1_100_000_000_000, personID: personID)
        let event = tracker.update(netWorth: 900_000_000_000, personID: personID)

        guard case .fellBelowTrillion(let message) = event else {
            return XCTFail("Expected fellBelowTrillion")
        }
        XCTAssertEqual(message, "One Trillion Is the Lonliest Number")
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
final class GainsViewModelComparisonDebounceTests: XCTestCase {
    private let personID = TrackedPersonProfile.musk.id

    private func makeSettings() -> AppSettings {
        let suiteName = "MuskometerTests-comparison-debounce-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppSettings(defaults: defaults)
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

    func testComparisonLineOnlyUpdatesOnDayOrBucketChange() async {
        let settings = makeSettings()
        settings.setShareCount(100, for: "TSLA")
        settings.setShareCount(100, for: "SPCX")

        let stockService = MutableMockStockService(quotes: quotes(producingCombinedGain: 15_000_000_000))
        let comparisonSelector = ComparisonLineSelector(randomizer: SeededComparisonRandomizer(seed: 99))
        let viewModel = GainsViewModel(
            settings: settings,
            stockService: stockService,
            comparisonLineSelector: comparisonSelector
        )

        await viewModel.refresh(force: true)
        let firstLine = viewModel.comparisonLine
        XCTAssertNotNil(firstLine)

        stockService.quotes = quotes(producingCombinedGain: 16_000_000_000)
        await viewModel.refresh(force: true)
        XCTAssertEqual(viewModel.comparisonLine?.text, firstLine?.text)

        stockService.quotes = quotes(producingCombinedGain: 25_000_000_000)
        await viewModel.refresh(force: true)
        XCTAssertNotEqual(viewModel.comparisonLine?.text, firstLine?.text)
    }

    func testComparisonLineUpdatesOnSignChange() async throws {
        let settings = makeSettings()
        settings.setShareCount(100, for: "TSLA")
        settings.setShareCount(100, for: "SPCX")

        let stockService = MutableMockStockService(quotes: quotes(producingCombinedGain: -15_000_000_000))
        let comparisonSelector = ComparisonLineSelector(randomizer: SeededComparisonRandomizer(seed: 99))
        let viewModel = GainsViewModel(
            settings: settings,
            stockService: stockService,
            comparisonLineSelector: comparisonSelector
        )

        await viewModel.refresh(force: true)
        let lossLine = try XCTUnwrap(viewModel.comparisonLine)
        XCTAssertTrue(lossLine.text.hasPrefix("Today's loss "))

        stockService.quotes = quotes(producingCombinedGain: 15_000_000_000)
        await viewModel.refresh(force: true)
        let gainLine = try XCTUnwrap(viewModel.comparisonLine)
        XCTAssertTrue(gainLine.text.hasPrefix("Today's gain "))
        XCTAssertNotEqual(gainLine.text, lossLine.text)
    }

    func testComparisonLineUpdatesOnDayChange() async throws {
        let settings = makeSettings()
        settings.setShareCount(100, for: "TSLA")
        settings.setShareCount(100, for: "SPCX")

        let dayOne = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let dayTwo = try EasternTestDates.date(year: 2026, month: 7, day: 1, hour: 11)
        var currentDate = dayOne

        let stockService = MutableMockStockService(quotes: quotes(producingCombinedGain: 15_000_000_000))
        let comparisonSelector = ComparisonLineSelector(randomizer: SeededComparisonRandomizer(seed: 99))
        let viewModel = GainsViewModel(
            settings: settings,
            stockService: stockService,
            comparisonLineSelector: comparisonSelector,
            dateProvider: { currentDate }
        )

        await viewModel.refresh(force: true)
        let firstLine = try XCTUnwrap(viewModel.comparisonLine)

        currentDate = dayTwo
        await viewModel.refresh(force: true)
        XCTAssertNotEqual(viewModel.comparisonLine?.text, firstLine.text)
    }

    func testComparisonDebounceIsPerPerson() async throws {
        let settings = makeSettings()
        settings.setShareCount(100, for: "TSLA")
        settings.setShareCount(100, for: "SPCX")

        let date = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        var currentDate = date

        let stockService = MutableMockStockService(quotes: quotes(producingCombinedGain: 15_000_000_000))
        let comparisonSelector = ComparisonLineSelector(randomizer: SeededComparisonRandomizer(seed: 99))
        let viewModel = GainsViewModel(
            settings: settings,
            stockService: stockService,
            comparisonLineSelector: comparisonSelector,
            dateProvider: { currentDate }
        )

        await viewModel.refresh(force: true)
        let muskLine = try XCTUnwrap(viewModel.comparisonLine)

        stockService.quotes = quotes(producingCombinedGain: 16_000_000_000)
        await viewModel.refresh(force: true)
        XCTAssertEqual(viewModel.comparisonLine?.text, muskLine.text)

        settings.selectedPersonID = "other"
        stockService.quotes = quotes(producingCombinedGain: 15_000_000_000)
        await viewModel.refresh(force: true)
        let otherLine = try XCTUnwrap(viewModel.comparisonLine)

        stockService.quotes = quotes(producingCombinedGain: 16_000_000_000)
        await viewModel.refresh(force: true)
        XCTAssertEqual(viewModel.comparisonLine?.text, otherLine.text)
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

@MainActor
private final class MutableMockStockService: StockPriceServiceProtocol {
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
        settings.updateDeliveryMode = .notifyOnly

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

    /// Automatic delivery must not use the Sparkle no-op stub (always nil),
    /// which would falsely report "you're on the latest."
    func testAutomaticModeFallsBackToGitHubChecker() async {
        let suiteName = "MuskometerTests-update-automatic-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let settings = AppSettings(defaults: defaults)
        settings.notifyOfAvailableUpdates = true
        settings.updateDeliveryMode = .automatic

        let deliverer = MockUpdateNotificationDeliverer()
        let releaseURL = URL(string: "https://github.com/jlgolson/muskometer/releases/tag/v0.2.0")!
        let githubChecker = MockUpdateChecker(result: UpdateCheckResult(
            availableVersion: "0.2.0",
            releasePageURL: releaseURL,
            publishedAt: nil
        ))
        // Sparkle stub / empty checker would return nil and lie about "latest".
        let sparkleDriver = MockUpdateChecker(result: nil)

        let coordinator = UpdateCoordinator(
            settings: settings,
            defaults: defaults,
            notificationDeliverer: deliverer,
            githubChecker: githubChecker,
            sparkleDriver: sparkleDriver
        )

        coordinator.checkNow()
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(coordinator.availableUpdate?.availableVersion, "0.2.0")
        XCTAssertEqual(coordinator.manualCheckSummary, "Version 0.2.0 is available.")
        XCTAssertFalse(
            coordinator.manualCheckSummary?.contains("latest version") ?? true,
            "Automatic mode must not report up-to-date when GitHub has a newer release"
        )
        XCTAssertEqual(deliverer.addedRequests.count, 1)
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