# Task 7 Spec Review — HOLDINGS.md + full verification

**Role:** spec-reviewer  
**Task:** 7 (HOLDINGS.md docs + full verification; design §6 Docs, Acceptance 1–7)  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md` §6, Compliance & messaging, Acceptance 1–7  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 7  
**Date:** 2026-08-08  

## Scope checked

Design §6 / plan Task 7 require:

| Requirement | Expected |
|-------------|----------|
| Issuer outstanding vs Form 4 | Document company-wide outstanding (companyfacts / cover defaults) vs Musk Form 4 ownership; independent paths |
| Dual-class SPCX | mcap ≈ Class A Yahoo price × (Class A + Class B outstanding) |
| Formula | implied TSLA = SPCX mcap / TSLA outstanding |
| Illustrative only | Card is market-cap parity illustration — not a deal announcement / advice |
| Verification | Spec acceptance 1–7 supported by green typecheck/tests (verify.sh or equivalent) |

## Findings

None.

## HOLDINGS.md compliance (Acceptance 7 / design §6)

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Distinct concepts table | Pass | § “Issuer outstanding vs Form 4 ownership” — Form 4 ownership vs issuer outstanding; source; used-for columns |
| Independent paths | Pass | Explicit: Form 4 never writes outstanding; companyfacts never overwrites Form 4; best-effort outstanding |
| Cover / companyfacts defaults | Pass | TSLA `3,949,547,394` (end 2026-07-16); SPCX `13,181,779,945` with A+B split + accession `0001628280-26-052535` |
| WASO rejected | Pass | “Weighted-average / EPS share counts (WASO) are **rejected** for mcap” |
| Dual-class SPCX mcap | Pass | § “Dual-class SPCX market cap” — `Class A Yahoo price × (A+B)`; Class B economically equivalent for this toy |
| Implied TSLA formula | Pass | § “Implied TSLA at SPCX market-cap parity” — SPCX mcap / TSLA outstanding with intermediate lines |
| Illustrative only | Pass | “illustrative market-cap parity only — not a merger announcement, fairness opinion, deal model, or investment advice” |
| Defaults-only still shows | Pass | Card hidden only when quote leg missing / guard fails; defaults-only outstanding still shows |
| Reset reseeds both | Pass | “Reset to defaults reseeds both ownership and outstanding” |
| Disclaimer link | Pass | `See [DISCLAIMER.md](DISCLAIMER.md)` |

## Acceptance criteria 1–7 (product + verification evidence)

| AC | Status | Evidence |
|----|--------|----------|
| 1. Loneliest string exact | Pass | `NetWorthMilestoneTracker.belowTrillionMessage` + `testSadMessageUsesLoneliestNumberCopy` assert `"One Trillion Is the Loneliest Number"` |
| 2. Card after stock rows when quotes + positive outstanding (defaults-only OK) | Pass | Tasks 5–6: `mergerParityPresentation` + `MergerParityCardView` after `ForEach(snapshot.holdings)`; presentation tests for defaults-only |
| 3. Formula + WASO not overwrite default | Pass | `MergerMarketCapParity` pure math; `CompanyFactsOutstandingResolverTests.testWASOOnlyReturnsNil` |
| 4. Form 4 independent of companyfacts | Pass | `testOutstandingAppliedAfterForm4FailureWithoutChangingMessage`; HOLDINGS independent-paths note |
| 5. `resetToDefaults()` reseeds outstanding; ownership keys separate | Pass | `testResetToDefaultsReseedsOutstanding`; `testSetGetRoundTripIndependentOfShareCount`; HOLDINGS reset sentence |
| 6. Unit coverage (resolver, calculator, typo, outstanding keys) | Pass | `CompanyFactsOutstandingResolverTests`, `MergerMarketCapParityTests`, Loneliest test, `IssuerSharesOutstandingTests` present and executed |
| 7. HOLDINGS documents outstanding vs Form 4 + dual-class | Pass | New section + dual-class + formula (above) |

## Verification evidence

| Check | Status | Evidence |
|-------|--------|----------|
| verify derived-data present | Pass | `build/verify-derived-87263/` matches `scripts/verify.sh` `build/verify-derived-$$` pattern (PID 87263) |
| Test run completed | Pass | `Logs/Test/Test-Muskometer-2026.08.08_00-02-30--0400.xcresult` dated 2026-08-08 |
| Test failures | Pass | `LogStoreManifest.plist`: `totalNumberOfTestFailures` = **0**; `totalNumberOfErrors` = **0** |
| Test count | Pass | `TestResults/metadata.db` records **220** executed `test*` methods under `MuskometerTests` (suite-wide; feature tests included). Source defines 220 `func test…` methods — all present in run metadata |
| Feature tests executed | Pass | Resolver (6), calculator (4), outstanding settings (6), presentation (3), outstanding sync isolation (2), Loneliest (1) all have `mrnet` entries |
| Build product | Pass | `Build/Products/Debug/Muskometer.app` + test bundles present; coverage ~70.6% |
| Residual compile errors | Pass | Build log: 0 errors (status `W` from 3 non-blocking warnings only) |

Note: orchestrator guidance mentioned “219 tests”; the on-disk verify run records **220** with **0 failures**. That meets or exceeds the verification bar.

## Non-blocking notes

- HOLDINGS uses curly apostrophe in “Musk’s” / “SPCX’s” while UI title uses ASCII `SPCX's` (Task 6 note). Docs prose is fine either way.
- Full `verify.sh` also typechecks and release-builds; tree retains the test derived-data artifact (step 2). Typecheck PASS is implied by successful `xcodebuild test` of the same sources; no typecheck-only log file is required for AC.

## VERDICT: APPROVED

## Reviewed files

- `docs/HOLDINGS.md` — issuer outstanding vs Form 4; dual-class; formula; illustrative; defaults/reset/WASO
- `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md` §6 Docs, Compliance, Acceptance 1–7
- `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 7
- `scripts/verify.sh` — expected HOW for verification
- `build/verify-derived-87263/Logs/Test/LogStoreManifest.plist` — 0 failures / 0 errors
- `build/verify-derived-87263/TestResults/metadata.db` — 220 executed tests
- `Muskometer/Utilities/IssuerSharesOutstanding.swift`, `MergerMarketCapParity.swift` — defaults/formula alignment with docs
- `Muskometer/Services/NetWorthMilestoneTracker.swift` — Loneliest string (AC1)
- `MuskometerTests/MuskometerTests.swift` — AC6 coverage present

VERDICT: APPROVED
