import Foundation
import UserNotifications

protocol DayCloseSummaryNotificationDelivering: Sendable {
    func add(_ request: UNNotificationRequest) async throws
}

struct SystemDayCloseSummaryNotificationDeliverer: DayCloseSummaryNotificationDelivering {
    func add(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }
}

/// Opt-in end-of-day paper gain/loss summary (once per ET trading day).
@MainActor
final class DayCloseSummaryNotificationService {
    private let defaults: UserDefaults
    private let deliverer: any DayCloseSummaryNotificationDelivering

    init(
        defaults: UserDefaults = .standard,
        deliverer: any DayCloseSummaryNotificationDelivering = SystemDayCloseSummaryNotificationDeliverer()
    ) {
        self.defaults = defaults
        self.deliverer = deliverer
    }

    @discardableResult
    func deliverIfNeeded(
        finalized: DailyRecordTracker.FinalizedTradingDay,
        personID: String,
        possessiveName: String,
        enabled: Bool
    ) async -> Bool {
        guard enabled else { return false }
        let notifiedKey = Self.lastNotifiedDayKey(personID)
        guard defaults.string(forKey: notifiedKey) != finalized.dayKey else { return false }

        let content = UNMutableNotificationContent()
        content.title = "\(possessiveName) day close"
        let close = CurrencyFormatter.formatCurrency(finalized.closeGain)
        let peak = CurrencyFormatter.formatCurrency(finalized.peak)
        let trough = CurrencyFormatter.formatCurrency(finalized.trough)
        content.body = "Combined paper P&L \(close) · high \(peak) · low \(trough)."
        content.sound = .default
        content.categoryIdentifier = NotificationAuthorization.dayCloseCategoryID
        content.userInfo = [
            NotificationAuthorization.notificationKindKey: NotificationAuthorization.dayCloseKind
        ]

        let request = UNNotificationRequest(
            identifier: "day-close-\(personID)-\(finalized.dayKey)",
            content: content,
            trigger: nil
        )

        do {
            try await deliverer.add(request)
            defaults.set(finalized.dayKey, forKey: notifiedKey)
            return true
        } catch {
            return false
        }
    }

    nonisolated static func resetPersistedState(for personID: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: lastNotifiedDayKey(personID))
    }

    private nonisolated static func lastNotifiedDayKey(_ personID: String) -> String {
        "dayCloseSummaryNotifiedDay_\(personID)"
    }
}
