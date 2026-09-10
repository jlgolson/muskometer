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
    enum DeliveryOutcome: Equatable, Sendable {
        /// Confirmed delivery; the caller may acknowledge this specific pending day.
        case delivered
        /// The same day is being submitted. Keep pending work for its completion/retry.
        case inFlight
        /// Disabled, or this day is covered by an equal/newer confirmed summary.
        case skipped
        /// Failed, canceled, or invalidated. Keep pending work for retry.
        case failed
    }

    private let defaults: UserDefaults
    private let deliverer: any DayCloseSummaryNotificationDelivering
    /// In-flight day claims so concurrent `deliverIfNeeded` cannot double-post across `await`.
    private var claimsByPerson: [String: [String: UUID]] = [:]

    init(
        defaults: UserDefaults = .standard,
        deliverer: any DayCloseSummaryNotificationDelivering = SystemDayCloseSummaryNotificationDeliverer()
    ) {
        self.defaults = defaults
        self.deliverer = deliverer
    }

    /// Invalidates outstanding completions without deleting durable notification/record state.
    func resetRuntimeState(for personID: String) {
        claimsByPerson.removeValue(forKey: personID)
    }

    @discardableResult
    func deliverIfNeeded(
        finalized: DailyRecordTracker.FinalizedTradingDay,
        personID: String,
        possessiveName: String,
        enabled: Bool
    ) async -> DeliveryOutcome {
        guard enabled else { return .skipped }
        guard !Task.isCancelled else { return .failed }
        let notifiedKey = Self.lastNotifiedDayKey(personID)
        if let notifiedDay = defaults.string(forKey: notifiedKey), notifiedDay >= finalized.dayKey {
            return .skipped
        }

        guard claimsByPerson[personID]?[finalized.dayKey] == nil else { return .inFlight }
        let claimID = UUID()
        claimsByPerson[personID, default: [:]][finalized.dayKey] = claimID

        let content = UNMutableNotificationContent()
        content.title = "\(possessiveName) day close"
        let close = CurrencyFormatter.formatCurrency(finalized.closeGain)
        let peak = CurrencyFormatter.formatCurrency(finalized.peak)
        let trough = CurrencyFormatter.formatCurrency(finalized.trough)
        let observationFormatter = DateFormatter()
        observationFormatter.locale = Locale(identifier: "en_US_POSIX")
        observationFormatter.timeZone = EasternTimeZone.americaNewYork
        observationFormatter.dateFormat = "MMM d, yyyy 'at' h:mm a z"
        let observationTime = observationFormatter.string(from: finalized.date)
        content.body = "Last observed session paper P&L \(close) (\(observationTime)) · high \(peak) · low \(trough)."
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
            guard releaseClaim(personID: personID, dayKey: finalized.dayKey, id: claimID),
                  !Task.isCancelled else { return .failed }
            // Different days can finish out of order. Keep a monotonic confirmation watermark.
            if (defaults.string(forKey: notifiedKey) ?? "") < finalized.dayKey {
                defaults.set(finalized.dayKey, forKey: notifiedKey)
            }
            return .delivered
        } catch {
            _ = releaseClaim(personID: personID, dayKey: finalized.dayKey, id: claimID)
            return .failed
        }
    }

    private func releaseClaim(personID: String, dayKey: String, id: UUID) -> Bool {
        guard claimsByPerson[personID]?[dayKey] == id else { return false }
        claimsByPerson[personID]?.removeValue(forKey: dayKey)
        if claimsByPerson[personID]?.isEmpty == true {
            claimsByPerson.removeValue(forKey: personID)
        }
        return true
    }

    nonisolated static func resetPersistedState(for personID: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: lastNotifiedDayKey(personID))
    }

    private nonisolated static func lastNotifiedDayKey(_ personID: String) -> String {
        "dayCloseSummaryNotifiedDay_\(personID)"
    }

}
