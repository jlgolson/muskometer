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
}