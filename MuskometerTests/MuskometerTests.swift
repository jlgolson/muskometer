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
        var components = DateComponents()
        components.year = 2027
        components.month = 4
        components.day = 2
        components.hour = 11
        components.minute = 0
        components.timeZone = eastern

        let holiday = try XCTUnwrap(calendar.date(from: components))
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)

        XCTAssertFalse(service.isMarketOpen(at: holiday))
    }

    func testNextOpenAfterHoursIs930Not945() throws {
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

    func testNextOpenBeforeMarketOpenSameDayIs930() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 1
        components.hour = 7
        components.minute = 0
        components.timeZone = eastern

        let wednesdayMorning = try XCTUnwrap(calendar.date(from: components))
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)

        let nextOpen = try XCTUnwrap(service.nextOpenDate(from: wednesdayMorning))

        XCTAssertEqual(calendar.component(.hour, from: nextOpen), 9)
        XCTAssertEqual(calendar.component(.minute, from: nextOpen), 30)
        XCTAssertEqual(calendar.component(.day, from: nextOpen), 1)
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
                tslaShares: nil,
                spcxShares: nil,
                syncedAt: syncedAt,
                sourceDescription: "SEC EDGAR Form 4"
            )
        )

        XCTAssertFalse(complete)
        XCTAssertNil(settings.lastHoldingsSyncDate)
        XCTAssertNil(settings.holdingsSyncSource)
    }

    func testPartialResultDoesNotSetLastHoldingsSyncDate() {
        let settings = makeSettings()
        let syncedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let complete = settings.applyHoldingsSync(
            HoldingsSyncResult(
                tslaShares: 123,
                spcxShares: nil,
                syncedAt: syncedAt,
                sourceDescription: "SEC EDGAR Form 4"
            )
        )

        XCTAssertFalse(complete)
        XCTAssertEqual(settings.tslaShareCount, 123)
        XCTAssertNil(settings.lastHoldingsSyncDate)
        XCTAssertNil(settings.holdingsSyncSource)
    }

    func testFullResultSetsLastHoldingsSyncDate() {
        let settings = makeSettings()
        let syncedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let complete = settings.applyHoldingsSync(
            HoldingsSyncResult(
                tslaShares: 123,
                spcxShares: 456,
                syncedAt: syncedAt,
                sourceDescription: "SEC EDGAR Form 4"
            )
        )

        XCTAssertTrue(complete)
        XCTAssertEqual(settings.tslaShareCount, 123)
        XCTAssertEqual(settings.spcxShareCount, 456)
        XCTAssertEqual(settings.lastHoldingsSyncDate, syncedAt)
        XCTAssertEqual(settings.holdingsSyncSource, "SEC EDGAR Form 4")
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

        XCTAssertEqual(settings.tslaShareCount, 699_580_882)
        XCTAssertEqual(settings.spcxShareCount, 6_068_734_060)
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

        XCTAssertEqual(result.tslaShares, 699_580_882)
        XCTAssertNil(result.spcxShares)
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

        XCTAssertEqual(result.tslaShares, 699_580_882)
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

        XCTAssertNil(result.tslaShares)
        XCTAssertEqual(result.spcxShares, 1_507_402_770)
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

@MainActor
final class GainsViewModelMenuBarTitleTests: XCTestCase {
    func testSplitMenuBarTitleTruncatesLongValues() {
        let title = GainsViewModel.formatSplitMenuBarTitle(["+$46.605B", "+$12.345B"], maxLength: 16)

        XCTAssertEqual(title.count, 16)
        XCTAssertTrue(title.contains("…"))
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

        let snapshot = GainsSnapshot(holdings: [tsla, spcx], lastUpdated: .now, marketIsOpen: true)

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
        let snapshot = GainsSnapshot(holdings: [tsla], lastUpdated: .now, marketIsOpen: true)

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

        let snapshot = GainsSnapshot(holdings: [tsla, spcx], lastUpdated: .now, marketIsOpen: true)

        XCTAssertEqual(snapshot.combinedPaperGain, 2_000)
    }
}

final class GainSummaryFormatterTests: XCTestCase {
    func testTodaysGainLossLabel() {
        XCTAssertEqual(GainSummaryFormatter.todaysGainLossLabel(for: 1), "Today's Gain")
        XCTAssertEqual(GainSummaryFormatter.todaysGainLossLabel(for: -1), "Today's Loss")
        XCTAssertEqual(GainSummaryFormatter.todaysGainLossLabel(for: 0), "Today's Gain/Loss")
    }

    func testFormatAppendsClipboardDisclaimer() {
        let tsla = HoldingGain(
            id: "tsla",
            symbol: "TSLA",
            displayName: "Tesla",
            shareCount: 100,
            quote: StockQuote(symbol: "TSLA", displayName: "Tesla", currentPrice: 110, previousClose: 100, currency: "USD")
        )
        let snapshot = GainsSnapshot(holdings: [tsla], lastUpdated: .now, marketIsOpen: true)

        let formatted = GainSummaryFormatter.format(snapshot)

        XCTAssertTrue(formatted.contains("Illustrative."))
        XCTAssertTrue(formatted.contains("Not financial advice."))
        XCTAssertTrue(formatted.contains("Holdings from SEC"))
        XCTAssertTrue(formatted.contains("Muskometer —"))
    }
}