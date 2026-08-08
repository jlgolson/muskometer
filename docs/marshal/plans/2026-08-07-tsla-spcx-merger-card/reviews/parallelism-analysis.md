# Parallelism analysis

**Role:** parallelism-analyst  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md`  
**Date:** 2026-08-07

## Parallelism analysis

**Declared dependency graph (plan self-review + Depends lines):**

```
1 → 2 → (3 ∥ 4) → 5 → 6 → 7
```

**Only concurrent pair possible:** `{3, 4}` after Task 2 is complete.  
All other adjacent pairs are sequential by hard dependency (foundation, wiring, UI, verify).

### File inventory (product sources)

| Task | Primary new product file | Shared collateral |
|------|--------------------------|-------------------|
| 3 | `Muskometer/Utilities/MergerMarketCapParity.swift` | `project.pbxproj`, `MuskometerTests/MuskometerTests.swift` |
| 4 | `Muskometer/Services/CompanyFactsOutstandingResolver.swift` | `project.pbxproj`, `MuskometerTests/MuskometerTests.swift` |

---

### Tasks {3, 4}

**Depends:** both on Task 2 only (no edge between 3 and 4).  
**Downstream:** both required by Task 5.

| Dimension | Assessment |
|-----------|------------|
| Product files | **Disjoint.** T3 = pure calculator + presentation struct; T4 = pure companyfacts JSON resolver. Different paths, modules roles (Utilities vs Services), no mutual imports. |
| Spec ownership | Disjoint: T3 → Goals/§3 formula; T4 → §2 concept priority / WASO reject / multi-member sum. |
| Logic coupling | None. Calculator takes numeric prices + outstanding; resolver returns `Int64?` from `Data`. Integration happens only in Task 5. |
| pbxproj | Both register one new `.swift` with **distinct** plan IDs (`…51` calculator, `…52` resolver). Merge-aware concurrent: adjacent PBX entries may conflict on apply order but IDs do not collide. |
| Tests | Both append to `MuskometerTests.swift` (different classes/sections expected). Same-file edit risk is mechanical merge, not semantic overlap. |
| Runtime / network | Neither introduces network or AppSettings writes. Fully offline unit work. |

**Recommendation: VERIFIED**

Product code for calculator vs resolver is file-disjoint and dependency-independent after Task 2. Safe to run Tasks 3 and 4 in parallel; reconcile `project.pbxproj` and `MuskometerTests.swift` on merge if both land concurrently.

---

### Non-concurrent pairs (for completeness)

| Pair | Why not parallel |
|------|------------------|
| {1, 2} | T2 Depends on 1 (plan gate + shared tests file sequencing). |
| {2, 3} | T3 Depends on 2 (foundation defaults/settings land first). |
| {2, 4} | T4 Depends on 2 (same foundation gate; resolver does not *code*-need AppSettings but plan gate is sequential). |
| {3, 5} / {4, 5} | T5 Depends on 3 **and** 4 (sync + VM presentation consumes both). |
| {5, 6} | T6 Depends on 5 (`mergerParityPresentation` API + wiring). |
| {6, 7} | T7 Depends on 6 (docs + full verify last). |

No other independent concurrent sets exist in the graph.

---

## Summary

| Concurrent set | Verdict |
|----------------|---------|
| Tasks {3, 4} | **VERIFIED** — calculator vs resolver product files disjoint; pure, no shared types; pbxproj/tests are mergeable collateral only |

**Max useful parallelism width:** 2 (only after Task 2).  
**Serial spine:** 1 → 2 → [3∥4] → 5 → 6 → 7.
