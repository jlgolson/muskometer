import UserNotifications

/// Centralizes local notification permission so callers request only when a
/// feature that needs alerts is turned on (not on every app launch).
enum NotificationAuthorization {
    static let deniedHint =
        "Notifications are disabled for Muskometer. Enable them in System Settings → Notifications → Muskometer."

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
