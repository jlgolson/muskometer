import Foundation

/// Convenience table total; SEC synchronization separately reconciles complete dated buckets.
enum SPCXOwnershipCalculator {
    static func totalPublicShares(from xml: String) -> Int64? {
        Form4OwnershipParser(data: Data(xml.utf8)).parse()["SPCX"]
    }
}
