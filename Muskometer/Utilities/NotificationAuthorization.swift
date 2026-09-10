import UserNotifications

/// Centralizes local notification permission so callers request only when a
/// feature that needs alerts is turned on (not on every app launch).
enum NotificationAuthorization {
    static let deniedHint =
        "Notifications are disabled for Muskometer. Enable them in System Settings → Notifications → Muskometer."

    static let updateOpenActionID = "OPEN_RELEASE"
    /// Keep in sync with `UpdateCoordinator.notificationCategoryID`.
    static let updateCategoryID = "org.muskometer.app.update-available"

    static let gainThresholdCategoryID = "org.muskometer.app.gain-threshold"
    static let notificationKindKey = "kind"
    static let gainThresholdKind = "gainThreshold"
    static let dayCloseCategoryID = "org.muskometer.app.day-close"
    static let dayCloseKind = "dayClose"

    /// Registers actionable categories used by update and gain notifications.
    static func registerCategories() {
        let openRelease = UNNotificationAction(
            identifier: updateOpenActionID,
            title: "Open Release",
            options: [.foreground]
        )
        let updateCategory = UNNotificationCategory(
            identifier: updateCategoryID,
            actions: [openRelease],
            intentIdentifiers: [],
            options: []
        )
        let gainCategory = UNNotificationCategory(
            identifier: gainThresholdCategoryID,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let dayCloseCategory = UNNotificationCategory(
            identifier: dayCloseCategoryID,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([
            updateCategory,
            gainCategory,
            dayCloseCategory,
        ])
    }

    /// Requests `[.alert, .sound]` when status is not determined.
    /// Returns whether notification delivery is currently allowed.
    @discardableResult
    static func requestIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }
}
