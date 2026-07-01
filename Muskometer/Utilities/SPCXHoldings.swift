import Foundation

/// Default SPCX share count and migration for prior app versions.
enum SPCXHoldings {
    /// Class A-equivalent beneficial ownership (June 2026 Form 4 + restricted remark).
    static let defaultShareCount: Int64 = 6_068_734_060

    private static let legacyScaledDefault: Int64 = 60_685_475
    private static let legacySingleRowParse: Int64 = 842_091_670
    private static let legacyMisparseLastRow: Int64 = 7_402_770
    /// Partial aggregate before restricted-share remark was included.
    private static let legacyPartialAggregateDefault: Int64 = 6_068_547_515

    static func migrateStoredShareCount(_ stored: Int64) -> Int64 {
        switch stored {
        case legacyScaledDefault, legacySingleRowParse, legacyMisparseLastRow, legacyPartialAggregateDefault:
            return defaultShareCount
        default:
            return stored
        }
    }
}