import Foundation

/// Selects whole-entity, point-in-time totals. Equal repeated facts are duplicates, not classes.
enum CompanyFactsOutstandingResolver {
    private static let preferredForms: Set<String> = ["10-Q", "10-K", "10-Q/A", "10-K/A"]

    static func resolve(from companyFactsJSON: Data) -> IssuerOutstandingFact? {
        guard let numbers = CompanyFactsJSONNumbers(companyFactsJSON) else { return nil }
        let decoder = JSONDecoder()
        decoder.userInfo[CompanyFactsJSONNumbers.userInfoKey] = numbers.tokens
        guard let root = try? decoder.decode(FactsDocument.self, from: numbers.indexedJSON) else { return nil }
        switch resolveConcept(root.facts.dei?.entity?.units?.shares) {
        case .fact(let fact): return fact
        case .unresolved: return nil
        case .unavailable:
            if case .fact(let fact) = resolveConcept(root.facts.usGaap?.common?.units?.shares) { return fact }
            return nil
        }
    }

    static func resolveSharesOutstanding(from companyFactsJSON: Data) -> Int64? {
        resolve(from: companyFactsJSON)?.shares
    }

    private enum Resolution {
        case unavailable
        case unresolved
        case fact(IssuerOutstandingFact)
    }
    private struct FilingIdentity: Hashable {
        let accession: String?
        let form: String?
    }
    // Metadata uses Foundation's structural decoder; values refer to original JSON number tokens.
    private struct FactsDocument: Decodable { let facts: Taxonomies }
    private struct Taxonomies: Decodable {
        let dei: Concepts?
        let usGaap: Concepts?
        enum CodingKeys: String, CodingKey { case dei; case usGaap = "us-gaap" }
    }
    private struct Concepts: Decodable {
        let entity: Concept?
        let common: Concept?
        enum CodingKeys: String, CodingKey {
            case entity = "EntityCommonStockSharesOutstanding"
            case common = "CommonStockSharesOutstanding"
        }
    }
    private struct Concept: Decodable { let units: Units? }
    private struct Units: Decodable { let shares: [FactRow]? }
    private struct FactRow: Decodable {
        let end: String
        let filed: String
        let filing: FilingIdentity
        let value: Int64?
        enum CodingKeys: String, CodingKey { case end, filed, form, accn, val }
        init(from decoder: Decoder) throws {
            let fields = try decoder.container(keyedBy: CodingKeys.self)
            end = (try? fields.decode(String.self, forKey: .end)) ?? ""
            filed = (try? fields.decode(String.self, forKey: .filed)) ?? ""
            filing = FilingIdentity(accession: try? fields.decode(String.self, forKey: .accn),
                                    form: try? fields.decode(String.self, forKey: .form))
            if let index = try? fields.decode(Int.self, forKey: .val),
               let tokens = decoder.userInfo[CompanyFactsJSONNumbers.userInfoKey] as? [String],
               tokens.indices.contains(index) {
                value = CompanyFactsJSONNumbers.positiveInt64(tokens[index])
            } else { value = nil }
        }
    }

    private static func resolveConcept(_ shares: [FactRow]?) -> Resolution {
        guard let shares, !shares.isEmpty else { return .unavailable }
        let rows = shares.filter { OwnershipNumber.date($0.end) != nil }
        guard !rows.isEmpty else { return .unresolved }
        let preferred = rows.filter { preferredForms.contains($0.filing.form ?? "") }
        let pool = preferred.isEmpty ? rows : preferred
        guard let best = pool.max(by: { $0.end == $1.end ? $0.filed < $1.filed : $0.end < $1.end }) else { return .unresolved }
        let tied = pool.filter { $0.end == best.end && $0.filed == best.filed }
        // Retain accession/form identity through selection. Different filings on the same day
        // have no reliable order here; conflicting totals remain unresolved, including amendments.
        let groups = Dictionary(grouping: tied, by: \.filing)
        var totals = Set<Int64>()
        for members in groups.values {
            guard members.allSatisfy({ $0.value != nil }) else { return .unresolved }
            totals.formUnion(members.compactMap(\.value))
        }
        guard totals.count == 1, let total = totals.first else { return .unresolved }
        return .fact(IssuerOutstandingFact(shares: total, periodEnd: best.end, filed: best.filed))
    }
}


