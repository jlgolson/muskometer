# Execution holistic review — round 1

**Role:** execution-holistic  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md`  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md`  
**Date:** 2026-08-08  
**Context:** All per-task reviews (T1–T7 spec + quality) APPROVED. This pass answers: does the branch implement the design as a coherent whole?

## Scope

Gestalt check against design Goals, Design §§1–6, Data flow, Error handling, Testing matrix, Acceptance 1–7, Non-goals, Compliance & messaging. Key shipped surfaces re-read in tree (not only prior review notes).

## Design → ship map

| Design slice | Shipped surface | Status |
|--------------|-----------------|--------|
| §1 Loneliest typo | `NetWorthMilestoneTracker.belowTrillionMessage` + `testSadMessageUsesLoneliestNumberCopy` | Match |
| §2 Issuer outstanding model | `IssuerSharesOutstanding` defaults + accession comments; `TrackedHoldingSpec.issuerCIKPadded` TSLA/SPCX; `AppSettings` `sharesOutstanding_*` independent of `shareCount_*`; `resetToDefaults` reseeds | Match |
| §2 companyfacts resolve | `CompanyFactsOutstandingResolver`: dei → us-gaap priority; `shares` unit only; form preference; `(end, filed)` latest; multi-member sum; WASO never read | Match |
| §2 orthogonal SEC path | `IssuerOutstandingSyncService` (never throws out of fetch); invoked from `syncHoldingsFromSEC` after Form 4 do/catch; not folded into `HoldingsSyncResult` / `applyHoldingsSync` completeness | Match |
| §3 Pure calculator | `MergerMarketCapParity.presentation` → `MergerParityPresentation`; formula `spcxPrice × spcxOutstanding / tslaOutstanding`; guards non-finite / ≤0 | Match |
| §4 VM wiring | `GainsViewModel.mergerParityPresentation` keys live `"TSLA"` / `"SPCX"` quotes + `settings.sharesOutstanding`; defaults-only still non-nil when quotes present | Match |
| §5 UI | `MergerParityCardView` after stock rows in `PopoverContentView.dataView`; title “If TSLA matched SPCX's market cap”; price + mcap caption; stock-row chrome | Match |
| §6 Docs | `docs/HOLDINGS.md` issuer-vs-Form-4 section, dual-class A+B, formula, illustrative disclaimer | Match |
| Data flow diagram | companyfacts → outstanding UD; Yahoo → snapshot; calculator → card | Match |
| Error table | Keep prior/default on companyfacts miss; hide card only on missing quote/guards; reset reseeds outstanding | Match |
| Non-goals | No reverse direction, no Yahoo mcap, no Form 4 as float, no settings editor for outstanding, no 10-Q HTML parse | Honored |

## End-to-end coherence

### Two “shares” meanings stay separate

The design’s core risk was conflating Musk Form 4 ownership with issuer outstanding. The branch keeps them orthogonal at every layer:

- **Keys:** `shareCount_*` vs `sharesOutstanding_*`
- **Loaders / mutators:** `shareCount` / `setShareCount` vs `sharesOutstanding` / `setSharesOutstanding` (positive-only write on outstanding)
- **Sync types:** `HoldingsSyncResult.sharesBySymbol` ownership only; outstanding is a separate map from `fetchOutstanding`
- **Completeness gate:** `applyHoldingsSync` still ownership-only; outstanding never participates
- **UI consumers:** stock rows / paper gains use ownership; merger card uses outstanding only

Tests lock independence (`testSetGetRoundTripIndependentOfShareCount`, Form 4 failure + outstanding success, empty outstanding + Form 4 success).

### Formula and dual-class convention

```
impliedTSLAPrice = (spcxClassAPrice × spcxAPlusBOutstanding) / tslaOutstanding
```

Implemented exactly in `MergerMarketCapParity`. SPCX A+B is carried as a single outstanding total (bundled default `13_181_779_945` = A + B with accession comment; companyfacts multi-member sum when present). Class A Yahoo price is the existing quote path — no new mcap endpoint. Matches Goals and dual-class section.

### Graceful degradation

| Condition | Behavior in code | Design |
|-----------|------------------|--------|
| Never companyfacts-synced | `sharesOutstanding(for:)` falls back to bundled defaults; card still shows | Required |
| WASO-only companyfacts | Resolver returns nil → symbol omitted from fetch map → prior/default kept | Required |
| Network / HTTP failure | `fetchOutstanding` omits symbol; no throw | Required |
| Form 4 throws | Outstanding still attempted after catch; Form 4 message unchanged | Required |
| Missing TSLA or SPCX quote | `mergerParityPresentation` nil → card hidden | Required |
| Zero/negative outstanding write | `setSharesOutstanding` ignores `count ≤ 0` | Required |

