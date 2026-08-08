# Parallelism verification

**Role:** parallelism-verifier  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md`  
**Analysis:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card/reviews/parallelism-analysis.md`  
**Date:** 2026-08-07

## Scope

Verify the analyst’s concurrent set `{3, 4}` (and that no other concurrent sets were claimed incorrectly) against the plan’s Depends lines, Files touched, and product-file ownership.

## Graph check

| Claim in analysis | Plan evidence | Result |
|-------------------|---------------|--------|
| Graph `1 → 2 → (3 ∥ 4) → 5 → 6 → 7` | T2 Depends 1; T3 Depends 2; T4 Depends 2; T5 Depends 3,4; T6 Depends 5; T7 Depends 6 | Match |
| Only concurrent pair `{3, 4}` | No edge between 3 and 4; both only depend on 2; both required before 5 | Match |
| All other adjacent pairs sequential | Hard Depends on every other spine edge | Match |

No undeclared concurrent sets appear in the analysis. No missed independent pairs: every other task pair either has a Depends edge or shares the serial spine after/before the fork.

## Pair {3, 4} — re-verification

| Dimension | Plan / analysis | Verifier note |
|-----------|-----------------|---------------|
| Depends | Both `Depends on: 2` only | Independent after Task 2; no 3↔4 edge |
| Downstream | Task 5 Depends on 3 **and** 4 | Correct join; not a reason to serialize 3 vs 4 |
| Primary product files | T3: `Muskometer/Utilities/MergerMarketCapParity.swift`; T4: `Muskometer/Services/CompanyFactsOutstandingResolver.swift` | Disjoint paths; different modules roles |
| Type / API coupling | T3 pure calculator + presentation struct; T4 pure `Data` → `Int64?` resolver | No mutual imports; integration deferred to T5 |
| Spec ownership | T3 Goals/§3 formula; T4 §2 companyfacts rules | Disjoint requirements |
| pbxproj IDs | T3 `…51` / T4 `…52` (distinct) | No ID collision; adjacent PBX text may need merge only |
| Tests file | Both append `MuskometerTests/MuskometerTests.swift` | Mechanical same-file merge risk only; different test concerns |
| Side effects | Neither task network, AppSettings writes, or UI | Safe concurrent pure units |

**Verdict for pair:** analysis **VERIFIED**. Safe to run Tasks 3 and 4 in parallel after Task 2; reconcile `project.pbxproj` and `MuskometerTests.swift` on merge if both land concurrently.

## Non-concurrent pairs (spot-check)

Analyst correctly excluded:

- `{1, 2}`, `{2, 3}`, `{2, 4}` — Depends edges  
- `{3, 5}`, `{4, 5}`, `{5, 6}`, `{6, 7}` — Depends edges  

No challenge.

## Summary

Analysis is accurate: max useful width 2 after Task 2; serial spine `1 → 2 → [3∥4] → 5 → 6 → 7`.

## Per-pair verdicts

- {3, 4}: VERIFIED

VERDICT: APPROVED
Plan-graph-sha256: d63b0b3cf9b8074f64e32873160f722bd411d6e45e3c10c00dc0870c4a0846ec
