import SwiftUI

/// Compact intraday sparkline for combined paper gain (~36pt tall).
/// Green above $0 breakeven, red below — drawn with Canvas for reliable per-segment coloring.
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
                Canvas { context, size in
                    Self.draw(
                        samples: samples,
                        size: size,
                        gainPositive: gainPositive,
                        gainNegative: gainNegative,
                        in: &context
                    )
                }
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
}

private extension GainSparklineView {
    static func draw(
        samples: [GainSample],
        size: CGSize,
        gainPositive: Color,
        gainNegative: Color,
        in context: inout GraphicsContext
    ) {
        guard samples.count >= 1, size.width > 0, size.height > 0 else { return }

        let layout = SparklineLayout(samples: samples, size: size)
        let segments = segments(from: samples)

        var zeroPath = Path()
        zeroPath.move(to: CGPoint(x: 0, y: layout.zeroY))
        zeroPath.addLine(to: CGPoint(x: size.width, y: layout.zeroY))
        context.stroke(
            zeroPath,
            with: .color(.secondary.opacity(0.35)),
            style: StrokeStyle(lineWidth: 0.5, dash: [3, 3])
        )

        for segment in segments {
            let plotPoints = segment.points.map { layout.point(for: $0) }
            guard plotPoints.count >= 1 else { continue }

            let strokeColor = segment.isPositive ? gainPositive : gainNegative

            var linePath = Path()
            linePath.move(to: plotPoints[0])
            for point in plotPoints.dropFirst() {
                linePath.addLine(to: point)
            }

            context.stroke(
                linePath,
                with: .color(strokeColor),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )

            guard plotPoints.count >= 2 else { continue }

            var fillPath = linePath
            fillPath.addLine(to: CGPoint(x: plotPoints.last!.x, y: layout.zeroY))
            fillPath.addLine(to: CGPoint(x: plotPoints.first!.x, y: layout.zeroY))
            fillPath.closeSubpath()
            context.fill(fillPath, with: .color(strokeColor.opacity(0.22)))
        }
    }

    static func segments(from samples: [GainSample]) -> [SparklineSegment] {
        guard !samples.isEmpty else { return [] }

        let augmented = samplesWithZeroCrossings(samples)
        var result: [SparklineSegment] = []
        var currentPoints: [GainSample] = []
        var currentIsPositive = isPositiveGain(augmented[0].combinedPaperGain, continuing: true)

        for sample in augmented {
            let isPositive = isPositiveGain(sample.combinedPaperGain, continuing: currentIsPositive)

            if isPositive != currentIsPositive, !currentPoints.isEmpty {
                result.append(SparklineSegment(points: currentPoints, isPositive: currentIsPositive))

                if let last = currentPoints.last, last.combinedPaperGain == 0 {
                    currentPoints = [last, sample]
                } else {
                    currentPoints = [sample]
                }
                currentIsPositive = isPositive
            } else {
                currentPoints.append(sample)
                if sample.combinedPaperGain != 0 {
                    currentIsPositive = isPositive
                }
            }
        }

        if !currentPoints.isEmpty {
            result.append(SparklineSegment(points: currentPoints, isPositive: currentIsPositive))
        }

        return result
    }

    static func isPositiveGain(_ gain: Double, continuing prior: Bool) -> Bool {
        if gain > 0 { return true }
        if gain < 0 { return false }
        return prior
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

private struct SparklineLayout {
    let minGain: Double
    let maxGain: Double
    let minTime: TimeInterval
    let maxTime: TimeInterval
    let size: CGSize

    init(samples: [GainSample], size: CGSize) {
        let gains = samples.map(\.combinedPaperGain)
        let rawMin = min(gains.min() ?? 0, 0)
        let rawMax = max(gains.max() ?? 0, 0)
        let span = max(rawMax - rawMin, 1)
        let padding = span * 0.08

        self.minGain = rawMin - padding
        self.maxGain = rawMax + padding
        self.minTime = samples.first!.timestamp.timeIntervalSince1970
        self.maxTime = samples.last!.timestamp.timeIntervalSince1970
        self.size = size
    }

    var zeroY: CGFloat {
        y(for: 0)
    }

    func point(for sample: GainSample) -> CGPoint {
        CGPoint(
            x: x(for: sample.timestamp.timeIntervalSince1970),
            y: y(for: sample.combinedPaperGain)
        )
    }

    private func x(for time: TimeInterval) -> CGFloat {
        let span = max(maxTime - minTime, 1)
        let t = (time - minTime) / span
        return CGFloat(t) * size.width
    }

    private func y(for gain: Double) -> CGFloat {
        let span = max(maxGain - minGain, 1)
        let normalized = (gain - minGain) / span
        return size.height * CGFloat(1 - normalized)
    }
}