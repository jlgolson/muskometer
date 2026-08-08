import Foundation

/// Pure SEC companyfacts parser for point-in-time common shares outstanding.
///
/// Concept priority (first usable):
/// 1. `dei:EntityCommonStockSharesOutstanding`
/// 2. `us-gaap:CommonStockSharesOutstanding`
///
/// Units key `shares` only. Weighted-average / EPS denominator concepts
/// (WASO basic/diluted) are never read — if only those exist, resolve returns nil.
enum CompanyFactsOutstandingResolver {
    private static let preferredForms: Set<String> = [
        "10-Q", "10-K", "10-Q/A", "10-K/A",
    ]

    /// Parse SEC companyfacts JSON Data → positive Int64 outstanding or nil.
    static func resolveSharesOutstanding(from companyFactsJSON: Data) -> Int64? {
        guard
            let root = try? JSONSerialization.jsonObject(with: companyFactsJSON) as? [String: Any],
            let facts = root["facts"] as? [String: Any]
        else {
            return nil
        }

        if let value = resolveConcept(
            facts: facts,
            taxonomy: "dei",
            concept: "EntityCommonStockSharesOutstanding"
        ) {
            return value
        }

        return resolveConcept(
            facts: facts,
            taxonomy: "us-gaap",
            concept: "CommonStockSharesOutstanding"
        )
    }

    // MARK: - Private

    private struct FactRow {
        let end: String
        let filed: String
        let form: String?
        let val: Double
    }

    private static func resolveConcept(
        facts: [String: Any],
        taxonomy: String,
        concept: String
    ) -> Int64? {
        guard
            let taxonomyNode = facts[taxonomy] as? [String: Any],
            let conceptNode = taxonomyNode[concept] as? [String: Any],
            let units = conceptNode["units"] as? [String: Any],
            let shares = units["shares"] as? [Any]
        else {
            return nil
        }

        let rows = shares.compactMap { item -> FactRow? in
            guard let dict = item as? [String: Any] else { return nil }
            return parseRow(dict)
        }
        guard !rows.isEmpty else { return nil }

        let preferred = rows.filter { row in
            guard let form = row.form else { return false }
            return preferredForms.contains(form)
        }
        let pool = preferred.isEmpty ? rows : preferred

        guard let best = pool.max(by: { lhs, rhs in
            if lhs.end != rhs.end { return lhs.end < rhs.end }
            return lhs.filed < rhs.filed
        }) else {
            return nil
        }

        let members = pool.filter { $0.end == best.end && $0.filed == best.filed }
        let sum = members.reduce(0.0) { $0 + $1.val }
        guard sum.isFinite, sum > 0, sum <= Double(Int64.max) else { return nil }
        let rounded = sum.rounded()
        guard rounded > 0 else { return nil }
        return Int64(rounded)
    }

    private static func parseRow(_ dict: [String: Any]) -> FactRow? {
        guard let end = dict["end"] as? String, !end.isEmpty else { return nil }
        guard let val = numberValue(dict["val"]), val.isFinite, val > 0 else { return nil }
        let filed = (dict["filed"] as? String) ?? ""
        let form = dict["form"] as? String
        return FactRow(end: end, filed: filed, form: form, val: val)
    }

    private static func numberValue(_ any: Any?) -> Double? {
        switch any {
        case let d as Double:
            return d
        case let i as Int:
            return Double(i)
        case let i64 as Int64:
            return Double(i64)
        case let n as NSNumber:
            return n.doubleValue
        default:
            return nil
        }
    }
}
