import Foundation

/// Selects the tradable price from Yahoo Finance chart meta for a given session.
///
/// RTH-only product: always uses `regularMarketPrice`. Pre/post session cases fall
/// through to regular so extended-hours price fields are never selected.
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
        case .regular, .preMarket, .postMarket, .closed:
            return meta.regularMarketPrice
        }
    }

    static func previousClose(from meta: Meta) -> Double? {
        meta.chartPreviousClose ?? meta.previousClose
    }
}
