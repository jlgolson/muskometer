import AppKit
import SwiftUI
import UserNotifications
import XCTest
import Vision
import ScreenCaptureKit
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

// Read-only September 10 observations, using Codable Date's 2001 reference epoch.
private enum VisualChartFixture {
    static let gains = [13_855_060_779.811922, 14_187_615_509.983934,
        13_385_345_764.31092, 16_083_600_343.614992, 14_670_726_847.679981,
        14_618_948_881.370857, 15_949_845_655.179981, 15_827_663_635.18001,
        15_921_438_748.099966]
    static let times = [810753101.078183, 810753192.039462, 810753287.968565,
        810753383.70998, 810753475.567488, 810753568.721071,
        810753661.558663, 810753752.990089, 810753844.606051]
    static let observed = zip(times, gains).map {
        GainSample(timestamp: Date(timeIntervalSinceReferenceDate: $0.0), combinedPaperGain: $0.1)
    }
}

private struct InterfaceProbeStock: StockPriceServiceProtocol {
    func fetchQuotes(for symbols: [String]) async throws -> [StockQuote] {
        // Controlled quote changes sum to the latest observed gain, without adding a chart sample.
        let tslaGain = (366.32 - 367.83) * 710_172_677
        let spcxChange = (VisualChartFixture.gains.last! - tslaGain) / 5_116_475_230
        return symbols.map { StockQuote(symbol: $0, displayName: $0,
            currentPrice: $0 == "TSLA" ? 366.32 : 150.90,
            previousClose: $0 == "TSLA" ? 367.83 : 150.90 - spcxChange, currency: "USD") }
    }
}

final class SparklineLayoutRegressionTests: XCTestCase {
    func testNarrowPositiveMovementUsesVisibleHeight() {
        let samples = VisualChartFixture.observed
        let layout = SparklineLayout(samples: samples, size: CGSize(width: 288, height: 60))
        let ys = samples.map { layout.point(for: $0).y }
        XCTAssertGreaterThan(layout.minGain, 0, "Distant zero must not flatten positive movement")
        XCTAssertGreaterThan(ys.max()! - ys.min()!, 35, "Observed $2.7B range must be legible")
    }
    private func samples(_ gains: [Double]) -> [GainSample] {
        gains.enumerated().map { GainSample(timestamp: Date(timeIntervalSinceReferenceDate: Double($0.offset * 60)), combinedPaperGain: $0.element) }
    }

    private func assertBounded(_ samples: [GainSample], file: StaticString = #filePath, line: UInt = #line) {
        let layout = SparklineLayout(samples: samples, size: CGSize(width: 288, height: 60))
        XCTAssertTrue(layout.minGain.isFinite && layout.maxGain.isFinite, file: file, line: line)
        XCTAssertGreaterThan(layout.maxGain, layout.minGain, file: file, line: line)
        XCTAssertEqual(layout.containsZero, layout.minGain <= 0 && layout.maxGain >= 0, file: file, line: line)
        for sample in samples {
            let point = layout.point(for: sample)
            XCTAssertTrue(point.x.isFinite && point.y.isFinite, file: file, line: line)
            XCTAssertTrue(CGRect(x: 0, y: 0, width: 288, height: 60).insetBy(dx: 3, dy: 3).contains(point), file: file, line: line)
        }
    }

    func testNegativeOnlyKeepsDistantZeroOutsideDomain() {
        let values = samples(VisualChartFixture.gains.map { -$0 })
        let layout = SparklineLayout(samples: values, size: CGSize(width: 288, height: 60))
        XCTAssertLessThan(layout.maxGain, 0)
        XCTAssertFalse(layout.containsZero)
        assertBounded(values)
    }

    func testMixedSignsStraddleVisibleZero() {
        let values = samples([-2e9, 1e9, -1e9, 2e9])
        let layout = SparklineLayout(samples: values, size: CGSize(width: 288, height: 60))
        XCTAssertTrue(layout.containsZero)
        XCTAssertGreaterThan(layout.point(for: values[0]).y, layout.zeroY)
        XCTAssertLessThan(layout.point(for: values[1]).y, layout.zeroY)
        assertBounded(values)
    }

