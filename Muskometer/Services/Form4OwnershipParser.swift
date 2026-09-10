import Foundation

/// Identity is independent of formatting and includes option terms to avoid combining grants.
struct OwnershipBucket: Hashable {
    let security: String
    let ownership: String
    let nature: String
    let strike: String?
    let expiration: String?

    init(security: String, ownership: String, nature: String, strike: String? = nil, expiration: String? = nil) {
        self.security = Self.normalized(security)
        self.ownership = ownership.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.nature = Self.normalized(nature)
        self.strike = strike
        self.expiration = expiration
    }

    static func normalized(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
    }

    var multiplier: Int64 { security.contains("preferred") ? 50 : 1 }
}

struct OwnershipObservation: Equatable {
    let bucket: OwnershipBucket
    /// Absolute balance, never transactionShares (a delta).
    let quantity: Int64
    let effectiveDate: String?
    let rowKind: String
    let rowOrder: Int
}

struct OwnershipDocument {
    let symbol: String
    let documentType: String?
    let originalSubmissionDate: String?
    let observations: [OwnershipObservation]
    let hasUnresolvedRelevantRows: Bool
}

/// Exact nonnegative integers: no floating-point rounding, truncation, or trapping conversion.
enum OwnershipNumber {
    static func integer(_ raw: String) -> Int64? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), !parts[0].isEmpty,
              parts[0].utf8.allSatisfy({ (48...57).contains($0) }),
              parts.count == 1 || (!parts[1].isEmpty && parts[1].allSatisfy({ $0 == "0" })) else { return nil }
        return Int64(parts[0])
    }

    /// Canonical decimal identity without rounding significant option-strike digits.
    static func decimalIdentity(_ raw: String) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), parts.allSatisfy({
            !$0.isEmpty && $0.utf8.allSatisfy({ (48...57).contains($0) })
        }) else { return nil }
        let digits = parts[0].drop(while: { $0 == "0" })
        let whole = digits.isEmpty ? "0" : String(digits)
        var fraction = parts.count == 2 ? parts[1] : ""
        while fraction.last == "0" { fraction.removeLast() }
        return fraction.isEmpty ? whole : whole + "." + String(fraction)
    }

    static func date(_ raw: String?) -> String? {
        guard let raw, raw.count == 10 else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: raw), formatter.string(from: date) == raw else { return nil }
        return raw
    }

    static func total(_ balances: [OwnershipBucket: Int64]) -> Int64? {
        guard !balances.isEmpty else { return nil }
        var total: Int64 = 0
        for (bucket, quantity) in balances {
            let (equivalent, productOverflow) = quantity.multipliedReportingOverflow(by: bucket.multiplier)
            let (next, sumOverflow) = total.addingReportingOverflow(equivalent)
            guard quantity >= 0, !productOverflow, !sumOverflow else { return nil }
            total = next
        }
        return total
    }
}

/// XML parsing is shared by the convenience total and the stricter dated reconciliation path.
struct Form4OwnershipParser {
    let data: Data

    func parse() -> [String: Int64] {
        guard let document = observations(strict: false), !document.hasUnresolvedRelevantRows else { return [:] }
        var balances: [OwnershipBucket: Int64] = [:]
        for observation in document.observations { balances[observation.bucket] = observation.quantity }
        guard let total = OwnershipNumber.total(balances) else { return [:] }
        return [document.symbol: total]
    }

