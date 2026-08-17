# Parallelism analysis

**Role:** parallelism-analyst
**Plan:** `docs/marshal/plans/2026-08-17-holdings-surface-refresh.md`
**Date:** 2026-08-17
**Threshold:** `MARSHAL_PARALLELISM_MIN_RATIO` = 0.25

## Parallelism analysis

Declared graph (acyclic): `1:[] 2:[] 3:[] 4:[1] 5:[] 6:[] 7:[3,4,5] 8:[5] 9:[1,2,3,4,5,6,7,8] 10:[9]`. Ready-set `{1, 2, 3, 5, 6}`. Transitive closures: 4 also after 1; 7 after 1 (via 4), 3, 4, 5; 8 after 5; 9 after 1–8; 10 after 1–9. `C(10,2) = 45` unordered pairs; 23 are ancestor–descendant (not concurrent); **22 pairs are declared concurrent**.

`component_size` is the length of the longest dependency chain through that task in the full graph (critical-path participation). Longest path is `1→4→7→9→10` (length 5). Sizes: `1:5, 2:3, 3:4, 4:5, 5:4, 6:3, 7:5, 8:4, 9:5, 10:5`. Every concurrent pair’s `min/max` is ≥ 0.600, so **no UNVERIFIED-LOW-VALUE** pairs. No declared serial edge is a missed opportunity: 4 consumes 1’s seed math and the same test file; 7’s copy cites 3/4 integers and 5’s deletion; 8’s mock is the post-5 popover; 9 authors CHANGELOG from the landed diff; 10 verifies the versioned tree.

The ready-set is wide on paper and narrow in the tree. Tasks 1–6 all write `MuskometerTests/MuskometerTests.swift` (one XCTest compilation unit). Tasks 3, 4, and 5 all write `Muskometer/Utilities/AppSettings.swift`. Tasks 2 and 7 both write `docs/ARCHITECTURE.md` with **no** 2→7 edge. Those collisions make **15 / 22** pairs **UNVERIFIED-UNSAFE**. The remaining **7** pairs are file-disjoint marketing/docs vs product work and are **VERIFIED**.

Serialized (not analyzed as concurrent): `{1,4} {1,7} {1,9} {1,10} {2,9} {2,10} {3,7} {3,9} {3,10} {4,7} {4,9} {4,10} {5,7} {5,8} {5,9} {5,10} {6,9} {6,10} {7,9} {7,10} {8,9} {8,10} {9,10}`.

---

- Tasks {1, 2}: declared concurrent.
  - Files touched disjoint: no — both write `MuskometerTests/MuskometerTests.swift` (plan Task 1 Files touched: `SPCXOwnershipCalculator.swift` + tests; Task 2: `MarketHoursService.swift` + tests + `docs/ARCHITECTURE.md`). T1 edits `SPCXOwnershipCalculatorTests`; T2 appends `MarketHoursServiceTests` (same file, line 105).
  - Test-fixture overlap: yes — single XCTest file; concurrent implementers rebase/overwrite adjacent class bodies.
  - Hidden runtime coupling: no — calculator vs NYSE holiday table share no import.
  - Chain-length ratio: 0.600
  - Cost-benefit assessment: meets threshold (0.600 ≥ 0.25)
  - Recommendation: UNVERIFIED-UNSAFE

- Tasks {1, 3}: declared concurrent.
  - Files touched disjoint: no — both write `MuskometerTests/MuskometerTests.swift` (T1 calculator tests; T3 `IssuerSharesOutstandingTests` at line 1054 plus AppSettings outstanding cases).
  - Test-fixture overlap: yes — same test file; T3 also adds remigration cases next to existing outstanding tests.
  - Hidden runtime coupling: no — spec §2 outstanding is orthogonal to Form 4 ownership; `SPCXOwnershipCalculator` does not import `IssuerSharesOutstanding`.
  - Chain-length ratio: 0.800
  - Cost-benefit assessment: meets threshold (0.800 ≥ 0.25)
  - Recommendation: UNVERIFIED-UNSAFE

- Tasks {1, 5}: declared concurrent.
  - Files touched disjoint: no — both write `MuskometerTests/MuskometerTests.swift` (T1 adds calculator tests; T5 deletes `ComparisonLibraryTests` / `ComparisonHistoryStoreTests` / `ComparisonLineSelectorTests` / `GainsViewModelComparisonDebounceTests` in the same file, lines 3661–3997).
  - Test-fixture overlap: yes — same XCTest file; large deletion vs insertion is a guaranteed merge conflict.
  - Hidden runtime coupling: no — calculator is not referenced by comparison types or `GainsViewModel` caption path.
  - Chain-length ratio: 0.800
  - Cost-benefit assessment: meets threshold (0.800 ≥ 0.25)
  - Recommendation: UNVERIFIED-UNSAFE

