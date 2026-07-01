import Foundation

struct StockQuote: Equatable, Sendable {
    let symbol: String
    let displayName: String
    let currentPrice: Double
    let previousClose: Double
    let currency: String

    var priceChange: Double {
        currentPrice - previousClose
    }

    var percentChange: Double {
        guard previousClose != 0 else { return 0 }
        return (priceChange / previousClose) * 100
    }

    func paperGain(shareCount: Int64) -> Double {
        priceChange * Double(shareCount)
    }
}