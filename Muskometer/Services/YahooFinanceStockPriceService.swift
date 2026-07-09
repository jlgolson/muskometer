import Foundation

final class YahooFinanceStockPriceService: StockPriceServiceProtocol, @unchecked Sendable {
    private let session: URLSession
    private let marketHours: any MarketHoursServiceProtocol
    private let dateProvider: () -> Date
    private let baseURL = "https://query1.finance.yahoo.com/v8/finance/chart"

    init(
        session: URLSession = .shared,
        marketHours: any MarketHoursServiceProtocol = MarketHoursService(),
        dateProvider: @escaping () -> Date = { .now }
    ) {
        self.session = session
        self.marketHours = marketHours
        self.dateProvider = dateProvider
    }

    func fetchQuotes(for symbols: [String]) async throws -> [StockQuote] {
        // Collect per-symbol Results so one flaky symbol (e.g. SPCX) cannot
        // abort the whole batch and wipe peers that already succeeded (e.g. TSLA).
        let results: [Result<StockQuote, Error>] = await withTaskGroup(
            of: Result<StockQuote, Error>.self
        ) { group in
            for symbol in symbols {
                group.addTask {
                    do {
                        return .success(try await self.fetchQuote(for: symbol))
                    } catch {
                        return .failure(error)
                    }
                }
            }

            var collected: [Result<StockQuote, Error>] = []
            collected.reserveCapacity(symbols.count)
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        return try QuoteBatchMerger.merge(results: results, symbolOrder: symbols)
    }

    private func fetchQuote(for symbol: String) async throws -> StockQuote {
        var components = URLComponents(string: "\(baseURL)/\(symbol)")
        components?.queryItems = [
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "range", value: "1d"),
            URLQueryItem(name: "includePrePost", value: "true")
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
              let meta = result.meta else {
            throw StockPriceServiceError.missingSymbol(symbol)
        }

        let quoteMeta = QuotePriceResolver.Meta(
            regularMarketPrice: meta.regularMarketPrice,
            preMarketPrice: meta.preMarketPrice,
            postMarketPrice: meta.postMarketPrice,
            chartPreviousClose: meta.chartPreviousClose,
            previousClose: meta.previousClose
        )

        // Prefer Yahoo's per-quote marketState (handles early closes / clock skew);
        // fall back to local session when missing or unrecognized.
        let tradingSession = YahooMarketStateMapper.tradingSession(from: meta.marketState)
            ?? marketHours.currentSession(at: dateProvider())

        guard let currentPrice = QuotePriceResolver.currentPrice(from: quoteMeta, session: tradingSession),
              let previousClose = QuotePriceResolver.previousClose(from: quoteMeta) else {
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

// MARK: - Yahoo marketState mapping

/// Maps Yahoo Finance chart meta `marketState` strings to local `TradingSession`.
///
/// RTH-only: only `REGULAR` maps to `.regular`. PRE/POST/PREPRE/POSTPOST and other
/// non-regular states map to `.closed` so extended-hours price fields are never selected.
/// Returns `nil` when the value is missing or unrecognized so callers can fall back
/// to local market hours.
enum YahooMarketStateMapper {
    static func tradingSession(from marketState: String?) -> TradingSession? {
        guard let raw = marketState?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        switch raw.uppercased() {
        case "REGULAR":
            return .regular
        case "PRE", "POST", "CLOSED", "PREPRE", "POSTPOST", "HOLIDAY", "BREAK":
            return .closed
        default:
            return nil
        }
    }
}

// MARK: - Batch merge helper

/// Merges per-symbol quote `Result`s into a batch response.
///
/// - Returns successful quotes even when some peers fail (partial success).
/// - Throws only when every requested symbol failed (prefers a network error
///   when present among the failures).
/// - Empty `symbolOrder` (nothing requested) yields an empty array.
enum QuoteBatchMerger {
    static func merge(
        results: [Result<StockQuote, Error>],
        symbolOrder: [String]
    ) throws -> [StockQuote] {
        var quotes: [StockQuote] = []
        quotes.reserveCapacity(results.count)

        var firstError: Error?
        var firstNetworkError: Error?

        for result in results {
            switch result {
            case .success(let quote):
                quotes.append(quote)
            case .failure(let error):
                if firstError == nil {
                    firstError = error
                }
                if firstNetworkError == nil, isNetworkError(error) {
                    firstNetworkError = error
                }
            }
        }

        guard !quotes.isEmpty else {
            if symbolOrder.isEmpty {
                return []
            }
            throw firstNetworkError
                ?? firstError
                ?? StockPriceServiceError.invalidResponse
        }

        return quotes.sorted { lhs, rhs in
            let leftIndex = symbolOrder.firstIndex(of: lhs.symbol) ?? Int.max
            let rightIndex = symbolOrder.firstIndex(of: rhs.symbol) ?? Int.max
            return leftIndex < rightIndex
        }
    }

    private static func isNetworkError(_ error: Error) -> Bool {
        if case .networkError = error as? StockPriceServiceError {
            return true
        }
        return error is URLError
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
    let preMarketPrice: Double?
    let postMarketPrice: Double?
    let marketState: String?
    let chartPreviousClose: Double?
    let previousClose: Double?
}