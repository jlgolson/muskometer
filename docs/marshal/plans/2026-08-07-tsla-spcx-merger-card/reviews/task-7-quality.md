# Task 7 Code Quality Review — HOLDINGS.md + verification evidence

**Role:** code-quality-reviewer  
**Task:** 7 (HOLDINGS.md clarity + verify actually run; residual compile hygiene)  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 7  
**Date:** 2026-08-08  

## Scope reviewed

Quality axes: documentation clarity/structure, factual alignment with code, verify-run authenticity, residual compile issues in tree, scope hygiene (docs + verify only for this task).

## Findings

None blocking.

### Doc clarity

| Check | Status |
|-------|--------|
| Placement | Pass — new section after existing paper-gain math; does not bury Form 4 ownership section |
| Concept separation | Pass — two-row table (Form 4 ownership vs issuer outstanding) makes the dual-number model scannable |
| Dual-class subsection | Pass — short, formula-first, explains *why* A+B (economic equivalence) without legal overclaim |
| Implied-price formula | Pass — three-line block mirrors calculator (`spcxPrice × outstanding / tslaOutstanding`) |
| Illustrative framing | Pass — explicit non-goals (no announcement / fairness / deal model); hide rules stated once |
| Defaults table | Pass — integers match `IssuerSharesOutstanding` (`3_949_547_394`, `13_181_779_945`) with as-of / accession |
| Cross-links | Pass — DISCLAIMER pointer; no marketing-site scope creep |

Prose is dense but readable for a technical holdings note. Tables + fenced formulas match the rest of HOLDINGS style.

### Factual alignment with code

| Doc claim | Code | Assessment |
|-----------|------|------------|
| Outstanding from companyfacts + cover defaults | `CompanyFactsOutstandingResolver` + `IssuerSharesOutstanding` | Match |
| Form 4 for paper gain only | Existing Form 4 path / stock rows | Match |
| Paths independent | `IssuerOutstandingSyncService` orthogonal; failure tests keep Form 4 message | Match |
| A+B via Class A price × total outstanding | `MergerMarketCapParity` multiplies `spcxPrice * Double(spcxOutstanding)` | Match (caller supplies A+B total) |
| implied = SPCX mcap / TSLA outstanding | `spcxMarketCap / tslaShares` | Match |
| WASO rejected | Resolver never reads WASO concepts; WASO-only → nil | Match |
| Defaults-only still shows card | Presentation uses settings fallbacks; hide only on missing quotes/guards | Match |
| Reset reseeds outstanding | `AppSettings.resetToDefaults` + outstanding tests | Match |

No drift between HOLDINGS numbers and bundled constants.

### Verify was actually run

| Signal | Assessment |
|--------|------------|
| Derived path `build/verify-derived-87263` | Matches `scripts/verify.sh` `TEST_DERIVED="$ROOT/build/verify-derived-$$"` (shell PID 87263) — not a hand-named folder |
| xcresult timestamp | `Test-Muskometer-2026.08.08_00-02-30--0400.xcresult` — same day as review |
| LogStoreManifest | `totalNumberOfTestFailures` = 0; `totalNumberOfErrors` = 0 |
| metadata.db | **220** distinct executed tests with per-test `mrnet` durations across 48 test classes |
| Products | Debug `Muskometer.app` + `MuskometerTests` modules built under that derived path |
| Coverage artifact | `hasCoverageData` true; ~70.6% recorded |

This is a real `xcodebuild test` (and likely full `verify.sh` step 2) run, not an empty or stale tree.

### Residual compile / tree hygiene

| Check | Status |
|-------|--------|
| Build errors | Pass — 0 errors in Test/Build LogStore manifests |
| Warnings | Non-blocking — 3 warnings, high-level status `W` (not `E`/`F`) |
| Feature sources typecheckable | Pass — app + tests built successfully in verify derived data |
| No orphaned broken stubs | Pass — `MergerParityCardView`, resolver, sync service, calculator all present and linked |

No residual compile failure blocking acceptance.

### Scope hygiene

| Check | Status |
|-------|--------|
| Task 7 primary file is docs | Pass — HOLDINGS.md is the docs deliverable |
| No drive-by UI rewrites in this task’s intent | Pass — UI already landed in Tasks 5–6; Task 7 is docs + gate |
| Verify artifacts under `build/` | Expected local/CI residue; not committed product source |

## Quality checklist

| Axis | Result |
|------|--------|
| Doc structure | Clear section hierarchy; table + formulas; matches existing HOLDINGS voice |
| Accuracy | Defaults, dual-class, formula, independence aligned with implementation |
| Verify authenticity | PID-named derived data + xcresult + 220 tests / 0 failures |
| Compile hygiene | 0 errors; only non-blocking warnings |

## Non-blocking notes

- Count note: suite is **220** executed tests (source has 220 `func test…`); if a prior note said 219, treat as off-by-one against an intermediate tree — current evidence is 220 green.
- `verify.sh` step 5 (live Yahoo) may have been skipped via `MUSKOMETER_SKIP_LIVE_YAHOO=1` per plan; unit-test gate is the acceptance-relevant signal and is present.

## VERDICT: APPROVED

## Reviewed files

- `docs/HOLDINGS.md` — structure, dual-number model, dual-class, formula, illustrative copy
- `Muskometer/Utilities/IssuerSharesOutstanding.swift` — default integer lock
- `Muskometer/Utilities/MergerMarketCapParity.swift` — formula alignment
- `scripts/verify.sh` — HOW / derived-path naming
- `build/verify-derived-87263/Logs/Test/LogStoreManifest.plist` — failure counts
- `build/verify-derived-87263/Logs/Build/LogStoreManifest.plist` — error/warning counts
- `build/verify-derived-87263/TestResults/metadata.db` — executed test inventory (220)

VERDICT: APPROVED
