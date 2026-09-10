import AppKit
import UserNotifications
import XCTest
@testable import Muskometer

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

    func testPeekPendingSurvivesFailedDeliveryUntilConsume() throws {
        let tracker = makeTracker()
        let midday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let afterClose = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 20)

        _ = tracker.update(personID: "musk", paperGain: 5_000_000_000, at: midday, isQuotable: true)
        _ = tracker.update(personID: "musk", paperGain: 5_000_000_000, at: afterClose, isQuotable: false)

        let peeked = tracker.peekPendingFinalizedDay(for: "musk")
        XCTAssertEqual(peeked?.dayKey, "2026-06-30")
        XCTAssertEqual(tracker.peekPendingFinalizedDay(for: "musk")?.dayKey, "2026-06-30")

        // Simulate delivery failure: leave pending; same day cannot re-finalize.
        _ = tracker.update(personID: "musk", paperGain: 5_000_000_000, at: afterClose.addingTimeInterval(60), isQuotable: false)
        XCTAssertEqual(tracker.peekPendingFinalizedDay(for: "musk")?.dayKey, "2026-06-30")

        let consumed = try XCTUnwrap(tracker.consumePendingFinalizedDay(for: "musk"))
        XCTAssertEqual(consumed.dayKey, "2026-06-30")
        XCTAssertNil(tracker.peekPendingFinalizedDay(for: "musk"))

        // Manual restore after mistaken consume — finalize won't re-queue the same dayKey.
        tracker.restorePendingFinalizedDay(consumed, for: "musk")
        XCTAssertEqual(tracker.peekPendingFinalizedDay(for: "musk")?.dayKey, "2026-06-30")
    }

    func testPendingFinalizedDaySurvivesRelaunchUntilConsume() throws {
        let suiteName = "MuskometerTests-pending-relaunch-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let tracker1 = DailyRecordTracker(defaults: defaults, calendar: easternCalendar, marketHours: marketHours)

        let midday = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)
        let afterClose = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 20)
        _ = tracker1.update(personID: "musk", paperGain: 5_000_000_000, at: midday, isQuotable: true)
        _ = tracker1.update(personID: "musk", paperGain: 5_000_000_000, at: afterClose, isQuotable: false)
        XCTAssertEqual(tracker1.peekPendingFinalizedDay(for: "musk")?.dayKey, "2026-06-30")

        // New tracker instance = process relaunch with same UserDefaults.
        let tracker2 = DailyRecordTracker(defaults: defaults, calendar: easternCalendar, marketHours: marketHours)
        XCTAssertEqual(tracker2.peekPendingFinalizedDay(for: "musk")?.dayKey, "2026-06-30")
        XCTAssertEqual(tracker2.peekPendingFinalizedDay(for: "musk")?.closeGain, 5_000_000_000)

        _ = tracker2.consumePendingFinalizedDay(for: "musk")
        let tracker3 = DailyRecordTracker(defaults: defaults, calendar: easternCalendar, marketHours: marketHours)
        XCTAssertNil(tracker3.peekPendingFinalizedDay(for: "musk"))
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
        XCTAssertEqual(
            deliverer.requests.first?.content.categoryIdentifier,
            NotificationAuthorization.gainThresholdCategoryID
        )
        XCTAssertEqual(
            deliverer.requests.first?.content.userInfo[NotificationAuthorization.notificationKindKey] as? String,
            NotificationAuthorization.gainThresholdKind
        )
        XCTAssertEqual(
            deliverer.requests.first?.identifier,
            "gain-threshold-gain-10b-\(easternCalendar.dayKey(for: date))"
        )
    }

    func testKeepsArmedWhenDeliveryFailsThenRetries() async throws {
        final class FailingThenSucceedingDeliverer: GainThresholdNotificationDelivering, @unchecked Sendable {
            private(set) var attempts = 0
            private(set) var requests: [UNNotificationRequest] = []

            func add(_ request: UNNotificationRequest) async throws {
                attempts += 1
                if attempts == 1 {
                    throw URLError(.notConnectedToInternet)
                }
                requests.append(request)
            }
        }

        let deliverer = FailingThenSucceedingDeliverer()
        let suiteName = "MuskometerTests-gain-notify-fail-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let service = GainThresholdNotificationService(
            defaults: defaults,
            calendar: easternCalendar,
            deliverer: deliverer
        )
        service.setEnabledThresholdIDs(["gain-10b"], for: "musk")
        let date = try EasternTestDates.date(year: 2026, month: 6, day: 30, hour: 11)

        _ = await service.processUpdate(
            paperGain: 9_000_000_000,
            personID: "musk",
            possessiveName: "Elon's",
            at: date,
            isQuotable: true
        )
        let failed = await service.processUpdate(
            paperGain: 11_000_000_000,
            personID: "musk",
            possessiveName: "Elon's",
            at: date.addingTimeInterval(60),
            isQuotable: true
        )
        XCTAssertTrue(failed.isEmpty)
        XCTAssertEqual(deliverer.attempts, 1)
        XCTAssertTrue(deliverer.requests.isEmpty)

        // Still above threshold — should retry while armed.
        let retried = await service.processUpdate(
            paperGain: 11_500_000_000,
            personID: "musk",
            possessiveName: "Elon's",
            at: date.addingTimeInterval(120),
            isQuotable: true
        )
        XCTAssertEqual(retried.count, 1)
        XCTAssertEqual(deliverer.requests.count, 1)
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

@MainActor
final class DayCloseSummaryNotificationServiceTests: XCTestCase {
    private final class MockDeliverer: DayCloseSummaryNotificationDelivering, @unchecked Sendable {
        private(set) var requests: [UNNotificationRequest] = []
        func add(_ request: UNNotificationRequest) async throws {
            requests.append(request)
        }
    }

