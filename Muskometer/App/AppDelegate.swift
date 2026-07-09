import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    static var onTerminateHandler: (@MainActor () -> Void)?
    static var shareShortcutHandler: (@MainActor () -> Bool)?

    private var shareShortcutController: ShareShortcutController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep delegate for foreground presentation / update tap handling.
        // Authorization is requested only when the user enables a feature that
        // needs notifications (gain thresholds or update notify).
        UNUserNotificationCenter.current().delegate = self

        guard let handler = Self.shareShortcutHandler else { return }

        let controller = ShareShortcutController(handler: handler)
        controller.start()
        shareShortcutController = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        shareShortcutController?.stop()

        guard let handler = Self.onTerminateHandler else { return }

        if Thread.isMainThread {
            MainActor.assumeIsolated {
                handler()
            }
        } else {
            DispatchQueue.main.sync {
                handler()
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let urlString = userInfo["releaseURL"] as? String,
              let url = URL(string: urlString) else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}