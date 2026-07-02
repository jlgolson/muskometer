import Foundation

/// A net-worth threshold crossed by combined holdings value.
/// Produced by `NetWorthMilestoneTracker`; consumed by `MilestoneCelebrationOverlay`.
struct NetWorthMilestone: Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let thresholdLabel: String

    init(id: String, title: String, thresholdLabel: String) {
        self.id = id
        self.title = title
        self.thresholdLabel = thresholdLabel
    }
}