    func testFlatPositiveNegativeAndZeroRemainHorizontal() {
        for value in [16e9, -16e9, 0] {
            let values = samples([value, value, value])
            let layout = SparklineLayout(samples: values, size: CGSize(width: 288, height: 60))
            XCTAssertEqual(Set(values.map { layout.point(for: $0).y }).count, 1)
            XCTAssertEqual(layout.point(for: values[0]).y, 30, accuracy: 0.01)
            assertBounded(values)
        }
    }

    func testSingleSampleIsCenteredWithoutInventingHistory() {
        let values = samples([16e9])
        let layout = SparklineLayout(samples: values, size: CGSize(width: 288, height: 60))
        XCTAssertEqual(layout.point(for: values[0]), CGPoint(x: 144, y: 30))
        assertBounded(values)
    }

    func testEmptyLayoutIsFiniteAndSafe() {
        assertBounded([])
        let layout = SparklineLayout(samples: [], size: CGSize(width: 288, height: 60))
        XCTAssertTrue(layout.containsZero)
        XCTAssertEqual(layout.zeroY, 30, accuracy: 0.01)
    }

    func testIrregularTimestampsKeepRelativeSpacing() {
        let values = zip([0.0, 10, 100], [1e9, 2e9, 3e9]).map {
            GainSample(timestamp: Date(timeIntervalSinceReferenceDate: $0.0), combinedPaperGain: $0.1)
        }
        let layout = SparklineLayout(samples: values, size: CGSize(width: 288, height: 60))
        let x = values.map { layout.point(for: $0).x }
        XCTAssertEqual((x[1] - x[0]) / (x[2] - x[0]), 0.1, accuracy: 0.0001)
        XCTAssertTrue(x[0] < x[1] && x[1] < x[2])
        assertBounded(values)
    }

    func testFullCapacityMonotonicFixturePreservesOrderAndBounds() {
        let values = samples((0..<400).map { 15e9 + Double($0) * 1e6 })
        assertBounded(values)
        let layout = SparklineLayout(samples: values, size: CGSize(width: 288, height: 60))
        let points = values.map { layout.point(for: $0) }
        for pair in zip(points, points.dropFirst()) {
            XCTAssertLessThan(pair.0.x, pair.1.x)
            XCTAssertGreaterThan(pair.0.y, pair.1.y)
        }
    }

}

final class PopoverLayoutRegressionTests: XCTestCase {
#if MUSKOMETER_TEST_HOST
    @MainActor
    func testUsesIsolatedApplicationEntryPoint() throws {
        XCTAssertTrue(MuskometerApp.isIsolatedTestHost,
                      "Hosted tests must use the inert application entry point")
        let assets = try XCTUnwrap(Bundle.main.url(forResource: "Assets", withExtension: "car"))
        let report = ["bundle": Bundle.main.bundlePath, "assets": assets.path, "isolated": "true"]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted]),
                                       uniformTypeIdentifier: "public.json")
        attachment.name = "compiled-host-assets.json"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