    func observations(strict: Bool = true) -> OwnershipDocument? {
        guard let root = OwnershipXML.read(data), root.name == "ownershipDocument",
              let rawSymbol = root.child("issuer")?.child("issuerTradingSymbol")?.textValue,
              !rawSymbol.isEmpty else { return nil }
        let symbol = rawSymbol.uppercased()
        guard ["TSLA", "SPCX"].contains(symbol) else {
            return OwnershipDocument(symbol: symbol, documentType: nil, originalSubmissionDate: nil, observations: [], hasUnresolvedRelevantRows: false)
        }
        let originalRaw = root.child("dateOfOriginalSubmission")?.textValue
        let original = OwnershipNumber.date(originalRaw)
        var unresolved = originalRaw != nil && original == nil
        var result: [OwnershipObservation] = []
        var hasOwnershipRows = false
        var order = 0
        for tableName in ["nonDerivativeTable", "derivativeTable"] {
            guard let table = root.child(tableName) else { continue }
            for row in table.children {
                defer { order += 1 }
                guard ["nonDerivativeHolding", "nonDerivativeTransaction", "derivativeHolding", "derivativeTransaction"].contains(row.name) else {
                    unresolved = true; continue
                }
                hasOwnershipRows = true
                let direction = row.child("ownershipNature")?.child("directOrIndirectOwnership")?.value?.uppercased()
                // TSLA's established metric is directly owned common stock only.
                if symbol == "TSLA", tableName == "derivativeTable" || direction == "I" { continue }
                let title = OwnershipBucket.normalized(row.child("securityTitle")?.value ?? (strict ? "" : "Common Stock"))
                let nature = row.child("ownershipNature")?.child("natureOfOwnership")?.value ?? ""
                let recognized = symbol == "TSLA" ? title == "common stock" : [
                    "class a common stock", "class b common stock", "series a preferred stock", "series b preferred stock",
                    "series c preferred stock", "series h preferred stock", "series i preferred stock",
                    "option to buy (class b common stock)", "option to buy"
                ].contains(title)
                guard recognized, !strict || (direction == "D" || (direction == "I" && !nature.isEmpty)) else {
                    unresolved = true; continue
                }
                let postNode = row.child("postTransactionAmounts")?.child("sharesOwnedFollowingTransaction")
                let underlying = row.child("underlyingSecurity")?.child("underlyingSecurityShares") ?? row.child("underlyingSecurityShares")
                // Legacy convenience fixtures omit post amounts; live updates always require them.
                let rawQuantity = postNode?.value ?? (!strict && postNode == nil ? underlying?.value : nil)
                guard let rawQuantity, let quantity = OwnershipNumber.integer(rawQuantity) else {
                    unresolved = true; continue
                }
                let rawDate = row.child("transactionDate")?.value
                let date = OwnershipNumber.date(rawDate)
                if row.child("transactionDate") != nil && date == nil { unresolved = true }
                var strike: String?
                var expiration: String?
                if title.contains("option") {
                    if let raw = row.child("conversionOrExercisePrice")?.value {
                        strike = OwnershipNumber.decimalIdentity(raw)
                    }
                    expiration = OwnershipNumber.date(row.child("expirationDate")?.value)
                    if strict && (strike == nil || expiration == nil) { unresolved = true }
                }
                let bucket = OwnershipBucket(security: title, ownership: direction ?? "D", nature: nature, strike: strike, expiration: expiration)
                result.append(OwnershipObservation(bucket: bucket, quantity: quantity, effectiveDate: date, rowKind: row.name, rowOrder: order))
            }
        }
        // Empty tables do not prove unchanged ownership. Count rows before intentionally ignoring TSLA positions.
        return OwnershipDocument(symbol: symbol, documentType: root.child("documentType")?.textValue,
                                 originalSubmissionDate: original, observations: result, hasUnresolvedRelevantRows: unresolved || !hasOwnershipRows)
    }
}

/// A small bounded XML tree. DTDs/entities are unsupported; never access external resources.
private final class OwnershipXML: NSObject, XMLParserDelegate {
    final class Node {
        let name: String
        var text = ""
        var children: [Node] = []
        init(_ name: String) { self.name = name }
        var textValue: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
        func child(_ name: String) -> Node? { children.first { $0.name == name } }
        var value: String? { child("value")?.textValue }
    }
    private var stack: [Node] = []
    private var root: Node?
    private var failed = false
    private var count = 0

    static func read(_ data: Data) -> Node? {
        guard data.count <= 2_000_000, let xml = String(data: data, encoding: .utf8),
              !xml.uppercased().contains("<!DOCTYPE"), !xml.uppercased().contains("<!ENTITY") else { return nil }
        let delegate = OwnershipXML()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), !delegate.failed, delegate.stack.isEmpty else { return nil }
        return delegate.root
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        count += 1
        guard count <= 50_000, stack.count < 64, !elementName.contains(":") else { failed = true; parser.abortParsing(); return }
        let node = Node(elementName)
        if let parent = stack.last {
            // Repeated rows and footnotes are expected; duplicate scalar fields are ambiguous.
            let repeatsAllowed = ["nonDerivativeTable", "derivativeTable", "footnotes", "ownershipDocument"]
            if !repeatsAllowed.contains(parent.name), elementName != "footnoteId", parent.children.contains(where: { $0.name == elementName }) {
                failed = true; parser.abortParsing(); return
            }
            if parent.name == "ownershipDocument", elementName != "reportingOwner", parent.children.contains(where: { $0.name == elementName }) {
                failed = true; parser.abortParsing(); return
            }
            parent.children.append(node)
        } else if root == nil { root = node } else { failed = true; parser.abortParsing(); return }
        stack.append(node)
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { stack.last?.text += string }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let text = String(data: CDATABlock, encoding: .utf8) else { failed = true; parser.abortParsing(); return }
        stack.last?.text += text
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) { _ = stack.popLast() }
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) { failed = true }
    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? { failed = true; parser.abortParsing(); return nil }
}
