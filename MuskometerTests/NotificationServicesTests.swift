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
        XCTAssertEqual(second, .skipped)
        XCTAssertEqual(deliverer.currentAddCount, 1)

        deliverer.resumeAdd()
        let firstOutcome = await first
        XCTAssertEqual(firstOutcome, .delivered)
        XCTAssertEqual(deliverer.currentAddCount, 1)
    }
}
