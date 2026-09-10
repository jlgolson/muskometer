import AppKit
import SwiftUI

enum ShareImageExporter {
    @MainActor
    static func shareItems(
        snapshot: GainsSnapshot,
        profile: TrackedPersonProfile,
        format: ShareFormat,
        intradaySamples: [GainSample] = [],
        parity: MergerParityPresentation? = nil
    ) -> [Any] {
        switch format {
        case .image:
            guard let png = renderPNGData(
                snapshot: snapshot,
                profile: profile,
                intradaySamples: intradaySamples,
                parity: parity
            ),
            let image = NSImage(data: png) else {
                return []
            }
            return [image]
        case .text:
            return [GainSummaryFormatter.format(snapshot, parity: parity)]
        }
    }

    @MainActor
    static func copyToPasteboard(
        snapshot: GainsSnapshot,
        profile: TrackedPersonProfile,
        format: ShareFormat,
        intradaySamples: [GainSample] = [],
        parity: MergerParityPresentation? = nil
    ) -> Bool {
        switch format {
        case .image:
            return copyImageToPasteboard(
                snapshot: snapshot,
                profile: profile,
                intradaySamples: intradaySamples,
                parity: parity
            )
        case .text:
            return copyTextToPasteboard(snapshot: snapshot, parity: parity)
        }
    }

    @MainActor
    private static func copyImageToPasteboard(
        snapshot: GainsSnapshot,
        profile: TrackedPersonProfile,
        intradaySamples: [GainSample],
        parity: MergerParityPresentation?
    ) -> Bool {
        guard let image = renderImage(
            snapshot: snapshot,
            profile: profile,
            intradaySamples: intradaySamples,
            parity: parity
        ) else {
            return false
        }

        // Confirm the image is pasteboard-serializable before mutating the
        // clipboard. NSPasteboard requires clearContents for exclusive image
        // ownership; a residual empty clipboard remains if writeObjects fails
        // after clear (uncommon once tiffRepresentation is available).
        guard image.tiffRepresentation != nil else {
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects([image])
    }

    @MainActor
    private static func copyTextToPasteboard(
        snapshot: GainsSnapshot,
        parity: MergerParityPresentation?
    ) -> Bool {
        // Format first so we never clear the clipboard if formatting failed
        // (formatting is pure and does not fail). NSPasteboard requires
        // clearContents to take ownership before setString will succeed.
        let text = GainSummaryFormatter.format(snapshot, parity: parity)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    @MainActor
    static func renderPNGData(
        snapshot: GainsSnapshot,
        profile: TrackedPersonProfile,
        intradaySamples: [GainSample] = [],
        parity: MergerParityPresentation? = nil
    ) -> Data? {
        guard let image = renderImage(
            snapshot: snapshot,
            profile: profile,
            intradaySamples: intradaySamples,
            parity: parity
        ) else {
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
    private static func renderImage(
        snapshot: GainsSnapshot,
        profile: TrackedPersonProfile,
        intradaySamples: [GainSample],
        parity: MergerParityPresentation?
    ) -> NSImage? {
        let renderer = ImageRenderer(
            content: ShareCardView(
                snapshot: snapshot,
                profile: profile,
                intradaySamples: intradaySamples,
                parity: parity
            )
        )
        renderer.scale = 2
        return renderer.nsImage
    }
}