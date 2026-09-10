import Foundation

/// Fetches reported share counts from recent SEC Form 4 filings for a tracked person profile.
/// SEC requires a descriptive User-Agent: https://www.sec.gov/os/accessing-edgar-data
final class SECHoldingsSyncService: HoldingsSyncServiceProtocol, @unchecked Sendable {
    /// Max Form 4 / 4A accessions to scan per sync. Scanning continues through both verified anchors, even after both symbols have appeared.
    static let maxForm4AccessionsToScan = 100
    /// Metadata pages spend their own allowance even when they contain no new accessions.
    /// A sync therefore issues at most 1 + 10 + (2 * 100) = 211 HTTP requests.
    static let maxSubmissionArchivePagesToScan = 10
    /// Also bound descriptor traversal when the server repeats archive names.
    private static let maxSubmissionArchiveEntriesToInspect = 100

    private let profile: TrackedPersonProfile
    private let expectedSymbols: Set<String>
    private let session: URLSession
    private var userAgent: String {
        "Muskometer/\(AppVersion.short) (info@muskometer.org; https://muskometer.org)"
    }

    init(profile: TrackedPersonProfile = .musk, session: URLSession = MuskometerNetworking.ephemeralSession) {
        self.profile = profile
        self.expectedSymbols = profile.expectedSymbols
        self.session = session
    }

    /// Whether an EDGAR form type is a Form 4, including amendments (`4/A`).
    static func isForm4Filing(_ form: String) -> Bool {
        form == "4" || form == "4/A"
    }

    func syncHoldings() async throws -> HoldingsSyncResult {
        let pacing = SECRequestPacing()
        let submissionsURL = URL(string: "https://data.sec.gov/submissions/CIK\(profile.secCIKPadded).json")!
        let payload = try JSONDecoder().decode(SECSubmissionsResponse.self, from: await fetchData(from: submissionsURL, pacing: pacing))
        guard let recent = payload.filings.recent else {
            throw HoldingsSyncError.noFilingsFound(personName: profile.displayName)
        }
        var pending = try recent.entries()
        var archives = Array((payload.filings.files ?? []).sorted { $0.filingTo > $1.filingTo }
            .prefix(Self.maxSubmissionArchiveEntriesToInspect))
        var visitedArchives = Set<String>()
        var visited = Set<String>()
        var reached = Set<String>()
        var invalid = Set<String>()
        var filings: [String: [DatedOwnershipFiling]] = [:]
        var observationCount = 0

        while visited.count < Self.maxForm4AccessionsToScan && !expectedSymbols.isSubset(of: reached) {
            try Task.checkCancellation()
            if pending.isEmpty {
                guard !archives.isEmpty, visitedArchives.count < Self.maxSubmissionArchivePagesToScan else { break }
                let archive = archives.removeFirst()
                guard visitedArchives.insert(archive.name).inserted else { continue }
                guard archive.name.range(of: #"^CIK[0-9]+-submissions-[0-9]+\.json$"#, options: .regularExpression) != nil else {
                    invalid.formUnion(expectedSymbols.subtracting(reached)); break
                }
                let url = URL(string: "https://data.sec.gov/submissions/\(archive.name)")!
                let data = try await fetchData(from: url, pacing: pacing)
                pending = try JSONDecoder().decode(SECRecentFilings.self, from: data).entries()
                continue
            }
            let metadata = pending.removeFirst()
            guard visited.insert(metadata.accession).inserted else { continue }
            guard let xmlURL = try await resolveForm4XMLURL(accession: metadata.accession, pacing: pacing) else {
                invalid.formUnion(expectedSymbols.subtracting(reached)); continue
            }
            let data = try await fetchData(from: xmlURL, pacing: pacing)
            guard let document = Form4OwnershipParser(data: data).observations() else {
                invalid.formUnion(expectedSymbols.subtracting(reached)); continue
            }
            let symbol = document.symbol
            guard expectedSymbols.contains(symbol), !reached.contains(symbol), let anchor = OwnershipAnchor.all[symbol] else { continue }
            observationCount += document.observations.count
            guard observationCount <= 10_000 else { invalid.formUnion(expectedSymbols.subtracting(reached)); break }
            if metadata.accession == anchor.accession {
                reached.insert(symbol)
                if metadata.filed != anchor.filed || metadata.form != "4" || document.hasUnresolvedRelevantRows || document.observations != anchor.observations {
                    invalid.insert(symbol)
                }
                continue
            }
            if document.hasUnresolvedRelevantRows || (document.documentType != nil && document.documentType != metadata.form) {
                invalid.insert(symbol)
            }
            filings[symbol, default: []].append(DatedOwnershipFiling(metadata: metadata, document: document))
        }
        var sharesBySymbol: [String: Int64] = [:]
        for symbol in expectedSymbols where reached.contains(symbol) && !invalid.contains(symbol) {
            guard let anchor = OwnershipAnchor.all[symbol], let total = OwnershipReconstruction.total(anchor: anchor, filings: filings[symbol] ?? []) else { continue }
            sharesBySymbol[symbol] = total
        }
        return HoldingsSyncResult(sharesBySymbol: sharesBySymbol, syncedAt: .now,
                                  sourceDescription: "SEC EDGAR Form 4 (CIK \(profile.secCIKPadded))")
    }

