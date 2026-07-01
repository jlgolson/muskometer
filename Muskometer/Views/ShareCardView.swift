import SwiftUI

/// Branded share card rendered to PNG for pasting into Messages and other apps.
struct ShareCardView: View {
    let snapshot: GainsSnapshot
    let profile: TrackedPersonProfile

    private let background = Color(red: 0.09, green: 0.09, blue: 0.1)
    private let surface = Color(red: 0.14, green: 0.14, blue: 0.16)
    private let muted = Color(red: 0.58, green: 0.58, blue: 0.62)
    private let accentSurface = Color(red: 0.16, green: 0.22, blue: 0.36)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            ownershipBlock
            combinedBlock
            holdingsBlock
            footer
        }
        .padding(20)
        .frame(width: 360, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(background)
        }
        .foregroundStyle(.white)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Muskometer")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text(profile.tagline)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(muted)
        }
    }

    private var ownershipBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(profile.possessiveName) Ownership")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(muted)

            Text(CurrencyFormatter.formatMarketValue(snapshot.combinedMarketValue))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var combinedBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Combined today")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(muted)

            Text(CurrencyFormatter.formatCurrency(snapshot.combinedPaperGain))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(gainColor(for: snapshot.combinedPaperGain))

            Text(CurrencyFormatter.formatPercent(snapshot.combinedPercentChange))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(gainColor(for: snapshot.combinedPaperGain))

            HStack(spacing: 6) {
                Circle()
                    .fill(snapshot.marketIsOpen ? gainPositive : muted)
                    .frame(width: 6, height: 6)
                Text(snapshot.marketIsOpen ? "Market open" : "Market closed")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(muted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accentSurface)
        }
    }

    private var holdingsBlock: some View {
        VStack(spacing: 10) {
            ForEach(snapshot.holdings) { holding in
                holdingRow(holding)
            }
        }
    }

    private func holdingRow(_ holding: HoldingGain) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(holding.symbol)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("\(CurrencyFormatter.formatShareCount(holding.shareCount)) shares")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(muted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(CurrencyFormatter.formatPrice(holding.quote.currentPrice))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(CurrencyFormatter.formatPercent(holding.quote.percentChange))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(gainColor(for: holding.quote.percentChange))
                }
            }

            metricRow(
                label: "\(profile.possessiveName) Stake",
                value: CurrencyFormatter.formatMarketValue(holding.marketValue)
            )

            metricRow(
                label: GainSummaryFormatter.todaysGainLossLabel(for: holding.paperGain),
                value: CurrencyFormatter.formatCurrency(holding.paperGain),
                valueColor: gainColor(for: holding.paperGain)
            )
        }
        .padding(12)
        .background(cardBackground)
    }

    private func metricRow(label: String, value: String, valueColor: Color = .white) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(muted)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(valueColor)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("muskometer.org")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.45, green: 0.62, blue: 1.0))

            Text("Entertainment only · Not financial advice")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(muted)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(surface)
    }

    private var gainPositive: Color {
        Color(red: 0.298, green: 0.878, blue: 0.420)
    }

    private var gainNegative: Color {
        Color(red: 0.949, green: 0.420, blue: 0.420)
    }

    private func gainColor(for amount: Double) -> Color {
        if amount > 0 { return gainPositive }
        if amount < 0 { return gainNegative }
        return .white
    }
}