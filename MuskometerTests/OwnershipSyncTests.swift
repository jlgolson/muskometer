import AppKit
import UserNotifications
import XCTest
@testable import Muskometer

final class AppSettingsHoldingsSyncTests: XCTestCase {
    private func makeSettings() -> AppSettings {
        let suiteName = "MuskometerTests-holdings-sync-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppSettings(defaults: defaults)
    }

    func testEmptyResultDoesNotSetLastHoldingsSyncDate() {
        let settings = makeSettings()
        let syncedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let complete = settings.applyHoldingsSync(
            HoldingsSyncResult(
                sharesBySymbol: [:],
                syncedAt: syncedAt,
                sourceDescription: "SEC EDGAR Form 4"
            )
        )

        XCTAssertFalse(complete)
        XCTAssertNil(settings.lastHoldingsSyncDate)
        XCTAssertNil(settings.holdingsSyncSource)
        // Attempt is still recorded so auto-retry backs off.
        XCTAssertEqual(settings.lastHoldingsSyncAttemptAt, syncedAt)
    }

    func testPartialResultDoesNotSetLastHoldingsSyncDate() {
        let settings = makeSettings()
        let syncedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let priorTSLA = settings.shareCount(for: "TSLA")
        let priorSPCX = settings.shareCount(for: "SPCX")

        let complete = settings.applyHoldingsSync(
            HoldingsSyncResult(
                sharesBySymbol: ["TSLA": 123],
                syncedAt: syncedAt,
                sourceDescription: "SEC EDGAR Form 4"
            )
        )

        XCTAssertFalse(complete)
        // Partial sync must not overwrite any share counts — keep prior values.
        XCTAssertEqual(settings.shareCount(for: "TSLA"), priorTSLA)
        XCTAssertEqual(settings.shareCount(for: "SPCX"), priorSPCX)
        XCTAssertNil(settings.lastHoldingsSyncDate)
        XCTAssertNil(settings.holdingsSyncSource)
        XCTAssertEqual(settings.lastHoldingsSyncAttemptAt, syncedAt)
    }

    func testPartialApplySuppressesNeedsHoldingsSyncUntilIntervalElapses() {
        let settings = makeSettings()
        XCTAssertTrue(settings.needsHoldingsSync)

        // Whole-second Date avoids flaky equality after UserDefaults Double round-trip.
        let recentAttempt = Date(timeIntervalSince1970: floor(Date.now.timeIntervalSince1970) - 60)
        let complete = settings.applyHoldingsSync(
            HoldingsSyncResult(
                sharesBySymbol: ["TSLA": 123],
                syncedAt: recentAttempt,
                sourceDescription: "SEC EDGAR Form 4"
            )
        )

        XCTAssertFalse(complete)
        XCTAssertNil(settings.lastHoldingsSyncDate)
        XCTAssertEqual(
            settings.lastHoldingsSyncAttemptAt?.timeIntervalSince1970 ?? 0,
            recentAttempt.timeIntervalSince1970,
            accuracy: 0.001
        )
        // Partial apply must not re-trigger auto-sync on the next quote cycle.
        XCTAssertFalse(settings.needsHoldingsSync)

        // Once the daily interval elapses, auto-sync is allowed again.
        settings.recordHoldingsSyncAttempt(
            at: Date(timeIntervalSince1970: floor(Date.now.timeIntervalSince1970) - (AppSettings.holdingsSyncInterval + 1))
        )
        XCTAssertTrue(settings.needsHoldingsSync)
    }

    func testFullResultSetsLastHoldingsSyncDate() {
        let settings = makeSettings()
        let syncedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let complete = settings.applyHoldingsSync(
            HoldingsSyncResult(
                sharesBySymbol: ["TSLA": 123, "SPCX": 456],
                syncedAt: syncedAt,
                sourceDescription: "SEC EDGAR Form 4"
            )
        )

        XCTAssertTrue(complete)
        XCTAssertEqual(settings.shareCount(for: "TSLA"), 123)
        XCTAssertEqual(settings.shareCount(for: "SPCX"), 456)
        XCTAssertEqual(settings.lastHoldingsSyncDate, syncedAt)
        XCTAssertEqual(settings.lastHoldingsSyncAttemptAt, syncedAt)
        XCTAssertEqual(settings.holdingsSyncSource, "SEC EDGAR Form 4")
        // Successful complete within the interval also suppresses auto-sync.
        settings.recordHoldingsSyncAttempt(at: Date.now)
        XCTAssertFalse(settings.needsHoldingsSync)
    }

    func testCompleteResultWithZeroSharesAppliesFullDisposal() {
        let settings = makeSettings()
        let syncedAt = Date(timeIntervalSince1970: 1_700_000_000)
        // Establish non-zero prior so we can prove zero is applied (not left as default/prior).
        settings.setShareCount(999_999, for: "TSLA")
        settings.setShareCount(888_888, for: "SPCX")

        let complete = settings.applyHoldingsSync(
            HoldingsSyncResult(
                sharesBySymbol: ["TSLA": 0, "SPCX": 456],
                syncedAt: syncedAt,
                sourceDescription: "SEC EDGAR Form 4"
            )
        )

        XCTAssertTrue(complete)
        XCTAssertEqual(settings.shareCount(for: "TSLA"), 0)
        XCTAssertEqual(settings.shareCount(for: "SPCX"), 456)
        XCTAssertEqual(settings.lastHoldingsSyncDate, syncedAt)
        XCTAssertEqual(settings.holdingsSyncSource, "SEC EDGAR Form 4")
    }

    func testPartialResultWithOnlyZeroForOneSymbolRemainsIncomplete() {
        let settings = makeSettings()
        let syncedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let priorTSLA = settings.shareCount(for: "TSLA")
        let priorSPCX = settings.shareCount(for: "SPCX")

        // Only one expected symbol present (as zero). Missing SPCX means incomplete —
        // zero alone must not be treated as a complete sync that clears prior counts.
        let complete = settings.applyHoldingsSync(
            HoldingsSyncResult(
                sharesBySymbol: ["TSLA": 0],
                syncedAt: syncedAt,
                sourceDescription: "SEC EDGAR Form 4"
            )
        )

        XCTAssertFalse(complete)
        XCTAssertEqual(settings.shareCount(for: "TSLA"), priorTSLA)
        XCTAssertEqual(settings.shareCount(for: "SPCX"), priorSPCX)
        XCTAssertNil(settings.lastHoldingsSyncDate)
        XCTAssertNil(settings.holdingsSyncSource)
        XCTAssertEqual(settings.lastHoldingsSyncAttemptAt, syncedAt)
    }

    func testUnknownPersonIDFallsBackToMusk() {
        let settings = makeSettings()
        settings.selectedPersonID = "zuckerberg"

        XCTAssertEqual(settings.selectedPersonID, "zuckerberg")
        XCTAssertEqual(settings.selectedProfile.id, TrackedPersonProfile.musk.id)
        XCTAssertEqual(settings.selectedProfile.expectedSymbols, Set(["TSLA", "SPCX"]))
    }

}

final class CompanyFactsOutstandingResolverTests: XCTestCase {
    private func data(_ json: String) -> Data {
        Data(json.utf8)
    }