- Tasks {1, 6}: declared concurrent.
  - Files touched disjoint: no — both write `MuskometerTests/MuskometerTests.swift` (T1 `SPCXOwnershipCalculatorTests`; T6 strips `currentTSLAPrice` asserts in `MergerMarketCapParityTests` / `GainsViewModelMergerParityPresentationTests`, lines 1172, 1287, 1504).
  - Test-fixture overlap: yes — same test file.
  - Hidden runtime coupling: no — option/remarks rule does not feed `MergerParityPresentation`.
  - Chain-length ratio: 0.600
  - Cost-benefit assessment: meets threshold (0.600 ≥ 0.25)
  - Recommendation: UNVERIFIED-UNSAFE

- Tasks {1, 8}: declared concurrent.
  - Files touched disjoint: yes — T1 `SPCXOwnershipCalculator.swift` + `MuskometerTests.swift`; T8 `docs/screenshots/*`, `docs/index.html`, `docs/README.md`, `scripts/verify.sh` (plan Task 8 Files touched). No shared path.
  - Test-fixture overlap: no — T1 XCTest vs T8 static HTML/PNG + a `verify.sh` string grep on marketing HTML.
  - Hidden runtime coupling: no — marketing mock may cite pinned integers from the plan; it does not import or run the calculator.
  - Chain-length ratio: 0.800
  - Cost-benefit assessment: meets threshold (0.800 ≥ 0.25)
  - Recommendation: VERIFIED

- Tasks {2, 3}: declared concurrent.
  - Files touched disjoint: no — both write `MuskometerTests/MuskometerTests.swift` (T2 `MarketHoursServiceTests`; T3 `IssuerSharesOutstandingTests` + AppSettings outstanding remigration tests).
  - Test-fixture overlap: yes — same XCTest file.
  - Hidden runtime coupling: no — holiday table vs issuer outstanding defaults share no types.
  - Chain-length ratio: 0.750
  - Cost-benefit assessment: meets threshold (0.750 ≥ 0.25)
  - Recommendation: UNVERIFIED-UNSAFE

- Tasks {2, 4}: declared concurrent.
  - Files touched disjoint: no — both write `MuskometerTests/MuskometerTests.swift` (T2 calendar tests; T4 rewrites `SPCXHoldingsTests` and AppSettings seed/fingerprint cases, including `AppSettingsTests.testDefaultShareCounts` at lines 988–995).
  - Test-fixture overlap: yes — same XCTest file.
  - Hidden runtime coupling: no — `MarketHoursService` is not on the share-count remigration path.
  - Chain-length ratio: 0.600
  - Cost-benefit assessment: meets threshold (0.600 ≥ 0.25)
  - Recommendation: UNVERIFIED-UNSAFE

- Tasks {2, 5}: declared concurrent.
  - Files touched disjoint: no — both write `MuskometerTests/MuskometerTests.swift` (T2 appends 2028 cases; T5 deletes comparison / debounce test types in the same file).
  - Test-fixture overlap: yes — same XCTest file. (`TradingDayCalendarTests` stays; T5 removes `GainsViewModel`’s `tradingDayCalendar` consumer, not that test class.)
  - Hidden runtime coupling: no — T2 extends `MarketHoursService` holiday maps; T5 deletes `tradingDayCalendar` on `GainsViewModel` (`TradingDayCalendar`, a different type). No shared edit to `MarketHoursService.swift`.
  - Chain-length ratio: 0.750
  - Cost-benefit assessment: meets threshold (0.750 ≥ 0.25)
  - Recommendation: UNVERIFIED-UNSAFE

- Tasks {2, 6}: declared concurrent.
  - Files touched disjoint: no — both write `MuskometerTests/MuskometerTests.swift` (T2 `MarketHoursServiceTests`; T6 parity `currentTSLAPrice` asserts).
  - Test-fixture overlap: yes — same XCTest file.
  - Hidden runtime coupling: no — calendar tables are not inputs to `MergerMarketCapParity.presentation`.
  - Chain-length ratio: 1.000
  - Cost-benefit assessment: meets threshold (1.000 ≥ 0.25)
  - Recommendation: UNVERIFIED-UNSAFE

