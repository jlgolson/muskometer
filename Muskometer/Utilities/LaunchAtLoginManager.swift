import Foundation
import ServiceManagement

enum LaunchAtLoginStatus {
    case notRegistered
    case enabled
    case requiresApproval
    case unavailable
}

protocol LaunchAtLoginManaging {
    var status: LaunchAtLoginStatus { get }
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

extension LaunchAtLoginManaging {
    // Compatibility for clients that expose only the original Boolean status.
    var status: LaunchAtLoginStatus { isEnabled ? .enabled : .notRegistered }
}

struct LaunchAtLoginManager: LaunchAtLoginManaging {
    static let shared = LaunchAtLoginManager()

    var status: LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered: return .notRegistered
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .unavailable
        @unknown default: return .unavailable
        }
    }

    var isEnabled: Bool { status == .enabled }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func reconcile(with settings: AppSettings) {
        settings.syncLaunchAtLoginFromService()
    }
}