    func testSingleEntityCommonStockSharesOutstanding() {
        let json = """
        {
          "facts": {
            "dei": {
              "EntityCommonStockSharesOutstanding": {
                "units": {
                  "shares": [
                    {
                      "end": "2026-07-16",
                      "val": 3949547394,
                      "form": "10-Q",
                      "filed": "2026-07-23"
                    }
                  ]
                }
              }
            }
          }
        }
        """
        XCTAssertEqual(
            CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: data(json)),
            3_949_547_394
        )
        let fact = try? XCTUnwrap(CompanyFactsOutstandingResolver.resolve(from: data(json)))
        XCTAssertEqual(fact?.shares, 3_949_547_394)
        XCTAssertEqual(fact?.periodEnd, "2026-07-16")
        XCTAssertEqual(fact?.filed, "2026-07-23")
    }

    func testConflictingSameEndFiledTotalsAreUnresolved() {
        let json = """
        {
          "facts": {
            "dei": {
              "EntityCommonStockSharesOutstanding": {
                "units": {
                  "shares": [
                    {
                      "end": "2026-07-28",
                      "val": 100,
                      "form": "10-Q",
                      "filed": "2026-08-01"
                    },
                    {
                      "end": "2026-07-28",
                      "val": 200,
                      "form": "10-Q",
                      "filed": "2026-08-01"
                    }
                  ]
                }
              }
            }
          }
        }
        """
        XCTAssertNil(CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: data(json)))
    }

    func testWASOOnlyReturnsNil() {
        let json = """
        {
          "facts": {
            "us-gaap": {
              "WeightedAverageNumberOfSharesOutstandingBasic": {
                "units": {
                  "shares": [
                    {
                      "end": "2026-06-30",
                      "val": 5860000000,
                      "form": "10-Q",
                      "filed": "2026-08-01"
                    }
                  ]
                }
              },
              "WeightedAverageNumberOfDilutedSharesOutstanding": {
                "units": {
                  "shares": [
                    {
                      "end": "2026-06-30",
                      "val": 6000000000,
                      "form": "10-Q",
                      "filed": "2026-08-01"
                    }
                  ]
                }
              }
            }
          }
        }
        """
        XCTAssertNil(CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: data(json)))
    }

    func testPrefers10QOverNonPreferredFormWithLaterEndOrFiled() {
        // 8-K has later end and filed; preferred 10-Q pool must win per form preference.
        let json = """
        {
          "facts": {
            "dei": {
              "EntityCommonStockSharesOutstanding": {
                "units": {
                  "shares": [
                    {
                      "end": "2026-08-01",
                      "val": 999,
                      "form": "8-K",
                      "filed": "2026-08-05"
                    },
                    {
                      "end": "2026-07-16",
                      "val": 3949547394,
                      "form": "10-Q",
                      "filed": "2026-07-23"
                    }
                  ]
                }
              }
            }
          }
        }
        """
        XCTAssertEqual(
            CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: data(json)),
            3_949_547_394
        )
    }

    func testFallsBackToCommonStockSharesOutstandingWhenEntityMissing() {
        let json = """
        {
          "facts": {
            "us-gaap": {
              "CommonStockSharesOutstanding": {
                "units": {
                  "shares": [
                    {
                      "end": "2025-12-31",
                      "val": 111222333,
                      "form": "10-K",
                      "filed": "2026-02-01"
                    }
                  ]
                }
              }
            }
          }
        }
        """
        XCTAssertEqual(
            CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: data(json)),
            111_222_333
        )
    }

    func testInvalidJSONReturnsNil() {
        XCTAssertNil(CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: data("not-json")))
        XCTAssertNil(CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: data("{}")))
    }
}

final class SPCXHoldingsTests: XCTestCase {
    private let sellableDefault: Int64 = 5_116_475_230

    func testDefaultShareCountIsSellableOwnership() {
        XCTAssertEqual(SPCXHoldings.defaultShareCount, sellableDefault)
    }

    func testMigratesLegacyScaledDefault() {
        XCTAssertEqual(SPCXHoldings.migrateStoredShareCount(60_685_475), sellableDefault)
    }

    func testMigratesLegacySingleRowParse() {
        XCTAssertEqual(SPCXHoldings.migrateStoredShareCount(842_091_670), sellableDefault)
    }

    func testMigratesLegacyMisparseLastRow() {
        XCTAssertEqual(SPCXHoldings.migrateStoredShareCount(7_402_770), sellableDefault)
    }

    func testMigratesLegacyPartialAggregateDefault() {
        XCTAssertEqual(SPCXHoldings.migrateStoredShareCount(6_068_547_515), sellableDefault)
    }

    func testMigratesPriorBundledDefaultWithPerformanceRSUs() {
        XCTAssertEqual(SPCXHoldings.migrateStoredShareCount(6_068_734_060), sellableDefault)
    }

    func testLeavesSellableDefaultAndUnknownUntouched() {
        XCTAssertEqual(SPCXHoldings.migrateStoredShareCount(5_116_475_230), 5_116_475_230)
        XCTAssertEqual(SPCXHoldings.migrateStoredShareCount(6_068_547_514), 6_068_547_514)
    }

    /// Legacy fingerprints already under `shareCount_SPCX` must be rewritten on load.
    func testAppSettingsRewritesLegacyFingerprintUnderNewKey() {
        let suiteName = "MuskometerTests-spcx-newkey-legacy-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Partial aggregate already stored under the new key (never re-migrated before this fix).
        defaults.set(String(6_068_547_515), forKey: "shareCount_SPCX")

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.shareCount(for: "SPCX"), SPCXHoldings.defaultShareCount)
        XCTAssertEqual(defaults.string(forKey: "shareCount_SPCX"), String(SPCXHoldings.defaultShareCount))
    }

    /// Non-fingerprint values under the new key must not be rewritten.
    func testAppSettingsLeavesUnknownSPCXShareCountUnderNewKey() {
        let suiteName = "MuskometerTests-spcx-newkey-unknown-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let customCount: Int64 = 6_068_547_514
        defaults.set(String(customCount), forKey: "shareCount_SPCX")

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.shareCount(for: "SPCX"), customCount)
        XCTAssertEqual(defaults.string(forKey: "shareCount_SPCX"), String(customCount))
    }

    func testAppSettingsRewritesLegacyTSLAFingerprintUnderNewKey() {
        let suiteName = "MuskometerTests-tsla-legacy-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(String(699_580_882), forKey: "shareCount_TSLA")

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.shareCount(for: "TSLA"), 710_172_677)
        XCTAssertEqual(defaults.string(forKey: "shareCount_TSLA"), String(710_172_677))
    }

    func testAppSettingsLeavesCurrentTSLADefaultUntouched() {
        let suiteName = "MuskometerTests-tsla-current-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(String(710_172_677), forKey: "shareCount_TSLA")

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.shareCount(for: "TSLA"), 710_172_677)
        XCTAssertEqual(defaults.string(forKey: "shareCount_TSLA"), String(710_172_677))
    }

    func testAppSettingsLeavesCustomTSLAShareCountUntouched() {
        let suiteName = "MuskometerTests-tsla-custom-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(String(123_456), forKey: "shareCount_TSLA")

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.shareCount(for: "TSLA"), 123_456)
        XCTAssertEqual(defaults.string(forKey: "shareCount_TSLA"), String(123_456))
    }

    func testEmptySuiteReturnsNewTSLADefault() {
        let suiteName = "MuskometerTests-tsla-empty-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.shareCount(for: "TSLA"), 710_172_677)
    }
}

final class SPCXOwnershipCalculatorTests: XCTestCase {
    func testAggregatesJune2026Form4Holdings() {
        let xml = """
        <ownershipDocument>
            <issuer><issuerTradingSymbol>SPCX</issuerTradingSymbol></issuer>
            <nonDerivativeTable>
                <nonDerivativeHolding>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>842091670</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Elon Musk Revocable Trust</value></natureOfOwnership></ownershipNature>
                </nonDerivativeHolding>
                <nonDerivativeHolding>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>7402770</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By EM 2024 GRAT-A</value></natureOfOwnership></ownershipNature>
                </nonDerivativeHolding>
                <nonDerivativeHolding>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>186545</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Trust</value></natureOfOwnership></ownershipNature>
                </nonDerivativeHolding>
                <nonDerivativeTransaction>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>0</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Trust</value></natureOfOwnership></ownershipNature>
                </nonDerivativeTransaction>
            </nonDerivativeTable>
            <derivativeTable>
                <derivativeHolding>
                    <securityTitle><value>Class B Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>3788654145</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Elon Musk Revocable Trust</value></natureOfOwnership></ownershipNature>
                </derivativeHolding>
                <derivativeHolding>
                    <securityTitle><value>Class B Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>127426150</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Mission Trust</value></natureOfOwnership></ownershipNature>
                </derivativeHolding>
                <derivativeHolding>
                    <securityTitle><value>Class B Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>900495</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Musk 2017 Sprinkling Trust</value></natureOfOwnership></ownershipNature>
                </derivativeHolding>
                <derivativeHolding>
                    <securityTitle><value>Option to Buy (Class B Common Stock)</value></securityTitle>
                    <underlyingSecurityShares><value>350000000</value></underlyingSecurityShares>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>350000000</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>D</value></directOrIndirectOwnership></ownershipNature>
                </derivativeHolding>
            </derivativeTable>
            <remarks>does not include 1302072285 shares of restricted Class B Common Stock</remarks>
        </ownershipDocument>
        """

        XCTAssertEqual(SPCXOwnershipCalculator.totalPublicShares(from: xml), 5_116_475_230)
    }

