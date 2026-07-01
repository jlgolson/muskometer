import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var onTerminateHandler: (@MainActor () -> Void)?

    func applicationWillTerminate(_ notification: Notification) {
        guard let handler = Self.onTerminateHandler else { return }

        if Thread.isMainThread {
            MainActor.assumeIsolated {
                handler()
            }
        } else {
            DispatchQueue.main.sync {
                handler()
            }
        }
    }
}