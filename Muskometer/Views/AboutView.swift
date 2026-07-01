import AppKit
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            if let icon = NSApplication.shared.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
            }

            Text("Muskometer")
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text(AppVersion.displayString)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Link("muskometer.org", destination: AppURLs.website)
                Link("info@muskometer.org", destination: AppURLs.contact)
            }
            .font(.caption)
        }
        .padding(24)
        .frame(width: 320)
    }
}

struct OpenAboutWindowButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("About Muskometer") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "about")
        }
    }
}