    func testDeliversOncePerDayWhenEnabled() async {
        let suite = "MuskometerTests-day-close-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let deliverer = MockDeliverer()
        let service = DayCloseSummaryNotificationService(defaults: defaults, deliverer: deliverer)
        let finalized = DailyRecordTracker.FinalizedTradingDay(
            dayKey: "2026-06-30",
            closeGain: 1_000_000_000,
            peak: 2_000_000_000,
            trough: -500_000_000,
            date: Date()
        )

        let disabled = await service.deliverIfNeeded(finalized: finalized, personID: "musk", possessiveName: "Elon's", enabled: false)
        XCTAssertEqual(disabled, .skipped)
        XCTAssertTrue(deliverer.requests.isEmpty)

        let delivered = await service.deliverIfNeeded(finalized: finalized, personID: "musk", possessiveName: "Elon's", enabled: true)
        XCTAssertEqual(delivered, .delivered)
        XCTAssertEqual(deliverer.requests.count, 1)
        XCTAssertEqual(deliverer.requests.first?.content.categoryIdentifier, NotificationAuthorization.dayCloseCategoryID)

        let duplicate = await service.deliverIfNeeded(finalized: finalized, personID: "musk", possessiveName: "Elon's", enabled: true)
        XCTAssertEqual(duplicate, .skipped)
        XCTAssertEqual(deliverer.requests.count, 1)
    }

    func testKeepsPendingRetryWhenDeliveryFailsThenSucceeds() async {
        final class FailingThenSucceedingDeliverer: DayCloseSummaryNotificationDelivering, @unchecked Sendable {
            private(set) var attempts = 0
            private(set) var requests: [UNNotificationRequest] = []

            func add(_ request: UNNotificationRequest) async throws {
                attempts += 1
                if attempts == 1 {
                    throw URLError(.notConnectedToInternet)
                }
                requests.append(request)
            }
        }

        let suite = "MuskometerTests-day-close-fail-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let deliverer = FailingThenSucceedingDeliverer()
        let service = DayCloseSummaryNotificationService(defaults: defaults, deliverer: deliverer)
        let finalized = DailyRecordTracker.FinalizedTradingDay(
            dayKey: "2026-06-30",
            closeGain: 1_000_000_000,
            peak: 2_000_000_000,
            trough: -500_000_000,
            date: Date()
        )

        let failed = await service.deliverIfNeeded(
            finalized: finalized,
            personID: "musk",
            possessiveName: "Elon's",
            enabled: true
        )
        XCTAssertEqual(failed, .failed)
        XCTAssertEqual(deliverer.attempts, 1)
        XCTAssertTrue(deliverer.requests.isEmpty)

        let retried = await service.deliverIfNeeded(
            finalized: finalized,
            personID: "musk",
            possessiveName: "Elon's",
            enabled: true
        )
        XCTAssertEqual(retried, .delivered)
        XCTAssertEqual(deliverer.attempts, 2)
        XCTAssertEqual(deliverer.requests.count, 1)
    }

    func testConcurrentDeliverIfNeededPostsOnlyOnce() async {
        final class SuspendingDeliverer: DayCloseSummaryNotificationDelivering, @unchecked Sendable {
            private let lock = NSLock()
            private var addCount = 0
            private var resumeContinuation: CheckedContinuation<Void, Never>?
            private var enteredContinuation: CheckedContinuation<Void, Never>?

            var currentAddCount: Int {
                lock.lock()
                defer { lock.unlock() }
                return addCount
            }

            func waitUntilAddEntered() async {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    lock.lock()
                    if addCount > 0 {
                        lock.unlock()
                        continuation.resume()
                    } else {
                        enteredContinuation = continuation
                        lock.unlock()
                    }
                }
            }

            func resumeAdd() {
                lock.lock()
                let cont = resumeContinuation
                resumeContinuation = nil
                lock.unlock()
                cont?.resume()
            }

            func add(_ request: UNNotificationRequest) async throws {
                // Store resume continuation before signaling entry so resumeAdd cannot race ahead.
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    lock.lock()
                    addCount += 1
                    resumeContinuation = continuation
                    let entered = enteredContinuation
                    enteredContinuation = nil
                    lock.unlock()
                    entered?.resume()
                }
            }
        }

        let suite = "MuskometerTests-day-close-reentrant-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let deliverer = SuspendingDeliverer()
        let service = DayCloseSummaryNotificationService(defaults: defaults, deliverer: deliverer)
        let finalized = DailyRecordTracker.FinalizedTradingDay(
            dayKey: "2026-06-30",
            closeGain: 1_000_000_000,
            peak: 2_000_000_000,
            trough: -500_000_000,
            date: Date()
        )

        async let first = service.deliverIfNeeded(
            finalized: finalized,
            personID: "musk",
            possessiveName: "Elon's",
            enabled: true
        )
        await deliverer.waitUntilAddEntered()

        let second = await service.deliverIfNeeded(
            finalized: finalized,
            personID: "musk",
            possessiveName: "Elon's",
            enabled: true
        )
        XCTAssertEqual(second, .inFlight)
        XCTAssertEqual(deliverer.currentAddCount, 1)

        deliverer.resumeAdd()
        let firstOutcome = await first
        XCTAssertEqual(firstOutcome, .delivered)
        XCTAssertEqual(deliverer.currentAddCount, 1)
    }
}

