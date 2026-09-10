import Foundation
import UserNotifications

protocol GainThresholdNotificationDelivering: Sendable {
    func add(_ request: UNNotificationRequest) async throws
}

struct SystemGainThresholdNotificationDeliverer: GainThresholdNotificationDelivering {
    func add(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }
}

/// Fires local notifications when combined paper gain crosses enabled thresholds.
@MainActor
final class GainThresholdNotificationService {
    struct CrossingEvent: Equatable, Sendable {
        let threshold: GainNotificationThreshold
        let paperGain: Double
        let tradingDayKey: String
    }

    private struct ThresholdState: Equatable {
        var armed: Bool
        var lastGain: Double?
        var tradingDayKey: String?
        // One current crossing per preset; below-threshold samples supersede it.
        var retryPending = false
        var claimID: UUID?
        var lifecycleID = UUID()
    }

    private struct DeliveryClaim {
        let stateKey: String
        let lifecycleID: UUID
        let id: UUID
        let event: CrossingEvent
    }

    private struct PersistedThresholdState: Codable, Equatable {
        var armed: Bool
        var lastGain: Double?
        var tradingDayKey: String?
        // Optional for compatibility with pre-claim persisted state.
        var retryPending: Bool?
    }

    private let defaults: UserDefaults
    private let calendar: TradingDayCalendar
    private let deliverer: any GainThresholdNotificationDelivering

    private var stateByKey: [String: ThresholdState] = [:]

    init(
        defaults: UserDefaults = .standard,
        calendar: TradingDayCalendar = TradingDayCalendar(),
        deliverer: any GainThresholdNotificationDelivering = SystemGainThresholdNotificationDeliverer()
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.deliverer = deliverer
    }

    func enabledThresholdIDs(for personID: String) -> Set<String> {
        let key = Self.enabledThresholdsKey(personID)
        guard let stored = defaults.array(forKey: key) as? [String] else {
            return []
        }
        return Set(stored)
    }

    func setEnabledThresholdIDs(_ ids: Set<String>, for personID: String) {
        defaults.set(Array(ids).sorted(), forKey: Self.enabledThresholdsKey(personID))
    }

    func resetRuntimeState(for personID: String) {
        for threshold in GainNotificationThreshold.presets {
            stateByKey.removeValue(forKey: Self.stateKey(personID: personID, thresholdID: threshold.id))
        }
    }

    @discardableResult
    func processUpdate(
        paperGain: Double,
        personID: String,
        possessiveName: String,
        at date: Date = .now,
        isQuotable: Bool
    ) async -> [CrossingEvent] {
        guard !Task.isCancelled else { return [] }

        let dayKey = calendar.dayKey(for: date)
        // Day advancement invalidates suspended work even when the new observation is closed/stale.
        for threshold in GainNotificationThreshold.presets {
            let key = Self.stateKey(personID: personID, thresholdID: threshold.id)
            guard let state = stateByKey[key],
                  let previousDay = state.tradingDayKey, previousDay < dayKey else { continue }
            let fresh = ThresholdState(armed: true, lastGain: nil, tradingDayKey: dayKey)
            stateByKey[key] = fresh
            saveState(fresh, forKey: key)
        }
        guard isQuotable else { return [] }
        let enabledIDs = enabledThresholdIDs(for: personID)
        var claims: [DeliveryClaim] = []

        // Commit every observation and crossing reservation before any delivery can suspend.
        for threshold in GainNotificationThreshold.presets where enabledIDs.contains(threshold.id) {
            let stateKey = Self.stateKey(personID: personID, thresholdID: threshold.id)
            var state = stateByKey[stateKey] ?? loadState(forKey: stateKey)
            if let previousDay = state.tradingDayKey, previousDay > dayKey { continue }
            if state.tradingDayKey != dayKey {
                state = ThresholdState(armed: true, lastGain: nil, tradingDayKey: dayKey)
            }

            let pastThreshold = isPastThreshold(threshold: threshold, paperGain: paperGain)
            if !pastThreshold {
                state.armed = true
                state.retryPending = false
                state.claimID = nil
            } else if state.lastGain == nil {
                // Starting a session beyond a threshold is not a crossing.
                state.armed = false
            } else if let previousGain = state.lastGain, state.claimID == nil,
                      state.retryPending || (state.armed && didCross(
                        threshold: threshold, from: previousGain, to: paperGain
                      )) {
                let id = UUID()
                state.claimID = id
                state.armed = false
                // Persist an unconfirmed claim as retryable across cancellation/relaunch.
                state.retryPending = true
                claims.append(DeliveryClaim(
                    stateKey: stateKey,
                    lifecycleID: state.lifecycleID,
                    id: id,
                    event: CrossingEvent(threshold: threshold, paperGain: paperGain, tradingDayKey: dayKey)
                ))
            }
            state.lastGain = paperGain
            stateByKey[stateKey] = state
            saveState(state, forKey: stateKey)
        }

        var fired: [CrossingEvent] = []
        for claim in claims {
            // Reset/rollover invalidates even claims queued behind an earlier preset.
            guard stateByKey[claim.stateKey]?.lifecycleID == claim.lifecycleID else { continue }
            if Task.isCancelled {
                finish(claim, delivered: false)
                continue
            }
            let delivered = await deliverNotification(event: claim.event, possessiveName: possessiveName)
            guard stateByKey[claim.stateKey]?.lifecycleID == claim.lifecycleID else { continue }
            let confirmed = delivered && !Task.isCancelled
            finish(claim, delivered: confirmed)
            if confirmed { fired.append(claim.event) }
        }
        return fired
    }

