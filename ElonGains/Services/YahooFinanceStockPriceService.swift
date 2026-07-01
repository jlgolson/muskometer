import Foundation

final class YahooFinanceStockPriceService: StockPriceServiceProtocol, @unchecked Sendable {
    private let session: URLSession
    private let baseURL = "https://query1.finance.yahoo.com/v8/finance/chart"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchQuotes(for symbols: [String]) async throws -> [StockQuote] {
        try await withThrowingTaskGroup(of: StockQuote.self) { group in
            for symbol in symbols {
                group.addTask {
                    try await self.fetchQuote(for: symbol)
                }
            }

            var quotes: [StockQuote] = []
            quotes.reserveCapacity(symbols.count)

            for try await quote in group {
                quotes.append(quote)
            }

            return quotes.sorted { lhs, rhs in
                symbols.firstIndex(of: lhs.symbol) ?? 0 < symbols.firstIndex(of: rhs.symbol) ?? 0
            }
        }
    }

    private func fetchQuote(for symbol: String) async throws -> StockQuote {
        var components = URLComponents(string: "\(baseURL)/\(symbol)")
        components?.queryItems = [
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "range", value: "1d")
        ]

        guard let url = components?.url else {
            throw StockPriceServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw StockPriceServiceError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw StockPriceServiceError.invalidResponse
        }

        return try parseQuote(data: data, symbol: symbol)
    }

    private func parseQuote(data: Data, symbol: String) throws -> StockQuote {
        let decoder = JSONDecoder()
        let payload = try decoder.decode(YahooChartResponse.self, from: data)

        guard let result = payload.chart.result?.first,
              let meta = result.meta,
              let currentPrice = meta.regularMarketPrice,
              let previousClose = meta.chartPreviousClose ?? meta.previousClose else {
            throw StockPriceServiceError.missingSymbol(symbol)
        }

        return StockQuote(
            symbol: symbol,
            displayName: meta.shortName ?? symbol,
            currentPrice: currentPrice,
            previousClose: previousClose,
            currency: meta.currency ?? "USD"
        )
    }
}

// MARK: - Yahoo Finance response models

private struct YahooChartResponse: Decodable {
    let chart: YahooChart
}

private struct YahooChart: Decodable {
    let result: [YahooChartResult]?
}

private struct YahooChartResult: Decodable {
    let meta: YahooChartMeta?
}

private struct YahooChartMeta: Decodable {
    let shortName: String?
    let currency: String?
    let regularMarketPrice: Double?
    let chartPreviousClose: Double?
    let previousClose: Double?
}