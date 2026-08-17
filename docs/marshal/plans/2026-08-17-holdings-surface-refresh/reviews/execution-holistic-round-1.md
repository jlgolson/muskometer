# Execution holistic review — round 1

**Role:** execution-holistic  
**Plan:** `docs/marshal/plans/2026-08-17-holdings-surface-refresh.md`  
**Spec:** `docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md`  
**Date:** 2026-08-17  
**Context:** All per-task spec + quality reviews (T1–T10) returned APPROVED. This pass answers: does the branch implement the design as a coherent whole?

## What landed correctly

The branch is a complete 0.1.5 (build 26) vertical slice of Design §§1–7. Ownership, outstanding, calendar, comparison deletion, marketing, docs, and the version tick compose without a leftover 0.1.4 identity or a half-deleted caption surface.

Trust these surfaces without re-reading:

- **Sellable SPCX ownership.** Calculator counts option underlying shares 1:1 and ignores remarks performance RSUs. June 17 live-shaped fixture (By Trust → 0, 350M option row, remarks 1.302B present) returns `5_116_475_230`. Seeds match in `SPCXHoldings.defaultShareCount` and `TrackedPersonProfile.musk`.
- **Fingerprint remigration.** SPCX legacy prints (`60_685_475`, `842_091_670`, `7_402_770`, `6_068_547_515`, `6_068_734_060`) and TSLA `699_580_882` rewrite on `AppSettings` load; unknown / current values pass through. Idempotent: targets are not members of the legacy sets.
- **Issuer outstanding is orthogonal.** `defaultSPCX = 13_181_779_945 + 389_289_254` (`13_571_069_199`); remigrates only stored `13_181_779_945`. TSLA outstanding stays `3_949_547_394`. Item (ii) 1,752,426 is not added. Form 4 keys never write outstanding.
- **2028 NYSE table.** Nine holidays, no `2028-01-01` / `2027-12-31`, early closes `2028-07-03` and `2028-11-24` only. Tests cover MLK, no phantom New Year’s observed close, Good Friday, July 4, July 3 morning/afternoon, Thanksgiving + Friday early close. 2026–2027 rows untouched.
- **Comparison is deleted, not hidden.** Four source files gone; pbxproj IDs `…2B/2E/3A/3B` not recycled; `GainsViewModel` has no `comparisonLine` / `tradingDayCalendar`; popover order is ownership → combined → records → rows → parity; leftover `comparisonHistoryEntries` keys sweep on load and Reset.
- **Marketing matches §5.** PNGs and HTML mock show one Copy control, 9:30 next-open, parity card, new share counts; no Post to X, comparison line, or 4:00 AM next-open. Site lede is RTH-only. `verify.sh` §6 greps the two forbidden strings.
- **Docs / Settings / PRIVACY.** HOLDINGS names the four accessions, strike-mark, and sellable rule. Settings caption covers daily Form 4 + best-effort outstanding. README lists ⌘⇧C. PRIVACY lists remaining prefs and does not list comparison history.
- **Version tick.** Four `MARKETING_VERSION = 0.1.5` and four `CURRENT_PROJECT_VERSION = 26`. `AppVersion.short` still reads the plist macros. No `v0.1.5` tag, no `dist/` artifacts.

## Design → ship map

| Design slice | Shipped surface | Status |
|--------------|-----------------|--------|
| §1 calculator (options in, remarks out) | `SPCXOwnershipCalculator.classAEquivalentShares`; `restrictedShares` gone | Match |
| §1 seeds | TSLA `710_172_677`, SPCX `5_116_475_230` in profile + `SPCXHoldings` | Match |
| §1 remigration | SPCX switch + TSLA `699_580_882` in `loadShareCounts`; persist-if-changed | Match |
| §2 outstanding + remigration | `defaultSPCX` sum + `migrateStoredOutstanding`; `loadSharesOutstanding` | Match |
| §3 2028 calendar | Holiday set + early-close map + `MarketHoursServiceTests` + ARCHITECTURE | Match |
| §4 comparison deletion | Four files, pbxproj, VM, popover, history-key helper, four test types | Match |
| §5 marketing / site | `render-capture.html` + three PNGs + `index.html` / `render-og.html` + verify grep | Match |
| §6 docs / Settings / PRIVACY / README | HOLDINGS, ARCHITECTURE, Settings caption, PRIVACY prefs, ⌘⇧C | Match |
| §6 dead field | `MergerParityPresentation` is three fields; zero `currentTSLAPrice` | Match |
| §6 / Rollout version | pbxproj 0.1.5 / 26; current-release strings; CHANGELOG `## [0.1.5] - 2026-08-17` | Match |
| Upgrade contract | `AppSettings` init only; fingerprint-only; load + Reset history sweep | Match |
| Non-goals | No 13G seed, no strike ledger, no 8-K parser, no Sparkle, no tag/DMG | Honored |
| AC12 | Task 10 skip-flag `verify.sh` green; no product edit required | Match |

