import Foundation

/// Default SPCX share count and migration for prior app versions.
enum SPCXHoldings {
    /// June 17 Form 4 tables + vested 350M options; no remarks performance RSUs.
    static let defaultShareCount: Int64 = 5_116_475_230

    private static let legacyScaledDefault: Int64 = 60_685_475
    private static let legacySingleRowParse: Int64 = 842_091_670
    private static let legacyMisparseLastRow: Int64 = 7_402_770
    /// Last-row-wins tables + performance RSUs, no vested options.
    private static let legacyPartialAggregateDefault: Int64 = 6_068_547_515
    /// Prior bundled default (tables + performance RSUs, no vested options).
    private static let legacyBundledWithPerformanceRSUs: Int64 = 6_068_734_060

    static func migrateStoredShareCount(_ stored: Int64) -> Int64 {
        switch stored {
        case legacyScaledDefault,
             legacySingleRowParse,
             legacyMisparseLastRow,
             legacyPartialAggregateDefault,
             legacyBundledWithPerformanceRSUs:
            return defaultShareCount
        default:
            return stored
        }
    }
}