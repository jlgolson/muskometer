# Task 4 Spec Review — CompanyFactsOutstandingResolver

**Role:** spec-reviewer  
**Task:** 4 (CompanyFactsOutstandingResolver — pure, WASO rejected; design §2 resolve rules)  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md` §2  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 4  
**Date:** 2026-08-07  

## Scope checked

Design §2 / plan Task 4 require (for this task only):

| Requirement | Expected |
|-------------|----------|
| Pure API | `resolveSharesOutstanding(from: Data) -> Int64?`; no network |
| Concept priority | `facts.dei.EntityCommonStockSharesOutstanding` then `facts.us-gaap.CommonStockSharesOutstanding` |
| Units | `shares` only |
| WASO reject | Never read basic/diluted weighted-average concepts; WASO-only → nil |
| Row shape | `end` required; positive finite `val`; optional `filed` / `form` |
| Form preference | Prefer `{10-Q, 10-K, 10-Q/A, 10-K/A}` when any such rows exist; else all rows with `end` |
| Latest selection | Max `(end, filed)` within pool |
| Multi-member sum | Sum members sharing the chosen `(end, filed)` pair |
| Invalid / missing | nil |
| pbxproj | IDs `A1…52` / `A2…52` |
| Tests (required) | TSLA-style single accept; multi-member sum 100+200→300; WASO-only nil; **form preference** 10-Q wins over non-preferred with later end/filed |

Out of scope for Task 4 (deferred): fetch/network, AppSettings persist, ViewModel wiring, UI.

## Findings

None.

## Compliance checklist

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Pure `enum` + `static func resolveSharesOutstanding(from:) -> Int64?` | Pass | `CompanyFactsOutstandingResolver`; no URLSession / SEC client |
| Concept priority Entity → CommonStock | Pass | Tries `dei`/`EntityCommonStockSharesOutstanding` first; falls back to `us-gaap`/`CommonStockSharesOutstanding` |
| Units key `shares` only | Pass | `units["shares"]` only; other unit keys ignored |
| WASO concepts never read | Pass | Only the two priority concept paths are resolved; WASO names absent from code |
| WASO-only fixture → nil | Pass | `testWASOOnlyReturnsNil` with basic + diluted us-gaap → `XCTAssertNil` |
| Row requires `end` + positive finite `val` | Pass | `parseRow`: empty/missing `end` or non-positive/non-finite `val` → nil |
| Optional `filed` / `form` | Pass | `filed` defaults `""`; `form` optional |
| Preferred forms set | Pass | `{"10-Q","10-K","10-Q/A","10-K/A"}` matches design §2 / plan |
| Form preference pool | Pass | If any preferred-form rows exist, pool = preferred only; else all rows |
| Max `(end, filed)` then sum same pair | Pass | `pool.max` by end then filed; `filter` same end+filed; `reduce` sum |
| Finite `> 0` → `Int64` | Pass | Guard `sum.isFinite, sum > 0, sum <= Int64.max`; round; reject non-positive round |
| Invalid JSON / missing facts → nil | Pass | Root/`facts` guard; `testInvalidJSONReturnsNil` (`not-json`, `{}`) |
| TSLA-style single Entity accept | Pass | `testSingleEntityCommonStockSharesOutstanding` → `3_949_547_394` |
| Multi-member same end/filed sum | Pass | `testMultiMemberSameEndFiledSums` 100+200 → 300 |
| **Required** form preference | Pass | `testPrefers10QOverNonPreferredFormWithLaterEndOrFiled`: 8-K later end/filed val 999 loses to 10-Q `3_949_547_394` |
| Concept fallback when Entity missing | Pass | `testFallsBackToCommonStockSharesOutstandingWhenEntityMissing` → `111_222_333` (covers priority path 2) |
| pbxproj IDs 52 | Pass | PBXBuildFile `A100…52`, fileRef `A200…52`, Services group child, Sources entry |

## Non-blocking notes

- Plan sums same `(end, filed)`; design multi-class prose emphasizes same `end` for the chosen instant. Matches plan (task contract); dual-class same-filing rows are the intended case. Residual edge (same `end`, divergent `filed`) remains rare and was already noted in plan correctness reviews.
- No separate fixture for “two preferred-form rows, later `end` wins alone”; form-preference fixture plus max-`(end, filed)` implementation still satisfy design Testing “latest selection by `(end, filed)` and form preference.”

## VERDICT: APPROVED

## Reviewed files

- `Muskometer/Services/CompanyFactsOutstandingResolver.swift` — pure resolver; concept priority; WASO never read; form preference; multi-member sum; nil on bad input
- `Muskometer.xcodeproj/project.pbxproj` — IDs `A10000000000000000000052` / `A20000000000000000000052`
- `MuskometerTests/MuskometerTests.swift` — `CompanyFactsOutstandingResolverTests` (single, multi-member, WASO, form preference, CommonStock fallback, invalid JSON)
- `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md` §2 Resolve + Testing
- `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 4 steps
