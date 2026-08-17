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

    static func userDefaultsKey(for symbol: String) -> String {
        "sharesOutstanding_\(symbol.uppercased())"
    }

    /// Remigrates exact prior bundled fingerprints; other stored values pass through.
    static func migrateStoredOutstanding(_ stored: Int64, symbol: String) -> Int64 {
        if symbol.uppercased() == "SPCX", stored == legacySPCXCoverDefault {
            return defaultSPCX
        }
        return stored
    }
}
