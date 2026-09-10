import AppKit

/// Opens the SwiftUI `MenuBarExtra` popover by activating the app and
/// synthesizing a click on this process’s status-item button when needed.
@MainActor
enum MenuBarPopoverPresenter {
    @discardableResult
    static func openIfNeeded() async -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        if PopoverVisibility.isVisible { return true }

        if let button = statusItemButton() {
            button.performClick(nil)
            return true
        }

        // Status item windows can lag briefly after activation; retry once.
        try? await Task.sleep(for: .milliseconds(80))
        if PopoverVisibility.isVisible { return true }
        if let button = statusItemButton() {
            button.performClick(nil)
            return true
        }

        #if DEBUG
        print("MenuBarPopoverPresenter.openIfNeeded: status item button missing after activate+retry")
        assertionFailure("MenuBarPopoverPresenter: status item button missing after activate+retry")
        #endif
        return false
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
