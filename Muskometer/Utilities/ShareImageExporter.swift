import AppKit
import SwiftUI

enum ShareImageExporter {
    @MainActor
    static func copyToPasteboard(snapshot: GainsSnapshot, profile: TrackedPersonProfile) -> Bool {
        guard let image = renderImage(snapshot: snapshot, profile: profile) else {
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects([image])
    }

    @MainActor
    static func renderPNGData(snapshot: GainsSnapshot, profile: TrackedPersonProfile) -> Data? {
        guard let image = renderImage(snapshot: snapshot, profile: profile) else {
            return nil
        }

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        return png
    }

    @MainActor
    private static func renderImage(snapshot: GainsSnapshot, profile: TrackedPersonProfile) -> NSImage? {
        let renderer = ImageRenderer(
            content: ShareCardView(snapshot: snapshot, profile: profile)
        )
        renderer.scale = 2
        return renderer.nsImage
    }
}