import Foundation

enum MenuBarMoodResolver {
    static func resolve(
        snapshot: GainsSnapshot?,
        displayMode: MenuBarDisplayMode,
        moodEnabled: Bool,
        dollarThreshold: Double,
        percentThreshold: Double
    ) -> MenuBarMoodLevel {
        guard moodEnabled, let snapshot else { return .calm }

        let basis = MenuBarMoodBasis.forDisplayMode(displayMode)
        let magnitude = basis.magnitude(from: snapshot)
        let threshold = basis.threshold(
            dollarThreshold: dollarThreshold,
            percentThreshold: percentThreshold
        )

        return magnitude >= threshold ? .bigDay : .calm
    }
}