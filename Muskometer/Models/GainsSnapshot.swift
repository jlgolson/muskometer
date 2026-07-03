import Foundation

struct HoldingGain: Identifiable, Equatable, Sendable {
    let id: String
    let symbol: String
    let displayName: String
    let shareCount: Int64
    let quote: StockQuote

    var paperGain: Double {
        quote.paperGain(shareCount: shareCount)
    }

    var marketValue: Double {
        Double(shareCount) * quote.currentPrice
    }
}

struct GainsSnapshot: Equatable, Sendable {
    let holdings: [HoldingGain]
    let lastUpdated: Date
    let tradingSession: TradingSession

    var marketIsOpen: Bool {
        tradingSession == .regular
    }

    var isQuotable: Bool {
        tradingSession.isQuotable
    }

    var combinedPaperGain: Double {
        holdings.reduce(0) { $0 + $1.paperGain }
    }

    var combinedMarketValue: Double {
        holdings.reduce(0) { $0 + $1.marketValue }
    }

    var priorCloseValue: Double {
        holdings.reduce(0) { $0 + Double($1.shareCount) * $1.quote.previousClose }
    }

    var combinedPercentChange: Double {
        guard priorCloseValue > 0 else { return 0 }
        return (combinedPaperGain / priorCloseValue) * 100
    }

    var isPositive: Bool {
        combinedPaperGain >= 0
    }
}