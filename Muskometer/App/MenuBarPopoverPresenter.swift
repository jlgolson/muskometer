import AppKit

/// Opens the SwiftUI `MenuBarExtra` popover by activating the app and
/// synthesizing a click on this process’s status-item button when needed.
@MainActor
enum MenuBarPopoverPresenter {
    @discardableResult
    static func openIfNeeded() async -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        if PopoverVisibility.isVisible { return true }

        // At most one click: a second performClick toggles the popover closed.
        var button = statusItemButton()
        if button == nil {
            // Status item windows can lag briefly after activation; retry lookup once.
            try? await Task.sleep(for: .milliseconds(80))
            if PopoverVisibility.isVisible { return true }
            button = statusItemButton()
        }

        guard let button else {
            #if DEBUG
            print("MenuBarPopoverPresenter.openIfNeeded: status item button missing after activate+retry")
            assertionFailure("MenuBarPopoverPresenter: status item button missing after activate+retry")
            #endif
            return false
        }

        button.performClick(nil)
        // SwiftUI onAppear may lag behind the click; poll instead of clicking again.
        for _ in 0..<8 {
            if PopoverVisibility.isVisible { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return PopoverVisibility.isVisible
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
