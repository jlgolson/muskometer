import AppKit

/// Opens the SwiftUI `MenuBarExtra` popover by activating the app and
/// synthesizing a click on this process’s status-item button when needed.
@MainActor
enum MenuBarPopoverPresenter {
    static func openIfNeeded() {
        NSApp.activate(ignoringOtherApps: true)
        guard !PopoverVisibility.isVisible else { return }
        statusItemButton()?.performClick(nil)
    }

    static func statusItemButton() -> NSStatusBarButton? {
        for window in NSApp.windows {
            let className = NSStringFromClass(type(of: window))
            guard className.contains("NSStatusBar") || className.contains("StatusItem") else {
                continue
            }
            if let button = findStatusBarButton(in: window.contentView) {
                return button
            }
        }
        return nil
    }

    private static func findStatusBarButton(in view: NSView?) -> NSStatusBarButton? {
        guard let view else { return nil }
        if let button = view as? NSStatusBarButton {
            return button
        }
        for subview in view.subviews {
            if let button = findStatusBarButton(in: subview) {
                return button
            }
        }
        return nil
    }
}
