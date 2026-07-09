import Foundation
import ServiceManagement

protocol LaunchAtLoginManaging {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

struct LaunchAtLoginManager: LaunchAtLoginManaging {
    static let shared = LaunchAtLoginManager()

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

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
