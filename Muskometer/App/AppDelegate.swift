import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    static var onTerminateHandler: (@MainActor () -> Void)?
    static var shareShortcutHandler: (@MainActor () -> Bool)?
    static var menuBarDisplayModeCycleHandler: (@MainActor () -> Void)?

    private var shareShortcutController: ShareShortcutController?
    private var menuBarDisplayModeCycleController: MenuBarDisplayModeCycleController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep delegate for foreground presentation / update tap handling.
        // Authorization is requested only when the user enables a feature that
        // needs notifications (gain thresholds or update notify).
        UNUserNotificationCenter.current().delegate = self
        NotificationAuthorization.registerCategories()

        if let handler = Self.shareShortcutHandler {
            let controller = ShareShortcutController(handler: handler)
            controller.start()
            shareShortcutController = controller
        }

        if let cycleHandler = Self.menuBarDisplayModeCycleHandler {
            let cycleController = MenuBarDisplayModeCycleController(handler: cycleHandler)
            cycleController.start()
            menuBarDisplayModeCycleController = cycleController
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        shareShortcutController?.stop()
        menuBarDisplayModeCycleController?.stop()

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
        let content = response.notification.request.content
        let destination = NotificationResponseRouter.destination(
            actionIdentifier: response.actionIdentifier,
            categoryIdentifier: content.categoryIdentifier,
            userInfo: content.userInfo
        )

        switch destination {
        case .openPopover:
            await MainActor.run {
                MenuBarPopoverPresenter.openIfNeeded()
            }
        case .openURL(let url):
            NSWorkspace.shared.open(url)
        case .ignore:
            break
        }
    }
}