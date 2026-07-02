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
                sharesBySymbol: [:],
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
                sharesBySymbol: ["TSLA": 123],
                syncedAt: syncedAt,
                sourceDescription: "SEC EDGAR Form 4"
            )
        )

        XCTAssertFalse(complete)
        XCTAssertEqual(settings.shareCount(for: "TSLA"), 123)
        XCTAssertNil(settings.lastHoldingsSyncDate)
        XCTAssertNil(settings.holdingsSyncSource)
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
        XCTAssertEqual(settings.holdingsSyncSource, "SEC EDGAR Form 4")
    }

    func testUnknownPersonIDFallsBackToMusk() {
        let settings = makeSettings()
        settings.selectedPersonID = "zuckerberg"

        XCTAssertEqual(settings.selectedPersonID, "zuckerberg")
        XCTAssertEqual(settings.selectedProfile.id, TrackedPersonProfile.musk.id)
        XCTAssertEqual(settings.selectedProfile.expectedSymbols, Set(["TSLA", "SPCX"]))
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
        return GainsSnapshot(holdings: [tsla, spcx], lastUpdated: .now, marketIsOpen: true)
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
        let snapshot = GainsSnapshot(holdings: [tsla], lastUpdated: .now, marketIsOpen: true)

        let formatted = GainSummaryFormatter.format(snapshot)

        XCTAssertFalse(formatted.contains("financial advice"))
        XCTAssertFalse(formatted.contains("Illustrative"))
        XCTAssertTrue(formatted.contains("Muskometer —"))
    }
}

private struct FixedMarketHours: MarketHoursServiceProtocol {
    let isOpen: Bool

    func isMarketOpen(at date: Date) -> Bool {
        isOpen
    }

    func nextOpenDate(from date: Date) -> Date? {
        nil
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
        suiteName: String = "MuskometerTests-intraday-\(UUID().uuidString)"
    ) -> (IntradayGainSampleStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: FixedMarketHours(isOpen: isMarketOpen)
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

        let store = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: marketHours
        )
        store.append(personID: "musk", combinedPaperGain: 42_000_000_000, at: date)

        let reloaded = IntradayGainSampleStore(
            defaults: defaults,
            calendar: calendar,
            marketHours: marketHours
        )
        let samples = reloaded.loadSamples(for: "musk")

        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples.first?.combinedPaperGain, 42_000_000_000)
        XCTAssertEqual(samples.first?.timestamp, date)
    }
}

final class XShareIntentTests: XCTestCase {
    private func sampleSnapshot(paperGain: Double = 1_000_000_000) -> GainsSnapshot {
        let tsla = HoldingGain(
            id: "tsla",
            symbol: "TSLA",
            displayName: "Tesla",
            shareCount: 100,
            quote: StockQuote(
                symbol: "TSLA",
                displayName: "Tesla",
                currentPrice: 110,
                previousClose: 100,
                currency: "USD"
            )
        )
        return GainsSnapshot(holdings: [tsla], lastUpdated: .now, marketIsOpen: true)
    }

