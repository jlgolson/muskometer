import AppKit

enum ShareShortcutMatcher {
    static func matches(
        modifierFlags: NSEvent.ModifierFlags,
        charactersIgnoringModifiers: String?
    ) -> Bool {
        let flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), flags.contains(.shift) else { return false }
        return charactersIgnoringModifiers?.lowercased() == "c"
    }
}

@MainActor
final class ShareShortcutController {
    /// Outcome of attempting to fire the share shortcut handler.
    enum FireResult: Equatable {
        case succeeded
        case failed
        case debounced
    }

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let handler: () -> Bool
    private var lastTriggerDate: Date?
    private let debounceInterval: TimeInterval

    /// Local monitors may swallow the event. Consume on success and debounce so
    /// SwiftUI `keyboardShortcut` does not re-fire; only pass through on failure.
    static func shouldConsumeEvent(_ result: FireResult) -> Bool {
        switch result {
        case .succeeded, .debounced:
            return true
        case .failed:
            return false
        }
    }

    init(
        debounceInterval: TimeInterval = 0.5,
        handler: @escaping () -> Bool
    ) {
        self.debounceInterval = debounceInterval
        self.handler = handler
    }

    func start() {
        stop()

        // Global monitors cannot consume events; they only observe.
        // Snapshot key fields before the Task hop so NSEvent is not retained past the callback.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let modifierFlags = event.modifierFlags
            let charactersIgnoringModifiers = event.charactersIgnoringModifiers
            Task { @MainActor in
                self?.handle(
                    modifierFlags: modifierFlags,
                    charactersIgnoringModifiers: charactersIgnoringModifiers
                )
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.matchesShortcut(event) else { return event }
            let result = self.fire()
            return Self.shouldConsumeEvent(result) ? nil : event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func handle(
        modifierFlags: NSEvent.ModifierFlags,
        charactersIgnoringModifiers: String?
    ) {
        guard ShareShortcutMatcher.matches(
            modifierFlags: modifierFlags,
            charactersIgnoringModifiers: charactersIgnoringModifiers
        ) else { return }
        _ = fire()
    }

    private func matchesShortcut(_ event: NSEvent) -> Bool {
        ShareShortcutMatcher.matches(
            modifierFlags: event.modifierFlags,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers
        )
    }

    /// Invokes the share handler, respecting debounce.
    /// Debounce starts only after a successful handler so failures can retry immediately
    /// and `shouldConsumeEvent(.failed)` continues to pass the key event through.
    @discardableResult
    private func fire() -> FireResult {
        let now = Date()
        if let lastTriggerDate,
           now.timeIntervalSince(lastTriggerDate) < debounceInterval {
            return .debounced
        }
        guard handler() else {
            return .failed
        }
        lastTriggerDate = now
        return .succeeded
    }
}
