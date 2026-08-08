# Task 3 Spec Review — MergerMarketCapParity pure calculator

**Role:** spec-reviewer  
**Task:** 3 (MergerMarketCapParity pure calculator — design Goals formula + §3)  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md` Goals + §3  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 3  
**Date:** 2026-08-07  

## Scope checked

Design Goals / §3 and plan Task 3 require (for this task only):

| Requirement | Expected |
|-------------|----------|
| Formula | `spcxMarketCap = spcxClassAPrice × Double(spcxOutstandingAPlusB)`; `tslaMarketCap = tslaPrice × Double(tslaOutstanding)`; `impliedTSLAPrice = spcxMarketCap / Double(tslaOutstanding)` |
| SPCX convention | Class A Yahoo price × total Class A+B outstanding (caller supplies A+B count; calculator multiplies price × outstanding) |
| Guards | `nil` if any input non-finite or `≤ 0`, or outstanding `≤ 0`; finite implied `> 0` |
| Presentation model | `MergerParityPresentation`: `impliedTSLAPrice`, `tslaMarketCap`, `spcxMarketCap`, `currentTSLAPrice` |
| API shape | `MergerMarketCapParity.presentation(tslaPrice:spcxPrice:tslaOutstanding:spcxOutstanding:) -> MergerParityPresentation?` |
| Purity | Pure static util; no I/O, settings, or quote services |
| pbxproj | IDs `A1…51` / `A2…51` for `MergerMarketCapParity.swift` |
| Tests | Happy path 100/50, 2/4 → spcx mcap 200, implied 100; zero/negative → nil; non-finite → nil; real-ish orders of magnitude |

Out of scope for Task 3 (deferred): companyfacts resolver, snapshot/VM wiring, UI card, HOLDINGS.md.

## Findings

None.

## Compliance checklist

| Requirement | Status | Evidence |
|-------------|--------|----------|
| SPCX mcap = Class A price × A+B outstanding | Pass | `spcxMarketCap = spcxPrice * Double(spcxOutstanding)`; doc comment states Class A Yahoo × total A+B |
| TSLA mcap = price × outstanding | Pass | `tslaMarketCap = tslaPrice * Double(tslaOutstanding)` |
| Implied TSLA = SPCX mcap / TSLA shares | Pass | `impliedTSLAPrice = spcxMarketCap / tslaShares` with `tslaShares = Double(tslaOutstanding)` |
| Goals formula equivalence | Pass | Matches Goals: `SPCX.marketCap = classAYahooPrice × economicallyEquivalentCommonOutstanding`; `impliedTSLAPrice = SPCX.marketCap / TSLA.sharesOutstanding` |
| Guards: non-finite prices → nil | Pass | `tslaPrice.isFinite` / `spcxPrice.isFinite` before math |
| Guards: price `≤ 0` → nil | Pass | `tslaPrice > 0`, `spcxPrice > 0` |
| Guards: outstanding `≤ 0` → nil | Pass | `tslaOutstanding > 0`, `spcxOutstanding > 0` (Int64; non-finite N/A) |
| Guards: implied non-finite or `≤ 0` → nil | Pass | Post-compute guard on `impliedTSLAPrice` (and mcaps) `isFinite` and `> 0` |
| `MergerParityPresentation` fields | Pass | `impliedTSLAPrice`, `tslaMarketCap`, `spcxMarketCap`, `currentTSLAPrice` (`= tslaPrice`); `Equatable, Sendable` |
| Pure enum static API | Pass | No instance state, network, or settings; only arithmetic + guards |
| pbxproj IDs 51 | Pass | PBXBuildFile `A100…51`, fileRef `A200…51`, Utilities group child, Sources entry |
| Happy-path test | Pass | 100/50, 2/4 → spcx mcap 200, tsla mcap 200, implied 100, current 100 |
| Zero/negative inputs → nil | Pass | All four inputs zero and negative covered |
| Non-finite inputs → nil | Pass | `.nan`, `.infinity`, `-.infinity` on both price legs |
| Real-ish magnitude smoke | Pass | Defaults ~3.95e9 / ~13.18e9 with 250/80; checks formula equality and plausible bands |

## VERDICT: APPROVED

## Reviewed files

- `Muskometer/Utilities/MergerMarketCapParity.swift` — formula, guards, presentation model match Goals/§3 and plan
- `Muskometer.xcodeproj/project.pbxproj` — IDs `A10000000000000000000051` / `A20000000000000000000051`
- `MuskometerTests/MuskometerTests.swift` — `MergerMarketCapParityTests` class
- `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md` Goals formula + §3
- `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 3 steps
