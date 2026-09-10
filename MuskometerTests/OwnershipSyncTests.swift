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

    func testMultiMemberSameEndFiledSums() {
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
        XCTAssertEqual(
            CompanyFactsOutstandingResolver.resolveSharesOutstanding(from: data(json)),
            300
        )
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
                    <ownershipNature><directOrIndirectOwnership><value>D</value></directOrIndirectOwnership>
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
