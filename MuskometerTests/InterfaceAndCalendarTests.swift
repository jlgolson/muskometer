import AppKit
import SwiftUI
import UserNotifications
import XCTest
@testable import Muskometer

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

    func testHolidayTableCoversCurrentAndNextYear() {
        let year = Calendar(identifier: .gregorian).component(.year, from: Date())
        XCTAssertTrue(
            MarketHoursService.holidayTableCovers(year: year),
            "NYSE holiday table must cover the current calendar year"
        )
        XCTAssertTrue(
            MarketHoursService.holidayTableCovers(year: year + 1),
            "NYSE holiday table should cover next year so year-end doesn't corrupt day state"
        )
        XCTAssertFalse(MarketHoursService.holidayTableCovers(year: MarketHoursService.holidayTableThroughYear + 1))
    }

    func testHolidayTableMaxKeyYearMatchesThroughYear() {
        XCTAssertEqual(
            MarketHoursService.holidayTableMaxKeyYear(),
            MarketHoursService.holidayTableThroughYear,
            "When extending NYSE holidays, bump holidayTableThroughYear to match the newest key year"
        )
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

    func test2028MLKIsClosedAndNextDayOpen() throws {
        let mlk = try EasternTestDates.date(year: 2028, month: 1, day: 17, hour: 11)
        let nextDay = try EasternTestDates.date(year: 2028, month: 1, day: 18, hour: 11)
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)
        XCTAssertFalse(service.isMarketOpen(at: mlk))
        XCTAssertTrue(service.isMarketOpen(at: nextDay))
    }

    func testDecember31_2027IsRegularTradingBeforeSaturdayNewYear() throws {
        // NYSE does not observe a Saturday New Year on the preceding Friday.
        let observedClose = try EasternTestDates.date(year: 2027, month: 12, day: 31, hour: 11)
        let jan3 = try EasternTestDates.date(year: 2028, month: 1, day: 3, hour: 11)
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)
        XCTAssertTrue(service.isMarketOpen(at: observedClose))
        let close = try XCTUnwrap(service.regularCloseDate(on: observedClose))
        XCTAssertEqual(calendar.component(.hour, from: close), 16)
        let nextOpen = try XCTUnwrap(service.nextOpenDate(from: close))
        XCTAssertEqual(nextOpen, try EasternTestDates.date(year: 2028, month: 1, day: 3, hour: 9, minute: 30))
        XCTAssertTrue(service.isMarketOpen(at: jan3))
    }

    func test2028GoodFridayAndIndependenceDayAreClosed() throws {
        let goodFriday = try EasternTestDates.date(year: 2028, month: 4, day: 14, hour: 11)
        let july4 = try EasternTestDates.date(year: 2028, month: 7, day: 4, hour: 11)
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)
        XCTAssertFalse(service.isMarketOpen(at: goodFriday))
        XCTAssertFalse(service.isMarketOpen(at: july4))
    }

    func test2028July3EarlyClose() throws {
        let morning = try EasternTestDates.date(year: 2028, month: 7, day: 3, hour: 11)
        let afternoon = try EasternTestDates.date(year: 2028, month: 7, day: 3, hour: 14)
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)
        XCTAssertTrue(service.isMarketOpen(at: morning))
        XCTAssertFalse(service.isMarketOpen(at: afternoon))
    }

    func test2028ThanksgivingAndDayAfterEarlyClose() throws {
        let thanksgiving = try EasternTestDates.date(year: 2028, month: 11, day: 23, hour: 11)
        let dayAfter = try EasternTestDates.date(year: 2028, month: 11, day: 24, hour: 14)
        let service = MarketHoursService(calendar: calendar, timeZone: eastern)
        XCTAssertFalse(service.isMarketOpen(at: thanksgiving))
        XCTAssertFalse(service.isMarketOpen(at: dayAfter))
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

        // Already unregistered: reset clears stale errors without another service call.
        manager.setEnabledHandler = { enabled in
            manager.isEnabled = enabled
        }

        settings.resetToDefaults()

        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertNil(settings.launchAtLoginError)
        XCTAssertFalse(defaults.bool(forKey: "launchAtLogin"))
        XCTAssertEqual(manager.setEnabledCalls.count, callsAfterFailure)
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

// Models SMAppService: registration can require approval, and registering twice
// throws. No service management calls are made by these tests.
private final class StatusAwareLoginManager: LaunchAtLoginManaging {
    typealias Status = LaunchAtLoginStatus
    var status: Status = .notRegistered
    var isEnabled: Bool { status == .enabled }
    var failure: Error?
    private(set) var calls: [Bool] = []
    func setEnabled(_ enabled: Bool) throws {
        calls.append(enabled)
        if let failure { throw failure }
        if enabled {
            guard status == .notRegistered else {
                throw NSError(domain: "SMAppServiceErrorDomain", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "already registered"])
            }
            status = .requiresApproval
        } else {
            status = .notRegistered
        }
    }
}

