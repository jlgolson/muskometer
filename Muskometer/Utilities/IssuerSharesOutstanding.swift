import Foundation

/// Bundled point-in-time issuer shares outstanding for market-cap parity
/// (company totals — not Musk Form 4 ownership).
enum IssuerSharesOutstanding {
    /// dei:EntityCommonStockSharesOutstanding, end 2026-07-16 (TSLA 10-Q / companyfacts).
    static let defaultTSLA: Int64 = 3_949_547_394

    /// 10-Q cover as of 2026-07-28: Class A 7_696_293_669 + Class B 5_485_486_276
    /// (accession 0001628280-26-052535).
    static let defaultSPCX: Int64 = 13_181_779_945

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
}
