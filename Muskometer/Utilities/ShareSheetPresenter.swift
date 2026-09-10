import AppKit

/// Presents the system sharing picker anchored to a visible app window.
@MainActor
enum ShareSheetPresenter {
    @discardableResult
    static func present(items: [Any]) -> Bool {
        guard !items.isEmpty else { return false }
        guard let view = anchorView() else { return false }
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        return true
    }

    static func anchorView() -> NSView? {
        if let key = NSApp.keyWindow?.contentView {
            return key
        }
        return NSApp.windows.first(where: \.isVisible)?.contentView
    }
}
