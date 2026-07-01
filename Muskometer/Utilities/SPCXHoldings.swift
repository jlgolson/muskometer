import Foundation

/// Default SPCX share count and migration for prior app versions.
enum SPCXHoldings {
    /// Beneficial ownership from the latest SEC Form 4 (June 2026 SpaceX filing).
    static let defaultShareCount: Int64 = 842_091_670

    /// v0.1.0 incorrectly divided SEC counts by 100 (proxy-ticker assumption).
    private static let legacyScaledDefault: Int64 = 60_685_475
    private static let legacyUnscaledDefault: Int64 = 6_068_547_515
    /// Parser used to pick the last Form 4 row (a small GRAT slice), not total holdings.
    private static let legacyMisparseLastRow: Int64 = 7_402_770

    static func migrateStoredShareCount(_ stored: Int64) -> Int64 {
        switch stored {
        case legacyScaledDefault, legacyUnscaledDefault, legacyMisparseLastRow:
            return defaultShareCount
        default:
            return stored
        }
    }
}