    func testTweetURLUsesXIntentEndpoint() throws {
        let url = try XCTUnwrap(XShareIntent.tweetURL(for: sampleSnapshot()))

        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "x.com")
        XCTAssertEqual(url.path, "/intent/tweet")
    }

    func testTweetURLUsesURLComponentsEncoding() throws {
        let snapshot = sampleSnapshot()
        let expectedText = GainSummaryFormatter.format(snapshot)
        let url = try XCTUnwrap(XShareIntent.tweetURL(for: snapshot))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let textItem = try XCTUnwrap(components.queryItems?.first { $0.name == "text" })

        XCTAssertEqual(textItem.value, expectedText)
        XCTAssertTrue(expectedText.contains("today's gain"))
        XCTAssertTrue(url.absoluteString.contains("text="))
        XCTAssertFalse(url.absoluteString.contains(" — "))
    }

    func testTweetURLEncodesSpecialCharacters() throws {
        let snapshot = sampleSnapshot()
        let text = try XCTUnwrap(GainSummaryFormatter.format(snapshot))
        let url = try XCTUnwrap(XShareIntent.tweetURL(for: snapshot))

        XCTAssertTrue(text.contains("—"))
        XCTAssertFalse(url.absoluteString.contains("—"))
        XCTAssertTrue(url.absoluteString.contains("%E2%80%94") || url.absoluteString.contains("%e2%80%94"))
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

    func testDayKeyUsesEasternCalendarDay() throws {
        let lateEveningUTC = try EasternTestDates.date(year: 2026, month: 7, day: 1, hour: 23)
        XCTAssertEqual(tradingCalendar.dayKey(for: lateEveningUTC), "2026-07-01")
    }

    func testIsSameTradingDayAcrossMidnightEastern() throws {
        let late = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 23, minute: 30)
        let early = try EasternTestDates.date(year: 2026, month: 7, day: 1, hour: 0, minute: 15)
        XCTAssertFalse(tradingCalendar.isSameTradingDay(late, early))
    }

    func testHasTradingDayCompletedAfterMarketClose() throws {
        let afterClose = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 17)
        XCTAssertTrue(
            tradingCalendar.hasTradingDayCompleted(
                dayKey: "2026-06-30",
                at: afterClose,
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
            marketIsOpen: true
        )

        XCTAssertFalse(snapshot.hasCompletedFirstTradingDay)
        XCTAssertNil(snapshot.bestRecord)
        XCTAssertNil(snapshot.worstRecord)
    }

    func testTracksBestAndWorstAfterFirstDayCompletes() throws {
        let tracker = makeTracker()
        let midday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let afterClose = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 17)

        _ = tracker.update(personID: "musk", paperGain: 12_000_000_000, at: midday, marketIsOpen: true)
        _ = tracker.update(personID: "musk", paperGain: -4_000_000_000, at: midday.addingTimeInterval(3_600), marketIsOpen: true)
        let snapshot = tracker.update(personID: "musk", paperGain: -4_000_000_000, at: afterClose, marketIsOpen: false)

        XCTAssertTrue(snapshot.hasCompletedFirstTradingDay)
        XCTAssertEqual(snapshot.bestRecord?.amount, 12_000_000_000)
        XCTAssertEqual(snapshot.worstRecord?.amount, -4_000_000_000)
    }

    func testRecordsAreScopedPerPersonID() throws {
        let tracker = makeTracker()
        let midday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let afterClose = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 17)

        _ = tracker.update(personID: "musk", paperGain: 20_000_000_000, at: midday, marketIsOpen: true)
        _ = tracker.update(personID: "musk", paperGain: 20_000_000_000, at: afterClose, marketIsOpen: false)

        let other = tracker.update(personID: "other", paperGain: 1_000_000_000, at: afterClose, marketIsOpen: false)

        XCTAssertEqual(tracker.snapshot(for: "musk").bestRecord?.amount, 20_000_000_000)
        XCTAssertFalse(other.hasCompletedFirstTradingDay)
        XCTAssertNil(other.bestRecord)
    }

    func testPersistsAcrossReload() throws {
        let suiteName = "MuskometerTests-daily-records-persist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let midday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let afterClose = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 17)

        let tracker = DailyRecordTracker(defaults: defaults, calendar: easternCalendar, marketHours: marketHours)
        _ = tracker.update(personID: "musk", paperGain: 8_000_000_000, at: midday, marketIsOpen: true)
        _ = tracker.update(personID: "musk", paperGain: 8_000_000_000, at: afterClose, marketIsOpen: false)

        let reloaded = DailyRecordTracker(defaults: defaults, calendar: easternCalendar, marketHours: marketHours)
        let snapshot = reloaded.snapshot(for: "musk")

        XCTAssertTrue(snapshot.hasCompletedFirstTradingDay)
        XCTAssertEqual(snapshot.bestRecord?.amount, 8_000_000_000)
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
            marketIsOpen: true
        )
        let events = await service.processUpdate(
            paperGain: 11_000_000_000,
            personID: "musk",
            possessiveName: "Elon's",
            at: date.addingTimeInterval(60),
            marketIsOpen: true
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
            marketIsOpen: false
        )
        let events = await service.processUpdate(
            paperGain: 11_000_000_000,
            personID: "musk",
            possessiveName: "Elon's",
            at: date.addingTimeInterval(60),
            marketIsOpen: false
        )

        XCTAssertTrue(events.isEmpty)
        XCTAssertTrue(deliverer.requests.isEmpty)
    }

    func testRearmsAfterDroppingBelowThreshold() async throws {
        let (service, deliverer) = makeService()
        service.setEnabledThresholdIDs(["gain-10b"], for: "musk")
        let date = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)

        _ = await service.processUpdate(paperGain: 9_000_000_000, personID: "musk", possessiveName: "Elon's", at: date, marketIsOpen: true)
        _ = await service.processUpdate(paperGain: 11_000_000_000, personID: "musk", possessiveName: "Elon's", at: date.addingTimeInterval(60), marketIsOpen: true)
        _ = await service.processUpdate(paperGain: 8_000_000_000, personID: "musk", possessiveName: "Elon's", at: date.addingTimeInterval(120), marketIsOpen: true)
        let secondCross = await service.processUpdate(
            paperGain: 12_000_000_000,
            personID: "musk",
            possessiveName: "Elon's",
            at: date.addingTimeInterval(180),
            marketIsOpen: true
        )

        XCTAssertEqual(secondCross.count, 1)
        XCTAssertEqual(deliverer.requests.count, 2)
    }

    func testFiresLossThresholdOnDownwardCross() async throws {
        let (service, deliverer) = makeService()
        service.setEnabledThresholdIDs(["loss-10b"], for: "musk")
        let date = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)

        _ = await service.processUpdate(paperGain: -8_000_000_000, personID: "musk", possessiveName: "Elon's", at: date, marketIsOpen: true)
        let events = await service.processUpdate(
            paperGain: -12_000_000_000,
            personID: "musk",
            possessiveName: "Elon's",
            at: date.addingTimeInterval(60),
            marketIsOpen: true
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
            marketIsOpen: true
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
            marketIsOpen: true
        )

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.threshold.id, "gain-10b")
        XCTAssertEqual(deliverer.requests.count, 1)
        XCTAssertTrue(deliverer.requests.first?.content.title.contains("+$10B") ?? false)
    }
}

final class ComparisonLibraryTests: XCTestCase {
    func testLibraryHasAtLeastSixtyEntries() {
        XCTAssertGreaterThanOrEqual(ComparisonLibrary.entries.count, 60)
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

    func testCandidatesMatchMagnitudeBucket() {
        let candidates = ComparisonLibrary.candidates(forMagnitude: 15_000_000_000)
        XCTAssertFalse(candidates.isEmpty)
        XCTAssertTrue(candidates.allSatisfy { $0.minMagnitude == 10_000_000_000 && $0.maxMagnitude == 20_000_000_000 })
    }

    func testLinePrefixesGainAndLoss() {
        let entry = ComparisonLibrary.entries.first!
        XCTAssertTrue(entry.line(forGain: 5_000_000_000).text.hasPrefix("Today's gain "))
        XCTAssertTrue(entry.line(forGain: -5_000_000_000).text.hasPrefix("Today's loss "))
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
            marketHours: FixedMarketHours(isOpen: true)
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