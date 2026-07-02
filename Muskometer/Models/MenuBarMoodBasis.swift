import Foundation

enum MenuBarMoodBasis: Equatable, Sendable {
    case dollars
    case percent

    static func forDisplayMode(_ mode: MenuBarDisplayMode) -> MenuBarMoodBasis {
        switch mode {
        case .combinedDollars, .splitDollars, .totalWorth:
            return .dollars
        case .combinedPercent, .splitPercent:
            return .percent
        }
    }

    func magnitude(from snapshot: GainsSnapshot) -> Double {
        switch self {
        case .dollars:
            return abs(snapshot.combinedPaperGain)
        case .percent:
            return abs(snapshot.combinedPercentChange)
        }
    }

    func threshold(dollarThreshold: Double, percentThreshold: Double) -> Double {
        switch self {
        case .dollars:
            return dollarThreshold
        case .percent:
            return percentThreshold
        }
    }
}