import Foundation

/// Parses SEC Form 4 ownership XML for issuer share counts.
struct Form4OwnershipParser {
    let data: Data

    func parse() -> (tslaShares: Int64?, spcxShares: Int64?) {
        guard let xml = String(data: data, encoding: .utf8) else {
            return (nil, nil)
        }

        guard let symbol = extractIssuerTradingSymbol(from: xml)?.uppercased() else {
            return (nil, nil)
        }

        switch symbol {
        case "TSLA":
            guard let shares = extractTSLAOwnershipShares(from: xml) else { return (nil, nil) }
            return (shares, nil)
        case "SPCX":
            guard let shares = SPCXOwnershipCalculator.totalPublicShares(from: xml) else { return (nil, nil) }
            return (nil, shares)
        default:
            return (nil, nil)
        }
    }

    private func extractIssuerTradingSymbol(from xml: String) -> String? {
        if let issuerBlock = extractBlock(named: "issuer", from: xml) {
            return extractTag("issuerTradingSymbol", from: issuerBlock)
        }
        return extractTag("issuerTradingSymbol", from: xml)
    }

    private func extractTSLAOwnershipShares(from xml: String) -> Int64? {
        guard let tableContent = extractBlock(named: "nonDerivativeTable", from: xml) else {
            return nil
        }

        let blocks = extractOwnershipBlocks(from: tableContent)
        guard !blocks.isEmpty else { return nil }

        let directBlocks = blocks.filter { $0.ownership == "D" }
        if !directBlocks.isEmpty {
            return directBlocks.last?.shares
        }
        return blocks.map(\.shares).max()
    }

    private func extractOwnershipBlocks(from tableContent: String) -> [OwnershipBlock] {
        let pattern = #"<(nonDerivativeTransaction|nonDerivativeHolding)>([\s\S]*?)</\1>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(tableContent.startIndex..<tableContent.endIndex, in: tableContent)
        let matches = regex.matches(in: tableContent, range: range)

        return matches.compactMap { match in
            guard let bodyRange = Range(match.range(at: 2), in: tableContent) else { return nil }
            let body = String(tableContent[bodyRange])

            guard let shares = extractSharesOwnedFollowingTransaction(from: body) else { return nil }
            let ownership = extractDirectOrIndirectOwnership(from: body) ?? "D"
            return OwnershipBlock(ownership: ownership.uppercased(), shares: shares)
        }
    }

    private func extractDirectOrIndirectOwnership(from block: String) -> String? {
        guard let ownershipBlock = extractBlock(named: "directOrIndirectOwnership", from: block) else {
            return extractTag("directOrIndirectOwnership", from: block)
        }
        return extractTag("value", from: ownershipBlock) ?? extractTag("directOrIndirectOwnership", from: ownershipBlock)
    }

    private func extractSharesOwnedFollowingTransaction(from block: String) -> Int64? {
        guard let postAmounts = extractBlock(named: "postTransactionAmounts", from: block) else {
            return nil
        }

        guard let raw = extractTag("value", from: extractBlock(named: "sharesOwnedFollowingTransaction", from: postAmounts) ?? postAmounts) else {
            return nil
        }

        return Int64(Double(raw) ?? 0)
    }

    private func extractBlock(named tag: String, from xml: String) -> String? {
        guard let open = xml.range(of: "<\(tag)>"),
              let close = xml.range(of: "</\(tag)>", range: open.upperBound..<xml.endIndex) else {
            return nil
        }
        return String(xml[open.upperBound..<close.lowerBound])
    }

    private func extractTag(_ tag: String, from xml: String) -> String? {
        guard let open = xml.range(of: "<\(tag)>"),
              let close = xml.range(of: "</\(tag)>", range: open.upperBound..<xml.endIndex) else {
            return nil
        }
        return String(xml[open.upperBound..<close.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct OwnershipBlock {
    let ownership: String
    let shares: Int64
}