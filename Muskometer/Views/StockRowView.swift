import SwiftUI

struct StockRowView: View {
    let holding: HoldingGain
    var animateValues = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(holding.symbol)
                        .font(.system(.headline, design: .rounded, weight: .semibold))

                    if holding.symbol == "SPCX" {
                        Text("SpaceX stock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text("\(CurrencyFormatter.formatShareCount(holding.shareCount)) shares")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    priceText(CurrencyFormatter.formatPrice(holding.quote.currentPrice))
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .monospacedDigit()

                    percentText(CurrencyFormatter.formatPercent(holding.quote.percentChange))
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(percentColor)
                }
            }

            metricRow(label: "Elon's Stake", value: CurrencyFormatter.formatMarketValue(holding.marketValue))

            HStack {
                Text(GainSummaryFormatter.todaysGainLossLabel(for: holding.paperGain))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                gainText(CurrencyFormatter.formatCurrency(holding.paperGain))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(gainColor)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        }
    }

    @ViewBuilder
    private func priceText(_ text: String) -> some View {
        if animateValues {
            Text(text)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.25), value: holding.quote.currentPrice)
        } else {
            Text(text)
        }
    }

    @ViewBuilder
    private func percentText(_ text: String) -> some View {
        if animateValues {
            Text(text)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.25), value: holding.quote.percentChange)
        } else {
            Text(text)
        }
    }

    @ViewBuilder
    private func gainText(_ text: String) -> some View {
        if animateValues {
            Text(text)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.25), value: holding.paperGain)
        } else {
            Text(text)
        }
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .monospacedDigit()
        }
    }

    private var gainColor: Color {
        if holding.paperGain > 0 {
            return Color("GainPositive")
        }
        if holding.paperGain < 0 {
            return Color("GainNegative")
        }
        return .primary
    }

    private var percentColor: Color {
        if holding.quote.percentChange > 0 {
            return Color("GainPositive")
        }
        if holding.quote.percentChange < 0 {
            return Color("GainNegative")
        }
        return .secondary
    }
}