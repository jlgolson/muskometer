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

/// Immutable observations transcribed from the verified public Form 4 XML.
/// Holding rows without transaction dates are observed at filing, not backdated to periodOfReport.
struct OwnershipAnchor {
    let symbol: String
    let accession: String
    let filed: String
    let observations: [OwnershipObservation]

    static let all: [String: OwnershipAnchor] = [
        "SPCX": OwnershipAnchor(symbol: "SPCX", accession: "0001628280-26-044069", filed: "2026-06-17", observations: [
            OwnershipObservation(bucket: OwnershipBucket(security: "Class A Common Stock", ownership: "I", nature: "By Elon Musk Revocable Trust"), quantity: 551349985, effectiveDate: "2026-02-02", rowKind: "nonDerivativeTransaction", rowOrder: 0),
            OwnershipObservation(bucket: OwnershipBucket(security: "Class A Common Stock", ownership: "I", nature: "By Trust"), quantity: 186545, effectiveDate: "2026-02-02", rowKind: "nonDerivativeTransaction", rowOrder: 1),
            OwnershipObservation(bucket: OwnershipBucket(security: "Class A Common Stock", ownership: "I", nature: "By Elon Musk Revocable Trust"), quantity: 526177290, effectiveDate: "2026-03-23", rowKind: "nonDerivativeTransaction", rowOrder: 2),
            OwnershipObservation(bucket: OwnershipBucket(security: "Class A Common Stock", ownership: "I", nature: "By Elon Musk Revocable Trust"), quantity: 526165900, effectiveDate: "2026-04-02", rowKind: "nonDerivativeTransaction", rowOrder: 3),
            OwnershipObservation(bucket: OwnershipBucket(security: "Class A Common Stock", ownership: "I", nature: "By Elon Musk Revocable Trust"), quantity: 526165420, effectiveDate: "2026-04-02", rowKind: "nonDerivativeTransaction", rowOrder: 4),
            OwnershipObservation(bucket: OwnershipBucket(security: "Class A Common Stock", ownership: "I", nature: "By Trust"), quantity: 0, effectiveDate: "2026-04-02", rowKind: "nonDerivativeTransaction", rowOrder: 5),
            OwnershipObservation(bucket: OwnershipBucket(security: "Class A Common Stock", ownership: "I", nature: "By Elon Musk Revocable Trust"), quantity: 808780270, effectiveDate: "2026-06-15", rowKind: "nonDerivativeTransaction", rowOrder: 6),
            OwnershipObservation(bucket: OwnershipBucket(security: "Class A Common Stock", ownership: "I", nature: "By Elon Musk Revocable Trust"), quantity: 827298770, effectiveDate: "2026-06-15", rowKind: "nonDerivativeTransaction", rowOrder: 7),
            OwnershipObservation(bucket: OwnershipBucket(security: "Class A Common Stock", ownership: "I", nature: "By Elon Musk Revocable Trust"), quantity: 842091670, effectiveDate: "2026-06-15", rowKind: "nonDerivativeTransaction", rowOrder: 8),
            OwnershipObservation(bucket: OwnershipBucket(security: "Class A Common Stock", ownership: "I", nature: "By EM 2024 GRAT-A"), quantity: 7402770, effectiveDate: nil, rowKind: "nonDerivativeHolding", rowOrder: 9),
            OwnershipObservation(bucket: OwnershipBucket(security: "Class B Common Stock", ownership: "I", nature: "By Elon Musk Revocable Trust"), quantity: 663806095, effectiveDate: "2026-02-02", rowKind: "derivativeTransaction", rowOrder: 10),
            OwnershipObservation(bucket: OwnershipBucket(security: "Series A Preferred Stock", ownership: "I", nature: "By Elon Musk Revocable Trust"), quantity: 0, effectiveDate: "2026-06-15", rowKind: "derivativeTransaction", rowOrder: 11),
            OwnershipObservation(bucket: OwnershipBucket(security: "Class B Common Stock", ownership: "I", nature: "By Elon Musk Revocable Trust"), quantity: 3538534145, effectiveDate: "2026-06-15", rowKind: "derivativeTransaction", rowOrder: 12),
            OwnershipObservation(bucket: OwnershipBucket(security: "Series A Preferred Stock", ownership: "I", nature: "By Mission Trust"), quantity: 0, effectiveDate: "2026-06-15", rowKind: "derivativeTransaction", rowOrder: 13),
            OwnershipObservation(bucket: OwnershipBucket(security: "Class B Common Stock", ownership: "I", nature: "By Mission Trust"), quantity: 127426150, effectiveDate: "2026-06-15", rowKind: "derivativeTransaction", rowOrder: 14),
            OwnershipObservation(bucket: OwnershipBucket(security: "Series B Preferred Stock", ownership: "I", nature: "By Elon Musk Revocable Trust"), quantity: 0, effectiveDate: "2026-06-15", rowKind: "derivativeTransaction", rowOrder: 15),
            OwnershipObservation(bucket: OwnershipBucket(security: "Class B Common Stock", ownership: "I", nature: "By Elon Musk Revocable Trust"), quantity: 3788654145, effectiveDate: "2026-06-15", rowKind: "derivativeTransaction", rowOrder: 16),
            OwnershipObservation(bucket: OwnershipBucket(security: "Series C Preferred Stock", ownership: "I", nature: "By Elon Musk Revocable Trust"), quantity: 0, effectiveDate: "2026-06-15", rowKind: "derivativeTransaction", rowOrder: 17),
            OwnershipObservation(bucket: OwnershipBucket(security: "Series H Preferred Stock", ownership: "I", nature: "By Elon Musk Revocable Trust"), quantity: 0, effectiveDate: "2026-06-15", rowKind: "derivativeTransaction", rowOrder: 18),
            OwnershipObservation(bucket: OwnershipBucket(security: "Series I Preferred Stock", ownership: "I", nature: "By Elon Musk Revocable Trust"), quantity: 0, effectiveDate: "2026-06-15", rowKind: "derivativeTransaction", rowOrder: 19),
            OwnershipObservation(bucket: OwnershipBucket(security: "Class B Common Stock", ownership: "I", nature: "By Musk 2017 Sprinkling Trust"), quantity: 900495, effectiveDate: nil, rowKind: "derivativeHolding", rowOrder: 20),
            OwnershipObservation(bucket: OwnershipBucket(security: "Option to Buy (Class B Common Stock)", ownership: "D", nature: "", strike: "8.3998", expiration: "2031-02-11"), quantity: 350000000, effectiveDate: nil, rowKind: "derivativeHolding", rowOrder: 21),
        ]),
        "TSLA": OwnershipAnchor(symbol: "TSLA", accession: "0001104659-26-075213", filed: "2026-06-17", observations: [
            OwnershipObservation(bucket: OwnershipBucket(security: "Common Stock", ownership: "D", nature: ""), quantity: 727704534, effectiveDate: "2026-06-16", rowKind: "nonDerivativeTransaction", rowOrder: 0),
            OwnershipObservation(bucket: OwnershipBucket(security: "Common Stock", ownership: "D", nature: ""), quantity: 710172677, effectiveDate: "2026-06-16", rowKind: "nonDerivativeTransaction", rowOrder: 1),
        ]),
    ]
}