/// Foundation's Double and Decimal decoders can both lose fractional digits. Preserve each
/// original number token and replace it with its array index before structural decoding.
/// Strings remain strings, so a quoted number or a forged object cannot become a numeric fact.
/// The original number grammar is checked before replacement; JSONDecoder validates structure.
private struct CompanyFactsJSONNumbers {
    static let userInfoKey = CodingUserInfoKey(rawValue: "companyFactsOriginalNumberTokens")!
    private static let grammar = try! NSRegularExpression(pattern: #"^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$"#)
    let indexedJSON: Data
    let tokens: [String]

    init?(_ data: Data) {
        let bytes = Array(data)
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        var tokens: [String] = []
        var cursor = 0
        while cursor < bytes.count {
            if bytes[cursor] == 34 { // Copy strings, including escaped quotes, without interpreting numbers inside them.
                let start = cursor
                cursor += 1
                var closed = false
                while cursor < bytes.count {
                    if bytes[cursor] == 92 { cursor += 2 }
                    else if bytes[cursor] == 34 { cursor += 1; closed = true; break }
                    else { cursor += 1 }
                }
                guard closed, cursor <= bytes.count else { return nil }
                output.append(contentsOf: bytes[start..<cursor])
            } else if bytes[cursor] == 45 || (48...57).contains(bytes[cursor]) {
                let start = cursor
                while cursor < bytes.count && ((48...57).contains(bytes[cursor]) || [43, 45, 46, 69, 101].contains(bytes[cursor])) { cursor += 1 }
                let token = String(decoding: bytes[start..<cursor], as: UTF8.self)
                guard Self.grammar.firstMatch(in: token, range: NSRange(location: 0, length: token.utf16.count)) != nil else { return nil }
                output.append(contentsOf: String(tokens.count).utf8)
                tokens.append(token)
            } else {
                output.append(bytes[cursor])
                cursor += 1
            }
        }
        self.indexedJSON = Data(output)
        self.tokens = tokens
    }

    /// Interpret decimal digits and exponent exactly. Only trailing zero digits may be
    /// removed; a nonzero fractional digit is never rounded away, regardless of precision.
    static func positiveInt64(_ token: String) -> Int64? {
        guard !token.hasPrefix("-") else { return nil }
        let parts = token.split(whereSeparator: { $0 == "e" || $0 == "E" })
        let mantissa = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        let fractionalCount = mantissa.count == 2 ? mantissa[1].count : 0
        let digits = mantissa.joined().drop(while: { $0 == "0" })
        guard !digits.isEmpty else { return nil }
        var exponent = 0
        if parts.count == 2 {
            let negative = parts[1].first == "-"
            let magnitude = parts[1].drop(while: { $0 == "+" || $0 == "-" || $0 == "0" })
            if !magnitude.isEmpty {
                guard let parsed = Int((negative ? "-" : "") + magnitude) else { return nil }
                exponent = parsed
            }
        }
        let (scale, overflow) = exponent.subtractingReportingOverflow(fractionalCount)
        guard !overflow else { return nil }
        let integerText: String
        if scale >= 0 {
            guard digits.count <= 19, scale <= 19 - digits.count else { return nil }
            integerText = String(digits) + String(repeating: "0", count: scale)
        } else {
            guard scale >= -digits.count else { return nil }
            let fractionalDigits = -scale
            guard digits.suffix(fractionalDigits).allSatisfy({ $0 == "0" }) else { return nil }
            let integralDigits = digits.dropLast(fractionalDigits)
            guard !integralDigits.isEmpty, integralDigits.count <= 19 else { return nil }
            integerText = String(integralDigits)
        }
        guard let value = Int64(integerText), value > 0 else { return nil }
        return value
    }
}