final class LoginStatusRegressionTests: XCTestCase {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "MuskometerTests-status-\(UUID().uuidString)")!
    }

    func testPendingRegistrationSurvivesReopenRestartAndApproval() {
        let defaults = defaults()
        let manager = StatusAwareLoginManager()
        let settings = AppSettings(defaults: defaults, launchAtLoginManager: manager)
        settings.launchAtLogin = true
        for _ in 0..<3 { settings.syncLaunchAtLoginFromService() }
        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertTrue(defaults.bool(forKey: "launchAtLogin"))
        XCTAssertEqual(manager.calls, [true])
        XCTAssertNotNil(settings.launchAtLoginError)

        let restarted = AppSettings(defaults: defaults, launchAtLoginManager: manager)
        restarted.syncLaunchAtLoginFromService()
        XCTAssertTrue(restarted.launchAtLogin)
        XCTAssertEqual(manager.calls, [true])
        manager.status = .enabled
        for _ in 0..<3 { restarted.syncLaunchAtLoginFromService() }
        XCTAssertTrue(restarted.launchAtLogin)
        XCTAssertNil(restarted.launchAtLoginError)
        XCTAssertEqual(manager.status, .enabled)
        XCTAssertEqual(manager.calls, [true])
    }

    func testRepeatedEnableDoesNotRegisterPendingOrEnabledServiceAgain() {
        for status in [StatusAwareLoginManager.Status.requiresApproval, .enabled] {
            let manager = StatusAwareLoginManager()
            manager.status = status
            let settings = AppSettings(defaults: defaults(), launchAtLoginManager: manager)
            settings.launchAtLogin = true
            settings.launchAtLogin = true
            XCTAssertTrue(settings.launchAtLogin)
            XCTAssertEqual(manager.calls, [])
            XCTAssertEqual(manager.status, status)
        }
    }

    func testDisableUnregistersPendingAndEnabledOnlyOnce() {
        for status in [StatusAwareLoginManager.Status.requiresApproval, .enabled] {
            let manager = StatusAwareLoginManager()
            manager.status = status
            let defaults = defaults()
            defaults.set(true, forKey: "launchAtLogin")
            let settings = AppSettings(defaults: defaults, launchAtLoginManager: manager)
            settings.launchAtLogin = false
            settings.launchAtLogin = false
            settings.syncLaunchAtLoginFromService()
            XCTAssertEqual(manager.status, .notRegistered)
            XCTAssertEqual(manager.calls, [false])
            XCTAssertFalse(defaults.bool(forKey: "launchAtLogin"))
            XCTAssertNil(settings.launchAtLoginError)
        }
    }

    func testDisableNotRegisteredIsNoOp() {
        let manager = StatusAwareLoginManager()
        let settings = AppSettings(defaults: defaults(), launchAtLoginManager: manager)
        settings.launchAtLogin = false
        settings.syncLaunchAtLoginFromService()
        XCTAssertEqual(manager.calls, [])
        XCTAssertFalse(settings.launchAtLogin)
    }

    func testFailedDisablePreservesPendingRegistrationAndPreference() {
        let manager = StatusAwareLoginManager()
        manager.status = .requiresApproval
        manager.failure = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "unregister failed"])
        let defaults = defaults()
        defaults.set(true, forKey: "launchAtLogin")
        let settings = AppSettings(defaults: defaults, launchAtLoginManager: manager)
        settings.launchAtLogin = false
        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertTrue(defaults.bool(forKey: "launchAtLogin"))
        XCTAssertEqual(manager.status, .requiresApproval)
        XCTAssertEqual(settings.launchAtLoginError, "Couldn't disable launch at login: unregister failed")
    }

    func testUnavailableDoesNotAttemptRegistrationAndSurfacesError() {
        let manager = StatusAwareLoginManager()
        manager.status = .unavailable
        let settings = AppSettings(defaults: defaults(), launchAtLoginManager: manager)
        settings.launchAtLogin = true
        XCTAssertEqual(manager.calls, [])
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertNotNil(settings.launchAtLoginError)
    }
}

private struct InterfaceProbeStock: StockPriceServiceProtocol {
    func fetchQuotes(for symbols: [String]) async throws -> [StockQuote] {
        symbols.map { StockQuote(symbol: $0, displayName: $0,
            currentPrice: $0 == "TSLA" ? 400 : 100,
            previousClose: $0 == "TSLA" ? 395 : 98, currency: "USD") }
    }
}