    private func resolveForm4XMLURL(accession: String, pacing: SECRequestPacing) async throws -> URL? {
        let folder = accession.replacingOccurrences(of: "-", with: "")
        let indexURL = URL(string: "https://www.sec.gov/Archives/edgar/data/\(profile.secCIKNumeric)/\(folder)/\(accession)-index.htm")!

        let html = String(data: try await fetchData(from: indexURL, pacing: pacing), encoding: .utf8) ?? ""
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

    private func fetchData(from url: URL, pacing: SECRequestPacing) async throws -> Data {
        try await pacing.wait()
        try Task.checkCancellation()
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw HoldingsSyncError.invalidResponse
            }
            return data
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as HoldingsSyncError {
            throw error
        } catch {
            try Task.checkCancellation()
            throw HoldingsSyncError.networkError(underlying: error)
        }
    }
}

// MARK: - SEC metadata and bounded request pacing

private actor SECRequestPacing {
    private var lastRequest: ContinuousClock.Instant?
    func wait() async throws {
        let clock = ContinuousClock()
        if let lastRequest { try await clock.sleep(until: lastRequest.advanced(by: .milliseconds(120))) }
        try Task.checkCancellation()
        lastRequest = clock.now
    }
}

private struct SECSubmissionsResponse: Decodable { let filings: SECFilings }
private struct SECFilings: Decodable {
    let recent: SECRecentFilings?
    let files: [SECSubmissionArchive]?
}
private struct SECSubmissionArchive: Decodable {
    let name: String
    let filingTo: String
}
private struct SECRecentFilings: Decodable {
    let form: [String]
    let accessionNumber: [String]
    let filingDate: [String]?
    let acceptanceDateTime: [String]?

    func entries() throws -> [SECFilingMetadata] {
        var result: [SECFilingMetadata] = []
        for index in form.indices where SECHoldingsSyncService.isForm4Filing(form[index]) {
            guard index < accessionNumber.count, let filingDate, index < filingDate.count,
                  let filed = OwnershipNumber.date(filingDate[index]), let acceptanceDateTime, index < acceptanceDateTime.count else {
                throw HoldingsSyncError.invalidResponse
            }
            let accepted = acceptanceDateTime[index]
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let fractionalDate = formatter.date(from: accepted)
            formatter.formatOptions = [.withInternetDateTime]
            guard let acceptedAt = fractionalDate ?? formatter.date(from: accepted),
                  accessionNumber[index].range(of: #"^[0-9]{10}-[0-9]{2}-[0-9]{6}$"#, options: .regularExpression) != nil else {
                throw HoldingsSyncError.invalidResponse
            }
            result.append(SECFilingMetadata(accession: accessionNumber[index], form: form[index], filed: filed, acceptedAt: acceptedAt))
        }
        return result.sorted { $0.acceptedAt == $1.acceptedAt ? $0.accession > $1.accession : $0.acceptedAt > $1.acceptedAt }
    }
}
private struct SECFilingMetadata {
    let accession: String
    let form: String
    let filed: String
    let acceptedAt: Date
}
private struct DatedOwnershipFiling {
    let metadata: SECFilingMetadata
    let document: OwnershipDocument
}

