import Foundation

/// A paper-gain crossing level that can trigger a local notification.
struct GainNotificationThreshold: Equatable, Identifiable, Sendable, Codable {
    let id: String
    let amount: Double
    let label: String

    var isGainThreshold: Bool {
        amount > 0
    }

    var isLossThreshold: Bool {
        amount < 0
    }

    static let presets: [GainNotificationThreshold] = [
        GainNotificationThreshold(id: "gain-5b", amount: 5_000_000_000, label: "+$5B"),
        GainNotificationThreshold(id: "gain-10b", amount: 10_000_000_000, label: "+$10B"),
        GainNotificationThreshold(id: "gain-20b", amount: 20_000_000_000, label: "+$20B"),
        GainNotificationThreshold(id: "gain-50b", amount: 50_000_000_000, label: "+$50B"),
        GainNotificationThreshold(id: "loss-5b", amount: -5_000_000_000, label: "-$5B"),
        GainNotificationThreshold(id: "loss-10b", amount: -10_000_000_000, label: "-$10B"),
        GainNotificationThreshold(id: "loss-20b", amount: -20_000_000_000, label: "-$20B"),
        GainNotificationThreshold(id: "loss-50b", amount: -50_000_000_000, label: "-$50B")
    ]

    static func preset(id: String) -> GainNotificationThreshold? {
        presets.first { $0.id == id }
    }
}