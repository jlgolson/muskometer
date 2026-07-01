import Foundation

extension Notification.Name {
    static let openMuskometerSettings = Notification.Name("openMuskometerSettings")
}

@MainActor
enum PopoverVisibility {
    static var isVisible = false
}