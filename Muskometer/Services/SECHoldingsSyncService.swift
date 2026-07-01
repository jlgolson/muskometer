import Foundation

/// Fetches Elon Musk's reported TSLA / SPCX share counts from recent SEC Form 4 filings.
/// SEC requires a descriptive User-Agent: https://www.sec.gov/os/accessing-edgar-data
final class SECHoldingsSyncService: HoldingsSyncServiceProtocol, @unchecked Sendable {
    private let session: URLSession
    private let muskCIKPadded = "0001494730"
    private let muskCIKNumeric = "1494730"
    private let userAgent = "Muskometer/0.1.0 (info@muskometer.org; https://muskometer.org)"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func syncHoldings() async throws -> HoldingsSyncResult {
        let accessions = try await fetchRecentForm4Accessions(limit: 25)
        var tslaShares: Int64?
        var spcxShares: Int64?

        for (index, accession) in accessions.enumerated() {
            if index > 0 {
                try await Task.sleep(for: .milliseconds(120))
            }

            guard let xmlURL = try await resolveForm4XMLURL(accession: accession) else {
                continue
            }

            let parsed = try await parseForm4(xmlURL: xmlURL)

            if parsed.tslaShares != nil, tslaShares == nil {
                tslaShares = parsed.tslaShares
            }
            if parsed.spcxShares != nil, spcxShares == nil {
                spcxShares = parsed.spcxShares
            }

            if tslaShares != nil, spcxShares != nil {
                break
            }
        }

        return HoldingsSyncResult(
            tslaShares: tslaShares,
            spcxShares: spcxShares,
            syncedAt: .now,
            sourceDescription: "SEC EDGAR Form 4 (CIK \(muskCIKPadded))"
        )
    }

    private func fetchRecentForm4Accessions(limit: Int) async throws -> [String] {
        let url = URL(string: "https://data.sec.gov/submissions/CIK\(muskCIKPadded).json")!
        let data = try await fetchData(from: url)
        let payload = try JSONDecoder().decode(SECSubmissionsResponse.self, from: data)

        guard let recent = payload.filings.recent else {
            throw HoldingsSyncError.noFilingsFound
        }

        var accessions: [String] = []
        accessions.reserveCapacity(limit)

        for index in recent.form.indices {
            guard index < recent.accessionNumber.count else { continue }
            guard recent.form[index] == "4" else { continue }
            accessions.append(recent.accessionNumber[index])
            if accessions.count >= limit { break }
        }

        guard !accessions.isEmpty else {
            throw HoldingsSyncError.noFilingsFound
        }

        return accessions
    }

    private func resolveForm4XMLURL(accession: String) async throws -> URL? {
        let folder = accession.replacingOccurrences(of: "-", with: "")
        let indexURL = URL(string: "https://www.sec.gov/Archives/edgar/data/\(muskCIKNumeric)/\(folder)/\(accession)-index.htm")!

        let html = String(data: try await fetchData(from: indexURL), encoding: .utf8) ?? ""
        let pattern = #"href="(/Archives/edgar/data/\d+/\d+/[^"]+\.xml)""#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, range: range)

        for match in matches {
            guard let hrefRange = Range(match.range(at: 1), in: html) else { continue }
            let href = String(html[hrefRange])
            guard !href.contains("xslF345"), href.contains(".xml") else { continue }
            return URL(string: "https://www.sec.gov\(href)")
        }

        return nil
    }

    private func parseForm4(xmlURL: URL) async throws -> (tslaShares: Int64?, spcxShares: Int64?) {
        let data = try await fetchData(from: xmlURL)
        let parser = Form4OwnershipParser(data: data)
        return parser.parse()
    }

    private func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw HoldingsSyncError.invalidResponse
            }
            return data
        } catch let error as HoldingsSyncError {
            throw error
        } catch {
            throw HoldingsSyncError.networkError(underlying: error)
        }
    }
}

// MARK: - SEC JSON models

private struct SECSubmissionsResponse: Decodable {
    let filings: SECFilings
}

private struct SECFilings: Decodable {
    let recent: SECRecentFilings?
}

private struct SECRecentFilings: Decodable {
    let form: [String]
    let accessionNumber: [String]
}