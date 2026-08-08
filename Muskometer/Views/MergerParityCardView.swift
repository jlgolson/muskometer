import SwiftUI

/// “If Tesla had SpaceX’s market cap” card for the main popover.
struct MergerParityCardView: View {
    let presentation: MergerParityPresentation
    var animateValues = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("If Tesla had SpaceX's market cap")
                .font(.caption)
                .foregroundStyle(.secondary)

            priceText(CurrencyFormatter.formatPrice(presentation.impliedTSLAPrice))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()

            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        }
    }

    private var caption: String {
        let spcx = CurrencyFormatter.formatMarketValue(presentation.spcxMarketCap)
        let tsla = CurrencyFormatter.formatMarketValue(presentation.tslaMarketCap)
        return "SPCX \(spcx) · TSLA \(tsla)"
    }

    @ViewBuilder
    private func priceText(_ text: String) -> some View {
        if animateValues {
            Text(text)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.25), value: presentation.impliedTSLAPrice)
        } else {
            Text(text)
        }
    }
}

#if DEBUG
struct MergerParityCardView_Previews: PreviewProvider {
    static var previews: some View {
        MergerParityCardView(
            presentation: MergerParityPresentation(
                impliedTSLAPrice: 1_250.40,
                tslaMarketCap: 1_100_000_000_000,
                spcxMarketCap: 1_400_000_000_000,
                currentTSLAPrice: 420.60
            ),
            animateValues: true
        )
        .padding()
        .frame(width: 328)
        .previewDisplayName("Parity card")
    }
}
#endif