- Tasks {2, 7}: declared concurrent.
  - Files touched disjoint: no — both write `docs/ARCHITECTURE.md` (T2 holiday/early-close prose 2026–2028, plan Task 2 last doc step; T7 “already updated for 2028 in Task 2; add a sentence that comparison captions are gone”, plan Task 7 Files touched). Product files otherwise differ (`MarketHoursService.swift` vs `SettingsView.swift` + HOLDINGS/README/PRIVACY).
  - Test-fixture overlap: no — T7 has no tests; T2’s XCTest edits do not meet T7.
  - Hidden runtime coupling: no — docs-only collision. The T7 step *assumes* T2’s 2028 prose already landed, so the missing 2→7 edge is an undeclared write-order dependency on that file.
  - Chain-length ratio: 0.600
  - Cost-benefit assessment: meets threshold (0.600 ≥ 0.25)
  - Recommendation: UNVERIFIED-UNSAFE

- Tasks {2, 8}: declared concurrent.
  - Files touched disjoint: yes — T2 `MarketHoursService.swift` + tests + `docs/ARCHITECTURE.md`; T8 screenshots / `docs/index.html` / `docs/README.md` / `scripts/verify.sh`. Distinct from root `README.md` and from `ARCHITECTURE.md`.
  - Test-fixture overlap: no — XCTest calendar cases vs marketing grep.
  - Hidden runtime coupling: no — 2028 calendar is not rendered in the HTML mock; T8 forbids “Post to X” / “comparison caption”, not holiday strings.
  - Chain-length ratio: 0.750
  - Cost-benefit assessment: meets threshold (0.750 ≥ 0.25)
  - Recommendation: VERIFIED

- Tasks {3, 4}: declared concurrent.
  - Files touched disjoint: no — both write `Muskometer/Utilities/AppSettings.swift` and `MuskometerTests/MuskometerTests.swift` (T3: `loadSharesOutstanding` remigrate + `IssuerSharesOutstanding.swift`; T4: `loadShareCounts` TSLA remigrate + `SPCXHoldings.swift` + `TrackedPersonProfile.swift`).
  - Test-fixture overlap: yes — same XCTest file; both add/rewrite AppSettings UserDefaults remigration tests (`IssuerSharesOutstandingTests` already constructs `AppSettings`; T4 rewrites `SPCXHoldingsTests.testAppSettingsRewritesLegacyFingerprintUnderNewKey` and seed asserts in `AppSettingsTests` / `GainsViewModelIssuerOutstandingSyncTests` at 1566–1567).
  - Hidden runtime coupling: yes — both hook `AppSettings` init load paths (`loadShareCounts` lines 342–365 vs `loadSharesOutstanding` lines 367+). Orthogonal UserDefaults keys, but one type’s `init` is edited by both; fingerprint vs outstanding remigration must not clobber each other’s persist-if-changed writes.
  - Chain-length ratio: 0.800
  - Cost-benefit assessment: meets threshold (0.800 ≥ 0.25)
  - Recommendation: UNVERIFIED-UNSAFE

- Tasks {3, 5}: declared concurrent.
  - Files touched disjoint: no — both write `AppSettings.swift` and `MuskometerTests.swift` (T3 remigrates outstanding after parse; T5 removes `ComparisonHistoryStore.resetPersistedState` from `resetPersistedState` at line 506, adds a comparison-key sweep on `init` + reset).
  - Test-fixture overlap: yes — same XCTest file; T5 deletes comparison/history tests that construct `AppSettings`; T3 adds outstanding remigration tests on the same type.
  - Hidden runtime coupling: yes — both edit `AppSettings` init / reset. T5’s load-time key sweep sits next to T3’s outstanding remigrate-and-persist; concurrent patches to `init`/`resetPersistedState` conflict even if keys differ.
  - Chain-length ratio: 1.000
  - Cost-benefit assessment: meets threshold (1.000 ≥ 0.25)
  - Recommendation: UNVERIFIED-UNSAFE

- Tasks {3, 6}: declared concurrent.
  - Files touched disjoint: no — both write `MuskometerTests/MuskometerTests.swift` (T3 `IssuerSharesOutstandingTests` + outstanding remigration; T6 `MergerMarketCapParityTests.testRealishOrdersOfMagnitude`, which reads `IssuerSharesOutstanding.defaultSPCX` at lines 1267–1268, and the other two `currentTSLAPrice` sites).
  - Test-fixture overlap: yes — same file, and T6’s realish test *uses* the constant T3 changes (`13_181_779_945` → `13_571_069_199`). Assertions are relative to the constant, so semantics survive, but the hunks overlap.
  - Hidden runtime coupling: no — `presentation(...)` takes outstanding as arguments; T6 only drops `currentTSLAPrice`. Product files (`IssuerSharesOutstanding.swift`/`AppSettings.swift` vs `MergerMarketCapParity.swift`/`MergerParityCardView.swift`) do not overlap.
  - Chain-length ratio: 0.750
  - Cost-benefit assessment: meets threshold (0.750 ≥ 0.25)
  - Recommendation: UNVERIFIED-UNSAFE

