# Code holistic quality review — round 1

**Role:** code-holistic-quality  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md`  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md`  
**Date:** 2026-08-08  
**Context:** Cold whole-diff quality review of product code + tests (naming, architecture hygiene, test adequacy, critical bugs). Not a re-score of per-task gates.

## Scope

Reviewed `.marshal-cache/cumulative.diff` and live product/test sources for the feature:

| Layer | Surfaces |
|-------|----------|
| Model | `TrackedHoldingSpec.issuerCIKPadded`; musk TSLA/SPCX CIKs |
| Settings | `AppSettings` outstanding load/get/set/reset; keys via `IssuerSharesOutstanding` |
| Pure calc | `MergerMarketCapParity` / `MergerParityPresentation` |
| Pure parse | `CompanyFactsOutstandingResolver` |
| Network | `IssuerOutstandingSyncService` + protocol |
| VM | `outstandingSyncServiceFactory`, `syncIssuerOutstanding`, `mergerParityPresentation` |
| UI | `MergerParityCardView`, `PopoverContentView.dataView` placement |
| Typo | `NetWorthMilestoneTracker.belowTrillionMessage` |
| Project | pbxproj `…50`–`…54` (BuildFile, FileRef, groups, Sources) |
| Tests | outstanding settings, resolver, calculator, VM presentation, sync isolation, Loneliest rename |
| Docs | `docs/HOLDINGS.md` issuer-vs-ownership section |

Excluded from fix bar: marshal plan/spec prose, historical review notes, build artifacts under `build/`.

## Architecture hygiene

End-to-end layering matches the design and existing Muskometer seams:

```
companyfacts JSON  →  CompanyFactsOutstandingResolver (pure)
URLSession fetch   →  IssuerOutstandingSyncService (best-effort, never throws out)
                   →  AppSettings.sharesOutstanding_* (orthogonal to shareCount_*)
Yahoo quotes       →  GainsSnapshot
quotes + outstanding → MergerMarketCapParity (pure) → MergerParityPresentation
                   →  MergerParityCardView (presentation-only SwiftUI)
```

**Orthogonality of the two share meanings is enforced at every layer**, not only documented:

| Concern | Ownership (Form 4) | Issuer outstanding |
|---------|--------------------|--------------------|
| UD keys | `shareCount_*` | `sharesOutstanding_*` |
| Settings API | `shareCount` / `setShareCount` | `sharesOutstanding` / `setSharesOutstanding` |
| Sync type | `HoldingsSyncResult` / `applyHoldingsSync` | separate map from `fetchOutstanding` |
| Completeness gate | ownership symbols only | never participates |
| UI consumer | stock rows / paper gains | merger card only |
| Failure coupling | throws → message | best-effort omit; no message mutation |

VM wiring places outstanding after the Form 4 `do/catch` so a throw still runs companyfacts, and success messaging is untouched on empty outstanding — covered by isolation tests.

Pure units (`MergerMarketCapParity`, `CompanyFactsOutstandingResolver`, `IssuerSharesOutstanding`) have no I/O, settings, or UI imports. Network service mirrors `SECHoldingsSyncService` (User-Agent, 120ms spacing, `@unchecked Sendable` session client). Card chrome matches `StockRowView` (padding 12, continuous radius 10, controlBackground 0.55, `animateValues` + numericText).

pbxproj registers all five new product files with plan IDs `…50`–`…54` in the correct groups and Sources phase. No orphan types.

## Naming

| Name | Assessment |
|------|------------|
| `IssuerSharesOutstanding` / `sharesOutstanding*` | Clear “company totals” vocabulary; no Form 4 collision |
| `issuerCIKPadded` | Distinct from person `secCIKPadded`; comment states companyfacts use |
| `CompanyFactsOutstandingResolver` | Domain-precise pure parser |
| `IssuerOutstandingSyncService` | Orthogonal to `SECHoldingsSyncService` |
| `MergerMarketCapParity` / `MergerParityPresentation` / `MergerParityCardView` | Consistent “merger parity” product framing (illustrative, not deal model) |
| `mergerParityPresentation` | Computed VM surface; keys hard-coded `"TSLA"`/`"SPCX"` as design requires |
| Test classes / mock | Mirror product types; mock is protocol-backed and file-private |

No ownership vocabulary leaks into outstanding APIs.

## Tests

