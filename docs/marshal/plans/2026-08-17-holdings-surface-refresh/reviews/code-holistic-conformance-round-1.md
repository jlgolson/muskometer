# Code holistic conformance — round 1

**Role:** code-holistic-conformance
**Plan:** `docs/marshal/plans/2026-08-17-holdings-surface-refresh.md`
**Spec:** `docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md`
**Date:** 2026-08-17
**Diff basis:** `docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-code-holistic-cumulative.diff`

## Scope

Cold whole-diff review: does the cumulative product implement Design Goals, §§1–7, upgrade/persisted-state contract, acceptance 1–12, testing strategy, and named non-goals? Plan tasks T1–T10 treated as the delivery vehicle; conformance judged against the spec, not prior review prose alone.

## What landed correctly

The branch is a complete 0.1.5 (build 26) vertical slice. Ownership seeds, outstanding remigration, 2028 calendar, comparison deletion, marketing surface, docs, and the version tick compose without a leftover 0.1.4 identity or a half-deleted caption path.

Trust these surfaces without re-reading:

- **Sellable SPCX ownership.** `classAEquivalentShares` counts `option` titles 1:1 and never adds remarks. `restrictedShares(from:)` is gone. June 17 live-shaped fixture (By Trust later 0, 350M option row, remarks 1.302B present) expects `5_116_475_230`. Dual seeds match in `TrackedPersonProfile.musk` and `SPCXHoldings.defaultShareCount`.
- **Fingerprint remigration.** SPCX legacy prints (`60_685_475`, `842_091_670`, `7_402_770`, `6_068_547_515`, `6_068_734_060`) and TSLA `699_580_882` rewrite on `AppSettings` load; current / unknown values pass through. Persist-if-changed; targets are not members of the legacy sets.
- **Issuer outstanding is orthogonal.** `defaultSPCX = 13_181_779_945 + 389_289_254` (`13_571_069_199`); remigrates only stored `13_181_779_945`. TSLA outstanding stays `3_949_547_394`. Item (ii) 1,752,426 is not added.
- **2028 NYSE table.** Nine holidays, no `2028-01-01` / `2027-12-31`, early closes `2028-07-03` and `2028-11-24` only. Required tests cover MLK, no phantom New Year’s close, Good Friday, July 4, July 3 morning/afternoon, Thanksgiving + Friday early close. 2026–2027 rows stay.
- **Comparison is deleted, not hidden.** Four compile units gone; pbxproj IDs `…2B/2E/3A/3B` not recycled; `GainsViewModel` has no `comparisonLine` / `tradingDayCalendar`; popover order is ownership → combined → records → rows → parity; leftover `comparisonHistoryEntries` keys sweep on load and Reset.
- **Marketing matches §5.** All three PNGs show one Copy control, 9:30 next-open, parity card, and the new share counts. No Post to X, comparison line, or 4:00 AM next-open. Site / OG ledes are RTH-only. `verify.sh` §6 greps the two forbidden strings.
- **Docs / Settings / PRIVACY.** HOLDINGS names the four accessions, strike-mark sentence, and sellable rule. Settings caption covers daily Form 4 + best-effort outstanding. README lists ⌘⇧C. PRIVACY lists remaining prefs and does not list comparison history.
- **Version tick.** Four `MARKETING_VERSION = 0.1.5` and four `CURRENT_PROJECT_VERSION = 26`. `AppVersion.short` still reads the plist macros. CHANGELOG `## [0.1.5] - 2026-08-17` with empty Unreleased above it.

## Design → ship map

