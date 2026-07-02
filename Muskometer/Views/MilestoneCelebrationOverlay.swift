import SwiftUI

/// One-shot Canvas confetti overlay for net-worth milestones. Non-interactive.
struct MilestoneCelebrationOverlay: View {
    let milestone: NetWorthMilestone?
    var onFinished: (() -> Void)? = nil

    @State private var pieces: [ConfettiPiece] = []
    @State private var animationStart: Date?
    @State private var activeMilestoneID: String?
    @State private var finishTask: Task<Void, Never>?

    private let animationDuration: TimeInterval = 2.8
    private let pieceCount = 140

    var body: some View {
        ZStack {
            if let milestone, animationStart != nil {
                milestoneBanner(milestone)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }

            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: animationStart == nil)) { timeline in
                Canvas { context, size in
                    guard let start = animationStart else { return }

                    let elapsed = timeline.date.timeIntervalSince(start)
                    guard elapsed <= animationDuration else { return }

                    let progress = elapsed / animationDuration
                    let fade = 1 - max(0, (progress - 0.55) / 0.45)

                    for piece in pieces {
                        drawPiece(piece, elapsed: elapsed, fade: fade, canvasSize: size, in: &context)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            if let milestone {
                beginCelebration(for: milestone)
            }
        }
        .onChange(of: milestone?.id) { _, newValue in
            guard let milestone, newValue != activeMilestoneID else { return }
            beginCelebration(for: milestone)
        }
        .onDisappear {
            finishTask?.cancel()
            finishTask = nil
        }
    }

    private func milestoneBanner(_ milestone: NetWorthMilestone) -> some View {
        VStack(spacing: 4) {
            Text(milestone.title)
                .font(.system(.title3, design: .rounded, weight: .bold))

            Text(milestone.thresholdLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        }
    }

    private func beginCelebration(for milestone: NetWorthMilestone) {
        finishTask?.cancel()

        activeMilestoneID = milestone.id
        pieces = makePieces(count: pieceCount)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            animationStart = .now
        }

        finishTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(animationDuration))
            guard !Task.isCancelled, activeMilestoneID == milestone.id else { return }
            completeCelebration()
        }
    }

    private func completeCelebration() {
        animationStart = nil
        pieces = []
        activeMilestoneID = nil
        onFinished?()
    }

    private func makePieces(count: Int) -> [ConfettiPiece] {
        let palette: [Color] = [
            Color("GainPositive"),
            Color("GainNegative"),
            .yellow,
            .orange,
            .pink,
            .cyan,
            .purple,
            .mint
        ]

        return (0..<count).map { index in
            let angle = CGFloat.random(in: (-.pi * 0.95)...(-.pi * 0.05))
            return ConfettiPiece(
                origin: CGPoint(
                    x: CGFloat.random(in: 0.35...0.65),
                    y: CGFloat.random(in: 0.08...0.22)
                ),
                color: palette[index % palette.count],
                size: CGSize(
                    width: CGFloat.random(in: 5...9),
                    height: CGFloat.random(in: 8...14)
                ),
                launchAngle: angle,
                launchSpeed: CGFloat.random(in: 180...360),
                spinRate: CGFloat.random(in: -9...9),
                phaseOffset: CGFloat.random(in: 0...(2 * .pi)),
                isCircle: index.isMultiple(of: 3)
            )
        }
    }

    private func drawPiece(
        _ piece: ConfettiPiece,
        elapsed: TimeInterval,
        fade: Double,
        canvasSize: CGSize,
        in context: inout GraphicsContext
    ) {
        let gravity: CGFloat = 420
        let t = CGFloat(elapsed)
        let originX = piece.origin.x * canvasSize.width
        let originY = piece.origin.y * canvasSize.height
        let vx = cos(piece.launchAngle) * piece.launchSpeed
        let vy = sin(piece.launchAngle) * piece.launchSpeed
        let x = originX + vx * t
        let y = originY + vy * t + 0.5 * gravity * t * t

        var pieceContext = context
        pieceContext.opacity = fade

        pieceContext.translateBy(x: x, y: y)
        pieceContext.rotate(by: .radians(piece.spinRate * t + piece.phaseOffset))

        let rect = CGRect(
            x: -piece.size.width / 2,
            y: -piece.size.height / 2,
            width: piece.size.width,
            height: piece.size.height
        )

        if piece.isCircle {
            pieceContext.fill(Path(ellipseIn: rect), with: .color(piece.color))
        } else {
            pieceContext.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(piece.color))
        }
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let origin: CGPoint
    let color: Color
    let size: CGSize
    let launchAngle: CGFloat
    let launchSpeed: CGFloat
    let spinRate: CGFloat
    let phaseOffset: CGFloat
    let isCircle: Bool
}

#if DEBUG
struct MilestoneCelebrationOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))

            VStack(spacing: 8) {
                Text("Combined today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("+$46.6B")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }

            MilestoneCelebrationOverlay(
                milestone: NetWorthMilestone(
                    id: "preview-500b",
                    title: "Half a trillion!",
                    thresholdLabel: "$500B net worth"
                )
            )
        }
        .frame(width: 360, height: 220)
        .padding()
    }
}
#endif