    func testOptionTitleCountsUnderlyingShares() {
        let xml = """
        <ownershipDocument>
            <issuer><issuerTradingSymbol>SPCX</issuerTradingSymbol></issuer>
            <derivativeTable>
                <derivativeHolding>
                    <securityTitle><value>Option to Buy</value></securityTitle>
                    <underlyingSecurityShares><value>100</value></underlyingSecurityShares>
                </derivativeHolding>
            </derivativeTable>
        </ownershipDocument>
        """
        XCTAssertEqual(SPCXOwnershipCalculator.totalPublicShares(from: xml), 100)
    }

    func testRemarksPerformanceSharesAreNotAdded() {
        let xml = """
        <ownershipDocument>
            <issuer><issuerTradingSymbol>SPCX</issuerTradingSymbol></issuer>
            <nonDerivativeTable>
                <nonDerivativeHolding>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>1000</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Trust</value></natureOfOwnership></ownershipNature>
                </nonDerivativeHolding>
            </nonDerivativeTable>
            <remarks>does not include 1302072285 shares of restricted Class B Common Stock</remarks>
        </ownershipDocument>
        """
        XCTAssertEqual(SPCXOwnershipCalculator.totalPublicShares(from: xml), 1000)
    }

    func testUsesLatestRowNotMaxWhenLaterRowHasLowerShares() {
        // Same (title, nature) appears twice; later post-transaction amount is lower (sale).
        let xml = """
        <ownershipDocument>
            <issuer><issuerTradingSymbol>SPCX</issuerTradingSymbol></issuer>
            <nonDerivativeTable>
                <nonDerivativeTransaction>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>1000000</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Elon Musk Revocable Trust</value></natureOfOwnership></ownershipNature>
                </nonDerivativeTransaction>
                <nonDerivativeTransaction>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>400000</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Elon Musk Revocable Trust</value></natureOfOwnership></ownershipNature>
                </nonDerivativeTransaction>
                <nonDerivativeHolding>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>100000</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Other Trust</value></natureOfOwnership></ownershipNature>
                </nonDerivativeHolding>
            </nonDerivativeTable>
        </ownershipDocument>
        """

        // Latest for Revocable Trust is 400_000 (not max 1_000_000) + 100_000 other = 500_000
        XCTAssertEqual(SPCXOwnershipCalculator.totalPublicShares(from: xml), 500_000)
    }

    func testUsesLatestZeroRowWhenTrustFullyDisposed() {
        // Full disposal: same (title, nature) goes 1_000_000 → 0; disposed line must not contribute.
        let xml = """
        <ownershipDocument>
            <issuer><issuerTradingSymbol>SPCX</issuerTradingSymbol></issuer>
            <nonDerivativeTable>
                <nonDerivativeTransaction>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>1000000</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Elon Musk Revocable Trust</value></natureOfOwnership></ownershipNature>
                </nonDerivativeTransaction>
                <nonDerivativeTransaction>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>0</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Elon Musk Revocable Trust</value></natureOfOwnership></ownershipNature>
                </nonDerivativeTransaction>
                <nonDerivativeHolding>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>100000</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Other Trust</value></natureOfOwnership></ownershipNature>
                </nonDerivativeHolding>
            </nonDerivativeTable>
        </ownershipDocument>
        """

        // Latest for Revocable Trust is 0 (not 1_000_000) + 100_000 other = 100_000
        XCTAssertEqual(SPCXOwnershipCalculator.totalPublicShares(from: xml), 100_000)
    }

    func testConvertsSeriesAPreferredToClassAEquivalentTimes50() {
        let xml = """
        <ownershipDocument>
            <issuer><issuerTradingSymbol>SPCX</issuerTradingSymbol></issuer>
            <derivativeTable>
                <derivativeHolding>
                    <securityTitle><value>Series A Preferred Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>1000</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Elon Musk Revocable Trust</value></natureOfOwnership></ownershipNature>
                </derivativeHolding>
                <derivativeHolding>
                    <securityTitle><value>Series B Preferred Stock</value></securityTitle>
                    <postTransactionAmounts><sharesOwnedFollowingTransaction><value>200</value></sharesOwnedFollowingTransaction></postTransactionAmounts>
                    <ownershipNature><directOrIndirectOwnership><value>I</value></directOrIndirectOwnership><natureOfOwnership><value>By Mission Trust</value></natureOfOwnership></ownershipNature>
                </derivativeHolding>
            </derivativeTable>
        </ownershipDocument>
        """

        // 1000 × 50 + 200 × 50 = 60_000 Class A-equivalent
        XCTAssertEqual(SPCXOwnershipCalculator.totalPublicShares(from: xml), 60_000)
    }
}

final class SECHoldingsSyncServiceFormTypeTests: XCTestCase {
    func testAcceptsForm4AndAmendment() {
        XCTAssertTrue(SECHoldingsSyncService.isForm4Filing("4"))
        XCTAssertTrue(SECHoldingsSyncService.isForm4Filing("4/A"))
    }

    func testRejectsOtherFormTypes() {
        XCTAssertFalse(SECHoldingsSyncService.isForm4Filing("3"))
        XCTAssertFalse(SECHoldingsSyncService.isForm4Filing("3/A"))
        XCTAssertFalse(SECHoldingsSyncService.isForm4Filing("5"))
        XCTAssertFalse(SECHoldingsSyncService.isForm4Filing("5/A"))
        XCTAssertFalse(SECHoldingsSyncService.isForm4Filing("8-K"))
        XCTAssertFalse(SECHoldingsSyncService.isForm4Filing("13F-HR"))
        XCTAssertFalse(SECHoldingsSyncService.isForm4Filing(""))
        XCTAssertFalse(SECHoldingsSyncService.isForm4Filing("4A"))
        XCTAssertFalse(SECHoldingsSyncService.isForm4Filing("4 /A"))
    }

    /// Guard against regressing to a short scan window that misses rarer issuers (e.g. SPCX under a TSLA-heavy stream).
    func testMaxForm4AccessionsToScanIsDeepEnoughForMultiIssuerProfiles() {
        XCTAssertGreaterThanOrEqual(SECHoldingsSyncService.maxForm4AccessionsToScan, 100)
    }
}

final class Form4OwnershipParserTests: XCTestCase {
    func testUsesLastDirectTransactionNotMaxAcrossRows() {
        let xml = """
        <ownershipDocument>
            <issuer>
                <issuerTradingSymbol>TSLA</issuerTradingSymbol>
            </issuer>
            <nonDerivativeTable>
                <nonDerivativeTransaction>
                    <postTransactionAmounts>
                        <sharesOwnedFollowingTransaction>
                            <value>800000000</value>
                        </sharesOwnedFollowingTransaction>
                    </postTransactionAmounts>
                    <ownershipNature>
                        <directOrIndirectOwnership>
                            <value>D</value>
                        </directOrIndirectOwnership>
                    </ownershipNature>
                </nonDerivativeTransaction>
                <nonDerivativeTransaction>
                    <postTransactionAmounts>
                        <sharesOwnedFollowingTransaction>
                            <value>699580882</value>
                        </sharesOwnedFollowingTransaction>
                    </postTransactionAmounts>
                    <ownershipNature>
                        <directOrIndirectOwnership>
                            <value>D</value>
                        </directOrIndirectOwnership>
                    </ownershipNature>
                </nonDerivativeTransaction>
            </nonDerivativeTable>
        </ownershipDocument>
        """

        let parser = Form4OwnershipParser(data: Data(xml.utf8))
        let result = parser.parse()

        XCTAssertEqual(result["TSLA"], 699_580_882)
        XCTAssertNil(result["SPCX"])
    }

