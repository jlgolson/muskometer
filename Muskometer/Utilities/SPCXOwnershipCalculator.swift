import Foundation

/// Aggregates Elon Musk's SpaceX (SPCX) beneficial ownership from SEC Form 4 ownership XML.
///
/// SpaceX filings split holdings across Class A, Class B, preferred series,
/// and trusts. We sum the latest per-trust rows, convert
/// preferred per filing footnotes, and add restricted Class B cited in remarks.
enum SPCXOwnershipCalculator {
    static func totalPublicShares(from xml: String) -> Int64? {
        var buckets: [BucketKey: Int64] = [:]

        for table in ["nonDerivativeTable", "derivativeTable"] {
            guard let tableContent = extractBlock(named: table, from: xml) else { continue }
            for block in extractOwnershipBlocks(from: tableContent) {
                guard let title = block.title, let shares = block.shares, shares >= 0 else { continue }
                let key = BucketKey(title: title, nature: block.nature ?? "")
                // Last row in document order wins (post-transaction amounts after a sale
                // can be lower—including full disposal to 0—for the same title/nature).
                buckets[key] = shares
            }
        }

        guard !buckets.isEmpty else { return nil }

        var classAEquivalent: Int64 = 0
        for (key, shares) in buckets {
            classAEquivalent += classAEquivalentShares(securityTitle: key.title, shares: shares)
        }

        classAEquivalent += restrictedShares(from: xml)
        return classAEquivalent > 0 ? classAEquivalent : nil
    }

    private static func classAEquivalentShares(securityTitle: String, shares: Int64) -> Int64 {
        let title = securityTitle.lowercased()
        if title.contains("option") { return 0 }
        if title.contains("class a common") { return shares }
        if title.contains("class b common") { return shares }
        if title.contains("series a preferred") || title.contains("series b preferred") {
            return shares * 50
        }
        if title.contains("series c preferred") || title.contains("series h preferred") || title.contains("series i preferred") {
            return shares * 50
        }
        return 0
    }

    private static func restrictedShares(from xml: String) -> Int64 {
        let haystack = extractBlock(named: "remarks", from: xml) ?? xml
        let pattern = #"(?:does not include|not include)[^0-9]*([0-9][0-9,]*)[^0-9]*shares"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return 0 }
        let range = NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)
        guard let match = regex.firstMatch(in: haystack, range: range),
              let numberRange = Range(match.range(at: 1), in: haystack) else {
            return 0
        }
        let digits = haystack[numberRange].filter(\.isWholeNumber)
        return Int64(digits) ?? 0
    }

    private struct OwnershipBlock {
        let title: String?
        let nature: String?
        let shares: Int64?
    }

    private struct BucketKey: Hashable {
        let title: String
        let nature: String
    }

    private static func extractOwnershipBlocks(from tableContent: String) -> [OwnershipBlock] {
        let pattern = #"<(nonDerivativeTransaction|nonDerivativeHolding|derivativeTransaction|derivativeHolding)>([\s\S]*?)</\1>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(tableContent.startIndex..<tableContent.endIndex, in: tableContent)
        let matches = regex.matches(in: tableContent, range: range)

        return matches.compactMap { match in
            guard let bodyRange = Range(match.range(at: 2), in: tableContent) else { return nil }
            let body = String(tableContent[bodyRange])
            let title = extractTag("value", from: extractBlock(named: "securityTitle", from: body) ?? body)
                ?? extractTag("securityTitle", from: body)
            let nature = extractTag("value", from: extractBlock(named: "natureOfOwnership", from: body) ?? "")
            let shares = extractShares(from: body)
            return OwnershipBlock(title: title, nature: nature, shares: shares)
        }
    }

    private static func extractShares(from block: String) -> Int64? {
        if let postAmounts = extractBlock(named: "postTransactionAmounts", from: block),
           let raw = extractTag("value", from: extractBlock(named: "sharesOwnedFollowingTransaction", from: postAmounts) ?? postAmounts) {
            return Int64(Double(raw) ?? 0)
        }
        if let raw = extractTag("value", from: extractBlock(named: "underlyingSecurityShares", from: block) ?? block) {
            return Int64(Double(raw) ?? 0)
        }
        return nil
    }

    private static func extractBlock(named tag: String, from xml: String) -> String? {
        guard let open = xml.range(of: "<\(tag)>"),
              let close = xml.range(of: "</\(tag)>", range: open.upperBound..<xml.endIndex) else {
            return nil
        }
        return String(xml[open.upperBound..<close.lowerBound])
    }

    private static func extractTag(_ tag: String, from xml: String) -> String? {
        guard let open = xml.range(of: "<\(tag)>"),
              let close = xml.range(of: "</\(tag)>", range: open.upperBound..<xml.endIndex) else {
            return nil
        }
        return String(xml[open.upperBound..<close.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}