final class PopoverLayoutRegressionTests: XCTestCase {
    @MainActor
    func testPopulatedPopoverFitsAvailableHeightAndRetainsScrolling() async throws {
        let defaults = UserDefaults(suiteName: "MuskometerTests-layout-\(UUID().uuidString)")!
        let settings = AppSettings(defaults: defaults, launchAtLoginManager: MockLaunchAtLoginManager())
        let now = try EasternTestDates.date(year: 2026, month: 9, day: 10, hour: 11)
        let tracker = DailyRecordTracker(defaults: defaults)
        _ = tracker.update(personID: "musk", paperGain: 2e9, at: now.addingTimeInterval(-86400), isQuotable: true)
        _ = tracker.update(personID: "musk", paperGain: 2e9, at: now.addingTimeInterval(-86400 + 6*3600), isQuotable: false)
        let vm = GainsViewModel(settings: settings, stockService: InterfaceProbeStock(),
            dailyRecordTracker: tracker,
            gainThresholdNotificationService: GainThresholdNotificationService(defaults: defaults),
            dayCloseSummaryNotificationService: DayCloseSummaryNotificationService(defaults: defaults),
            intradayGainSampleStore: IntradayGainSampleStore(defaults: defaults, now: { now }),
            netWorthMilestoneTracker: NetWorthMilestoneTracker(defaults: defaults), dateProvider: { now })
        await vm.refresh(force: true)
        XCTAssertNotNil(vm.snapshot)
        XCTAssertNotNil(vm.dailyRecordsSnapshot.bestRecord)
        XCTAssertNotNil(vm.mergerParityPresentation)
        for height in [600.0, 700.0, 800.0, 900.0] {
            let host = NSHostingView(rootView: PopoverContentView(viewModel: vm, availableHeight: height))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: height),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderFront(nil)
            host.frame = NSRect(x: 0, y: 0, width: 360, height: height)
            await settle(host)
            print("LAYOUT main available=\(height) fitting=\(host.fittingSize)")
            XCTAssertEqual(host.fittingSize.width, 360, accuracy: 0.5)
            XCTAssertLessThanOrEqual(host.fittingSize.height, height)
            let scroll = try XCTUnwrap(scrollViews(in: host).first)
            let document = try XCTUnwrap(scroll.documentView)
            XCTAssertGreaterThan(document.bounds.height, scroll.contentView.bounds.height,
                                 "Populated cards must occupy a scrollable document")
            let before = scroll.contentView.bounds.origin.y
            document.scroll(NSPoint(x: 0, y: document.bounds.height))
            scroll.reflectScrolledClipView(scroll.contentView)
            XCTAssertGreaterThan(scroll.contentView.bounds.origin.y, before)
            XCTAssertEqual(scroll.contentView.bounds.maxY, document.bounds.maxY, accuracy: 1)
            attachSnapshot(host, name: "main-\(Int(height))-scrolled")

            // SwiftUI exposes compact button focus/hit-test frames as direct subviews.
            // Deduplicate overlapping focus proxies without relying on private class names.
            let footerFrames = compactControlFrames(in: host).filter { $0.minY >= scroll.superview!.frame.maxY }
            XCTAssertEqual(footerFrames.count, 3, "Refresh, Settings and Quit must remain outside the scrolling area")
            for frame in footerFrames {
                XCTAssertTrue(host.bounds.contains(frame), "Footer control must remain visible")
            }
            NotificationCenter.default.post(name: .openMuskometerSettings, object: nil)
            await settle(host)
            window.setContentSize(host.fittingSize)
            await settle(host)
            print("LAYOUT settings available=\(height) fitting=\(host.fittingSize)")
            XCTAssertEqual(host.fittingSize.width, 592, accuracy: 0.5)
            XCTAssertLessThanOrEqual(host.fittingSize.height, height)
            XCTAssertFalse(scrollViews(in: host).isEmpty)
            let back = try XCTUnwrap(compactControlFrames(in: host).first { $0.minY < 60 })
            XCTAssertTrue(host.bounds.contains(back), "Back must remain visible")
            attachSnapshot(host, name: "settings-\(Int(height))")
            let location = host.convert(NSPoint(x: back.midX, y: back.midY), to: nil)
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: location,
                    modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
                window.sendEvent(event)
            }
            await settle(host)
            XCTAssertEqual(host.fittingSize.width, 360, accuracy: 0.5, "Back must return to the main panel")
            window.close()
        }
    }

    @MainActor
    private func settle(_ host: NSView) async {
        for _ in 0..<6 {
            await Task.yield()
            host.layoutSubtreeIfNeeded()
        }
    }

    @MainActor
    private func attachSnapshot(_ host: NSView, name: String) {
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            XCTFail("Unable to capture \(name)")
            return
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let image = NSImage(size: host.bounds.size, flipped: false) { rect in
            NSColor.windowBackgroundColor.setFill()
            rect.fill()
            bitmap.draw(in: rect)
            return true
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func compactControlFrames(in host: NSView) -> [NSRect] {
        host.subviews.map(\.frame).filter { $0.height >= 18 && $0.height <= 24 && $0.width > 20 }
            .reduce(into: [NSRect]()) { frames, frame in
                if !frames.contains(frame) { frames.append(frame) }
            }
    }

    @MainActor
    private func scrollViews(in view: NSView) -> [NSScrollView] {
        (view as? NSScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
    }
}
