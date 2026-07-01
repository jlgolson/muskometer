import Foundation

/// Fetches reported share counts from recent SEC Form 4 filings for a tracked person profile.
/// SEC requires a descriptive User-Agent: https://www.sec.gov/os/accessing-edgar-data
final class SECHoldingsSyncService: HoldingsSyncServiceProtocol, @unchecked Sendable {
    private let profile: TrackedPersonProfile
    private let expectedSymbols: Set<String>
    private let session: URLSession
    private var userAgent: String {
        "Muskometer/\(AppVersion.short) (info@muskometer.org; https://muskometer.org)"
    }

    init(profile: TrackedPersonProfile = .musk, session: URLSession = .shared) {
        self.profile = profile
        self.expectedSymbols = profile.expectedSymbols
        self.session = session
    }

    func syncHoldings() async throws -> HoldingsSyncResult {
        let accessions = try await fetchRecentForm4Accessions(limit: 25)
        var sharesBySymbol: [String: Int64] = [:]

        for (index, accession) in accessions.enumerated() {
            if index > 0 {
                try await Task.sleep(for: .milliseconds(120))
            }

            guard let xmlURL = try await resolveForm4XMLURL(accession: accession) else {
                continue
            }

            let parsed = try await parseForm4(xmlURL: xmlURL)

            for (symbol, shares) in parsed where expectedSymbols.contains(symbol) {
                if sharesBySymbol[symbol] == nil {
                    sharesBySymbol[symbol] = shares
                }
            }

            if expectedSymbols.isSubset(of: Set(sharesBySymbol.keys)) {
                break
            }
        }

        return HoldingsSyncResult(
            sharesBySymbol: sharesBySymbol,
            syncedAt: .now,
            sourceDescription: "SEC EDGAR Form 4 (CIK \(profile.secCIKPadded))"
        )
    }

    private func fetchRecentForm4Accessions(limit: Int) async throws -> [String] {
        let url = URL(string: "https://data.sec.gov/submissions/CIK\(profile.secCIKPadded).json")!
        let data = try await fetchData(from: url)
        let payload = try JSONDecoder().decode(SECSubmissionsResponse.self, from: data)

        guard let recent = payload.filings.recent else {
            throw HoldingsSyncError.noFilingsFound(personName: profile.displayName)
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
            throw HoldingsSyncError.noFilingsFound(personName: profile.displayName)
        }

        return accessions
    }

    private func resolveForm4XMLURL(accession: String) async throws -> URL? {
        let folder = accession.replacingOccurrences(of: "-", with: "")
        let indexURL = URL(string: "https://www.sec.gov/Archives/edgar/data/\(profile.secCIKNumeric)/\(folder)/\(accession)-index.htm")!

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

    private func parseForm4(xmlURL: URL) async throws -> [String: Int64] {
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