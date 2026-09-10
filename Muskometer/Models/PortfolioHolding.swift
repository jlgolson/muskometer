import Foundation

struct PortfolioHolding: Identifiable, Equatable, Sendable {
    let id: String
    let symbol: String
    let displayName: String
    let shareCount: Int64
}
