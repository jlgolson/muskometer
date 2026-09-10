import SwiftUI

/// Shared Liquid Glass surfaces for Muskometer cards (macOS 26+).
/// Prefer this over opaque `controlBackgroundColor` fills so system glass,
/// Reduce Transparency, and Increased Contrast adapt correctly.
enum MuskometerGlass {
    static let cardCornerRadius: CGFloat = 12
    static let compactCornerRadius: CGFloat = 10
    static let containerSpacing: CGFloat = 14
}

extension View {
    /// Applies Regular Liquid Glass in a continuous rounded rectangle.
    func muskometerGlassCard(
        cornerRadius: CGFloat = MuskometerGlass.cardCornerRadius,
        tint: Color? = nil
    ) -> some View {
        glassEffect(
            .regular.tint(tint),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}
