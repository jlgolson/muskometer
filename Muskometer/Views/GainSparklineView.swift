import SwiftUI

/// Intraday gain with an explicit observed-range scale and sign-aware shading.
struct GainSparklineView: View {
    let samples: [GainSample]
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GainSparklineContent(samples: samples, colorScheme: colorScheme,
                             contrast: contrast, reduceTransparency: reduceTransparency)
    }
}

/// Explicit rendering inputs keep accessibility presentation independently testable;
/// the shared public-facing view always supplies the live SwiftUI environment.
struct GainSparklineContent: View {
    let samples: [GainSample]
    let colorScheme: ColorScheme
    let contrast: ColorSchemeContrast
    let reduceTransparency: Bool

    private let height: CGFloat = 60
    private let gainPositive = Color("GainPositive")
    private let gainNegative = Color("GainNegative")

    var body: some View {
        if !samples.isEmpty {
            VStack(spacing: 3) {
                Canvas { context, size in
                    Self.draw(samples: samples, size: size, gainPositive: gainPositive,
                              gainNegative: gainNegative, highContrast: contrast == .increased,
                              reduceTransparency: reduceTransparency, dark: colorScheme == .dark,
                              in: &context)
                }
                .frame(height: height)
                HStack(spacing: 4) {
                    Text("Range")
                    Spacer(minLength: 4)
                    Text("\(CurrencyFormatter.formatCurrency(domain.minGain)) – \(CurrencyFormatter.formatCurrency(domain.maxGain))")
                        .monospacedDigit()
                }
                .font(.caption2)
                .foregroundStyle(contrast == .increased ? .primary : .secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var domain: SparklineLayout {
        SparklineLayout(samples: samples, size: .zero)
    }

    private var accessibilityLabel: String {
        guard let last = samples.last?.combinedPaperGain else { return "Intraday gain sparkline" }
        let side = last >= 0 ? "above" : "below"
        return "Intraday gain sparkline, \(side) breakeven, current \(CurrencyFormatter.formatCurrency(last)), displayed range \(CurrencyFormatter.formatCurrency(domain.minGain)) to \(CurrencyFormatter.formatCurrency(domain.maxGain))"
    }
}

private struct SparklineSegment {
    let points: [GainSample]
    let isPositive: Bool
}

private extension GainSparklineContent {
    static func draw(
        samples: [GainSample], size: CGSize, gainPositive: Color, gainNegative: Color,
        highContrast: Bool, reduceTransparency: Bool, dark: Bool,
        in context: inout GraphicsContext
    ) {
        guard !samples.isEmpty, size.width > 0, size.height > 0 else { return }
        let layout = SparklineLayout(samples: samples, size: size)
        let segments = segments(from: samples)
        let crossesZero = samples.contains { $0.combinedPaperGain < 0 }
            && samples.contains { $0.combinedPaperGain > 0 }

        // All fills precede reference lines, rounded strokes and the endpoint.
        for segment in segments where segment.points.count >= 2 && !reduceTransparency {
            let points = segment.points.map { layout.point(for: $0) }
            let color = segment.isPositive ? gainPositive : gainNegative
            let baseline = crossesZero ? layout.zeroY : (segment.isPositive ? layout.bottomY : layout.topY)
            var fill = Path()
            fill.addLines(points)
            fill.addLine(to: CGPoint(x: points.last!.x, y: baseline))
            fill.addLine(to: CGPoint(x: points.first!.x, y: baseline))
            fill.closeSubpath()
            let opacity = highContrast ? 0.32 : (dark ? 0.25 : 0.18)
            context.fill(fill, with: .linearGradient(
                Gradient(colors: [color.opacity(opacity), color.opacity(0.015)]),
                startPoint: CGPoint(x: 0, y: segment.isPositive ? layout.topY : layout.bottomY),
                endPoint: CGPoint(x: 0, y: baseline)))
        }
        if layout.containsZero {
            var zero = Path()
            zero.move(to: CGPoint(x: layout.leftX, y: layout.zeroY))
            zero.addLine(to: CGPoint(x: layout.rightX, y: layout.zeroY))
            context.stroke(zero, with: .color(.secondary.opacity(highContrast ? 0.7 : 0.4)),
                           style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
        }
        for segment in segments where segment.points.count >= 2 {
            var line = Path()
            line.addLines(segment.points.map { layout.point(for: $0) })
            context.stroke(line, with: .color(segment.isPositive ? gainPositive : gainNegative),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        if let last = samples.last {
            let point = layout.point(for: last)
            let color = last.combinedPaperGain >= 0 ? gainPositive : gainNegative
            let dot = Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
            context.fill(dot, with: .color(color))
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

struct SparklineLayout {
    let minGain: Double
    let maxGain: Double
    let minTime: TimeInterval
    let maxTime: TimeInterval
    let size: CGSize

    init(samples: [GainSample], size: CGSize) {
        let gains = samples.map(\.combinedPaperGain)
        let rawMin = gains.min() ?? 0
        let rawMax = gains.max() ?? 0
        let midpoint = rawMin + (rawMax - rawMin) / 2
        let minimumSpan = max(1, max(abs(rawMin), abs(rawMax)) * 0.01)
        let span = max(rawMax - rawMin, minimumSpan)
        let halfRange = span * 0.58

        self.minGain = midpoint - halfRange
        self.maxGain = midpoint + halfRange
        self.minTime = samples.first?.timestamp.timeIntervalSince1970 ?? 0
        self.maxTime = samples.last?.timestamp.timeIntervalSince1970 ?? self.minTime
        self.size = size
    }

    // Four points keep the rounded stroke and three-point endpoint inside the plot.
    var leftX: CGFloat { min(4, max(0, size.width) / 2) }
    var rightX: CGFloat { max(leftX, size.width - leftX) }
    var topY: CGFloat { min(4, max(0, size.height) / 2) }
    var bottomY: CGFloat { max(topY, size.height - topY) }
    var containsZero: Bool { minGain <= 0 && maxGain >= 0 }

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
        guard maxTime > minTime else { return (leftX + rightX) / 2 }
        let t = min(1, max(0, (time - minTime) / (maxTime - minTime)))
        return leftX + CGFloat(t) * (rightX - leftX)
    }

    private func y(for gain: Double) -> CGFloat {
        let span = max(maxGain - minGain, 1)
        let normalized = min(1, max(0, (gain - minGain) / span))
        return topY + (bottomY - topY) * CGFloat(1 - normalized)
    }
}
