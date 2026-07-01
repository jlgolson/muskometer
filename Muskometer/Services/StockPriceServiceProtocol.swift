import Foundation

enum StockPriceServiceError: LocalizedError {
    case invalidResponse
    case missingSymbol(String)
    case networkError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Received an invalid response from Yahoo Finance."
        case .missingSymbol(let symbol):
            return "No quote data found for \(symbol)."
        case .networkError(let underlying):
            return underlying.localizedDescription
        }
    }
}

protocol StockPriceServiceProtocol: Sendable {
    func fetchQuotes(for symbols: [String]) async throws -> [StockQuote]
}