### Product narrative

- Title is illustrative parity (“If TSLA matched SPCX's market cap”), not a deal announcement — matches Compliance.
- HOLDINGS documents model, independence, WASO reject, and disclaimer pointer; DISCLAIMER not weakened.
- Loneliest easter-egg fixed in product + tests; zero `Lonliest` under `Muskometer/` / `MuskometerTests/`.

### Architecture fit

New pieces land on existing seams without forcing a redesign:

1. Typo on existing milestone tracker  
2. Outstanding constants + settings keys next to ownership  
3. Pure resolver + pure calculator (unit-testable, no UI)  
4. Thin network service mirrors Form 4 User-Agent / inter-request delay  
5. VM factory inject + computed presentation  
6. One SwiftUI card after stock rows (Musk-centric content first)  
7. Docs section on HOLDINGS  

pbxproj includes all five new product sources (`…50`–`…54`). No orphaned types.

## Acceptance criteria (holistic)

| AC | Verdict | Evidence |
|----|---------|----------|
| 1. Loneliest exact | Pass | Constant + `testSadMessageUsesLoneliestNumberCopy` |
| 2. Card after stock rows; defaults-only OK | Pass | `PopoverContentView` after `ForEach(snapshot.holdings)`; presentation tests with unset outstanding |
| 3. Formula + WASO not overwrite default | Pass | Calculator + `testWASOOnlyReturnsNil` + empty-fetch keeps defaults |
| 4. Form 4 independent of companyfacts | Pass | Orthogonal service; failure-path test; HOLDINGS independence note |
| 5. Reset reseeds outstanding; keys separate | Pass | `resetToDefaults` + settings tests |
| 6. Unit coverage matrix | Pass | Resolver (6), calculator (4), outstanding settings (6), presentation (3), sync isolation (2), Loneliest (1) |
| 7. HOLDINGS documents model | Pass | New section + dual-class + formula + illustrative |

## Verification residue

On-disk `build/verify-derived-87263` matches `scripts/verify.sh` PID naming; Test LogStore: **0 failures / 0 errors**; **220** executed tests. Consistent with Task 7 reviews.

## Per-task approval rollup

All task reviews APPROVED: T1–T7 (spec + quality), plan correctness R1–R2, parallelism verification. No open NEEDS_FIXES from execution tasks.

## Non-blocking notes (not design gaps)

1. Multi-member sum filters same `(end, filed)` rather than design’s looser “same end only” — safer against double-counting across filings; fixtures/tests cover the intended dual-class sum.
2. No dedicated single-leg missing-quote presentation unit test (behavior is a dual `guard` + calculator coverage).
3. No URLProtocol/HTTP unit test for `IssuerOutstandingSyncService` (design: no mandatory live SEC integration).
4. UI apostrophe is ASCII in title; HOLDINGS uses curly in prose — cosmetic.

None of these change acceptance, data flow, or user-visible design intent.

## Gestalt verdict

The branch is a complete vertical slice of the design: typo fix, issuer outstanding (defaults + SEC), pure parity math, orthogonal daily sync, popover card after stock rows, docs, and tests. Layers compose as the data-flow diagram specifies; ownership and outstanding never cross wires; error handling matches the table; non-goals remain out of scope. No missing design pillar, no contradictory implementation, no incomplete seam that would leave the feature half-shipped.

## Reviewed files (primary)

- `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md`
- `Muskometer/Utilities/MergerMarketCapParity.swift`
- `Muskometer/Utilities/IssuerSharesOutstanding.swift`
- `Muskometer/Utilities/AppSettings.swift` (outstanding keys, reset)
- `Muskometer/Services/CompanyFactsOutstandingResolver.swift`
- `Muskometer/Services/IssuerOutstandingSyncService.swift`
- `Muskometer/Services/NetWorthMilestoneTracker.swift`
- `Muskometer/Models/TrackedPersonProfile.swift` (issuer CIKs)
- `Muskometer/ViewModels/GainsViewModel.swift` (`syncIssuerOutstanding`, `mergerParityPresentation`)
- `Muskometer/Views/MergerParityCardView.swift`
- `Muskometer/Views/PopoverContentView.swift`
- `docs/HOLDINGS.md`
- `MuskometerTests/MuskometerTests.swift` (feature test classes)
- `Muskometer.xcodeproj/project.pbxproj`
- Prior APPROVED task/plan reviews under this plan’s `reviews/`

VERDICT: APPROVED
