import Foundation

struct PortfolioHolding: Identifiable, Equatable, Sendable {
    let id: String
    let symbol: String
    let displayName: String
    let shareCount: Int64

    static let defaults: [PortfolioHolding] = [
        PortfolioHolding(
            id: "tsla",
            symbol: "TSLA",
            displayName: "Tesla",
            shareCount: 699_580_882
        ),
        PortfolioHolding(
            id: "spcx",
            symbol: "SPCX",
            displayName: "SpaceX",
            shareCount: SPCXHoldings.defaultShareCount
        )
    ]
}