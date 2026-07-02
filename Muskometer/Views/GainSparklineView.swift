import Charts
import SwiftUI

/// Compact intraday sparkline for combined paper gain (~36pt tall).
struct GainSparklineView: View {
    let samples: [GainSample]

    private let height: CGFloat = 36
    private let gainPositive = Color("GainPositive")
    private let gainNegative = Color("GainNegative")

    private var segments: [SparklineSegment] {
        Self.segments(from: samples)
    }

    var body: some View {
        Group {
            if samples.isEmpty {
                Color.clear
            } else {
                Chart {
                    RuleMark(y: .value("Breakeven", 0))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 3]))

                    ForEach(segments) { segment in
                        ForEach(segment.points) { sample in
                            LineMark(
                                x: .value("Time", sample.timestamp),
                                y: .value("Gain", sample.combinedPaperGain)
                            )
                            .interpolationMethod(.linear)
                            .foregroundStyle(segment.color(gainPositive: gainPositive, gainNegative: gainNegative))

                            AreaMark(
                                x: .value("Time", sample.timestamp),
                                yStart: .value("Zero", 0),
                                yEnd: .value("Gain", sample.combinedPaperGain)
                            )
                            .interpolationMethod(.linear)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: segment.gradientColors(
                                        gainPositive: gainPositive,
                                        gainNegative: gainNegative
                                    ),
                                    startPoint: segment.isPositive ? .top : .bottom,
                                    endPoint: segment.isPositive ? .bottom : .top
                                )
                            )
                        }
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartLegend(.hidden)
            }
        }
        .frame(height: height)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let last = samples.last?.combinedPaperGain else {
            return "Intraday gain sparkline"
        }
        return "Intraday gain sparkline, current \(CurrencyFormatter.formatCurrency(last))"
    }
}

private struct SparklineSegment: Identifiable {
    let id = UUID()
    let points: [GainSample]
    let isPositive: Bool

    func color(gainPositive: Color, gainNegative: Color) -> Color {
        isPositive ? gainPositive : gainNegative
    }

    func gradientColors(gainPositive: Color, gainNegative: Color) -> [Color] {
        let line = color(gainPositive: gainPositive, gainNegative: gainNegative)
        return [line.opacity(0.35), line.opacity(0.02)]
    }
}

private extension GainSparklineView {
    static func segments(from samples: [GainSample]) -> [SparklineSegment] {
        guard !samples.isEmpty else { return [] }

        let augmented = samplesWithZeroCrossings(samples)
        var result: [SparklineSegment] = []
        var currentPoints: [GainSample] = []
        var currentIsPositive = augmented[0].combinedPaperGain >= 0

        for sample in augmented {
            let isPositive = sample.combinedPaperGain >= 0

            if isPositive != currentIsPositive, !currentPoints.isEmpty {
                currentPoints.append(sample)
                result.append(SparklineSegment(points: currentPoints, isPositive: currentIsPositive))
                currentPoints = [sample]
                currentIsPositive = isPositive
            } else {
                currentPoints.append(sample)
                currentIsPositive = isPositive
            }
        }

        if !currentPoints.isEmpty {
            result.append(SparklineSegment(points: currentPoints, isPositive: currentIsPositive))
        }

        return result
    }

    static func samplesWithZeroCrossings(_ samples: [GainSample]) -> [GainSample] {
        guard samples.count > 1 else { return samples }

        var augmented: [GainSample] = [samples[0]]

        for index in 1..<samples.count {
            let previous = samples[index - 1]
            let current = samples[index]
            let previousGain = previous.combinedPaperGain
            let currentGain = current.combinedPaperGain

            if crossesZero(from: previousGain, to: currentGain) {
                let delta = current.timestamp.timeIntervalSince(previous.timestamp)
                let fraction = abs(previousGain) / (abs(previousGain) + abs(currentGain))
                let crossTime = previous.timestamp.addingTimeInterval(delta * fraction)
                augmented.append(GainSample(timestamp: crossTime, combinedPaperGain: 0))
            }

            augmented.append(current)
        }

        return augmented
    }

    static func crossesZero(from previous: Double, to current: Double) -> Bool {
        (previous > 0 && current < 0) || (previous < 0 && current > 0)
    }
}