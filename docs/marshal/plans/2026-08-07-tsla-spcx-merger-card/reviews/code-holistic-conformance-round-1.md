# Code holistic conformance — round 1

**Role:** code-holistic-conformance  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md`  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md`  
**Date:** 2026-08-08  
**Diff basis:** `.marshal-cache/cumulative.diff` (`origin/main...HEAD`)

## Scope

Cold whole-diff review: does the shipped product code implement the approved design (Goals, Design §§1–6, data flow, error table, testing matrix, acceptance 1–7, non-goals, compliance)? Plan tasks T1–T7 treated as the intended delivery vehicle; conformance judged against design + plan, not prior review prose alone.

## Design → ship map

| Design slice | Shipped surface | Conformance |
|--------------|-----------------|-------------|
| §1 Loneliest typo | `NetWorthMilestoneTracker.belowTrillionMessage` = `"One Trillion Is the Loneliest Number"`; test renamed + dual assert | Match |
| §2 Defaults + keys | `IssuerSharesOutstanding` TSLA `3_949_547_394`, SPCX `13_181_779_945` (A+B + accession comments); `sharesOutstanding_SYMBOL` keys | Match |
| §2 Issuer CIKs | `TrackedHoldingSpec.issuerCIKPadded`: TSLA `0001318605`, SPCX `0001181412` | Match |
| §2 Settings isolation | `sharesOutstanding` / `setSharesOutstanding` independent of `shareCount_*`; not in `applyHoldingsSync`; `resetToDefaults` reseeds outstanding | Match |
| §2 Resolver | `CompanyFactsOutstandingResolver`: dei → us-gaap; `shares` only; form preference; max `(end, filed)`; multi-member sum; WASO never read | Match |
| §2 Orthogonal sync | `IssuerOutstandingSyncService` never throws from `fetchOutstanding`; same User-Agent + ~120ms delay; VM runs after Form 4 do/catch | Match |
| §3 Calculator | `MergerMarketCapParity.presentation`: `spcxPrice × spcxOutstanding / tslaOutstanding`; nil on non-finite / ≤0 | Match |
| §4 VM wiring | `mergerParityPresentation` keys live TSLA/SPCX quotes + settings outstanding (defaults-only still computable) | Match |
| §5 UI | `MergerParityCardView` after stock rows, before error caption; title “If TSLA matched SPCX's market cap”; price + mcap caption; StockRow chrome | Match |
| §6 HOLDINGS | Issuer-vs-Form-4 table, dual-class A+B, formula, illustrative disclaimer | Match |
| Non-goals | No reverse card, no Yahoo mcap, no Form 4 as float, no outstanding settings editor, no 10-Q HTML parse | Honored |
| Always-on | No settings toggle; hide only when presentation nil | Match |

## Acceptance criteria

| AC | Result | Evidence |
|----|--------|----------|
| 1. Loneliest exact string (product + tests) | Pass | Constant + `testSadMessageUsesLoneliestNumberCopy`; zero `Lonliest` under `Muskometer/` / `MuskometerTests/` |
| 2. Card after stock rows; defaults-only OK | Pass | `PopoverContentView.dataView` after `ForEach(snapshot.holdings)`; presentation tests with unset outstanding |
| 3. Formula; WASO must not overwrite SPCX default | Pass | Calculator; `testWASOOnlyReturnsNil`; empty outstanding fetch keeps defaults |
| 4. Form 4 independent of companyfacts | Pass | Orthogonal service; try outstanding after Form 4 success/partial/throw; message isolation tests |
| 5. Reset reseeds outstanding; keys separate | Pass | `resetToDefaults` + settings independence tests |
| 6. Unit matrix (resolver / calc / typo / keys) | Pass | Resolver 6, calculator 4, outstanding settings 6, presentation 3, sync isolation 2, Loneliest 1 |
| 7. HOLDINGS documents model | Pass | New section covers independence, A+B, formula, illustrative-only |

## End-to-end coherence

1. **Two share meanings stay separate** at keys, loaders, sync result types, completeness gate, and UI consumers — the design’s primary risk is not realized in the ship.
2. **Data flow** matches the diagram: companyfacts → `sharesOutstandingBySymbol`; Yahoo → snapshot quotes; pure calculator → card.
3. **Error table** implemented: miss/WASO/unresolved keep prior/default; Form 4 path unaffected; card hidden only on missing quote/guard failure; positive-only persist.
4. **Compliance copy** is illustrative parity (“If TSLA matched SPCX's market cap”), not a deal announcement; HOLDINGS does not weaken disclaimer posture.
5. **pbxproj** registers all five new product sources (`…50`–`…54`) in groups + Sources build phase.

## Non-blocking notes (not design gaps)

These are residual refinements already aligned with plan or strictly safer than ambiguous design wording; none fail acceptance:

1. Multi-member sum uses same `(end, filed)` (plan) rather than design’s looser “same end only” — safer dual-class aggregation; fixtures cover the intended sum.
2. Title uses ASCII apostrophe; HOLDINGS prose uses curly — plan allows either.
3. No dedicated single-leg missing-quote presentation unit test (dual `guard` + calculator coverage still implement the hide rule).
4. No URLProtocol HTTP unit test for the thin companyfacts client (design: no mandatory live SEC integration).

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
  "role": "code-holistic-conformance",
  "findings": []
}
```

VERDICT: APPROVED

Diff-sha256: 361ef0676b2916bc81501ba33395822e499530e2d3fa40650b2b2b3dc3025a8b
