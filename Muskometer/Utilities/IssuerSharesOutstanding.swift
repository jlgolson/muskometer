import Foundation

/// Bundled point-in-time issuer shares outstanding for market-cap parity
/// (company totals — not Musk Form 4 ownership).
enum IssuerSharesOutstanding {
    /// dei:EntityCommonStockSharesOutstanding, end 2026-07-16 (TSLA 10-Q / companyfacts).
    static let defaultTSLA: Int64 = 3_949_547_394

    /// 10-Q cover A+B (2026-07-28, accession 0001628280-26-052535) plus Cursor 8-K
    /// `0001628280-26-056945` item (i) Class A 389_289_254.
    /// Class A 8_085_582_923 + Class B 5_485_486_276. Does not add item (ii) 1_752_426.
    static let defaultSPCX: Int64 = 13_181_779_945 + 389_289_254

    /// Prior bundled A+B cover (pre-Cursor issuance).
    private static let legacySPCXCoverDefault: Int64 = 13_181_779_945

    static func defaultOutstanding(for symbol: String) -> Int64? {
        switch symbol.uppercased() {
        case "TSLA": return defaultTSLA
        case "SPCX": return defaultSPCX
        default: return nil
        }
    }

    /// Human-readable “as of” for bundled defaults (matches comments above).
    static func defaultAsOfLabel(for symbol: String) -> String? {
        switch symbol.uppercased() {
        case "TSLA": return "2026-07-16"
        case "SPCX": return "2026-07-28 + Cursor 8-K"
        default: return nil
        }
    }

    static func userDefaultsKey(for symbol: String) -> String {
        "sharesOutstanding_\(symbol.uppercased())"
    }

    static func provenanceKey(for symbol: String) -> String {
        "sharesOutstandingProvenance_\(symbol.uppercased())"
    }

    static func periodEndKey(for symbol: String) -> String {
        "sharesOutstandingPeriodEnd_\(symbol.uppercased())"
    }

    static func filedKey(for symbol: String) -> String {
        "sharesOutstandingFiled_\(symbol.uppercased())"
    }

    /// Remigrates exact prior bundled fingerprints; other stored values pass through.
    static func migrateStoredOutstanding(_ stored: Int64, symbol: String) -> Int64 {
        if symbol.uppercased() == "SPCX", stored == legacySPCXCoverDefault {
            return defaultSPCX
        }
        return stored
    }
}

/// Where issuer outstanding came from for parity UI.
enum OutstandingSharesProvenance: Equatable, Sendable {
    case bundledDefault
    case companyfacts(periodEnd: String?, filed: String?)

    var shortCaption: String {
        switch self {
        case .bundledDefault:
            return "bundled default"
        case .companyfacts(let periodEnd, _):
            if let periodEnd, !periodEnd.isEmpty {
                return "SEC companyfacts · as of \(periodEnd)"
            }
            return "SEC companyfacts"
        }
    }

    func caption(defaultAsOf: String?) -> String {
        switch self {
        case .bundledDefault:
            if let defaultAsOf, !defaultAsOf.isEmpty {
                return "bundled default · as of \(defaultAsOf)"
            }
            return "bundled default"
        case .companyfacts:
            return shortCaption
        }
    }

    var storageRawValue: String {
        switch self {
        case .bundledDefault: return "bundledDefault"
        case .companyfacts: return "companyfacts"
        }
    }

    static func fromStorage(
        raw: String?,
        periodEnd: String?,
        filed: String?,
        storedShares: Int64?,
        defaultShares: Int64?
    ) -> OutstandingSharesProvenance {
        switch raw {
        case "bundledDefault":
            return .bundledDefault
        case "companyfacts":
            return .companyfacts(periodEnd: periodEnd, filed: filed)
        default:
            // Legacy installs: no provenance key — infer from equality to bundled default.
            if let storedShares, let defaultShares, storedShares == defaultShares {
                return .bundledDefault
            }
            if storedShares != nil {
                return .companyfacts(periodEnd: periodEnd, filed: filed)
            }
            return .bundledDefault
        }
    }
}

/// Resolved companyfacts outstanding with filing dates for provenance captions.
struct IssuerOutstandingFact: Equatable, Sendable {
    let shares: Int64
    let periodEnd: String
    let filed: String
}