| Design slice | Shipped surface | Conformance |
|--------------|-----------------|-------------|
| §1 calculator (options in, remarks out) | `SPCXOwnershipCalculator`; Form 4 parser still calls it; focused option / remarks tests | Match |
| §1 seeds | TSLA `710_172_677`, SPCX `5_116_475_230` in profile + `SPCXHoldings` | Match |
| §1 remigration | SPCX switch + TSLA `699_580_882` in `loadShareCounts`; persist-if-changed | Match |
| §2 outstanding + remigration | `defaultSPCX` sum + `migrateStoredOutstanding` on load | Match |
| §3 2028 calendar | Holiday set + early-close map + tests + ARCHITECTURE 2026–2028 | Match |
| §4 comparison deletion | Four files, pbxproj, VM, popover, history-key helper, four test types | Match |
| §5 marketing / site | `render-capture.html` + three PNGs + `index.html` / `render-og.html` + verify grep | Match |
| §6 docs / Settings / PRIVACY / README | HOLDINGS, ARCHITECTURE, Settings caption, PRIVACY prefs, ⌘⇧C | Match |
| §6 dead field | `MergerParityPresentation` is three fields; zero `currentTSLAPrice` | Match |
| §6 / Rollout version | pbxproj 0.1.5 / 26; current-release strings; dated CHANGELOG | Match |
| Upgrade contract | `AppSettings` init only; fingerprint-only; load + Reset history sweep | Match |
| Non-goals | No 13G seed, no strike ledger, no 8-K parser, no Sparkle, no tag/DMG | Honored |

## Acceptance criteria

| AC | Result | Evidence |
|----|--------|----------|
| 1. Empty suite → new ownership + outstanding defaults | Pass | `testDefaultShareCounts`, `testMissingOutstandingKeyReturnsNewBundledDefault` |
| 2. SPCX `6_068_734_060` / `6_068_547_515` → `5_116_475_230`; current stays | Pass | `SPCXHoldingsTests` migrate + load-path rewrite |
| 3. TSLA `699_580_882` → `710_172_677`; other stored stays | Pass | TSLA load-path tests (legacy / current / custom / empty) |
| 4. Outstanding `13_181_779_945` → `13_571_069_199`; other positive stays | Pass | migrate helper + `testLoadRemigratesPriorSPCXCoverOutstandingAndPersists` |
| 5. Live-shaped June 17 fixture → `5_116_475_230`; remarks do not add | Pass | `testAggregatesJune2026Form4Holdings`, `testRemarksPerformanceSharesAreNotAdded` |
| 6. 2028 holiday/early-close tests; 2026–2027 stay | Pass | `test2028*` next to existing Good Friday / early-close cases |
| 7. App target does not compile comparison types; no VM API; no popover view | Pass | files deleted; zero product/test references; pbxproj IDs gone |
| 8. PNGs + site HTML match §5; no Post to X / comparison / “minute by minute” | Pass | visual check of three PNGs; site + mock HTML; verify.sh §6 |
| 9. README ⌘⇧C; PRIVACY prefs; HOLDINGS / ARCHITECTURE match §2–§3 | Pass | keyboard table; prefs list; accessions + 2028 early-close table |
| 10. No `currentTSLAPrice` | Pass | presentation struct, calculator, preview, tests |
| 11. Four pbxproj pairs 0.1.5 / 26; current-release docs; dated CHANGELOG | Pass | pbxproj + README / INSTALL / RELEASE / PRIVACY / SECURITY |
| 12. `MUSKOMETER_SKIP_LIVE_YAHOO=1 ./scripts/verify.sh` | Pass | Task 10 gate; marketing grep present |

## End-to-end coherence

Ownership and outstanding stay on separate keys, loaders, and UI consumers. Paper gain uses `shareCount`; the parity card uses `sharesOutstanding`. Remigration is the same persist-if-changed `String(Int64)` pattern on three disjoint keys. A second `AppSettings` init is a no-op once stored values are the new integers.

Popover composition matches Design §4 after the caption cut: combined card has no replacement line and no empty placeholder. `tradingDayCalendar` remains a daily-records utility; only the VM debounce dependency is gone.

Calculator option handling keeps an explicit `title.contains("option")` rather than falling through. That is a considered improvement: `Option to Buy` (no class) still counts 1:1, which the focused test requires. Live title `Option to Buy (Class B Common Stock)` still matches.

## Non-blocking notes (not design gaps)

1. `scripts/verify.sh` optional live-Yahoo `SHARES` dict still prints the old fingerprints. The required skip-flag path never runs it.
2. Extra `render-capture.html` + `render-pngs.swift` are the §5-allowed mock pipeline, not scope creep.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{
  "schema_version": 1,
  "dispatch_id": null,
  "verdict": "approved",
  "round": 1,
  "role": "code-holistic-conformance",
  "findings": []
}
```

VERDICT: APPROVED

Diff-sha256: 82011dec7f368093f33be3ff9412d774824e45c447ba03fe0c3b483ce5a3c722