    func testPrefersDirectOwnershipOverHigherIndirectRows() {
        let xml = """
        <ownershipDocument>
            <issuer>
                <issuerTradingSymbol>TSLA</issuerTradingSymbol>
            </issuer>
            <nonDerivativeTable>
                <nonDerivativeTransaction>
                    <postTransactionAmounts>
                        <sharesOwnedFollowingTransaction>
                            <value>1000000000</value>
                        </sharesOwnedFollowingTransaction>
                    </postTransactionAmounts>
                    <ownershipNature>
                        <directOrIndirectOwnership>
                            <value>I</value>
                        </directOrIndirectOwnership>
                    </ownershipNature>
                </nonDerivativeTransaction>
                <nonDerivativeHolding>
                    <postTransactionAmounts>
                        <sharesOwnedFollowingTransaction>
                            <value>699580882</value>
                        </sharesOwnedFollowingTransaction>
                    </postTransactionAmounts>
                    <ownershipNature>
                        <directOrIndirectOwnership>
                            <value>D</value>
                        </directOrIndirectOwnership>
                    </ownershipNature>
                </nonDerivativeHolding>
            </nonDerivativeTable>
        </ownershipDocument>
        """

        let parser = Form4OwnershipParser(data: Data(xml.utf8))
        let result = parser.parse()

        XCTAssertEqual(result["TSLA"], 699_580_882)
    }

    func testSPCXUsesOwnershipAggregatorNotSingleRow() {
        let xml = """
        <ownershipDocument>
            <issuer><issuerTradingSymbol>SPCX</issuerTradingSymbol></issuer>
            <nonDerivativeTable>
                <nonDerivativeHolding>
                    <securityTitle><value>Class A Common Stock</value></securityTitle>
                    <postTransactionAmounts>
                        <sharesOwnedFollowingTransaction><value>7402770</value></sharesOwnedFollowingTransaction>
                    </postTransactionAmounts>
                    <ownershipNature>
                        <directOrIndirectOwnership><value>I</value></directOrIndirectOwnership>
                        <natureOfOwnership><value>By EM 2024 GRAT-A</value></natureOfOwnership>
                    </ownershipNature>
                </nonDerivativeHolding>
            </nonDerivativeTable>
            <derivativeTable>
                <derivativeHolding>
                    <securityTitle><value>Class B Common Stock</value></securityTitle>
                    <underlyingSecurityShares><value>1000000000</value></underlyingSecurityShares>
                    <ownershipNature>
                        <directOrIndirectOwnership><value>I</value></directOrIndirectOwnership>
                        <natureOfOwnership><value>By Elon Musk Revocable Trust</value></natureOfOwnership>
                    </ownershipNature>
                </derivativeHolding>
            </derivativeTable>
            <remarks>
                does not include 500000000 shares of restricted Class B Common Stock
            </remarks>
        </ownershipDocument>
        """

        let parser = Form4OwnershipParser(data: Data(xml.utf8))
        let result = parser.parse()

        XCTAssertNil(result["TSLA"])
        // Table only: Class A 7_402_770 + Class B 1_000_000_000. Remarks restricted
        // shares are not sellable ownership and must not be added.
        XCTAssertEqual(result["SPCX"], 1_007_402_770)
    }
}

