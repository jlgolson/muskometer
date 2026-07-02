import Charts
import SwiftUI

/// Compact intraday sparkline for combined paper gain (~36pt tall).
struct GainSparklineView: View {
    let samples: [GainSample]

    private let height: CGFloat = 36
    private let gainPositive = Color("GainPositive")
    private let gainNegative = Color("GainNegative")

    var body: some View {
        Group {
            if samples.isEmpty {
                Color.clear
            } else {
                Chart(samples) { sample in
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Gain", sample.combinedPaperGain)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(lineColor)

                    AreaMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Gain", sample.combinedPaperGain)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [lineColor.opacity(0.35), lineColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartLegend(.hidden)
            }
        }
        .frame(height: height)
        .accessibilityLabel(accessibilityLabel)
    }

    private var lineColor: Color {
        guard let last = samples.last?.combinedPaperGain else { return gainPositive }
        return last >= 0 ? gainPositive : gainNegative
    }

    private var accessibilityLabel: String {
        guard let last = samples.last?.combinedPaperGain else {
            return "Intraday gain sparkline"
        }
        return "Intraday gain sparkline, current \(CurrencyFormatter.formatCurrency(last))"
    }
}