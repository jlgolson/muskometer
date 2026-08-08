# Task 3 Code Quality Review — MergerMarketCapParity pure calculator

**Role:** code-quality-reviewer  
**Task:** 3 (Pure calculator + presentation model + unit tests)  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 3  
**Date:** 2026-08-07  

## Scope reviewed

Quality axes: purity, edge cases, tests. Task introduces `MergerParityPresentation`, pure `MergerMarketCapParity.presentation(...)`, pbxproj registration (`…51`), and focused XCTest coverage — no network, settings, VM, or UI.

## Findings

None blocking.

### Purity

| Check | Status |
|-------|--------|
| No I/O, networking, `UserDefaults`, or `AppSettings` | Pass |
| No snapshot / quote / view-model coupling | Pass |
| Static pure function; all inputs explicit | Pass |
| No mutable state or side effects | Pass |
| `MergerParityPresentation: Equatable, Sendable` | Pass — safe for MainActor / concurrent handoff later |
| Namespace as `enum` (uninstantiable) | Pass — matches plan and existing util style (`IssuerSharesOutstanding`) |

Implementation is a closed arithmetic transform: four scalars in → optional presentation out. Suitable for Task 5 wiring without re-testing math in the VM.

### Formula & edge cases

| Item | Assessment |
|------|------------|
| SPCX mcap | `spcxPrice * Double(spcxOutstanding)` — Class A Yahoo × A+B total as plan/spec |
| TSLA mcap | `tslaPrice * Double(tslaOutstanding)` |
| Implied | `spcxMarketCap / Double(tslaOutstanding)` |
| Input guards | Prices: `isFinite && > 0`; outstanding: `> 0` (Int64 needs no finite check) |
| Output guards | Both mcaps and implied: `isFinite && > 0` — covers overflow → `inf` from extreme products |
| Happy numbers | Prices 100/50, outstanding 2/4 → spcx mcap 200, implied 100 — exact plan case |

Secondary output guard is a deliberate belt-and-suspenders for non-finite products/quotients; with realistic share counts (~1e9–1e10) Double stays exact and finite. No practical quality concern.

### Naming

| Item | Assessment |
|------|------------|
| `MergerParityPresentation` | Clear presentation DTO; field set matches plan/spec §4 contract |
| `MergerMarketCapParity` / `presentation(...)` | Domain-aligned; parameter names (`tslaPrice`, `spcxPrice`, `*Outstanding`) read as the formula |
| Doc comments | State Class A × A+B SPCX rule and nil conditions without over-documenting |

### pbxproj

| Check | Status |
|-------|--------|
| Build file ID `A10000000000000000000051` | Pass — plan table exact |
| File ref ID `A20000000000000000000051` | Pass — plan table exact |
| `PBXFileReference` path `MergerMarketCapParity.swift` | Pass |
| Utilities group child | Pass |
| `A60000000000000000000002 /* Sources */` entry | Pass |

### Tests

| Plan requirement | Coverage | Notes |
|------------------|----------|-------|
| Happy path 100/50, 2/4 → mcap 200, implied 100 | `testHappyPathImpliedEqualsSPCXMarketCapOverTSLAShares` | Also asserts TSLA mcap 200 + `currentTSLAPrice` passthrough |
| Zero/negative outstanding or price → nil | `testZeroOrNegativeInputsReturnNil` | All four inputs at 0 and −1 |
| Non-finite → nil | `testNonFiniteInputsReturnNil` | `.nan`, `.infinity`, `-.infinity` on both price legs |
| Real-ish orders of magnitude | `testRealishOrdersOfMagnitude` | Bundled defaults (~3.95e9 / ~13.18e9) + sanity band on implied/mcaps |

Tests use `XCTUnwrap` + tight `accuracy` on the toy happy path; looser accuracy (1.0) on large realish mcaps is appropriate. Coupling smoke test to `IssuerSharesOutstanding.defaultTSLA/SPCX` locks the calculator against the Task 2 constants without inventing magic numbers.

### Drive-by / scope

| Check | Status |
|-------|--------|
| Product file set = calculator util only | Pass |
| No UI, resolver network, or VM presentation property | Pass (VM/UI deferred to T5/T6) |
| Tests isolated to calculator class | Pass |

Parallel Task 4 product may exist in tree; Task 3 artifacts do not depend on or entangle with it.

## Quality checklist

| Axis | Result |
|------|--------|
| Purity | Closed pure function; Sendable presentation; no I/O or app services |
| Edge cases | Finite/>0 input guards + finite/>0 product/implied guards |
| Tests | All four plan scenarios covered with clear names and sensible accuracy |
| pbxproj | Plan IDs `…51`; Utilities + Sources complete |
| Naming / scope | On-plan API; no drive-by |

## VERDICT: APPROVED

## Reviewed files

- `Muskometer/Utilities/MergerMarketCapParity.swift` — pure calculator + `MergerParityPresentation`
- `Muskometer.xcodeproj/project.pbxproj` — PBXBuildFile / FileReference / Utilities group / Sources (`…51`)
- `MuskometerTests/MuskometerTests.swift` — `MergerMarketCapParityTests`
