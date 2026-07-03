import Foundation

/// Selects the tradable price from Yahoo Finance chart meta for a given session.
enum QuotePriceResolver {
    struct Meta: Equatable, Sendable {
        let regularMarketPrice: Double?
        let preMarketPrice: Double?
        let postMarketPrice: Double?
        let chartPreviousClose: Double?
        let previousClose: Double?
    }

    static func currentPrice(from meta: Meta, session: TradingSession) -> Double? {
        switch session {
        case .regular:
            return meta.regularMarketPrice
        case .preMarket:
            return meta.preMarketPrice ?? meta.regularMarketPrice
        case .postMarket:
            return meta.postMarketPrice ?? meta.regularMarketPrice
        case .closed:
            return meta.regularMarketPrice
        }
    }

    static func previousClose(from meta: Meta) -> Double? {
        meta.chartPreviousClose ?? meta.previousClose
    }
}