Coverage maps cleanly onto the design Testing matrix and acceptance criteria:

| Area | Coverage |
|------|----------|
| Bundled defaults + keys | `IssuerSharesOutstandingTests` |
| Issuer CIKs on musk holdings | same |
| Settings independence + reload + ignore ≤0 + reset reseed | same |
| Calculator happy / zero-neg / non-finite / realish mags | `MergerMarketCapParityTests` |
| Resolver Entity, multi-member sum, WASO nil, form preference, us-gaap fallback, invalid JSON | `CompanyFactsOutstandingResolverTests` |
| Presentation nil without snapshot; prices+outstanding; defaults-only | `GainsViewModelMergerParityPresentationTests` |
| Outstanding after Form 4 failure; empty outstanding leaves Form 4 success + defaults | `GainsViewModelIssuerOutstandingSyncTests` |
| Loneliest exact + constant equality | `testSadMessageUsesLoneliestNumberCopy` |
| Holdings backoff avoids live companyfacts | factory inject of empty mock |

Gaps that remain acceptable (not fix-required):

- No HTTP-shape unit tests for `IssuerOutstandingSyncService` (thin sequential wrapper; resolver + VM isolation cover contracts).
- No SwiftUI snapshot tests for the card (consistent with other pure cards).
- No live SEC integration (explicit non-goal for CI).

## Critical-bug scan

| Risk | Result |
|------|--------|
| Outstanding overwrites Form 4 ownership | No path; separate keys/APIs; isolation tests |
| WASO accepted as mcap base | Concepts never read; WASO-only → nil; defaults preserved |
| Form 4 throw aborts outstanding | Call after catch; always attempted |
| Outstanding failure poisons Form 4 message | Only `setSharesOutstanding`; tests assert |
| Card uses Musk shareCount as float | Presentation uses `settings.sharesOutstanding` only |
| Calculator accepts non-finite / ≤0 | Guards on inputs and outputs |
| Defaults-only hides card | `sharesOutstanding(for:)` falls back to bundled; presentation test |
| Missing quote leg still shows card | Both TSLA+SPCX required; nil otherwise |
| pbxproj misses new sources | All five registered |
| Loneliest residual in product/tests | Only corrected spelling under `Muskometer/` |

No critical or high-severity defects found in product logic.

## Findings

None blocking.

### [LOW] Residual dual-class companyfacts edge (accepted by design)

Resolver multi-member sum is same `(end, filed)` within the preferred-form pool. Design multi-class prose also allows “same end”; if preferred forms later expose only one SPCX class, a successful resolve could overwrite the cover A+B default with a partial total. Mitigations already in place: WASO hard-reject (current SPCX companyfacts path stays default), multi-member sum when dual rows share end/filed, and HOLDINGS dual-class documentation. Not a ship blocker for v1; no code change required unless SEC starts publishing incomplete preferred-form single-class rows for SPCX.

### [LOW] Outstanding loop does not short-circuit on task cancellation

`try? await Task.sleep` swallows cancellation, and the fetch loop continues for remaining CIKs. Matches other best-effort paths; daily two-request cadence makes cost negligible. Optional polish only.

### [LOW] `docs/HOLDINGS.md` ends without a trailing newline

Cosmetic file hygiene only; content and formula documentation are complete.

## Quality checklist (whole PR)

| Axis | Result |
|------|--------|
| Naming | Domain-clear; ownership vs outstanding vocabulary separated |
| Architecture | Pure parse/calc → thin network → settings → VM → pure view; Form 4 path unchanged |
| Independence | Keys, APIs, completeness gate, UI consumers all orthogonal |
| Guards | Positive-only outstanding writes (service + VM + settings); calculator nil on bad inputs |
| UI hygiene | StockRow chrome parity; after stock rows; hide when nil; no settings toggle |
| Tests | Design matrix + Form 4 isolation + defaults-only presentation covered |
| Project hygiene | pbxproj complete; `.worktrees/` gitignored |
| Critical bugs | None found |

## Verdict

Ship-quality implementation of the merger parity card and Loneliest typo fix. Layering, naming, and test isolation are strong; residual notes are design-accepted dual-class edge cases and polish, not defects.

VERDICT: APPROVED

Diff-sha256: 361ef0676b2916bc81501ba33395822e499530e2d3fa40650b2b2b3dc3025a8b