- Tasks {3, 8}: declared concurrent.
  - Files touched disjoint: yes — T3 `IssuerSharesOutstanding.swift` + `AppSettings.swift` + tests; T8 marketing HTML/PNGs + `docs/README.md` + `verify.sh`.
  - Test-fixture overlap: no — XCTest outstanding remigration vs marketing string grep.
  - Hidden runtime coupling: no — site copy does not load UserDefaults or `defaultSPCX`.
  - Chain-length ratio: 1.000
  - Cost-benefit assessment: meets threshold (1.000 ≥ 0.25)
  - Recommendation: VERIFIED

- Tasks {4, 5}: declared concurrent.
  - Files touched disjoint: no — both write `AppSettings.swift` and `MuskometerTests.swift` (T4: `loadShareCounts` TSLA fingerprint `699_580_882` → `710_172_677` plus `SPCXHoldings.migrateStoredShareCount`; T5: comparison history sweep on the same `init`/`resetPersistedState`).
  - Test-fixture overlap: yes — T4 rewrites seed/fingerprint AppSettings tests; T5 deletes comparison history tests that also spin `AppSettings` suites.
  - Hidden runtime coupling: yes — same `AppSettings` init as T3/T4/T5. T4 persist-if-changed share-count writes and T5’s key deletion must not land as conflicting patches to one initializer.
  - Chain-length ratio: 0.800
  - Cost-benefit assessment: meets threshold (0.800 ≥ 0.25)
  - Recommendation: UNVERIFIED-UNSAFE

- Tasks {4, 6}: declared concurrent.
  - Files touched disjoint: no — both write `MuskometerTests/MuskometerTests.swift` (T4 seed/fingerprint tests and every seed-assert of `699_580_882`; T6 parity `currentTSLAPrice` asserts). T4 also rewrites defaults that `GainsViewModelIssuerOutstandingSyncTests` (lines 1566–1567) still encodes as seeds.
  - Test-fixture overlap: yes — same XCTest file; T4’s “update every seed assert” pass can land in classes T6 is also editing (`GainsViewModelMergerParityPresentationTests` lives in the same file).
  - Hidden runtime coupling: no — ownership seeds are not fields on `MergerParityPresentation`; T6 does not read `SPCXHoldings.defaultShareCount`.
  - Chain-length ratio: 0.600
  - Cost-benefit assessment: meets threshold (0.600 ≥ 0.25)
  - Recommendation: UNVERIFIED-UNSAFE

- Tasks {4, 8}: declared concurrent.
  - Files touched disjoint: yes — T4 `SPCXHoldings.swift` + `TrackedPersonProfile.swift` + `AppSettings.swift` + tests; T8 screenshots / HTML / `docs/README.md` / `verify.sh`.
  - Test-fixture overlap: no — XCTest remigration vs static marketing grep.
  - Hidden runtime coupling: no — HTML mock can hardcode the pinned `5_116_475_230` / `710_172_677` from the plan without importing `AppSettings`.
  - Chain-length ratio: 0.800
  - Cost-benefit assessment: meets threshold (0.800 ≥ 0.25)
  - Recommendation: VERIFIED

- Tasks {5, 6}: declared concurrent.
  - Files touched disjoint: no — both write `MuskometerTests/MuskometerTests.swift` (T5 deletes comparison/debounce classes and any `GainsViewModel` constructor call sites that still pass `comparisonLineSelector` / `tradingDayCalendar`; T6 edits parity presentation tests in the same file, including `GainsViewModelMergerParityPresentationTests`).
  - Test-fixture overlap: yes — same XCTest file; both touch `GainsViewModel`-shaped tests. Product files otherwise differ (comparison/popover/pbxproj vs `MergerMarketCapParity.swift` / `MergerParityCardView.swift`).
  - Hidden runtime coupling: no — T5 does not edit merger-parity types; T6 does not restore captions. Popover still hosts `MergerParityCardView` after caption deletion (separate view file).
  - Chain-length ratio: 0.750
  - Cost-benefit assessment: meets threshold (0.750 ≥ 0.25)
  - Recommendation: UNVERIFIED-UNSAFE

