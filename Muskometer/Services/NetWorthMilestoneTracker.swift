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

    func currentZone() -> NetWorthZone {
        guard let raw = defaults.string(forKey: Self.zoneKey),
              let zone = NetWorthZone(rawValue: raw) else {
            return .belowOneTrillion
        }
        return zone
    }

    @discardableResult
    func update(netWorth: Double, at date: Date = .now) -> NetWorthMilestoneEvent? {
        let previousZone = currentZone()
        let newZone = resolvedZone(for: netWorth, from: previousZone)
        defaults.set(newZone.rawValue, forKey: Self.zoneKey)

        switch (previousZone, newZone) {
        case (.belowOneTrillion, .aboveOneTrillion), (.belowOneTrillion, .aboveTwoTrillion):
            return .celebration(
                NetWorthMilestone(
                    id: "trillion-up-\(Int(date.timeIntervalSince1970))",
                    title: "One trillion dollars!",
                    thresholdLabel: CurrencyFormatter.formatMarketValue(Self.oneTrillion)
                )
            )

        case (.aboveOneTrillion, .aboveTwoTrillion):
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

    private static let zoneKey = "netWorthMilestoneZone"
}