## End-to-end coherence

Ownership and outstanding stay on separate keys, loaders, and UI consumers. Paper gain and the parity card cannot cross wires: stock rows use `shareCount`; the card uses `sharesOutstanding`. Remigration is the same persist-if-changed `String(Int64)` pattern on three disjoint keys. A second `AppSettings` init is a no-op once stored values are the new integers.

Popover composition matches Design §4 after the caption cut: combined card has no replacement line and no empty placeholder. `tradingDayCalendar` remains a daily-records utility; only the VM debounce dependency is gone.

Calculator option handling keeps an explicit `title.contains("option") { return shares }` rather than deleting the branch and falling through. That is a considered improvement: it is what makes `testOptionTitleCountsUnderlyingShares` (`Option to Buy`, no class) return 100, which the plan required. Live title `Option to Buy (Class B Common Stock)` still counts 1:1. Do not flatten it back to fall-through.

## CHANGELOG vs branch

`## [Unreleased]` is empty above `## [0.1.5] - 2026-08-17`. Each new bullet names a change that is present:

| Bullet | Present |
|--------|---------|
| TSLA 710,172,677 / SPCX 5,116,475,230 (tables + 350M options) and named Form 4s | Yes |
| Calculator options-in / remarks-out | Yes |
| Fingerprint remigration of listed SPCX / TSLA / outstanding prints | Yes |
| Cursor 8-K item (i) 389,289,254; TSLA outstanding unchanged | Yes |
| NYSE through 2028; no New Year’s 2028 session holiday | Yes |
| HOLDINGS / Settings / README ⌘⇧C / PRIVACY / ARCHITECTURE | Yes |
| Marketing PNGs + site copy (Copy, 9:30, parity; no Post to X / comparison / “minute by minute”) | Yes |
| Version 0.1.5 / build 26 | Yes |
| Comparison types + history-key sweep | Yes |
| `currentTSLAPrice` removed | Yes |

No changelog-confabulation. Historical 0.1.1 comparison / Post to X entries stay as history.

## Acceptance criteria

| AC | Verdict |
|----|---------|
| 1. Empty suite → TSLA 710,172,677 / SPCX 5,116,475,230 / outstanding 13,571,069,199 / 3,949,547,394 | Pass |
| 2. SPCX fingerprints `6_068_734_060` / `6_068_547_515` → 5,116,475,230; current stays | Pass |
| 3. TSLA `699_580_882` → 710,172,677; other stored stays | Pass |
| 4. Outstanding `13_181_779_945` → 13,571,069,199; other positive stays | Pass |
| 5. Live-shaped June 17 fixture → 5,116,475,230; remarks do not add | Pass |
| 6. 2028 tests + 2026–2027 stay green | Pass (Task 10 verify) |
| 7. App target does not compile comparison types; no VM API; no popover view | Pass |
| 8. PNGs + site HTML match §5; no Post to X / comparison caption / “minute by minute” | Pass |
| 9. README ⌘⇧C; PRIVACY prefs; HOLDINGS / ARCHITECTURE match §2–§3 | Pass |
| 10. No `currentTSLAPrice` | Pass |
| 11. Four pbxproj pairs 0.1.5 / 26; current-release docs; dated CHANGELOG | Pass |
| 12. `MUSKOMETER_SKIP_LIVE_YAHOO=1 ./scripts/verify.sh` | Pass (Task 10 evidence) |

## Per-task approval rollup

T1–T10 spec + quality APPROVED (Task 8 needed a round-2 mock-math / lede / leftover-jpg fix; closed). Plan correctness R1–R2 and plan holistic APPROVED. No open NEEDS_FIXES.

## Non-blocking (not design gaps)

1. `scripts/verify.sh` §5 optional live-Yahoo `SHARES` dict still prints the old fingerprints. The required skip-flag path never runs it. Left as a Task 10 no-op on purpose.
2. Extra `render-capture.html` + `render-pngs.swift` are the §5-allowed mock pipeline, not scope creep.

## Gestalt

No missing design pillar, no contradictory seed, no hidden comparison path, no stale current-release 0.1.4. Layers compose as the upgrade contract specifies. Non-goals stayed out. The branch is ready to merge as 0.1.5 (build 26).

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED
