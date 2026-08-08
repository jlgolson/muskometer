import Foundation

/// Best-effort fetch of issuer shares outstanding from SEC companyfacts (for market-cap parity).
/// Orthogonal to Form 4 ownership: failures never throw out of `fetchOutstanding`.
protocol IssuerOutstandingSyncServiceProtocol: Sendable {
    func fetchOutstanding(for specs: [TrackedHoldingSpec]) async -> [String: Int64]
}

/// Fetches companyfacts JSON per issuer CIK and resolves point-in-time common shares outstanding.
final class IssuerOutstandingSyncService: IssuerOutstandingSyncServiceProtocol, @unchecked Sendable {
    private let session: URLSession
    private var userAgent: String {
        "Muskometer/\(AppVersion.short) (info@muskometer.org; https://muskometer.org)"
    }

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Returns symbol → positive outstanding for specs that resolve successfully.
    /// Specs without an issuer CIK, network/HTTP failures, and unresolved payloads are omitted.
    func fetchOutstanding(for specs: [TrackedHoldingSpec]) async -> [String: Int64] {
        var results: [String: Int64] = [:]
        var requestIndex = 0

        for spec in specs {
            guard let cik = spec.issuerCIKPadded, !cik.isEmpty else { continue }

            if requestIndex > 0 {
                try? await Task.sleep(for: .milliseconds(120))
            }
            requestIndex += 1

            guard let shares = await fetchOutstanding(cikPadded: cik), shares > 0 else {
                continue
            }
            results[spec.symbol.uppercased()] = shares
        }

        return results
    }

    // MARK: - Private

    private func fetchOutstanding(cikPadded: String) async -> Int64? {
        guard let url = URL(string: "https://data.sec.gov/api/xbrl/companyfacts/CIK\(cikPadded).json") else {
            return nil
        }
        do {
            let data = try await fetchData(from: url)
            return CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: data)
        } catch {
            return nil
        }
    }

    private func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