- Tasks {6, 7}: declared concurrent.
  - Files touched disjoint: yes — T6 `MergerMarketCapParity.swift` + `MergerParityCardView.swift` + tests; T7 `SettingsView.swift` + `docs/HOLDINGS.md` + root `README.md` + `docs/PRIVACY.md` + `docs/ARCHITECTURE.md`.
  - Test-fixture overlap: no — T7 has no tests.
  - Hidden runtime coupling: no — Settings/HOLDINGS copy does not mention `currentTSLAPrice`; dropping the dead field does not change the strings T7 writes.
  - Chain-length ratio: 0.600
  - Cost-benefit assessment: meets threshold (0.600 ≥ 0.25)
  - Recommendation: VERIFIED

- Tasks {6, 8}: declared concurrent.
  - Files touched disjoint: yes — T6 parity presentation + tests; T8 marketing assets + `verify.sh`. T8’s mock must include the parity card (plan Task 8) but does not edit `MergerParityCardView.swift`.
  - Test-fixture overlap: no — XCTest field removal vs PNG/HTML.
  - Hidden runtime coupling: no — unused `currentTSLAPrice` is not a screenshot-visible control; the card still shows implied/current prices from other fields.
  - Chain-length ratio: 0.750
  - Cost-benefit assessment: meets threshold (0.750 ≥ 0.25)
  - Recommendation: VERIFIED

- Tasks {7, 8}: declared concurrent.
  - Files touched disjoint: yes — T7 `SettingsView.swift`, `docs/HOLDINGS.md`, root `README.md`, `docs/PRIVACY.md`, `docs/ARCHITECTURE.md`; T8 `docs/screenshots/*`, `docs/index.html`, `docs/README.md` (different file from root `README.md`), `scripts/verify.sh`.
  - Test-fixture overlap: no — neither shares a test file; T8’s `verify.sh` grep is scoped to `docs/index.html` and `docs/screenshots/render-*.html`, not HOLDINGS/PRIVACY/ARCHITECTURE.
  - Hidden runtime coupling: no — product Settings copy vs marketing mock. T7 may mention comparison-gone in ARCHITECTURE; T8 forbids those words only in site HTML. No shared mutable state.
  - Chain-length ratio: 0.800
  - Cost-benefit assessment: meets threshold (0.800 ≥ 0.25)
  - Recommendation: VERIFIED

---

## Summary

| Concurrent pairs | 22 |
| VERIFIED | 7 — `{1,8} {2,8} {3,8} {4,8} {6,7} {6,8} {7,8}` |
| UNVERIFIED-UNSAFE | 15 — fourteen `{1–6}×{1–6}` test-file pairs plus `{2,7}` on `ARCHITECTURE.md` |
| UNVERIFIED-LOW-VALUE | 0 |
| UNVERIFIED-MISSED-OPPORTUNITY | 0 |

**Max useful parallelism width after serialization of UNSAFE pairs:** ready-set collapses toward one of `{1,2,3,5,6}` at a time (shared `MuskometerTests.swift`), with T8 free beside 1–4/6 and T7 free beside 2 (unsafe — serialize) or 6. Safe ready-set-adjacent lanes that remain: **T8 ∥ any of {1,2,3,4,6}**, and **T6 ∥ T7**.

## Findings

- [Task 7 / Task 2:docs/ARCHITECTURE.md] missing-dep: T7 Files-touched includes ARCHITECTURE.md and its steps assume T2’s 2028 prose already landed, but Depends on is only 3, 4, 5 — pair {2, 7} is concurrent and UNVERIFIED-UNSAFE.
- [Tasks 3, 4, 5:Muskometer/Utilities/AppSettings.swift] shared-product-file: three tasks write AppSettings init/reset concurrently; pairs {3, 4}, {3, 5}, {4, 5} are UNVERIFIED-UNSAFE beyond the shared test file.
- [Tasks 1-6:MuskometerTests/MuskometerTests.swift] shared-test-file: every concurrent pair among 1–6 edits the single XCTest file, so those 14 pairs are UNVERIFIED-UNSAFE.

VERDICT: APPROVED

Reviewed-files: docs/marshal/plans/2026-08-17-holdings-surface-refresh.md, Muskometer/Utilities/AppSettings.swift, Muskometer/Utilities/MergerMarketCapParity.swift, MuskometerTests/MuskometerTests.swift, docs/ARCHITECTURE.md