/// All HTTP responses, including accession coverage, are controlled at the SEC transport boundary.
private final class OwnershipFixtureProtocol: URLProtocol {
    static let lock = NSLock()
    static var fixtures: [String: [String: Data]] = [:]
    static var requests: [String: [String]] = [:]
    static var accessionCounter = 900000
    static func nextAccession() -> String {
        lock.withLock {
            accessionCounter += 1
            return "0000000000-26-" + String(format: "%06d", accessionCounter)
        }
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        let fixtureID = request.value(forHTTPHeaderField: "Fixture-ID") ?? ""
        Self.requests[fixtureID, default: []].append(request.url!.path)
        let data = Self.fixtures[fixtureID]?[request.url!.path]
        Self.lock.unlock()
        guard let data else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist)); return
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class OwnershipReconciliationTests: XCTestCase {
    private struct Filing {
        let accession: String
        let form: String
        let filed: String
        let xml: String
        init(_ xml: String, accession: String = OwnershipFixtureProtocol.nextAccession(), form: String = "4", filed: String = "2026-07-01") {
            self.xml = xml; self.accession = accession; self.form = form; self.filed = filed
        }
    }
    private func anchor(_ symbol: String) throws -> Filing {
        let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/Ownership/\(symbol.lowercased())-anchor.xml")
        return Filing(try String(contentsOf: path, encoding: .utf8), accession: symbol == "SPCX" ? "0001628280-26-044069" : "0001104659-26-075213", filed: "2026-06-17")
    }
    private func row(_ shares: String, title: String = "Class A Common Stock", nature: String = "By Elon Musk Revocable Trust", date: String? = "2026-06-25", kind: String = "nonDerivativeTransaction", extra: String = "") -> String {
        "<\(kind)><securityTitle><value>\(title)</value></securityTitle>" + (date.map { "<transactionDate><value>\($0)</value></transactionDate>" } ?? "") + "<postTransactionAmounts><sharesOwnedFollowingTransaction><value>\(shares)</value></sharesOwnedFollowingTransaction></postTransactionAmounts><ownershipNature><directOrIndirectOwnership><value>\(nature.isEmpty ? "D" : "I")</value></directOrIndirectOwnership><natureOfOwnership><value>\(nature)</value></natureOfOwnership></ownershipNature>\(extra)</\(kind)>"
    }
    private func xml(_ rows: String, symbol: String = "SPCX", original: String? = nil) -> String {
        let pattern = try! NSRegularExpression(pattern: #"<(nonDerivativeTransaction|nonDerivativeHolding|derivativeTransaction|derivativeHolding)>[\s\S]*?</\1>"#)
        let blocks = pattern.matches(in: rows, range: NSRange(rows.startIndex..., in: rows)).compactMap { match in
            Range(match.range, in: rows).map { String(rows[$0]) }
        }
        let common = blocks.filter { $0.hasPrefix("<nonDerivative") }.joined()
        let derivatives = blocks.filter { $0.hasPrefix("<derivative") }.joined()
        return "<ownershipDocument><documentType>\(original == nil ? "4" : "4/A")</documentType><periodOfReport>2026-02-02</periodOfReport>" + (original.map { "<dateOfOriginalSubmission>\($0)</dateOfOriginalSubmission>" } ?? "") + "<issuer><issuerTradingSymbol>\(symbol)</issuerTradingSymbol></issuer><nonDerivativeTable>\(common)</nonDerivativeTable><derivativeTable>\(derivatives)</derivativeTable></ownershipDocument>"
    }
    private func sync(_ updates: [Filing], includeAnchors: Bool = true) async throws -> [String: Int64] {
        let entries = updates + (includeAnchors ? try [anchor("SPCX"), anchor("TSLA")] : [])
        let id = UUID().uuidString
        var bodies: [String: Data] = [:]
        let recent: [String: Any] = ["form": entries.map(\.form), "accessionNumber": entries.map(\.accession), "filingDate": entries.map(\.filed), "acceptanceDateTime": entries.map { $0.filed + "T21:00:00.000Z" }]
        bodies["/submissions/CIK0001494730.json"] = try JSONSerialization.data(withJSONObject: ["filings": ["recent": recent]])
        for entry in entries {
            let base = "/Archives/edgar/data/1494730/\(entry.accession.replacingOccurrences(of: "-", with: ""))/"
            bodies[base + entry.accession + "-index.htm"] = Data("<a href=\"\(base)form4.xml\">Form 4</a>".utf8)
            bodies[base + "form4.xml"] = Data(entry.xml.utf8)
        }
        OwnershipFixtureProtocol.lock.withLock { OwnershipFixtureProtocol.fixtures[id] = bodies }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OwnershipFixtureProtocol.self]
        config.httpAdditionalHeaders = ["Fixture-ID": id]
        let session = URLSession(configuration: config)
        defer {
            session.invalidateAndCancel()
            OwnershipFixtureProtocol.lock.withLock {
                OwnershipFixtureProtocol.fixtures.removeValue(forKey: id)
                OwnershipFixtureProtocol.requests.removeValue(forKey: id)
            }
        }
        return try await SECHoldingsSyncService(session: session).syncHoldings().sharesBySymbol
    }
    func testVerifiedAnchorsRemainUnchangedDespiteFebruaryReportDate() async throws {
        let result = try await sync([])
        XCTAssertEqual(result, ["SPCX": 5_116_475_230, "TSLA": 710_172_677])
    }
    func testClassAOnlySalePreservesClassBTrustsAndOptionsAndIsIdempotent() async throws {
        let updates = [Filing(xml(row("842091570")))]
        let result = try await sync(updates)
        XCTAssertEqual(result["SPCX"], 5_116_475_130)
        let repeated = try await sync(updates)
        XCTAssertEqual(result, repeated)
    }
    private func assertUnidentifiedTickerPreservesSyncedHoldings(_ tickerElement: String) async throws {
        let suiteName = "MuskometerTests-unidentified-issuer-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        let validXML = xml(row("842091570"))
        let successfulShares = try await sync([Filing(validXML)])
        XCTAssertEqual(successfulShares, ["SPCX": 5_116_475_130, "TSLA": 710_172_677])
        let successfulAt = Date(timeIntervalSince1970: 1_700_000_000)
        let successfulSource = "Verified sale synchronization"
        XCTAssertTrue(settings.applyHoldingsSync(HoldingsSyncResult(
            sharesBySymbol: successfulShares, syncedAt: successfulAt, sourceDescription: successfulSource
        )))

        let unidentifiedXML = validXML.replacingOccurrences(
            of: "<issuerTradingSymbol>SPCX</issuerTradingSymbol>", with: tickerElement
        )
        let update = Filing(unidentifiedXML)
        for attempt in 1...2 {
            let shares = try await sync([update])
            XCTAssertFalse(TrackedPersonProfile.musk.expectedSymbols.isSubset(of: Set(shares.keys)),
                           "An unidentified newer filing must not return complete anchor totals")
            let attemptedAt = successfulAt.addingTimeInterval(Double(attempt) * (AppSettings.holdingsSyncInterval + 1))
            XCTAssertFalse(settings.applyHoldingsSync(HoldingsSyncResult(
                sharesBySymbol: shares, syncedAt: attemptedAt, sourceDescription: "Unidentified issuer attempt"
            )), "The incomplete result must preserve the previously synchronized holding on every replay")
            XCTAssertEqual(settings.shareCount(for: "SPCX"), 5_116_475_130)
            XCTAssertEqual(settings.shareCount(for: "TSLA"), 710_172_677)
            XCTAssertEqual(settings.lastHoldingsSyncDate, successfulAt)
            XCTAssertEqual(settings.holdingsSyncSource, successfulSource)
            XCTAssertEqual(settings.lastHoldingsSyncAttemptAt, attemptedAt)
        }
    }
    func testEmptyIssuerTickerPreservesSyncedHoldingsOnReplay() async throws {
        for tickerElement in ["<issuerTradingSymbol/>", "<issuerTradingSymbol></issuerTradingSymbol>"] {
            try await assertUnidentifiedTickerPreservesSyncedHoldings(tickerElement)
        }
    }
    func testWhitespaceIssuerTickerPreservesSyncedHoldingsOnReplay() async throws {
        try await assertUnidentifiedTickerPreservesSyncedHoldings("<issuerTradingSymbol> \t\n </issuerTradingSymbol>")
    }
    func testMissingIssuerTickerPreservesSyncedHoldingsOnReplay() async throws {
        try await assertUnidentifiedTickerPreservesSyncedHoldings("")
    }
    func testValidUnrelatedIssuerDoesNotInvalidateAnchorCoverage() async throws {
        let result = try await sync([Filing(xml(row("842091570"), symbol: "OTHER"))])
        XCTAssertEqual(result, ["SPCX": 5_116_475_230, "TSLA": 710_172_677])
    }
    private func documentWithTables(_ tables: String, symbol: String) -> String {
        "<ownershipDocument><documentType>4</documentType><issuer><issuerTradingSymbol>\(symbol)</issuerTradingSymbol></issuer>\(tables)</ownershipDocument>"
    }

    private func assertRowlessTablesPreserveSyncedHoldings(_ tables: String) async throws {
        for symbol in ["SPCX", "TSLA"] {
            let suiteName = "MuskometerTests-rowless-tables-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defer { defaults.removePersistentDomain(forName: suiteName) }
            let settings = AppSettings(defaults: defaults)
            let spcxSale = Filing(xml(row("842091570")))
            let tslaSale = Filing(xml(row("700000000", title: "Common Stock", nature: ""), symbol: "TSLA"))
            let successfulShares = try await sync([spcxSale, tslaSale])
            XCTAssertEqual(successfulShares, ["SPCX": 5_116_475_130, "TSLA": 700_000_000])
            let successfulAt = Date(timeIntervalSince1970: 1_700_000_000)
            let successfulSource = "Verified newer ownership balances"
            XCTAssertTrue(settings.applyHoldingsSync(HoldingsSyncResult(
                sharesBySymbol: successfulShares, syncedAt: successfulAt, sourceDescription: successfulSource
            )))

            // Refetch the same accession with incomplete tables, then retry after the daily backoff.
            let accession = symbol == "SPCX" ? spcxSale.accession : tslaSale.accession
            let incomplete = Filing(documentWithTables(tables, symbol: symbol), accession: accession)
            for attempt in 1...2 {
                let context = "\(symbol), tables=\(tables), replay=\(attempt)"
                let shares = try await sync([incomplete])
                XCTAssertNil(shares[symbol], "Missing row evidence must omit the affected issuer: \(context)")
                let attemptedAt = successfulAt.addingTimeInterval(Double(attempt) * (AppSettings.holdingsSyncInterval + 1))
                XCTAssertFalse(settings.applyHoldingsSync(HoldingsSyncResult(
                    sharesBySymbol: shares, syncedAt: attemptedAt, sourceDescription: "Incomplete table attempt"
                )), context)
                XCTAssertEqual(settings.shareCount(for: "SPCX"), 5_116_475_130, context)
                XCTAssertEqual(settings.shareCount(for: "TSLA"), 700_000_000, context)
                XCTAssertEqual(settings.lastHoldingsSyncDate, successfulAt, context)
                XCTAssertEqual(settings.holdingsSyncSource, successfulSource, context)
                XCTAssertEqual(settings.lastHoldingsSyncAttemptAt, attemptedAt, context)
            }
        }
    }

    func testMissingOwnershipTablesPreserveSyncedHoldingsOnReplay() async throws {
        try await assertRowlessTablesPreserveSyncedHoldings("")
    }

    func testSelfClosingOwnershipTablesPreserveSyncedHoldingsOnReplay() async throws {
        for tables in ["<nonDerivativeTable/>", "<derivativeTable/>", "<nonDerivativeTable/><derivativeTable/>"] {
            try await assertRowlessTablesPreserveSyncedHoldings(tables)
        }
    }

    func testEmptyOwnershipTablesPreserveSyncedHoldingsOnReplay() async throws {
        try await assertRowlessTablesPreserveSyncedHoldings("<nonDerivativeTable></nonDerivativeTable><derivativeTable></derivativeTable>")
    }

    func testWhitespaceOnlyOwnershipTablesPreserveSyncedHoldingsOnReplay() async throws {
        try await assertRowlessTablesPreserveSyncedHoldings("<nonDerivativeTable> \t\n </nonDerivativeTable><derivativeTable> \n </derivativeTable>")
    }

    func testOwnershipContainersWithoutRowsPreserveSyncedHoldingsOnReplay() async throws {
        for contents in ["<!-- no rows supplied -->", "incomplete ownership data", "<unexpectedContainer/>"] {
            try await assertRowlessTablesPreserveSyncedHoldings("<nonDerivativeTable>\(contents)</nonDerivativeTable><derivativeTable/>")
        }
    }

    func testValidSingleOwnershipTableStillAppliesBalance() async throws {
        let cases: [(symbol: String, table: String, rows: String, expected: [String: Int64])] = [
            ("SPCX", "nonDerivativeTable", row("842091570"), ["SPCX": 5_116_475_130, "TSLA": 710_172_677]),
            ("SPCX", "derivativeTable", optionRow("8.3998"), ["SPCX": 4_766_475_231, "TSLA": 710_172_677]),
            ("TSLA", "nonDerivativeTable", row("700000000", title: "Common Stock", nature: ""), ["SPCX": 5_116_475_230, "TSLA": 700_000_000])
        ]
        for entry in cases {
            let other = entry.table == "nonDerivativeTable" ? "derivativeTable" : "nonDerivativeTable"
            for emptyOther in ["", "<\(other)/>", "<\(other)></\(other)>", "<\(other)> \t\n </\(other)>"] {
                let tables = "<\(entry.table)>\(entry.rows)</\(entry.table)>" + emptyOther
                let shares = try await sync([Filing(documentWithTables(tables, symbol: entry.symbol))])
                XCTAssertEqual(shares, entry.expected, tables)
                let suiteName = "MuskometerTests-single-table-\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suiteName)!
                defer { defaults.removePersistentDomain(forName: suiteName) }
                let settings = AppSettings(defaults: defaults)
                XCTAssertTrue(settings.applyHoldingsSync(HoldingsSyncResult(
                    sharesBySymbol: shares, syncedAt: Date(timeIntervalSince1970: 1_700_000_000), sourceDescription: "Valid one-table filing"
                )), tables)
                for (symbol, quantity) in entry.expected {
                    XCTAssertEqual(settings.shareCount(for: symbol), quantity, tables)
                }
            }
        }
    }

    func testIntentionallyUntrackedTSLARowsRemainComplete() async throws {
        let option = row("10", title: "Stock Option (Right to Buy)", nature: "", kind: "derivativeTransaction",
                         extra: "<conversionOrExercisePrice><value>100</value></conversionOrExercisePrice><expirationDate><value>2031-02-11</value></expirationDate>")
        let indirect = row("20", title: "Common Stock", nature: "By Trust")
        for tables in ["<derivativeTable>\(option)</derivativeTable>", "<nonDerivativeTable>\(indirect)</nonDerivativeTable>"] {
            let documentXML = documentWithTables(tables, symbol: "TSLA")
            let document = try XCTUnwrap(Form4OwnershipParser(data: Data(documentXML.utf8)).observations())
            XCTAssertTrue(document.observations.isEmpty, "Valid rows may be irrelevant to the tracked metric")
            XCTAssertFalse(document.hasUnresolvedRelevantRows)
            let shares = try await sync([Filing(documentXML)])
            XCTAssertEqual(shares, ["SPCX": 5_116_475_230, "TSLA": 710_172_677])
        }
    }

    func testLateHistoricalAmendmentCannotReplaceNewerBalance() async throws {
        let amendment = Filing(xml(row("800000000", date: "2026-06-20"), original: "2026-06-21"), form: "4/A", filed: "2026-07-03")
        let newer = Filing(xml(row("842091570")), filed: "2026-06-26")
        let original = Filing(xml(row("810000000", date: "2026-06-20")), filed: "2026-06-21")
        let result = try await sync([amendment, newer, original])
        XCTAssertEqual(result["SPCX"], 5_116_475_130)
    }
    func testUniquelyTargetedAmendmentCorrectsOriginalBalance() async throws {
        let amendment = Filing(xml(row("842091570"), original: "2026-06-26"), form: "4/A", filed: "2026-07-03")
        let original = Filing(xml(row("810000000")), filed: "2026-06-26")
        let result = try await sync([amendment, original])
        XCTAssertEqual(result["SPCX"], 5_116_475_130)
    }
    func testAmendmentCannotChooseAmongMultipleOriginalRowsOnOneDay() async throws {
        let original = Filing(xml(row("842091600") + row("842091570")), filed: "2026-06-26")
        let amendment = Filing(xml(row("842091550"), original: "2026-06-26"), form: "4/A")
        let result = try await sync([amendment, original])
        XCTAssertNil(result["SPCX"])
    }
    func testSupersededOrdinaryObservationDoesNotRegressAnchor() async throws {
        let result = try await sync([Filing(xml(row("1", date: "2026-03-01")))])
        XCTAssertEqual(result["SPCX"], 5_116_475_230)
    }
    func testNewDirectTSLAOrdinaryBalancePreservesSPCX() async throws {
        let result = try await sync([Filing(xml(row("700000000", title: "Common Stock", nature: ""), symbol: "TSLA"))])
        XCTAssertEqual(result, ["TSLA": 700_000_000, "SPCX": 5_116_475_230])
    }
    func testOptionGrantIdentityMustMatchStrikeAndExpiry() async throws {
        let changedOption = row("1", title: "Option to Buy (Class B Common Stock)", nature: "", kind: "derivativeTransaction", extra: "<conversionOrExercisePrice><value>9</value></conversionOrExercisePrice><expirationDate><value>2031-02-11</value></expirationDate>")
        let result = try await sync([Filing(xml(changedOption))])
        XCTAssertNil(result["SPCX"])
    }
    func testDistinctHighPrecisionOptionStrikeCannotReplaceAnchorBucket() async throws {
        let strike = "8.399800000000000000000000000000000000000000000000001"
        let result = try await sync([Filing(xml(optionRow(strike)))])
        XCTAssertNil(result["SPCX"], "A distinct precise strike must not replace the 350,000,000-option anchor bucket")
        XCTAssertEqual(result["TSLA"], 710_172_677)
    }

    func testEquivalentOptionStrikeSpellingsReplaceAnchorBucket() async throws {
        for strike in ["8.3998", "0008.399800", "8.399800000000000000000000000000000000000000000000000"] {
            let result = try await sync([Filing(xml(optionRow(strike)))])
            XCTAssertEqual(result, ["SPCX": 4_766_475_231, "TSLA": 710_172_677], strike)
        }
    }

    func testOptionStrikeIdentityPreservesSignificantDecimalDigits() throws {
        let precise = "8.399800000000000000000000000000000000000000000000001"
        let anchorBucket = try XCTUnwrap(OwnershipAnchor.all["SPCX"]?.observations.first { $0.bucket.strike == "8.3998" }?.bucket)
        for strike in [precise, "000" + precise + "000"] {
            let document = try XCTUnwrap(Form4OwnershipParser(data: Data(xml(optionRow(strike)).utf8)).observations())
            let bucket = try XCTUnwrap(document.observations.first?.bucket)
            XCTAssertFalse(document.hasUnresolvedRelevantRows)
            XCTAssertEqual(bucket.strike, precise)
            XCTAssertNotEqual(bucket, anchorBucket)
        }
    }

    func testOptionStrikeIdentityNormalizesOnlyInsignificantZeros() throws {
        let forms = [("8.3998", "8.3998"), ("0008.399800", "8.3998"), ("8", "8"), ("0008.000", "8"),
                     ("0", "0"), ("000.000", "0"), ("000.0001000", "0.0001")]
        for (strike, expected) in forms {
            let document = try XCTUnwrap(Form4OwnershipParser(data: Data(xml(optionRow(strike)).utf8)).observations())
            XCTAssertFalse(document.hasUnresolvedRelevantRows, strike)
            XCTAssertEqual(document.observations.first?.bucket.strike, expected, strike)
        }
    }

    func testMalformedOptionStrikeRemainsUnresolved() throws {
        for strike in ["", "8.", ".8", "8e0", "8,3998", "-8", "+8", "NaN", "８.３９９８"] {
            let document = try XCTUnwrap(Form4OwnershipParser(data: Data(xml(optionRow(strike)).utf8)).observations())
            XCTAssertTrue(document.hasUnresolvedRelevantRows, strike)
            XCTAssertNil(document.observations.first?.bucket.strike, strike)
        }
    }

    private func optionRow(_ strike: String) -> String {
        row("1", title: "Option to Buy (Class B Common Stock)", nature: "", kind: "derivativeTransaction", extra: "<conversionOrExercisePrice><value>\(strike)</value></conversionOrExercisePrice><expirationDate><value>2031-02-11</value></expirationDate>")
    }

    func testCancellationStopsTheBoundedScan() async throws {
        let task = Task { try await self.sync([Filing(self.xml(self.row("1")))]) }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("A canceled sync must not return a reconstructed holding")
        } catch is CancellationError {
            // The service preserves structured cancellation rather than wrapping it as a network error.
        }
    }

    func testUnknownAmendmentTargetIsRefused() async throws {
        let result = try await sync([Filing(xml(row("842091570"), original: "2026-06-26"), form: "4/A")])
        XCTAssertNil(result["SPCX"])
        XCTAssertEqual(result["TSLA"], 710_172_677)
    }
    func testConflictingSameDayFilingsAreRefused() async throws {
        let result = try await sync([Filing(xml(row("1"))), Filing(xml(row("2")))])
        XCTAssertNil(result["SPCX"])
    }
    func testSameDayRowsInOrdinaryFilingUseDocumentOrder() async throws {
        let result = try await sync([Filing(xml(row("842091600") + row("842091570")))])
        XCTAssertEqual(result["SPCX"], 5_116_475_130)
    }
    func testUnknownUndatedMalformedAndUnsupportedUpdatesAreRefused() async throws {
        for change in [row("1", nature: "By Unknown Trust"), row("1", date: nil), row("bogus"), row("1.5"), row("1", title: "Convertible Mystery"), row("1", date: "2026-02-30")] {
            let result = try await sync([Filing(xml(change))])
            XCTAssertNil(result["SPCX"], change)
        }
    }
    func testMissingAnchorCoverageIsRefused() async throws {
        let result = try await sync([Filing(xml(row("1")))], includeAnchors: false)
        XCTAssertNil(result["SPCX"])
    }
    func testHundredAccessionBudgetDoesNotClaimTruncatedCoverage() async throws {
        let updates = (0..<100).map { _ in Filing(xml(row("1"))) }
        let result = try await sync(updates)
        XCTAssertNil(result["SPCX"])
        XCTAssertNil(result["TSLA"])
    }
    func testAggregateOverflowWithValidInt64BalanceIsRefused() async throws {
        let result = try await sync([Filing(xml(row(String(Int64.max))))])
        XCTAssertNil(result["SPCX"])
        XCTAssertEqual(result["TSLA"], 710_172_677)
    }

    func testRecognizedZeroDisposalSurvivesParser() {
        XCTAssertEqual(Form4OwnershipParser(data: Data(xml(row("0")).utf8)).parse()["SPCX"], 0)
    }
    func testFullDisposalZerosEveryPositiveAnchorBucket() async throws {
        let rows = row("0") + row("0", nature: "By EM 2024 GRAT-A") + row("0", title: "Class B Common Stock") + row("0", title: "Class B Common Stock", nature: "By Mission Trust") + row("0", title: "Class B Common Stock", nature: "By Musk 2017 Sprinkling Trust") + row("0", title: "Option to Buy (Class B Common Stock)", nature: "", kind: "derivativeTransaction", extra: "<conversionOrExercisePrice><value>8.3998</value></conversionOrExercisePrice><expirationDate><value>2031-02-11</value></expirationDate>")
        let result = try await sync([Filing(xml(rows))])
        XCTAssertEqual(result["SPCX"], 0)
    }
    func testMalformedXMLCannotProducePartialBalance() {
        XCTAssertTrue(Form4OwnershipParser(data: Data((xml(row("10")) + "<broken>").utf8)).parse().isEmpty)
    }
    func testExactIntegerParsingDoesNotRoundThroughDouble() {
        XCTAssertEqual(Form4OwnershipParser(data: Data(xml(row("9007199254740993")).utf8)).parse()["SPCX"], 9_007_199_254_740_993)
    }
    func testIndividualInt64BoundsAndPreferredMultiplicationOverflow() {
        XCTAssertEqual(Form4OwnershipParser(data: Data(xml(row(String(Int64.max))).utf8)).parse()["SPCX"], Int64.max)
        for quantity in ["9223372036854775808", "999999999999999999999999999999", "1e30"] {
            XCTAssertNil(Form4OwnershipParser(data: Data(xml(row(quantity)).utf8)).parse()["SPCX"])
        }
        XCTAssertNil(Form4OwnershipParser(data: Data(xml(row(String(Int64.max), title: "Series A Preferred Stock")).utf8)).parse()["SPCX"])
    }
    func testExternalDoctypeIsRejectedWithoutReadingResources() {
        let unsafe = "<!DOCTYPE ownershipDocument SYSTEM 'file:///definitely-not-a-real-file'>" + xml(row("10"))
        XCTAssertTrue(Form4OwnershipParser(data: Data(unsafe.utf8)).parse().isEmpty)
    }
    func testVerifiedAnchorTranscriptionMatchesSourceAndKeepsZeros() throws {
        for symbol in ["TSLA", "SPCX"] {
            let parsed = try XCTUnwrap(Form4OwnershipParser(data: Data(anchor(symbol).xml.utf8)).observations())
            XCTAssertEqual(parsed.observations, OwnershipAnchor.all[symbol]?.observations)
        }
        let spcx = try XCTUnwrap(OwnershipAnchor.all["SPCX"])
        var balances: [OwnershipBucket: Int64] = [:]
        for observation in spcx.observations { balances[observation.bucket] = observation.quantity }
        XCTAssertEqual(balances.count, 13)
        XCTAssertEqual(balances.values.filter { $0 == 0 }.count, 7)
        XCTAssertEqual(OwnershipNumber.total(balances), 5_116_475_230)
    }

    func testInvalidNumbersAreUnresolvedInsteadOfZero() {
        for value in ["bogus", "1.5", "-1", ""] {
            XCTAssertNil(Form4OwnershipParser(data: Data(xml(row(value)).utf8)).parse()["SPCX"])
        }
    }
}

