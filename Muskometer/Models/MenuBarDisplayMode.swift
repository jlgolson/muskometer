import Foundation

enum MenuBarDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case combinedDollars
    case combinedPercent
    case splitDollars
    case splitPercent
    case totalWorth

    var id: String { rawValue }

    var label: String {
        switch self {
        case .combinedDollars:
            return "Combined $ gain"
        case .combinedPercent:
            return "Combined % gain"
        case .splitDollars:
            return "Split $ gains"
        case .splitPercent:
            return "Split % gains"
        case .totalWorth:
            return "Total worth"
        }
    }

    /// Next mode in Settings picker order, wrapping after the last case.
    var next: MenuBarDisplayMode {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else { return .combinedDollars }
        return all[(index + 1) % all.count]
    }
}