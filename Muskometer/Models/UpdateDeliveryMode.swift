import Foundation

enum UpdateDeliveryMode: String, Codable, CaseIterable, Sendable {
    /// Notify via GitHub release checks (current, supported path).
    case notifyOnly
    /// Reserved for future Sparkle auto-install. Until Sparkle is wired,
    /// UpdateCoordinator treats this the same as `notifyOnly` for checking
    /// and notifications so the setting is never a silent no-op.
    case automatic

    var label: String {
        switch self {
        case .notifyOnly:
            return "Notify me"
        case .automatic:
            return "Install automatically"
        }
    }
}