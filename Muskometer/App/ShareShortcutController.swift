import AppKit

@MainActor
final class ShareShortcutController {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let handler: () -> Bool
    private var lastTriggerDate: Date?
    private let debounceInterval: TimeInterval

    init(
        debounceInterval: TimeInterval = 0.5,
        handler: @escaping () -> Bool
    ) {
        self.debounceInterval = debounceInterval
        self.handler = handler
    }

    func start() {
        stop()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.matchesShortcut(event) else { return event }
            self.fire()
            return nil
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

    private func handle(_ event: NSEvent) {
        guard matchesShortcut(event) else { return }
        fire()
    }

    private func matchesShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), flags.contains(.shift) else { return false }
        return event.charactersIgnoringModifiers?.lowercased() == "c"
    }

    private func fire() {
        let now = Date()
        if let lastTriggerDate,
           now.timeIntervalSince(lastTriggerDate) < debounceInterval {
            return
        }
        lastTriggerDate = now
        _ = handler()
    }
}