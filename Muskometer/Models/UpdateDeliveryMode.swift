import Foundation

enum UpdateDeliveryMode: String, Codable, CaseIterable, Sendable {
    case notifyOnly
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