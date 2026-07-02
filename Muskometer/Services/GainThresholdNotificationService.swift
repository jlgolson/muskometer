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
    }

    private struct PersistedThresholdState: Codable, Equatable {
        var armed: Bool
        var lastGain: Double?
        var tradingDayKey: String?
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
        let prefix = "\(personID)-"
        stateByKey = stateByKey.filter { !$0.key.hasPrefix(prefix) }
    }

    @discardableResult
    func processUpdate(
        paperGain: Double,
        personID: String,
        possessiveName: String,
        at date: Date = .now,
        marketIsOpen: Bool
    ) async -> [CrossingEvent] {
        guard marketIsOpen else { return [] }

        let dayKey = calendar.dayKey(for: date)
        let enabledIDs = enabledThresholdIDs(for: personID)
        guard !enabledIDs.isEmpty else { return [] }

        var fired: [CrossingEvent] = []

        for threshold in GainNotificationThreshold.presets where enabledIDs.contains(threshold.id) {
            let stateKey = Self.stateKey(personID: personID, thresholdID: threshold.id)
            var state = stateByKey[stateKey] ?? loadState(forKey: stateKey)

            if state.tradingDayKey != dayKey {
                state.armed = true
                state.lastGain = nil
                state.tradingDayKey = dayKey
            }

            if state.lastGain == nil, state.tradingDayKey == dayKey, isPastThreshold(threshold: threshold, paperGain: paperGain) {
                state.armed = false
            }

            if let previousGain = state.lastGain, state.armed, didCross(threshold: threshold, from: previousGain, to: paperGain) {
                let event = CrossingEvent(threshold: threshold, paperGain: paperGain, tradingDayKey: dayKey)
                fired.append(event)
                state.armed = false

                await deliverNotification(
                    event: event,
                    possessiveName: possessiveName
                )
            }

            state.lastGain = paperGain
            state.armed = shouldRearm(threshold: threshold, paperGain: paperGain, currentlyArmed: state.armed)
            stateByKey[stateKey] = state
            saveState(state, forKey: stateKey)
        }

        return fired
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
            tradingDayKey: persisted.tradingDayKey
        )
    }

    private func saveState(_ state: ThresholdState, forKey stateKey: String) {
        let persistKey = Self.persistedStateKey(stateKey)
        let persisted = PersistedThresholdState(
            armed: state.armed,
            lastGain: state.lastGain,
            tradingDayKey: state.tradingDayKey
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

    private func shouldRearm(threshold: GainNotificationThreshold, paperGain: Double, currentlyArmed: Bool) -> Bool {
        guard !currentlyArmed else { return true }
        if threshold.isGainThreshold {
            return paperGain < threshold.amount
        }
        return paperGain > threshold.amount
    }

    private func deliverNotification(event: CrossingEvent, possessiveName: String) async {
        let content = UNMutableNotificationContent()
        if event.threshold.isGainThreshold {
            content.title = "\(possessiveName) gain crossed \(event.threshold.label)"
            content.body = "Combined paper gain is now \(CurrencyFormatter.formatCurrency(event.paperGain))."
        } else {
            content.title = "\(possessiveName) loss crossed \(event.threshold.label)"
            content.body = "Combined paper loss is now \(CurrencyFormatter.formatCurrency(event.paperGain))."
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "gain-threshold-\(event.threshold.id)-\(event.tradingDayKey)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        try? await deliverer.add(request)
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