#endif

    @MainActor
    func testPopulatedPopoverFitsAvailableHeightAndRetainsScrolling() async throws {
        let vm = try await makeVisualModel()
        for height in [600.0, 700.0, 800.0, 900.0] {
            let host = NSHostingView(rootView: PopoverContentView(viewModel: vm, availableHeight: height)
                .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .dark))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: height),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            host.appearance = NSAppearance(named: .darkAqua)
            window.contentView = host
            window.orderFront(nil)
            host.frame = NSRect(x: 0, y: 0, width: 360, height: height)
            await settle(host)
            print("LAYOUT main available=\(height) fitting=\(host.fittingSize)")
            XCTAssertEqual(host.fittingSize.width, 360, accuracy: 0.5)
            XCTAssertLessThanOrEqual(host.fittingSize.height, height)
            let scroll = try XCTUnwrap(scrollViews(in: host).first)
            let document = try XCTUnwrap(scroll.documentView)
            if height <= 700 {
                XCTAssertGreaterThan(document.bounds.height, scroll.contentView.bounds.height,
                                     "Small panels must retain real secondary-content scrolling")
            }
            try await assertInitialParity(host, scroll: scroll, price: CurrencyFormatter.formatPrice(
                try XCTUnwrap(vm.mergerParityPresentation).impliedTSLAPrice), name: "main-\(Int(height))-top")
            let before = scroll.contentView.bounds.origin.y
            document.scroll(NSPoint(x: 0, y: document.bounds.height))
            scroll.reflectScrolledClipView(scroll.contentView)
            if document.bounds.height > scroll.contentView.bounds.height {
                XCTAssertGreaterThan(scroll.contentView.bounds.origin.y, before)
                XCTAssertEqual(scroll.contentView.bounds.maxY, document.bounds.maxY, accuracy: 1)
            } else {
                XCTAssertEqual(scroll.contentView.bounds.origin.y, before)
            }
            await settle(host)
            let detail = try await capture(host, name: "main-\(Int(height))-detail")
            let detailText = try recognizedText(detail, size: host.bounds.size).map(\.0).joined(separator: " ")
            XCTAssertFalse(detailText.lowercased().contains("vested options"))
            XCTAssertTrue(detailText.contains("TSLA") && detailText.contains("SPCX"), "Both stock details must be reachable")

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
            let settingsImage = try await capture(host, name: "settings-\(Int(height))")
            if height == 600 {
                let text = try recognizedText(settingsImage, size: host.bounds.size)
                let holdings = try XCTUnwrap(text.first { $0.0 == "Holdings" })
                try click(CGPoint(x: holdings.1.midX, y: holdings.1.midY), in: host)
                await settle(host)
                let holdingsImage = try await capture(host, name: "holdings-600")
                let lines = try recognizedText(holdingsImage, size: host.bounds.size).map(\.0)
                let rendered = lines.joined(separator: " ").lowercased()
                XCTAssertEqual(rendered.components(separatedBy: "vested options only").count - 1, 1)
                XCTAssertTrue(rendered.contains("performance rsus excluded until milestones"))
                let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
                attachment.name = "holdings-rendered-text.txt"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
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
    func testAssetBackedChartFixturesAndAppearances() async throws {
        let vm = try await makeVisualModel()
        let snapshot = try XCTUnwrap(vm.snapshot)
        let parity = try XCTUnwrap(vm.mergerParityPresentation)
        for (name, appearance) in [("light", NSAppearance.Name.aqua),
                                   ("requested-high-contrast", .accessibilityHighContrastDarkAqua)] {
            var observedContrast: ColorSchemeContrast?
            let content = PopoverContentView(viewModel: vm, availableHeight: 900)
                .background(VisualContrastProbe { observedContrast = $0 })
                .background(Color(nsColor: .windowBackgroundColor))
            let host = NSHostingView(rootView: content)
            let window = makeWindow(host, size: CGSize(width: 360, height: 900), appearance: appearance)
            await settle(host)
            // macOS 26.4.1 normalizes a requested high-contrast hosting appearance
            // to Dark Aqua; its read-only contrast follows system preferences. Record that fact;
            // explicitly exercise the same renderer's accessibility inputs below.
            let report = XCTAttachment(string: "Native appearance: \(host.effectiveAppearance.name.rawValue); SwiftUI contrast: \(String(describing: observedContrast))")
            report.name = "appearance-\(name).txt"
            report.lifetime = .keepAlways
            add(report)
            let scroll = try XCTUnwrap(scrollViews(in: host).first)
            try await assertInitialParity(host, scroll: scroll, price: CurrencyFormatter.formatPrice(parity.impliedTSLAPrice),
                                          name: "main-900-" + name)
            window.close()
        }
        let accessibleChart = VStack(alignment: .leading, spacing: 10) {
            Text("Increased contrast · reduced transparency fixture").font(.caption)
            GainSparklineContent(samples: VisualChartFixture.observed, colorScheme: .dark,
                                 contrast: .increased, reduceTransparency: true)
        }.padding(12).frame(width: 328, height: 130, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .dark)
        let accessibleHost = NSHostingView(rootView: accessibleChart)
        let accessibleWindow = makeWindow(accessibleHost, size: CGSize(width: 328, height: 130), appearance: .accessibilityHighContrastDarkAqua)
        await settle(accessibleHost)
        let accessibleImage = try await capture(accessibleHost, name: "chart-increased-contrast-reduced-transparency")
        let accessibleText = try recognizedText(accessibleImage, size: accessibleHost.bounds.size)
        // Verify the complete monetary domain and its visible bounds. On a 1x
        // display, Vision misreads the descriptive word "Range" as "kande".
        let rangeLabel = try XCTUnwrap(accessibleText.first {
            $0.0.contains("$13.2B") && $0.0.contains("$16.3B")
        }, "Both displayed range values must be readable")
        XCTAssertTrue(accessibleHost.bounds.contains(rangeLabel.1),
                      "The complete monetary range must remain inside the chart fixture")
        accessibleWindow.close()
        let fixtures: [(String, [GainSample])] = [
            ("observed", VisualChartFixture.observed),
            ("negative", VisualChartFixture.observed.map { GainSample(timestamp: $0.timestamp, combinedPaperGain: -$0.combinedPaperGain) }),
            ("mixed", fixture([-2e9, 1e9, -1e9, 2e9])),
            ("flat-positive", fixture([16e9, 16e9, 16e9])),
            ("flat-negative", fixture([-16e9, -16e9, -16e9])),
            ("flat-zero", fixture([0, 0, 0])),
            ("single", fixture([16e9])), ("empty", []),
            ("400", fixture((0..<400).map { 15e9 + Double($0) * 1e6 }))]
        for (name, samples) in fixtures {
            let chart = VStack(alignment: .leading, spacing: 10) {
                Text(name == "observed" ? "September 10 · observed samples" : "\(name) · synthetic test fixture")
                    .font(.caption)
                GainSparklineView(samples: samples)
            }.padding(12).frame(width: 328, height: 130, alignment: .topLeading)
                .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .dark)
            let host = NSHostingView(rootView: chart)
            let window = makeWindow(host, size: CGSize(width: 328, height: 130), appearance: .darkAqua)
            await settle(host)
            _ = try await capture(host, name: "chart-" + name)
            window.close()
            let target = samples.last?.combinedPaperGain ?? 0
            let holdings = snapshot.holdings.map { holding in
                let gain = holding.symbol == "SPCX" ? target - snapshot.holdings[0].paperGain : holding.paperGain
                let quote = StockQuote(symbol: holding.symbol, displayName: holding.displayName,
                    currentPrice: holding.quote.currentPrice,
                    previousClose: holding.quote.currentPrice - gain / Double(holding.shareCount), currency: "USD")
                return HoldingGain(id: holding.id, symbol: holding.symbol, displayName: holding.displayName,
                                   shareCount: holding.shareCount, quote: quote)
            }
            let exportSnapshot = GainsSnapshot(holdings: holdings, lastUpdated: snapshot.lastUpdated, tradingSession: .regular)
            XCTAssertEqual(exportSnapshot.combinedPaperGain, target, accuracy: 0.01)
            let png = try XCTUnwrap(ShareImageExporter.renderPNGData(snapshot: exportSnapshot,
                profile: vm.settings.selectedProfile, intradaySamples: samples, parity: parity))
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: png))
            XCTAssertEqual(bitmap.pixelsWide, 720, "Production export retains 2x resolution")
            let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
            attachment.name = "share-\(name).png"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func fixture(_ gains: [Double]) -> [GainSample] {
        gains.enumerated().map { GainSample(timestamp: VisualChartFixture.observed[0].timestamp.addingTimeInterval(Double($0.offset * 60)), combinedPaperGain: $0.element) }
    }

    @MainActor
    private func makeWindow<Content: View>(_ host: NSHostingView<Content>, size: CGSize,
                                           appearance: NSAppearance.Name) -> NSWindow {
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: appearance)
        host.appearance = NSAppearance(named: appearance)
        window.contentView = host
        window.orderFront(nil)
        host.frame = CGRect(origin: .zero, size: size)
        return window
    }

    @MainActor
    private func makeVisualModel() async throws -> GainsViewModel {
        let defaults = UserDefaults(suiteName: "MuskometerTests-visual-\(UUID().uuidString)")!
        let settings = AppSettings(defaults: defaults, launchAtLoginManager: MockLaunchAtLoginManager())
        let now = try XCTUnwrap(VisualChartFixture.observed.last?.timestamp)
        settings.showMergerParityCard = true
        settings.lastHoldingsSyncDate = now
        settings.holdingsSyncSource = "SEC EDGAR · Form 4 · September 10, 2026 (controlled fixture)"
        let store = IntradayGainSampleStore(defaults: defaults, now: { now })
        let tracker = DailyRecordTracker(defaults: defaults)
        _ = tracker.update(personID: "musk", paperGain: -109e9, at: now.addingTimeInterval(-2*86400), isQuotable: true)
        _ = tracker.update(personID: "musk", paperGain: -109e9, at: now.addingTimeInterval(-2*86400 + 6*3600), isQuotable: false)
        _ = tracker.update(personID: "musk", paperGain: 116.4e9, at: now.addingTimeInterval(-86400), isQuotable: true)
        _ = tracker.update(personID: "musk", paperGain: 116.4e9, at: now.addingTimeInterval(-86400 + 6*3600), isQuotable: false)
        let vm = GainsViewModel(settings: settings, stockService: InterfaceProbeStock(),
            holdingsSyncServiceFactory: { _ in MockHoldingsSyncService(result: .failure(URLError(.cancelled))) },
            outstandingSyncServiceFactory: { MockIssuerOutstandingSyncService(result: [:]) },
            dailyRecordTracker: tracker,
            gainThresholdNotificationService: GainThresholdNotificationService(defaults: defaults, deliverer: VisualNotificationSink()),
            dayCloseSummaryNotificationService: DayCloseSummaryNotificationService(defaults: defaults, deliverer: VisualNotificationSink()),
            intradayGainSampleStore: store,
            netWorthMilestoneTracker: NetWorthMilestoneTracker(defaults: defaults), dateProvider: { now })
        await vm.refresh(force: true)
        // Replace only this test suite's persisted samples, then reload without a live refresh.
        struct StoredSamples: Encodable { let dayKey: String; let samples: [GainSample] }
        defaults.set(try JSONEncoder().encode(StoredSamples(dayKey: "2026-09-10", samples: VisualChartFixture.observed)),
                     forKey: "intradayGainSampleStore_musk")
        vm.reloadPersistedDisplayState()
        XCTAssertEqual(vm.intradaySamples, VisualChartFixture.observed)
        XCTAssertEqual(try XCTUnwrap(vm.snapshot).combinedPaperGain, VisualChartFixture.gains.last!, accuracy: 0.01)
        XCTAssertNotNil(vm.snapshot)
        XCTAssertNotNil(vm.dailyRecordsSnapshot.worstRecord)
        XCTAssertNotNil(vm.dailyRecordsSnapshot.bestRecord)
        XCTAssertNotNil(vm.mergerParityPresentation)
        return vm
    }

    @MainActor
    private func capture(_ host: NSView, name: String) async throws -> NSBitmapImageRep {
        let window = try XCTUnwrap(host.window)
        // Only this inert test process's own window is shareable without TCC consent.
        // Window-server capture preserves Liquid Glass, whose compositor layers are
        // absent (and primary text black) in cacheDisplay's offscreen bitmap.
        let content = try await SCShareableContent.currentProcess
        let surface = try XCTUnwrap(content.windows.first { $0.windowID == CGWindowID(window.windowNumber) })
        let filter = SCContentFilter(desktopIndependentWindow: surface)
        // Match the window's native scale. Requesting 2x on a 1x display pads
        // the screenshot instead of upscaling it, which halves OCR coordinates.
        let pixelScale = CGFloat(filter.pointPixelScale)
        let config = SCStreamConfiguration()
        config.width = Int((host.bounds.width * pixelScale).rounded())
        config.height = Int((host.bounds.height * pixelScale).rounded())
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        config.shouldBeOpaque = true
        let cgImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: config)
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        bitmap.size = host.bounds.size
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name + ".png"
        attachment.lifetime = .keepAlways
        add(attachment)
        return bitmap
    }

    @MainActor
    private func recognizedText(_ bitmap: NSBitmapImageRep, size: CGSize) throws -> [(String, CGRect)] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: try XCTUnwrap(bitmap.cgImage), options: [:]).perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            let box = observation.boundingBox
            return (text, CGRect(x: box.minX * size.width, y: (1 - box.maxY) * size.height,
                                 width: box.width * size.width, height: box.height * size.height))
        }
    }

    @MainActor
    private func assertInitialParity(_ host: NSView, scroll: NSScrollView, price: String, name: String) async throws {
        let observed = try recognizedText(try await capture(host, name: name), size: host.bounds.size)
        XCTAssertFalse(observed.map(\.0).joined(separator: " ").lowercased().contains("vested options"))
        var clip = scroll.contentView.convert(scroll.contentView.bounds, to: host)
        if !host.isFlipped { clip.origin.y = host.bounds.height - clip.maxY }
        func normalize(_ value: String) -> String {
            value.replacingOccurrences(of: "’", with: "'").split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        for expected in ["If Tesla had SpaceX's market cap", price] {
            if let match = observed.first(where: { normalize($0.0) == normalize(expected) }) {
                XCTAssertTrue(clip.contains(match.1), "Complete \(expected) must lie inside initial viewport \(clip), got \(match.1)")
            } else {
                XCTFail("Complete \(expected) missing from initial viewport at \(host.bounds.height)")
            }
        }
        let report: [String: Any] = ["clipRect": NSStringFromRect(clip), "hostBounds": NSStringFromRect(host.bounds),
            "expectedTitle": "If Tesla had SpaceX's market cap", "expectedPrice": price,
            "text": observed.map { ["text": $0.0, "rect": NSStringFromRect($0.1)] }]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]),
                                       uniformTypeIdentifier: "public.json")
        attachment.name = name + "-geometry.json"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func settle(_ host: NSView) async {
        for _ in 0..<6 {
            await Task.yield()
            host.layoutSubtreeIfNeeded()
        }
        host.displayIfNeeded()
        try? await Task.sleep(for: .milliseconds(150))
    }

    @MainActor
    private func click(_ imagePoint: CGPoint, in host: NSView) throws {
        let window = try XCTUnwrap(host.window)
        let point = host.isFlipped ? imagePoint : CGPoint(x: imagePoint.x, y: host.bounds.height - imagePoint.y)
        let location = host.convert(point, to: nil)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: location, modifierFlags: [],
                timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            window.sendEvent(event)
        }
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

private struct VisualNotificationSink: GainThresholdNotificationDelivering, DayCloseSummaryNotificationDelivering {
    func add(_ request: UNNotificationRequest) async throws {
        XCTFail("Visual fixtures must not deliver notifications")
    }
}

private struct VisualContrastProbe: View {
    @Environment(\.colorSchemeContrast) private var contrast
    let report: (ColorSchemeContrast) -> Void
    var body: some View {
        Color.clear.onAppear { report(contrast) }.onChange(of: contrast) { _, value in report(value) }
    }
}