final class CompanyFactsDeduplicationTests: XCTestCase {
    private func facts(_ values: String, gaap: String = "") -> Data {
        Data("{\"facts\":{\"dei\":{\"EntityCommonStockSharesOutstanding\":{\"units\":{\"shares\":[\(values)]}}}\(gaap)}}".utf8)
    }
    private func fact(_ value: String, form: String = "10-Q", accession: String = "one") -> String {
        "{\"end\":\"2026-07-16\",\"val\":\(value),\"form\":\"\(form)\",\"filed\":\"2026-07-23\",\"accn\":\"\(accession)\"}"
    }
    func testEqualOriginalAndAmendmentTotalsCountOnce() {
        XCTAssertEqual(CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: facts(fact("100") + "," + fact("100", form: "10-Q/A", accession: "two"))), 100)
    }
    func testConflictingTiedFactsDoNotFallBackToOlderGAAP() {
        let fallback = ",\"us-gaap\":{\"CommonStockSharesOutstanding\":{\"units\":{\"shares\":[{\"end\":\"2025-12-31\",\"val\":50,\"form\":\"10-K\",\"filed\":\"2026-01-30\"}]}}}"
        XCTAssertNil(CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: facts(fact("100") + "," + fact("200", form: "10-Q/A", accession: "two"), gaap: fallback)))
    }
    func testFractionsBeyondDecimalPrecisionAreRejectedExactly() {
        for token in [
            "100.000000000000000000000000000000000000000000000000001",
            "100.00000000000000000000000000000000000000000000000001",
            "9223372036854775807.0000000000000000000000000000001",
            "1.000000000000000000000000000000000000000000000001e2",
            "100000000000000000000000000000000000000000000000001e-48"
        ] {
            XCTAssertNil(CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: facts(fact(token))), token)
        }
    }
    func testLongExactIntegersAndExponentFormsRemainUsable() {
        for token in ["100.000000000000000000000000000000000000000000000000000", "1e2", "1.0e2", "1000e-1", "0.001e5", "1E+00000000000000000000000000000000000000000000000000000002"] {
            XCTAssertEqual(CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: facts(fact(token))), 100, token)
        }
        XCTAssertEqual(CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: facts(fact("9223372036854775807.0000000000000000000000000000000000"))), Int64.max)
    }
    func testNumericTokensCannotBeForgedByStringsObjectsOrInvalidSyntax() {
        for token in [#""100""#, #"{"number":"100"}"#, "01", "1.", ".1", "1e", "+1", "1e99999999999999999999999999999", "1e-99999999999999999999999999999", "1e-1", "-1e2", "9.223372036854775808e18"] {
            XCTAssertNil(CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: facts(fact(token))), token)
        }
    }

    func testCompanyFactsPreservesLargeIntegralDecimalExactly() {
        XCTAssertEqual(CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: facts(fact("9007199254740993.0"))), 9_007_199_254_740_993)
        XCTAssertNil(CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: facts(fact("100.00000000000000001"))))
    }

    func testCompanyFactsInt64BoundaryAndInvalidNumbers() {
        XCTAssertEqual(CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: facts(fact(String(Int64.max)))), Int64.max)
        for value in ["9223372036854775808", "1e30", "true", "0", "-1"] {
            XCTAssertNil(CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: facts(fact(value))))
        }
    }
    func testConflictingFactsWithinSameAccessionAreUnresolved() {
        XCTAssertNil(CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: facts(fact("100") + "," + fact("200"))))
    }

    func testNonintegralOutstandingIsRejected() {
        XCTAssertNil(CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: facts(fact("100.5"))))
    }
}


