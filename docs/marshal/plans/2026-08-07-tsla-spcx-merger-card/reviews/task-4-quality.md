# Task 4 Code Quality Review — CompanyFactsOutstandingResolver

**Role:** code-quality-reviewer  
**Task:** 4 (Pure companyfacts JSON → outstanding Int64; WASO rejected)  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 4  
**Date:** 2026-08-07  

## Scope reviewed

Quality axes: parser robustness, fixture-test accuracy, purity, naming, pbxproj, no drive-by. Task adds a pure SEC companyfacts resolver + unit fixtures — no network, no AppSettings writes, no VM/UI.

## Findings

None blocking.

### Purity & structure

| Check | Status |
|-------|--------|
| Single entry `resolveSharesOutstanding(from: Data) -> Int64?` | Pass |
| No `URLSession` / file I/O / UserDefaults / MainActor | Pass — `JSONSerialization` only |
| `enum` namespace + private helpers (`resolveConcept`, `parseRow`, `numberValue`) | Pass — matches pure-utility style (`MergerMarketCapParity`, etc.) |
| Concept paths hardcoded (whitelist), not dynamic concept scan | Pass — WASO cannot be selected by accident |

### Parser robustness

| Rule / edge | Implementation | Assessment |
|-------------|----------------|------------|
| Invalid JSON / missing `facts` | early `guard` → nil | Solid |
| Units key `shares` only | `units["shares"]` required | Solid |
| Row requires non-empty `end`, finite `val > 0` | `parseRow` drops bad rows | Solid |
| Optional `filed` / `form` | `filed` defaults `""`; `form` optional | Solid — empty `filed` loses lexicographic max to real ISO dates |
| Preferred forms `{10-Q,10-K,10-Q/A,10-K/A}` | `preferredForms` set; pool = preferred if non-empty else all | Solid |
| Latest `(end, filed)` | `max(by:)` string compare on ISO dates | Correct for `YYYY-MM-DD` |
| Multi-member sum | filter same `(end, filed)`, `reduce` vals | Solid; matches plan; slightly tighter than “same end only” (good for dual-class same filing) |
| Int64 bounds | `sum <= Double(Int64.max)`, `rounded()`, `> 0` | Defensive without over-engineering |
| Numeric JSON types | `Double` / `Int` / `Int64` / `NSNumber` | Covers `JSONSerialization`’s typical `NSNumber` path |
| WASO / other concepts | Never read; only Entity then CommonStock | Correct hard reject |

Lexicographic date ordering is appropriate for SEC ISO date strings. Share counts used here sit well under Double’s exact integer range (~2^53), so `Double` → `Int64` rounding is safe for this domain.

### Naming

| Item | Assessment |
|------|------------|
| `CompanyFactsOutstandingResolver` | Clear SEC-domain role; not confused with Form 4 ownership parsers. |
| `resolveSharesOutstanding` | Verb matches plan API; returns optional positive outstanding only. |
| `FactRow` / `preferredForms` | Local, accurate; form set matches plan/spec set. |
| `CompanyFactsOutstandingResolverTests` | Test class name mirrors product type. |

No ownership / “shareCount” vocabulary leakage.

### Fixture tests

| Plan / design requirement | Test | Status |
|---------------------------|------|--------|
| TSLA-style single EntityCommonStockSharesOutstanding | `testSingleEntityCommonStockSharesOutstanding` → `3_949_547_394` | Pass |
| Multi-member same end/filed sum 100+200 → 300 | `testMultiMemberSameEndFiledSums` | Pass |
| WASO-only → nil | `testWASOOnlyReturnsNil` (basic + diluted) | Pass |
| **Required** form preference: preferred 10-Q/10-K wins over non-preferred with later end/filed | `testPrefers10QOverNonPreferredFormWithLaterEndOrFiled` (8-K 999 vs 10-Q real TSLA figure) | Pass — asserts the hard case the plan called out |
| Concept fallback Entity → us-gaap CommonStock | `testFallsBackToCommonStockSharesOutstandingWhenEntityMissing` | Extra, good |
| Invalid JSON / empty object → nil | `testInvalidJSONReturnsNil` | Extra, good |

Fixtures are minimal UTF-8 JSON strings → `Data` — no live SEC, no shared mutable state. Form-preference fixture comment documents the intent (8-K later end/filed must not beat preferred pool).

**Non-blocking gap:** No dedicated fixture for “among preferred forms only, later `end` then later `filed` wins.” Selection logic is small and form-preference already stresses pool filtering; optional follow-up only.

### pbxproj

| Check | Status |
|-------|--------|
| Build file ID `A10000000000000000000052` | Pass — plan table exact |
| File ref ID `A20000000000000000000052` | Pass |
| Services group child | Pass |
| `A60000000000000000000002 /* Sources */` entry | Pass |
| No Task 5–6 files (`…53`, `…54`) | Pass |

Task 3’s `…51` (`MergerMarketCapParity`) is also registered — expected under T3∥T4 parallelism; not Task 4 drive-by.

### Drive-by / scope

| Check | Status |
|-------|--------|
| No `IssuerOutstandingSyncService` / network fetch | Pass |
| No `GainsViewModel` / presentation / card UI | Pass |
| No AppSettings outstanding writes in resolver | Pass |
| Product surface = one new pure file + tests + pbxproj | Pass |

## Quality checklist

| Axis | Result |
|------|--------|
| Parser robustness | Whitelist concepts, form pool, (end,filed) max + sum, nil on bad/missing data, Int64 guards |
| Fixture tests | All four required scenarios including form preference; solid extras for fallback + invalid JSON |
| Naming | Domain-clear; no Form 4 / ownership collision |
| Purity / scope | No I/O; no T5–T6 creep; pbxproj IDs correct |

## VERDICT: APPROVED

## Reviewed files

- `Muskometer/Services/CompanyFactsOutstandingResolver.swift` — pure resolve, concept priority, form preference, multi-member sum, WASO never read
- `MuskometerTests/MuskometerTests.swift` — `CompanyFactsOutstandingResolverTests` (single, multi-sum, WASO nil, form preference, us-gaap fallback, invalid JSON)
- `Muskometer.xcodeproj/project.pbxproj` — IDs `…52`, Services group + Sources

VERDICT: APPROVED
