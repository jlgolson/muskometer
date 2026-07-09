import Foundation

enum NetWorthZone: String, Codable, Sendable, Equatable {
    case belowOneTrillion
    case aboveOneTrillion
    case aboveTwoTrillion
}

enum NetWorthMilestoneEvent: Equatable, Sendable {
    case celebration(NetWorthMilestone)
    case fellBelowTrillion(message: String)
}

/// Tracks combined net-worth crossings with hysteresis around $1T and $2T.
@MainActor
final class NetWorthMilestoneTracker {
    static let oneTrillion: Double = 1_000_000_000_000
    static let twoTrillion: Double = 2_000_000_000_000
    static let hysteresisFraction: Double = 0.01
    static let belowTrillionMessage = "One Trillion Is the Lonliest Number"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func currentZone(for personID: String) -> NetWorthZone {
        Self.migrateLegacyZoneIfNeeded(defaults: defaults, personID: personID)

        guard let raw = defaults.string(forKey: Self.zoneKey(personID: personID)),
              let zone = NetWorthZone(rawValue: raw) else {
            return .belowOneTrillion
        }
        return zone
    }

    @discardableResult
    func update(netWorth: Double, personID: String, at date: Date = .now) -> NetWorthMilestoneEvent? {
        let previousZone = currentZone(for: personID)
        let newZone = resolvedZone(for: netWorth, from: previousZone)
        defaults.set(newZone.rawValue, forKey: Self.zoneKey(personID: personID))

        switch (previousZone, newZone) {
        case (.belowOneTrillion, .aboveOneTrillion):
            return .celebration(
                NetWorthMilestone(
                    id: "trillion-up-\(Int(date.timeIntervalSince1970))",
                    title: "One trillion dollars!",
                    thresholdLabel: CurrencyFormatter.formatMarketValue(Self.oneTrillion)
                )
            )

        // Prefer the highest threshold when both $1T and $2T are crossed in one jump.
        case (.belowOneTrillion, .aboveTwoTrillion), (.aboveOneTrillion, .aboveTwoTrillion):
            return .celebration(
                NetWorthMilestone(
                    id: "two-trillion-up-\(Int(date.timeIntervalSince1970))",
                    title: "Two trillion club!",
                    thresholdLabel: CurrencyFormatter.formatMarketValue(Self.twoTrillion)
                )
            )

        case (.aboveOneTrillion, .belowOneTrillion), (.aboveTwoTrillion, .belowOneTrillion):
            return .fellBelowTrillion(message: Self.belowTrillionMessage)

        default:
            return nil
        }
    }

    func resolvedZone(for netWorth: Double, from previousZone: NetWorthZone) -> NetWorthZone {
        let upOne = Self.oneTrillion
        let upTwo = Self.twoTrillion
        let downOne = Self.oneTrillion * (1 - Self.hysteresisFraction)
        let downTwo = Self.twoTrillion * (1 - Self.hysteresisFraction)

        switch previousZone {
        case .belowOneTrillion:
            if netWorth >= upTwo { return .aboveTwoTrillion }
            if netWorth >= upOne { return .aboveOneTrillion }
            return .belowOneTrillion

        case .aboveOneTrillion:
            if netWorth >= upTwo { return .aboveTwoTrillion }
            if netWorth < downOne { return .belowOneTrillion }
            return .aboveOneTrillion

        case .aboveTwoTrillion:
            if netWorth < downOne { return .belowOneTrillion }
            if netWorth < downTwo { return .aboveOneTrillion }
            return .aboveTwoTrillion
        }
    }

    nonisolated static func resetPersistedState(for personID: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: "netWorthMilestoneZone_\(personID)")
        if personID == TrackedPersonProfile.musk.id {
            defaults.removeObject(forKey: "netWorthMilestoneZone")
        }
    }

    private static let legacyZoneKey = "netWorthMilestoneZone"

    private static func zoneKey(personID: String) -> String {
        "netWorthMilestoneZone_\(personID)"
    }

    private static func migrateLegacyZoneIfNeeded(defaults: UserDefaults, personID: String) {
        guard personID == TrackedPersonProfile.musk.id else { return }
        let key = zoneKey(personID: personID)
        guard defaults.string(forKey: key) == nil,
              let legacy = defaults.string(forKey: legacyZoneKey) else {
            return
        }
        defaults.set(legacy, forKey: key)
        defaults.removeObject(forKey: legacyZoneKey)
    }
}