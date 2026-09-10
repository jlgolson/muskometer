import AppKit

enum MenuBarDisplayModeCycleMatcher {
    /// ⌥-click (option alone) on the menu bar status item cycles display mode without opening Settings.
    static func shouldCycle(modifierFlags: NSEvent.ModifierFlags, window: NSWindow?) -> Bool {
        shouldCycle(modifierFlags: modifierFlags, windowClassName: window.map { NSStringFromClass(type(of: $0)) })
    }

    static func shouldCycle(modifierFlags: NSEvent.ModifierFlags, windowClassName: String?) -> Bool {
        let flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.option),
              !flags.contains(.command),
              !flags.contains(.control),
              !flags.contains(.shift) else {
            return false
        }
        return isStatusBarWindowClassName(windowClassName)
    }

    static func isStatusBarWindow(_ window: NSWindow?) -> Bool {
        isStatusBarWindowClassName(window.map { NSStringFromClass(type(of: $0)) })
    }

    static func isStatusBarWindowClassName(_ name: String?) -> Bool {
        guard let name else { return false }
        return name.contains("NSStatusBar") || name.contains("StatusItem")
    }
}

@MainActor
final class MenuBarDisplayModeCycleController {
    private nonisolated(unsafe) var localMonitor: Any?
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    func start() {
        stop()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self else { return event }
            guard MenuBarDisplayModeCycleMatcher.shouldCycle(
                modifierFlags: event.modifierFlags,
                window: event.window
            ) else {
                return event
            }
            self.handler()
            // Consume so ⌥-click cycles without also toggling the popover.
            return nil
        }
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    deinit {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }
}