    private func finish(_ claim: DeliveryClaim, delivered: Bool) {
        guard var state = stateByKey[claim.stateKey],
              state.lifecycleID == claim.lifecycleID,
              state.claimID == claim.id else { return }
        // Never write a captured observation back over a newer sample or rearm/recross.
        state.claimID = nil
        state.retryPending = !delivered
        stateByKey[claim.stateKey] = state
        saveState(state, forKey: claim.stateKey)
    }

    private func loadState(forKey stateKey: String) -> ThresholdState {
        let persistKey = Self.persistedStateKey(stateKey)
        guard let data = defaults.data(forKey: persistKey),
              let persisted = try? JSONDecoder().decode(PersistedThresholdState.self, from: data) else {
            return ThresholdState(armed: true, lastGain: nil, tradingDayKey: nil)
        }
        return ThresholdState(
            armed: persisted.armed,
            lastGain: persisted.lastGain,
            tradingDayKey: persisted.tradingDayKey,
            retryPending: persisted.retryPending ?? false
        )
    }

    private func saveState(_ state: ThresholdState, forKey stateKey: String) {
        let persistKey = Self.persistedStateKey(stateKey)
        let persisted = PersistedThresholdState(
            armed: state.armed,
            lastGain: state.lastGain,
            tradingDayKey: state.tradingDayKey,
            retryPending: state.retryPending
        )
        guard let data = try? JSONEncoder().encode(persisted) else { return }
        defaults.set(data, forKey: persistKey)
    }

    private func isPastThreshold(threshold: GainNotificationThreshold, paperGain: Double) -> Bool {
        if threshold.isGainThreshold {
            return paperGain >= threshold.amount
        }
        return paperGain <= threshold.amount
    }

    private func didCross(threshold: GainNotificationThreshold, from previous: Double, to current: Double) -> Bool {
        if threshold.isGainThreshold {
            return previous < threshold.amount && current >= threshold.amount
        }
        return previous > threshold.amount && current <= threshold.amount
    }

    @discardableResult
    private func deliverNotification(event: CrossingEvent, possessiveName: String) async -> Bool {
        let content = UNMutableNotificationContent()
        // Illustrative paper P&L for a public figure — treated as market “news,” not private finance.
        if event.threshold.isGainThreshold {
            content.title = "\(possessiveName) gain crossed \(event.threshold.label)"
            content.body = "Combined paper gain is now \(CurrencyFormatter.formatCurrency(event.paperGain))."
        } else {
            content.title = "\(possessiveName) loss crossed \(event.threshold.label)"
            content.body = "Combined paper loss is now \(CurrencyFormatter.formatCurrency(event.paperGain))."
        }
        content.sound = .default
        content.categoryIdentifier = NotificationAuthorization.gainThresholdCategoryID
        content.userInfo = [
            NotificationAuthorization.notificationKindKey: NotificationAuthorization.gainThresholdKind
        ]

        // Deterministic ID so retries replace rather than stack Notification Center entries.
        let request = UNNotificationRequest(
            identifier: "gain-threshold-\(event.threshold.id)-\(event.tradingDayKey)",
            content: content,
            trigger: nil
        )

        do {
            try await deliverer.add(request)
            return true
        } catch {
            return false
        }
    }

    private static func enabledThresholdsKey(_ personID: String) -> String {
        "gainNotificationEnabledThresholds_\(personID)"
    }

    private static func stateKey(personID: String, thresholdID: String) -> String {
        "\(personID)-\(thresholdID)"
    }

    private static func persistedStateKey(_ stateKey: String) -> String {
        "gainNotificationThresholdState_\(stateKey)"
    }

    nonisolated static func resetPersistedState(for personID: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: "gainNotificationEnabledThresholds_\(personID)")
        for threshold in GainNotificationThreshold.presets {
            let stateKey = "\(personID)-\(threshold.id)"
            defaults.removeObject(forKey: "gainNotificationThresholdState_\(stateKey)")
        }
    }
}
