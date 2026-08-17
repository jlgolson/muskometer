---
main_sha_at_review: 3f22cf5c40f91b8047710e67b685d45e4462c794
branch_tip_sha: f1d048a44bfc66f041af74c84ff478dc1e0d99fc
reviewed_at: 2026-08-17T12:57:41Z
pr_number: 4
---

# Pre-merge review — round 1

**Role:** pre-merge-reviewer  
**PR:** https://github.com/jlgolson/muskometer/pull/4  
**Plan:** `docs/marshal/plans/2026-08-17-holdings-surface-refresh.md`  
**Spec:** `docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md`  
**Diff basis:** GitHub PR 4 files + worktree product/tests/docs vs `origin/main` (`3f22cf5…` → `f1d048a…`); 21,641 additions / 5,287 deletions across 147 files (~26.9k, well under the 50k overflow bar). Most of the volume is marshal reviews plus the deleted 4,520-line comparison library.

## Summary

Fresh-eyes whole-PR review of the 0.1.5 (build 26) holdings-surface refresh. Planned functionality landed: sellable SPCX ownership (tables + vested options, remarks performance RSUs out), inverted fingerprint remigration, Cursor outstanding bump, NYSE 2028 calendar, comparison deleted end-to-end, marketing/docs refresh, unused `currentTSLAPrice` drop, version tick. Approach matches the architecture in the spec (Form 4 walker unchanged; outstanding orthogonal; remigration on `AppSettings` init only; comparison deleted not hidden). No critical or important defects. Deviations from the plan’s sketch (option-first `return shares`, `defaultSPCX` as a sum, TSLA remigration writing `spec.defaultShareCount`) are considered improvements that keep a single source of truth.

## What landed cleanly

Trust these without re-reading:

- **Sellable ownership is one rule.** `classAEquivalentShares` counts `option` titles 1:1 and never adds remarks. `restrictedShares(from:)` is gone. June 17 live-shaped fixture (By Trust later 0, 350M option row, remarks 1.302B present) returns `5_116_475_230`. Dual seeds match in `TrackedPersonProfile.musk` and `SPCXHoldings.defaultShareCount`.
- **Fingerprint remigration is persist-if-changed `String(Int64)` on three disjoint keys.** SPCX ownership fingerprints (`60_685_475`, `842_091_670`, `7_402_770`, `6_068_547_515`, `6_068_734_060`), TSLA `699_580_882`, SPCX outstanding `13_181_779_945`. Targets are not members of the legacy sets, so a second `AppSettings` init is a no-op. Unknown / current / custom values pass through.
- **Outstanding stays orthogonal.** `defaultSPCX = 13_181_779_945 + 389_289_254` (`13_571_069_199`). Item (ii) 1,752,426 is not added. TSLA outstanding stays `3_949_547_394`. Form 4 keys never write outstanding.
- **Comparison is deleted, not hidden.** Four compile units gone; pbxproj IDs `…2B` / `2E` / `3A` / `3B` not recycled; `GainsViewModel` has no `comparisonLine` / `tradingDayCalendar`; popover order is ownership → combined → records → rows → parity; leftover `comparisonHistoryEntries` keys sweep on load and Reset. Four comparison test types deleted.
- **2028 calendar matches the official NYSE table.** Nine holidays, no `2028-01-01` / `2027-12-31`, early closes `2028-07-03` and `2028-11-24` only. Tests cover MLK, no phantom New Year’s, Good Friday, July 4, July 3 early, Thanksgiving + Friday.
- **Marketing matches Design §5.** `app-capture.png` / `app-preview.png` show one Copy control, 9:30 next-open, parity card, new share counts; no Post to X, comparison line, or 4:00 AM. Site lede is RTH-only. `verify.sh` §6 greps the two forbidden strings.
- **Shipping identity is one source.** Four `MARKETING_VERSION = 0.1.5` and four `CURRENT_PROJECT_VERSION = 26`. `AppVersion.short` still reads the plist macros. Current-release docs name 0.1.5. `## [Unreleased]` is empty above `## [0.1.5] - 2026-08-17`. No tag, no `dist/`.

## Plan alignment

| Spec / plan pillar | Result |
|--------------------|--------|
| §1 calculator (options in, remarks out) | Match. Option-first branch is required for class-less `Option to Buy` and is an improvement over a fall-through-only sketch. |
| §1 seeds + remigration | Match. TSLA `710_172_677`, SPCX `5_116_475_230`; inverted SPCX switch; TSLA load-path equality rewrite. |
| §2 outstanding + remigration | Match. Cursor item (i) only; remigrate stored `13_181_779_945` only. |
| §3 2028 calendar | Match. ARCHITECTURE prose/table updated through 2028. |
| §4 comparison deletion | Match. Closed cut. |
| §5 marketing PNGs / site | Match. HTML mock (`render-capture.html`) is the §5-allowed source. |
| §6 docs, Settings, PRIVACY, README, dead field | Match. ⌘⇧C, holdings caption, four accessions, strike-mark sentence, three-field parity DTO. |
| Version 0.1.5 / build 26 / CHANGELOG | Match. CHANGELOG names landed integers/accessions/deleted types, not plan paraphrase. |
| AC 1–12 / Task 10 verify | Match. Skip-flag `verify.sh` is the CI command; marketing grep present. |
| Non-goals (13G, strike ledger, 8-K parse, Sparkle, tag/DMG) | Not shipped. |

## Residual notes (non-blocking)

1. `scripts/verify.sh` §5 optional live-Yahoo `SHARES` dict still prints `699_580_882` / `6_068_734_060`. The required skip-flag path (CI and Task 10) never runs it. Comment still says “bundled holdings”; a later maintainer pass can retarget it.
2. Unused `PortfolioHolding.defaults` still hardcodes TSLA `699_580_882` while SPCX reads `SPCXHoldings.defaultShareCount`. Zero call sites; not a seed or remigration path. Task 4 correctly left fixture uses of `699_580_882`.
3. No sweep test for `comparisonHistoryEntries` keys. The helper is `removeObject` on known strings; load and Reset both call it. Not required by the plan.

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
  "role": "pre-merge-reviewer",
  "pr_number": 4,
  "main_sha_at_review": "3f22cf5c40f91b8047710e67b685d45e4462c794",
  "branch_tip_sha": "f1d048a44bfc66f041af74c84ff478dc1e0d99fc",
  "findings": []
}
```

VERDICT: APPROVED

Diff-sha256: 82011dec7f368093f33be3ff9412d774824e45c447ba03fe0c3b483ce5a3c722