/// Gates only selected delivery attempts; all others finish immediately so a duplicate
/// submission is an assertion failure, rather than a test deadlock.
private actor NotificationDeliveryGate: GainThresholdNotificationDelivering, DayCloseSummaryNotificationDelivering {
    private let heldAttempts: Set<Int>
    private var continuations: [Int: CheckedContinuation<Void, Error>] = [:]
    private var entryWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private(set) var requests: [UNNotificationRequest] = []

    init(holding attempts: Set<Int> = [0]) { heldAttempts = attempts }

    func add(_ request: UNNotificationRequest) async throws {
        let index = requests.count
        requests.append(request)
        if heldAttempts.contains(index) {
            try await withCheckedThrowingContinuation { continuation in
                continuations[index] = continuation
                signalEntry()
            }
        } else {
            signalEntry()
        }
    }

    private func signalEntry() {
        let ready = entryWaiters.filter { requests.count >= $0.0 }
        entryWaiters.removeAll { requests.count >= $0.0 }
        for (_, continuation) in ready { continuation.resume() }
    }

    func waitForFirstEntry() async {
        if !requests.isEmpty { return }
        await withCheckedContinuation { entryWaiters.append((1, $0)) }
    }

    func waitForEntries(_ count: Int) async -> Bool {
        // A missing replacement claim must fail within a bound, not hang the red run.
        for _ in 0..<200 {
            if requests.count >= count { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }

    func release(_ index: Int = 0, failing: Bool = false) {
        let continuation = continuations.removeValue(forKey: index)
        if failing { continuation?.resume(throwing: URLError(.notConnectedToInternet)) }
        else { continuation?.resume() }
    }
}

@MainActor
final class NotificationSuspensionRegressionTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let suite = "MuskometerTests-notification-suspension-\(UUID().uuidString)"
        let result = UserDefaults(suiteName: suite)!
        result.removePersistentDomain(forName: suite)
        addTeardownBlock { result.removePersistentDomain(forName: suite) }
        return result
    }

    private func date(day: Int = 30, hour: Int = 11, minute: Int = 0) throws -> Date {
        try EasternTestDates.date(year: 2026, month: 6, day: day, hour: hour, minute: minute)
    }

    private func gainService(_ gate: NotificationDeliveryGate, defaults: UserDefaults? = nil,
                             thresholds: Set<String> = ["gain-10b"]) -> GainThresholdNotificationService {
        let service = GainThresholdNotificationService(defaults: defaults ?? self.defaults(), deliverer: gate)
        service.setEnabledThresholdIDs(thresholds, for: "musk")
        return service
    }

    @discardableResult
    private func sample(_ service: GainThresholdNotificationService, _ billions: Double,
                        at date: Date) async -> [GainThresholdNotificationService.CrossingEvent] {
        await service.processUpdate(paperGain: billions * 1_000_000_000, personID: "musk",
                                    possessiveName: "Elon's", at: date, isQuotable: true)
    }

    private func finalized(dayKey: String = "2026-06-30", at date: Date) -> DailyRecordTracker.FinalizedTradingDay {
        .init(dayKey: dayKey, closeGain: 3_000_000_000, peak: 4_000_000_000,
              trough: -1_000_000_000, date: date)
    }

    func testOlderSuccessCannotEraseBelowThresholdRearm() async throws {
        let gate = NotificationDeliveryGate()
        let service = gainService(gate)
        let now = try date()
        await sample(service, 9, at: now)
        let first = Task { await self.sample(service, 11, at: now.addingTimeInterval(1)) }
        await gate.waitForFirstEntry()
        await sample(service, 8, at: now.addingTimeInterval(2))
        await gate.release()
        let firstEvents = await first.value
        let secondEvents = await sample(service, 12, at: now.addingTimeInterval(3))
        let count = await gate.requests.count
        XCTAssertEqual(firstEvents.count, 1)
        XCTAssertEqual(secondEvents.count, 1, "9→11(await)→8→complete11→12 must retain the second crossing")
        XCTAssertEqual(count, 2)
    }

    func testOverlappingAboveObservationsReserveOneCrossing() async throws {
        let gate = NotificationDeliveryGate()
        let service = gainService(gate)
        let now = try date()
        await sample(service, 9, at: now)
        let first = Task { await self.sample(service, 11, at: now.addingTimeInterval(1)) }
        await gate.waitForFirstEntry()
        let overlap = await sample(service, 12, at: now.addingTimeInterval(2))
        let count = await gate.requests.count
        XCTAssertTrue(overlap.isEmpty, "An in-flight crossing must already be reserved")
        XCTAssertEqual(count, 1)
        await gate.release()
        _ = await first.value
    }

    func testEveryPresetObservationAndClaimIsCommittedBeforeFirstAwait() async throws {
        let gate = NotificationDeliveryGate()
        let service = gainService(gate, thresholds: ["gain-5b", "gain-10b", "gain-20b"])
        let now = try date()
        await sample(service, 4, at: now)
        let first = Task { await self.sample(service, 21, at: now.addingTimeInterval(1)) }
        await gate.waitForFirstEntry()
        let overlap = await sample(service, 22, at: now.addingTimeInterval(2))
        let during = await gate.requests.count
        XCTAssertTrue(overlap.isEmpty, "Later presets must be reserved even while the first delivery waits")
        XCTAssertEqual(during, 1)
        await gate.release()
        let firstEvents = await first.value
        XCTAssertEqual(Set(firstEvents.map(\.threshold.id)), ["gain-5b", "gain-10b", "gain-20b"])
        let requests = await gate.requests
        XCTAssertEqual(requests.count, 3)
        XCTAssertTrue(requests.allSatisfy { $0.content.body.contains("21") }, "Each claim retains its observed gain")
    }

    func testMultiPresetOlderSuccessCannotEraseNewerBelowObservations() async throws {
        let gate = NotificationDeliveryGate()
        let service = gainService(gate, thresholds: ["gain-5b", "gain-10b", "gain-20b"])
        let now = try date()
        await sample(service, 4, at: now)
        let first = Task { await self.sample(service, 21, at: now.addingTimeInterval(1)) }
        await gate.waitForFirstEntry()
        await sample(service, 3, at: now.addingTimeInterval(2))
        await gate.release()
        _ = await first.value
        let recross = await sample(service, 22, at: now.addingTimeInterval(3))
        XCTAssertEqual(Set(recross.map(\.threshold.id)), ["gain-5b", "gain-10b", "gain-20b"])
        let count = await gate.requests.count
        XCTAssertEqual(count, 6)
    }

    func testFailureAfterNewerAboveObservationRemainsRetryable() async throws {
        let gate = NotificationDeliveryGate()
        let service = gainService(gate)
        let now = try date()
        await sample(service, 9, at: now)
        let first = Task { await self.sample(service, 11, at: now.addingTimeInterval(1)) }
        await gate.waitForFirstEntry()
        let overlap = await sample(service, 12, at: now.addingTimeInterval(2))
        XCTAssertTrue(overlap.isEmpty)
        await gate.release(failing: true)
        let failed = await first.value
        let retry = await sample(service, 13, at: now.addingTimeInterval(3))
        let count = await gate.requests.count
        XCTAssertTrue(failed.isEmpty)
        XCTAssertEqual(retry.count, 1)
        XCTAssertEqual(retry.first?.paperGain, 13_000_000_000)
        XCTAssertEqual(count, 2)
    }

    func testFailureCannotUndoNewerRecrossSuccess() async throws {
        let gate = NotificationDeliveryGate()
        let service = gainService(gate)
        let now = try date()
        await sample(service, 9, at: now)
        let first = Task { await self.sample(service, 11, at: now.addingTimeInterval(1)) }
        await gate.waitForFirstEntry()
        await sample(service, 8, at: now.addingTimeInterval(2))
        let recross = await sample(service, 12, at: now.addingTimeInterval(3))
        XCTAssertEqual(recross.count, 1)
        await gate.release(failing: true)
        _ = await first.value
        let above = await sample(service, 13, at: now.addingTimeInterval(4))
        XCTAssertTrue(above.isEmpty, "Old failure must not retry a newer delivered crossing")
        let count = await gate.requests.count
        XCTAssertEqual(count, 2)
    }

    func testFailureAfterBelowObservationKeepsDistinctRecross() async throws {
        let gate = NotificationDeliveryGate()
        let service = gainService(gate)
        let now = try date()
        await sample(service, 9, at: now)
        let first = Task { await self.sample(service, 11, at: now.addingTimeInterval(1)) }
        await gate.waitForFirstEntry()
        await sample(service, 8, at: now.addingTimeInterval(2))
        await gate.release(failing: true)
        _ = await first.value
        let recross = await sample(service, 12, at: now.addingTimeInterval(3))
        XCTAssertEqual(recross.count, 1)
        let count = await gate.requests.count
        XCTAssertEqual(count, 2)
    }

    func testGainResetInvalidatesOldSuccessWithoutErasingNewObservation() async throws {
        let gate = NotificationDeliveryGate()
        let store = defaults()
        let service = gainService(gate, defaults: store)
        let now = try date()
        await sample(service, 9, at: now)
        let first = Task { await self.sample(service, 11, at: now.addingTimeInterval(1)) }
        await gate.waitForFirstEntry()
        GainThresholdNotificationService.resetPersistedState(for: "musk", defaults: store)
        service.resetRuntimeState(for: "musk")
        service.setEnabledThresholdIDs(["gain-10b"], for: "musk")
        await sample(service, 8, at: now.addingTimeInterval(2))
        await gate.release()
        let stale = await first.value
        let recross = await sample(service, 12, at: now.addingTimeInterval(3))
        XCTAssertTrue(stale.isEmpty, "Invalidated completions cannot report a current event")
        XCTAssertEqual(recross.count, 1)
    }

    func testGainRolloverInvalidatesOldSuccess() async throws {
        let gate = NotificationDeliveryGate()
        let service = gainService(gate)
        let now = try date()
        let tomorrow = now.addingTimeInterval(86_400)
        await sample(service, 9, at: now)
        let first = Task { await self.sample(service, 11, at: now.addingTimeInterval(1)) }
        await gate.waitForFirstEntry()
        await sample(service, 8, at: tomorrow)
        await gate.release()
        let stale = await first.value
        let recross = await sample(service, 12, at: tomorrow.addingTimeInterval(1))
        XCTAssertTrue(stale.isEmpty)
        XCTAssertEqual(recross.count, 1)
        XCTAssertEqual(recross.first?.tradingDayKey, "2026-07-01")
    }

    func testCancelledGainDeliveryCanRetryAfterRuntimeRestart() async throws {
        let gate = NotificationDeliveryGate()
        let service = gainService(gate)
        let now = try date()
        await sample(service, 9, at: now)
        let first = Task { await self.sample(service, 11, at: now.addingTimeInterval(1)) }
        await gate.waitForFirstEntry()
        first.cancel()
        service.resetRuntimeState(for: "musk")
        let retry = await sample(service, 12, at: now.addingTimeInterval(2))
        await gate.release()
        let stale = await first.value
        XCTAssertEqual(retry.count, 1, "Unconfirmed persisted crossing remains retryable after restart")
        XCTAssertTrue(stale.isEmpty)
        let above = await sample(service, 13, at: now.addingTimeInterval(3))
        XCTAssertTrue(above.isEmpty)
    }

    func testLegacyThresholdStateDecodesAndRearmsNormally() async throws {
        let gate = NotificationDeliveryGate(holding: [])
        let store = defaults()
        store.set(Data(#"{"armed":true,"lastGain":9000000000,"tradingDayKey":"2026-06-30"}"#.utf8),
                  forKey: "gainNotificationThresholdState_musk-gain-10b")
        let service = gainService(gate, defaults: store)
        let events = await sample(service, 11, at: try date())
        XCTAssertEqual(events.count, 1)
    }

    func testDayCloseInFlightFailureRetainsDurablePendingDay() async throws {
        let gate = NotificationDeliveryGate()
        let store = defaults()
        let tracker = DailyRecordTracker(defaults: store)
        let day = finalized(at: try date())
        tracker.restorePendingFinalizedDay(day, for: "musk")
        let service = DayCloseSummaryNotificationService(defaults: store, deliverer: gate)
        let first = Task { await service.deliverIfNeeded(finalized: day, personID: "musk", possessiveName: "Elon's", enabled: true) }
        await gate.waitForFirstEntry()
        let overlap = await service.deliverIfNeeded(finalized: day, personID: "musk", possessiveName: "Elon's", enabled: true)
        XCTAssertEqual(overlap, .inFlight)
        if overlap == .delivered || overlap == .skipped {
            tracker.consumePendingFinalizedDay(for: "musk", matching: day)
        }
        await gate.release(failing: true)
        let failure = await first.value
        XCTAssertEqual(failure, .failed)
        XCTAssertNil(store.string(forKey: "dayCloseSummaryNotifiedDay_musk"))
        let reloaded = DailyRecordTracker(defaults: store)
        XCTAssertEqual(reloaded.peekPendingFinalizedDay(for: "musk"), day)
        let retry = await service.deliverIfNeeded(finalized: day, personID: "musk", possessiveName: "Elon's", enabled: true)
        XCTAssertEqual(retry, .delivered)
        let count = await gate.requests.count
        XCTAssertEqual(count, 2)
    }

    func testDayCloseResetInvalidatesSuspendedSuccessWithoutDeletingPending() async throws {
        let gate = NotificationDeliveryGate()
        let store = defaults()
        let tracker = DailyRecordTracker(defaults: store)
        let day = finalized(at: try date())
        tracker.restorePendingFinalizedDay(day, for: "musk")
        let service = DayCloseSummaryNotificationService(defaults: store, deliverer: gate)
        let first = Task { await service.deliverIfNeeded(finalized: day, personID: "musk", possessiveName: "Elon's", enabled: true) }
        await gate.waitForFirstEntry()
        service.resetRuntimeState(for: "musk")
        await gate.release()
        let stale = await first.value
        XCTAssertEqual(stale, .failed)
        XCTAssertNil(store.string(forKey: "dayCloseSummaryNotifiedDay_musk"))
        XCTAssertEqual(tracker.peekPendingFinalizedDay(for: "musk"), day)
        let retry = await service.deliverIfNeeded(finalized: day, personID: "musk", possessiveName: "Elon's", enabled: true)
        XCTAssertEqual(retry, .delivered)
    }

    func testCancelledDayCloseCannotConfirmAfterRestart() async throws {
        let gate = NotificationDeliveryGate()
        let store = defaults()
        let day = finalized(at: try date())
        let service = DayCloseSummaryNotificationService(defaults: store, deliverer: gate)
        let first = Task { await service.deliverIfNeeded(finalized: day, personID: "musk", possessiveName: "Elon's", enabled: true) }
        await gate.waitForFirstEntry()
        first.cancel()
        service.resetRuntimeState(for: "musk")
        let retry = await service.deliverIfNeeded(finalized: day, personID: "musk", possessiveName: "Elon's", enabled: true)
        XCTAssertEqual(retry, .delivered)
        await gate.release()
        let stale = await first.value
        XCTAssertEqual(stale, .failed)
        XCTAssertEqual(store.string(forKey: "dayCloseSummaryNotifiedDay_musk"), day.dayKey)
    }

    func testDayCloseCancellationWithoutResetDoesNotPersistSuccess() async throws {
        let gate = NotificationDeliveryGate()
        let store = defaults()
        let day = finalized(at: try date())
        let service = DayCloseSummaryNotificationService(defaults: store, deliverer: gate)
        let first = Task { await service.deliverIfNeeded(finalized: day, personID: "musk", possessiveName: "Elon's", enabled: true) }
        await gate.waitForFirstEntry()
        first.cancel()
        await gate.release()
        let stale = await first.value
        XCTAssertEqual(stale, .failed)
        XCTAssertNil(store.string(forKey: "dayCloseSummaryNotifiedDay_musk"))
        let retry = await service.deliverIfNeeded(finalized: day, personID: "musk", possessiveName: "Elon's", enabled: true)
        XCTAssertEqual(retry, .delivered)
    }

    func testOlderDifferentDayCompletionCannotRegressNotifiedDayOrConsumeNewPending() async throws {
        let gate = NotificationDeliveryGate()
        let store = defaults()
        let tracker = DailyRecordTracker(defaults: store)
        let old = finalized(at: try date())
        let newer = finalized(dayKey: "2026-07-01", at: try date().addingTimeInterval(86_400))
        tracker.restorePendingFinalizedDay(old, for: "musk")
        let service = DayCloseSummaryNotificationService(defaults: store, deliverer: gate)
        let first = Task { await service.deliverIfNeeded(finalized: old, personID: "musk", possessiveName: "Elon's", enabled: true) }
        await gate.waitForFirstEntry()
        tracker.restorePendingFinalizedDay(newer, for: "musk")
        let delivered = await service.deliverIfNeeded(finalized: newer, personID: "musk", possessiveName: "Elon's", enabled: true)
        XCTAssertEqual(delivered, .delivered)
        await gate.release()
        _ = await first.value
        XCTAssertEqual(store.string(forKey: "dayCloseSummaryNotifiedDay_musk"), newer.dayKey)
        XCTAssertNil(tracker.consumePendingFinalizedDay(for: "musk", matching: old))
        XCTAssertEqual(tracker.peekPendingFinalizedDay(for: "musk"), newer)
        let duplicate = await service.deliverIfNeeded(finalized: newer, personID: "musk", possessiveName: "Elon's", enabled: true)
        XCTAssertEqual(duplicate, .skipped)
    }

    func testDayCloseContentUsesLastObservedSessionAndSampleTime() async throws {
        let gate = NotificationDeliveryGate(holding: [])
        let service = DayCloseSummaryNotificationService(defaults: defaults(), deliverer: gate)
        let day = finalized(at: try date(hour: 15, minute: 42))
        let result = await service.deliverIfNeeded(finalized: day, personID: "musk", possessiveName: "Elon's", enabled: true)
        XCTAssertEqual(result, .delivered)
        let requests = await gate.requests
        let body = try XCTUnwrap(requests.first?.content.body)
        XCTAssertTrue(body.contains("Last observed session"), body)
        XCTAssertTrue(body.contains("3:42 PM"), "Must report the actual last sample time: \(body)")
        XCTAssertTrue(body.contains("EDT"), body)
        XCTAssertTrue(body.contains("Jun 30, 2026"), body)
    }

    func testIdentityConsumeRequiresExactFinalizedValueAndPersistsClear() throws {
        let store = defaults()
        let tracker = DailyRecordTracker(defaults: store)
        let day = finalized(at: try date())
        tracker.restorePendingFinalizedDay(day, for: "musk")
        let mismatched = finalized(at: try date(hour: 12))
        XCTAssertNil(tracker.consumePendingFinalizedDay(for: "musk", matching: mismatched))
        XCTAssertEqual(tracker.peekPendingFinalizedDay(for: "musk"), day)
        XCTAssertEqual(tracker.consumePendingFinalizedDay(for: "musk", matching: day), day)
        XCTAssertNil(DailyRecordTracker(defaults: store).peekPendingFinalizedDay(for: "musk"))
    }

    func testAdvanceClockFinalizesCloseWithoutAddingSample() throws {
        let tracker = DailyRecordTracker(defaults: defaults())
        let lastSample = try date(hour: 15, minute: 42)
        tracker.update(personID: "musk", paperGain: 7, at: try date(), isQuotable: true)
        tracker.update(personID: "musk", paperGain: -3, at: lastSample, isQuotable: true)
        let before = tracker.advanceClock(personID: "musk", at: try date(hour: 15, minute: 59))
        XCTAssertFalse(before.hasCompletedFirstTradingDay)
        let closed = tracker.advanceClock(personID: "musk", at: try date(hour: 16))
        XCTAssertTrue(closed.hasCompletedFirstTradingDay)
        XCTAssertEqual(closed.bestRecord?.amount, 7)
        XCTAssertEqual(closed.worstRecord?.amount, -3)
        let day = tracker.peekPendingFinalizedDay(for: "musk")
        XCTAssertEqual(day?.closeGain, -3)
        XCTAssertEqual(day?.date, lastSample)
        _ = tracker.advanceClock(personID: "musk", at: try date(hour: 20))
        XCTAssertEqual(tracker.peekPendingFinalizedDay(for: "musk"), day)
    }

    func testAdvanceClockRespectsEarlyClose() throws {
        let tracker = DailyRecordTracker(defaults: defaults())
        let sampleTime = try EasternTestDates.date(year: 2026, month: 11, day: 27, hour: 12, minute: 44)
        tracker.update(personID: "musk", paperGain: 7, at: sampleTime, isQuotable: true)
        let before = tracker.advanceClock(personID: "musk", at: sampleTime.addingTimeInterval(15 * 60))
        XCTAssertFalse(before.hasCompletedFirstTradingDay)
        let closed = tracker.advanceClock(personID: "musk", at: sampleTime.addingTimeInterval(16 * 60))
        XCTAssertTrue(closed.hasCompletedFirstTradingDay)
        XCTAssertEqual(tracker.peekPendingFinalizedDay(for: "musk")?.date, sampleTime)
    }

    func testAdvanceClockRelaunchLoadsRealUnfinishedDayAtCloseAndNextOpen() throws {
        for nextDay in [false, true] {
            let store = defaults()
            let sampleTime = try date(hour: 15, minute: 42)
            DailyRecordTracker(defaults: store).update(personID: "musk", paperGain: 7, at: sampleTime, isQuotable: true)
            let reloaded = DailyRecordTracker(defaults: store)
            let clock = nextDay ? try date().addingTimeInterval(86_400) : try date(hour: 16)
            let result = reloaded.advanceClock(personID: "musk", at: clock)
            XCTAssertTrue(result.hasCompletedFirstTradingDay, "nextDay=\(nextDay)")
            XCTAssertEqual(result.bestRecord?.amount, 7)
            XCTAssertEqual(reloaded.peekPendingFinalizedDay(for: "musk")?.date, sampleTime)
            if let day = reloaded.peekPendingFinalizedDay(for: "musk") {
                reloaded.consumePendingFinalizedDay(for: "musk", matching: day)
            }
            _ = reloaded.advanceClock(personID: "musk", at: clock.addingTimeInterval(5 * 3_600))
            XCTAssertNil(reloaded.peekPendingFinalizedDay(for: "musk"), "No invented next-day sample")
        }
    }

    func testAdvanceClockWithoutAnyQuoteCreatesNoDay() throws {
        let store = defaults()
        let tracker = DailyRecordTracker(defaults: store)
        let result = tracker.advanceClock(personID: "musk", at: try date(hour: 16))
        XCTAssertFalse(result.hasCompletedFirstTradingDay)
        XCTAssertNil(tracker.peekPendingFinalizedDay(for: "musk"))
        XCTAssertNil(store.data(forKey: "dailyRecordUnfinished_musk"))
    }

    func testBackwardClockAndSampleCannotRegressCurrentTradingDay() throws {
        let store = defaults()
        let tracker = DailyRecordTracker(defaults: store)
        let current = try date()
        tracker.update(personID: "musk", paperGain: 7, at: current, isQuotable: true)
        _ = tracker.advanceClock(personID: "musk", at: current.addingTimeInterval(-86_400))
        tracker.update(personID: "musk", paperGain: 999, at: current.addingTimeInterval(-86_400), isQuotable: true)
        XCTAssertNil(tracker.peekPendingFinalizedDay(for: "musk"), "Backward dates cannot prematurely finalize today")
        let result = tracker.advanceClock(personID: "musk", at: try date(hour: 16))
        XCTAssertEqual(result.bestRecord?.amount, 7)
        XCTAssertEqual(result.worstRecord?.amount, 7)
        XCTAssertEqual(tracker.peekPendingFinalizedDay(for: "musk")?.dayKey, "2026-06-30")
        XCTAssertEqual(tracker.peekPendingFinalizedDay(for: "musk")?.date, current)
    }
}


extension NotificationSuspensionRegressionTests {
    func testOldDayCloseSuccessCannotRemoveRestartedSameDayClaim() async throws {
        try await checkReplacementDayCloseClaim(oldFails: false)
    }

    func testOldDayCloseFailureCannotRemoveRestartedSameDayClaim() async throws {
        try await checkReplacementDayCloseClaim(oldFails: true)
    }

    private func checkReplacementDayCloseClaim(oldFails: Bool) async throws {
        let gate = NotificationDeliveryGate(holding: [0, 1])
        let store = defaults()
        let day = finalized(at: try date())
        let service = DayCloseSummaryNotificationService(defaults: store, deliverer: gate)
        let first = Task { await service.deliverIfNeeded(finalized: day, personID: "musk", possessiveName: "Elon's", enabled: true) }
        await gate.waitForFirstEntry()
        first.cancel()
        service.resetRuntimeState(for: "musk")
        let replacement = Task { await service.deliverIfNeeded(finalized: day, personID: "musk", possessiveName: "Elon's", enabled: true) }
        let entered = await gate.waitForEntries(2)
        XCTAssertTrue(entered, "Reset must allow a replacement claim while the canceled attempt is suspended")
        guard entered else {
            await gate.release(failing: oldFails)
            _ = await first.value
            _ = await replacement.value
            return
        }
        await gate.release(failing: oldFails)
        let stale = await first.value
        XCTAssertEqual(stale, .failed)
        XCTAssertNil(store.string(forKey: "dayCloseSummaryNotifiedDay_musk"))
        let duplicate = await service.deliverIfNeeded(finalized: day, personID: "musk", possessiveName: "Elon's", enabled: true)
        XCTAssertEqual(duplicate, .inFlight, "Old completion cannot remove the replacement claim")
        let count = await gate.requests.count
        XCTAssertEqual(count, 2)
        await gate.release(1)
        let replaced = await replacement.value
        XCTAssertEqual(replaced, .delivered)
        XCTAssertEqual(store.string(forKey: "dayCloseSummaryNotifiedDay_musk"), day.dayKey)
    }

    func testOlderDayCompletingFirstPreservesNewerInFlightClaim() async throws {
        let gate = NotificationDeliveryGate(holding: [0, 1])
        let store = defaults()
        let old = finalized(at: try date())
        let newer = finalized(dayKey: "2026-07-01", at: try date().addingTimeInterval(86_400))
        let service = DayCloseSummaryNotificationService(defaults: store, deliverer: gate)
        let first = Task { await service.deliverIfNeeded(finalized: old, personID: "musk", possessiveName: "Elon's", enabled: true) }
        await gate.waitForFirstEntry()
        let second = Task { await service.deliverIfNeeded(finalized: newer, personID: "musk", possessiveName: "Elon's", enabled: true) }
        let entered = await gate.waitForEntries(2)
        XCTAssertTrue(entered)
        await gate.release()
        _ = await first.value
        XCTAssertEqual(store.string(forKey: "dayCloseSummaryNotifiedDay_musk"), old.dayKey)
        if entered {
            let duplicate = await service.deliverIfNeeded(finalized: newer, personID: "musk", possessiveName: "Elon's", enabled: true)
            XCTAssertEqual(duplicate, .inFlight)
        }
        await gate.release(1)
        let secondResult = await second.value
        XCTAssertEqual(secondResult, .delivered)
        XCTAssertEqual(store.string(forKey: "dayCloseSummaryNotifiedDay_musk"), newer.dayKey)
    }

    func testOldThresholdFailureCannotClearNewerSuspendedCrossingClaim() async throws {
        let gate = NotificationDeliveryGate(holding: [0, 1])
        let service = gainService(gate)
        let now = try date()
        await sample(service, 9, at: now)
        let first = Task { await self.sample(service, 11, at: now.addingTimeInterval(1)) }
        await gate.waitForFirstEntry()
        await sample(service, 8, at: now.addingTimeInterval(2))
        let second = Task { await self.sample(service, 12, at: now.addingTimeInterval(3)) }
        let entered = await gate.waitForEntries(2)
        XCTAssertTrue(entered)
        await gate.release(failing: true)
        _ = await first.value
        let duplicate = await sample(service, 13, at: now.addingTimeInterval(4))
        XCTAssertTrue(duplicate.isEmpty, "Older failure cannot clear a newer crossing claim")
        let count = await gate.requests.count
        XCTAssertEqual(count, 2)
        await gate.release(1)
        let delivered = await second.value
        XCTAssertEqual(delivered.count, 1)
    }

    func testAllGainAndLossPresetsCommitBeforeDeliveryAndRetainRearm() async throws {
        for direction in [1.0, -1.0] {
            let gate = NotificationDeliveryGate()
            let ids = Set(GainNotificationThreshold.presets.map(\.id))
            let service = gainService(gate, thresholds: ids)
            let now = try date()
            await sample(service, 0, at: now)
            let first = Task { await self.sample(service, 51 * direction, at: now.addingTimeInterval(1)) }
            await gate.waitForFirstEntry()
            let overlap = await sample(service, 52 * direction, at: now.addingTimeInterval(2))
            XCTAssertTrue(overlap.isEmpty)
            await sample(service, 0, at: now.addingTimeInterval(3))
            await gate.release()
            let firstEvents = await first.value
            XCTAssertEqual(firstEvents.count, 4)
            let recross = await sample(service, 53 * direction, at: now.addingTimeInterval(4))
            XCTAssertEqual(recross.count, 4)
            let count = await gate.requests.count
            XCTAssertEqual(count, 8, "Every enabled preset has exactly two distinct crossings")
        }
    }

    func testCanceledMultiPresetDeliveryLeavesEveryUnconfirmedCrossingRetryable() async throws {
        let gate = NotificationDeliveryGate()
        let service = gainService(gate, thresholds: ["gain-5b", "gain-10b", "gain-20b", "gain-50b"])
        let now = try date()
        await sample(service, 0, at: now)
        let first = Task { await self.sample(service, 51, at: now.addingTimeInterval(1)) }
        await gate.waitForFirstEntry()
        first.cancel()
        await gate.release()
        let canceled = await first.value
        XCTAssertTrue(canceled.isEmpty)
        let countAfterCancellation = await gate.requests.count
        XCTAssertEqual(countAfterCancellation, 1, "Cancellation prevents remaining queued preset sends")
        let retry = await sample(service, 52, at: now.addingTimeInterval(2))
        XCTAssertEqual(retry.count, 4)
        let count = await gate.requests.count
        XCTAssertEqual(count, 5)
    }
}

extension NotificationSuspensionRegressionTests {
    func testClosedMarketDayRolloverInvalidatesSuspendedThresholdDelivery() async throws {
        let gate = NotificationDeliveryGate()
        let store = defaults()
        let service = gainService(gate, defaults: store)
        let now = try date()
        await sample(service, 9, at: now)
        let first = Task { await self.sample(service, 11, at: now.addingTimeInterval(1)) }
        await gate.waitForFirstEntry()
        let tomorrow = try EasternTestDates.date(year: 2026, month: 7, day: 1, hour: 2)
        _ = await service.processUpdate(paperGain: 11_000_000_000, personID: "musk", possessiveName: "Elon's", at: tomorrow, isQuotable: false)
        await gate.release()
        let stale = await first.value
        XCTAssertTrue(stale.isEmpty, "A closed-market day change must invalidate yesterday's delivery lifecycle")
        let opening = try EasternTestDates.date(year: 2026, month: 7, day: 1, hour: 10)
        let initial = await sample(service, 12, at: opening)
        XCTAssertTrue(initial.isEmpty, "Clock advancement cannot invent a threshold crossing")
        await sample(service, 8, at: opening.addingTimeInterval(1))
        let recross = await sample(service, 13, at: opening.addingTimeInterval(2))
        XCTAssertEqual(recross.count, 1)
    }
}

@MainActor
final class BoundedThresholdObservationTests: XCTestCase {
    private func makeService(_ gate: NotificationDeliveryGate, ids: Set<String> = ["gain-10b"]) -> (GainThresholdNotificationService, UserDefaults) {
        let defaults = UserDefaults(suiteName: "BoundedThreshold-\(UUID().uuidString)")!
        let service = GainThresholdNotificationService(defaults: defaults, deliverer: gate)
        service.setEnabledThresholdIDs(ids, for: "musk")
        return (service, defaults)
    }
    private func observe(_ service: GainThresholdNotificationService, _ billions: Double, day: Int = 30, month: Int = 6, quotable: Bool = true) {
        let now = try! EasternTestDates.date(year: 2026, month: month, day: day, hour: 11)
        service.observeUpdate(paperGain: billions * 1e9, personID: "musk", possessiveName: "Elon's", at: now, isQuotable: quotable)
    }
    private func state(_ defaults: UserDefaults, id: String = "gain-10b") -> [String: Any] {
        let data = defaults.data(forKey: "gainNotificationThresholdState_musk-\(id)") ?? Data()
        return ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
    }
    private func settle(_ predicate: () async -> Bool) async {
        for _ in 0..<10000 { if await predicate() { return }; await Task.yield() }
    }

    func testObservesAllPresetsSynchronouslyBeforeStartingDelivery() async {
        let gate = NotificationDeliveryGate(holding: Set(0..<20))
        let ids = Set(GainNotificationThreshold.presets.map(\.id))
        let (service, defaults) = makeService(gate, ids: ids)
        observe(service, 0)
        observe(service, 60)
        for id in ids { XCTAssertEqual(state(defaults, id: id)["lastGain"] as? Double, 60e9) }
        await settle { await gate.requests.count > 0 }
        let count = await gate.requests.count
        XCTAssertGreaterThan(count, 0)
        service.resetRuntimeState(for: "musk")
        for id in 0..<count { await gate.release(id, failing: true) }
    }

    func testCoalescesRepeatedRecrossingsAndDeliversNewestPendingValue() async {
        let gate = NotificationDeliveryGate(holding: [0, 1])
        let (service, defaults) = makeService(gate)
        observe(service, 9); observe(service, 11)
        await settle { await gate.requests.count == 1 }
        for value in 12...40 { observe(service, 9); observe(service, Double(value)) }
        XCTAssertEqual(state(defaults)["lastGain"] as? Double, 40e9)
        for _ in 0..<100 { await Task.yield() }
        let count = await gate.requests.count
        XCTAssertEqual(count, 1, "Repeated recrossings must not open additional physical deliveries")
        await gate.release(0)
        await settle { await gate.requests.count == 2 }
        let requests = await gate.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests.last?.content.body.contains("40.0B") == true)
        await gate.release(1)
        await settle { self.state(defaults)["retryPending"] as? Bool == false }
        observe(service, 41)
        for _ in 0..<100 { await Task.yield() }
        let finalCount = await gate.requests.count
        XCTAssertEqual(finalCount, 2, "Confirmed newest crossing is not retried by a later above observation")
    }

    func testRepeatedResetKeepsPhysicalSlotUntilOldDeliveryReturns() async {
        let gate = NotificationDeliveryGate(holding: [0, 1])
        let (service, defaults) = makeService(gate)
        observe(service, 9); observe(service, 11)
        await settle { await gate.requests.count == 1 }
        for value in 12...30 {
            service.resetRuntimeState(for: "musk")
            observe(service, 9); observe(service, Double(value))
        }
        for _ in 0..<100 { await Task.yield() }
        let count = await gate.requests.count
        XCTAssertEqual(count, 1)
        XCTAssertEqual(state(defaults)["lastGain"] as? Double, 30e9)
        await gate.release(0)
        await settle { await gate.requests.count == 2 }
        let requests = await gate.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests.last?.content.body.contains("30.0B") == true)
        await gate.release(1)
    }

    func testFailureRetriesOnNextAboveObservationWithoutTightLoop() async {
        let gate = NotificationDeliveryGate(holding: [0, 1])
        let (service, defaults) = makeService(gate)
        observe(service, 9); observe(service, 11)
        await settle { await gate.requests.count == 1 }
        await gate.release(0, failing: true)
        await settle { self.state(defaults)["retryPending"] as? Bool == true }
        for _ in 0..<100 { await Task.yield() }
        let failedCount = await gate.requests.count
        XCTAssertEqual(failedCount, 1)
        observe(service, 12)
        await settle { await gate.requests.count == 2 }
        let retryCount = await gate.requests.count
        XCTAssertEqual(retryCount, 2)
        await gate.release(1)
    }

    func testBelowAndClosedDayRolloverDiscardObsoletePendingCrossing() async {
        let gate = NotificationDeliveryGate(holding: [0, 1])
        let (service, defaults) = makeService(gate)
        observe(service, 9); observe(service, 11)
        await settle { await gate.requests.count == 1 }
        observe(service, 9); observe(service, 12)
        observe(service, 9, day: 1, month: 7, quotable: false)
        await gate.release(0)
        for _ in 0..<100 { await Task.yield() }
        let count = await gate.requests.count
        XCTAssertEqual(count, 1, "Closed-market rollover drops yesterday's pending crossing")
        XCTAssertEqual(state(defaults)["tradingDayKey"] as? String, "2026-07-01")
        observe(service, 12, day: 1, month: 7)
        observe(service, 9, day: 1, month: 7)
        observe(service, 13, day: 1, month: 7)
        await settle { await gate.requests.count == 2 }
        let countAfterRecross = await gate.requests.count
        XCTAssertEqual(countAfterRecross, 2)
        await gate.release(1)
    }
}