/// A reconstruction lasts one sync and is bounded by accession/observation budgets.
/// The immutable anchor is always the starting point; no prior sync result is fed back in.
private enum OwnershipReconstruction {
    private struct Event {
        let observation: OwnershipObservation
        let accession: String
        let filed: String
        let date: String
        var quantity: Int64
    }

    static func total(anchor: OwnershipAnchor, filings: [DatedOwnershipFiling]) -> Int64? {
        let knownBuckets = Set(anchor.observations.map(\.bucket))
        var events = anchor.observations.map {
            Event(observation: $0, accession: anchor.accession, filed: anchor.filed,
                  date: $0.effectiveDate ?? anchor.filed, quantity: $0.quantity)
        }
        for filing in filings {
            guard !filing.document.hasUnresolvedRelevantRows else { return nil }
            for observation in filing.document.observations {
                guard knownBuckets.contains(observation.bucket), let date = observation.effectiveDate,
                      date <= filing.metadata.filed else { return nil }
                if filing.metadata.form == "4" {
                    events.append(Event(observation: observation, accession: filing.metadata.accession,
                                        filed: filing.metadata.filed, date: date, quantity: observation.quantity))
                }
            }
        }
        var corrections: [Int: Set<Int64>] = [:]
        for filing in filings where filing.metadata.form == "4/A" {
            guard let originalDate = filing.document.originalSubmissionDate, originalDate <= filing.metadata.filed else { return nil }
            for observation in filing.document.observations {
                // Original-submission date alone is not an accession. Require exactly one
                // original bucket/date row, including across multiple filings on that date.
                let matches = events.indices.filter {
                    events[$0].filed == originalDate && events[$0].observation.bucket == observation.bucket &&
                    events[$0].observation.effectiveDate == observation.effectiveDate
                }
                guard matches.count == 1, let index = matches.first else { return nil }
                corrections[index, default: []].insert(observation.quantity)
            }
        }
        for (index, values) in corrections {
            if events.contains(where: { $0.observation.bucket == events[index].observation.bucket && $0.date > events[index].date }) { continue }
            guard values.count == 1, let value = values.first else { return nil }
            events[index].quantity = value
        }
        var balances: [OwnershipBucket: Int64] = [:]
        for bucket in knownBuckets {
            let observations = events.filter { $0.observation.bucket == bucket }
            guard let latestDate = observations.map(\.date).max() else { return nil }
            let latest = observations.filter { $0.date == latestDate }
            var filingTotals = Set<Int64>()
            for sameFiling in Dictionary(grouping: latest, by: \.accession).values {
                // Document order orders transactions within one ordinary filing only.
                if sameFiling.count > 1 && sameFiling.contains(where: { !$0.observation.rowKind.hasSuffix("Transaction") }) && Set(sameFiling.map(\.quantity)).count > 1 { return nil }
                guard let last = sameFiling.max(by: { $0.observation.rowOrder < $1.observation.rowOrder }) else { return nil }
                filingTotals.insert(last.quantity)
            }
            guard filingTotals.count == 1 else { return nil }
            balances[bucket] = filingTotals.first
        }
        return OwnershipNumber.total(balances)
    }
}
