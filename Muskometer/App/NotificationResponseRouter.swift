import Foundation
import UserNotifications

/// Pure routing for notification tap / action responses.
enum NotificationResponseRouter {
    enum Destination: Equatable {
        case openPopover
        case openURL(URL)
        case ignore
    }

    static func destination(
        actionIdentifier: String,
        categoryIdentifier: String,
        userInfo: [AnyHashable: Any]
    ) -> Destination {
        let shouldOpen =
            actionIdentifier == UNNotificationDefaultActionIdentifier
            || actionIdentifier == NotificationAuthorization.updateOpenActionID
        guard shouldOpen else { return .ignore }

        let kind = userInfo[NotificationAuthorization.notificationKindKey] as? String
        if kind == NotificationAuthorization.gainThresholdKind
            || kind == NotificationAuthorization.dayCloseKind
            || categoryIdentifier == NotificationAuthorization.gainThresholdCategoryID
            || categoryIdentifier == NotificationAuthorization.dayCloseCategoryID {
            return .openPopover
        }

        guard let urlString = userInfo["releaseURL"] as? String,
              let url = URL(string: urlString),
              AppURLs.isTrustedReleasePageURL(url) else {
            return .ignore
        }
        return .openURL(url)
    }
}