final class OwnershipArchiveBudgetTests: XCTestCase {
    private final class Fixture {
        let id = UUID().uuidString
        let session: URLSession
        let service: SECHoldingsSyncService
        init(names: [String], pages: [String: Data], recent: [String: Any], extra: [String: Data] = [:]) throws {
            var bodies = extra
            bodies["/submissions/CIK0001494730.json"] = try JSONSerialization.data(withJSONObject: ["filings": ["recent": recent, "files": names.map { ["name": $0, "filingTo": "2026-06-17"] }]])
            for (name, page) in pages { bodies["/submissions/" + name] = page }
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [OwnershipFixtureProtocol.self]
            config.httpAdditionalHeaders = ["Fixture-ID": id]
            session = URLSession(configuration: config)
            service = SECHoldingsSyncService(session: session)
            OwnershipFixtureProtocol.lock.withLock { OwnershipFixtureProtocol.fixtures[id] = bodies }
        }
        var requests: [String] { OwnershipFixtureProtocol.lock.withLock { OwnershipFixtureProtocol.requests[id] ?? [] } }
        deinit {
            session.invalidateAndCancel()
            OwnershipFixtureProtocol.lock.withLock {
                OwnershipFixtureProtocol.fixtures.removeValue(forKey: id)
                OwnershipFixtureProtocol.requests.removeValue(forKey: id)
            }
        }
    }
    private var empty: [String: Any] { ["form": [String](), "accessionNumber": [String](), "filingDate": [String](), "acceptanceDateTime": [String]()] }
    private func name(_ index: Int) -> String { "CIK0001494730-submissions-\(index).json" }
    private func entries(_ accessions: [String]) -> [String: Any] {
        ["form": accessions.map { _ in "4" }, "accessionNumber": accessions, "filingDate": accessions.map { _ in "2026-06-17" }, "acceptanceDateTime": accessions.map { _ in "2026-06-17T21:00:00.000Z" }]
    }
    private func filingBodies(_ accession: String, xml: String) -> [String: Data] {
        let base = "/Archives/edgar/data/1494730/\(accession.replacingOccurrences(of: "-", with: ""))/"
        return [base + accession + "-index.htm": Data("<a href=\"\(base)form4.xml\">Form4</a>".utf8), base + "form4.xml": Data(xml.utf8)]
    }
    private func anchorXML(_ symbol: String) throws -> String {
        try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/Ownership/\(symbol)-anchor.xml"), encoding: .utf8)
    }
    func testEmptyArchivePagesHaveAFixedBudgetOnEveryAttempt() async throws {
        let names = (0..<102).map(name)
        let data = try JSONSerialization.data(withJSONObject: empty)
        let fixture = try Fixture(names: names, pages: Dictionary(uniqueKeysWithValues: names.map { ($0, data) }), recent: empty)
        for attempt in 1...2 {
            let before = fixture.requests.count
            let result = try await fixture.service.syncHoldings()
            XCTAssertTrue(result.sharesBySymbol.isEmpty)
            XCTAssertEqual(fixture.requests.count - before, 11, "One submissions request plus at most ten archive pages, attempt \(attempt)")
        }
    }
    func testDuplicateArchiveNamesAreFetchedOnlyOnce() async throws {
        let data = try JSONSerialization.data(withJSONObject: empty)
        let fixture = try Fixture(names: Array(repeating: name(0), count: 5), pages: [name(0): data], recent: empty)
        let result = try await fixture.service.syncHoldings()
        XCTAssertTrue(result.sharesBySymbol.isEmpty)
        XCTAssertEqual(fixture.requests, ["/submissions/CIK0001494730.json", "/submissions/" + name(0)])
    }
    func testArchivesContainingOnlyVisitedAccessionsStillConsumePageBudget() async throws {
        let accession = "0000000000-26-000001"
        let names = (0..<15).map(name)
        let data = try JSONSerialization.data(withJSONObject: entries([accession]))
        let fixture = try Fixture(names: names, pages: Dictionary(uniqueKeysWithValues: names.map { ($0, data) }), recent: entries([accession]), extra: filingBodies(accession, xml: "<ownershipDocument><issuer><issuerTradingSymbol>OTHER</issuerTradingSymbol></issuer></ownershipDocument>"))
        let result = try await fixture.service.syncHoldings()
        XCTAssertTrue(result.sharesBySymbol.isEmpty)
        XCTAssertEqual(fixture.requests.count, 13, "Initial submissions, one index/XML pair, and ten archive pages")
    }
    func testVerifiedAnchorsCanStillBeDiscoveredInAnArchive() async throws {
        let spcx = "0001628280-26-044069", tsla = "0001104659-26-075213"
        let pages = [name(0): try JSONSerialization.data(withJSONObject: empty), name(1): try JSONSerialization.data(withJSONObject: entries([spcx, tsla]))]
        let bodies = filingBodies(spcx, xml: try anchorXML("spcx")).merging(filingBodies(tsla, xml: try anchorXML("tsla"))) { first, _ in first }
        let fixture = try Fixture(names: [name(0), name(1)], pages: pages, recent: empty, extra: bodies)
        let result = try await fixture.service.syncHoldings()
        XCTAssertEqual(result.sharesBySymbol, ["SPCX": 5_116_475_230, "TSLA": 710_172_677])
        XCTAssertEqual(fixture.requests.count, 7)
    }
    func testAnchorBeyondPageBudgetDoesNotClaimCompleteCoverage() async throws {
        let spcx = "0001628280-26-044069", tsla = "0001104659-26-075213"
        let names = (0..<11).map(name)
        let emptyData = try JSONSerialization.data(withJSONObject: empty)
        var pages = Dictionary(uniqueKeysWithValues: names.map { ($0, emptyData) })
        pages[name(10)] = try JSONSerialization.data(withJSONObject: entries([spcx]))
        let bodies = filingBodies(spcx, xml: try anchorXML("spcx")).merging(filingBodies(tsla, xml: try anchorXML("tsla"))) { first, _ in first }
        let fixture = try Fixture(names: names, pages: pages, recent: entries([tsla]), extra: bodies)
        let result = try await fixture.service.syncHoldings()
        XCTAssertEqual(result.sharesBySymbol, ["TSLA": 710_172_677])
        XCTAssertEqual(fixture.requests.count, 13)
    }
    func testMalformedArchiveStopsWithoutFurtherRequests() async throws {
        let names = (0..<102).map(name)
        let fixture = try Fixture(names: names, pages: Dictionary(uniqueKeysWithValues: names.map { ($0, Data("not JSON".utf8)) }), recent: empty)
        do {
            _ = try await fixture.service.syncHoldings()
            XCTFail("Malformed metadata must not yield complete holdings")
        } catch is DecodingError {}
        XCTAssertEqual(fixture.requests.count, 2)
    }
}
