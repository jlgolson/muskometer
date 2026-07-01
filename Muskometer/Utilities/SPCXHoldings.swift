import Foundation

/// SPCX share counts for Yahoo paper-gain math.
///
/// SEC Form 4 reports SpaceX beneficial ownership in units that are 100× the
/// public SPCX ticker share count used with Yahoo quotes.
enum SPCXHoldings {
    static let secToPublicShareDivisor: Int64 = 100
    static let defaultPublicShareCount: Int64 = 60_685_475
    static let legacyIncorrectDefault: Int64 = 6_068_547_515

    static func publicShares(fromSECReported raw: Int64) -> Int64 {
        guard raw > 0 else { return defaultPublicShareCount }
        if raw == legacyIncorrectDefault { return defaultPublicShareCount }
        if raw > 1_000_000_000 { return raw / secToPublicShareDivisor }
        return raw
    }

    static func migrateStoredShareCount(_ stored: Int64) -> Int64 {
        publicShares(fromSECReported: stored)
    }
}