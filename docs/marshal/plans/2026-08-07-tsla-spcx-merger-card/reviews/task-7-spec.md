# Task 7 Spec Review — HOLDINGS.md + full verification

**Date:** 2026-08-08  
**Role:** spec-reviewer (cold)  
**Task:** 7 (HOLDINGS.md docs + full verification; design §6 Docs, Acceptance 1–7)  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md` §6, Compliance & messaging, Acceptance 1–7  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 7  

---

## Requirements under review

Design §6 / plan Task 7 require:

| Item | Requirement |
|------|-------------|
| HOLDINGS content | Issuer outstanding (companyfacts / cover defaults) vs Form 4 **ownership** |
| HOLDINGS content | Dual-class SPCX: mcap ≈ Class A price × (A+B) |
| HOLDINGS content | Formula: implied TSLA = SPCX mcap / TSLA outstanding |
| HOLDINGS content | Card is illustrative only |
| Verification WHAT | Spec acceptance criteria 1–7 covered |
| Verification HOW | `./scripts/verify.sh` (with optional `MUSKOMETER_SKIP_LIVE_YAHOO=1`) or typecheck + xcodebuild test; expect 0 failures |
| Verification WHO | Task 7 implementer |

---

## HOLDINGS.md compliance (Acceptance 7 / design §6)

`docs/HOLDINGS.md` adds section **“Issuer outstanding vs Form 4 ownership”** plus dual-class and parity subsections. Checklist:

| Design §6 / plan bullet | Status | Evidence in HOLDINGS.md |
|-------------------------|--------|-------------------------|
| Issuer outstanding vs Form 4 ownership | Pass | Two-concept table: Form 4 ownership (paper gain / stock rows) vs issuer outstanding (companyfacts + cover defaults; merger card only). Explicit independence of write paths. |
| companyfacts / cover defaults | Pass | Source column names companyfacts XBRL + cover-derived bundled defaults; defaults table TSLA `3,949,547,394` (end 2026-07-16) and SPCX `13,181,779,945` (A+B cover 2026-07-28, accession `0001628280-26-052535`) — matches design bundled defaults. |
| Dual-class SPCX mcap convention | Pass | “Dual-class SPCX market cap”: Class A Yahoo price × (A+B); not Class A alone; not fully diluted. |
| Implied TSLA formula | Pass | Fenced block: `SPCX mcap = SPCX Class A price × SPCX (A+B) outstanding`; `implied TSLA = SPCX mcap / TSLA outstanding`. |
| Illustrative only | Pass | “illustrative market-cap parity only — not a merger announcement, fairness opinion, deal model, or investment advice”; pointer to `DISCLAIMER.md`. |
| Card visibility / defaults | Pass | Hidden only when a required quote leg is missing or guards fail; defaults-only outstanding still shows the card. |
| WASO reject (supporting honesty) | Pass | Weighted-average / EPS share counts rejected for mcap; miss keeps prior/default. |
| Reset reseeds outstanding | Pass | Settings → Reset to defaults reseeds both ownership and outstanding. |

No marketing-site change required for v1 (design §6) — N/A, not present.

**Minor / non-blocking:** Prose uses curly apostrophes (“Musk’s”, “SPCX’s”) while UI title uses ASCII `SPCX's`. Docs-only; does not affect acceptance. `DISCLAIMER.md` still describes share counts as Form 4 only — design Compliance says not to weaken disclaimer and does not require DISCLAIMER edits for outstanding; HOLDINGS is the designated model doc.

---

## Acceptance criteria 1–7 (branch evidence)

| # | Criterion | Verdict | Evidence |
|---|-----------|---------|----------|
| 1 | Typo string exactly `One Trillion Is the Loneliest Number` (product + tests) | Pass | `NetWorthMilestoneTracker.belowTrillionMessage`; `testSadMessageUsesLoneliestNumberCopy` asserts exact string + constant equality. Grep: zero `Lonliest` under `Muskometer/` and `MuskometerTests/`. |
| 2 | Main popover shows merger parity card after stock rows when TSLA+SPCX quotes present and outstanding positive (including defaults-only) | Pass | `PopoverContentView.dataView`: `ForEach` stock rows then `if let presentation = viewModel.mergerParityPresentation { MergerParityCardView(...) }`. Title “If TSLA matched SPCX's market cap”. VM `mergerParityPresentation` uses snapshot prices + settings outstanding. `testPresentationUsesDefaultOutstandingWhenUnset` covers defaults-only. |
| 3 | Implied price = SPCX Class A price × SPCX A+B outstanding / TSLA outstanding; WASO must not overwrite SPCX default | Pass | `MergerMarketCapParity.presentation`: `spcxMarketCap = spcxPrice * spcxShares`; `impliedTSLAPrice = spcxMarketCap / tslaShares`. Unit happy-path + realish-orders tests. `testWASOOnlyReturnsNil` → resolver nil (does not accept WASO). HOLDINGS documents A+B and WASO reject. |
| 4 | Form 4 ownership sync completes/applies without depending on companyfacts | Pass | Orthogonal outstanding path; `testOutstandingAppliedAfterForm4FailureWithoutChangingMessage` (outstanding applies when Form 4 fails); `testOutstandingEmptyResultDoesNotChangeDefaultsOrForm4SuccessMessage` (Form 4 success when outstanding empty). HOLDINGS: independent paths / best-effort outstanding. |
| 5 | `resetToDefaults()` reseeds outstanding to bundled constants; ownership keys separate | Pass | `testResetToDefaultsReseedsOutstanding`; `testSetGetRoundTripIndependentOfShareCount` (keys `sharesOutstanding_*` vs `shareCount_*`). HOLDINGS reset sentence. |
| 6 | Unit tests: resolver (TSLA-style, WASO-only reject, multi-member sum), calculator guards, typo, outstanding key independence | Pass | `CompanyFactsOutstandingResolverTests`: single EntityCommon, multi-member same-end sum, WASO-only nil, form preference 10-Q, us-gaap fallback, invalid JSON. `MergerMarketCapParityTests`: happy path, zero/negative, non-finite. Typo + settings independence tests above. |
| 7 | HOLDINGS documents issuer outstanding vs Form 4 and dual-class mcap | Pass | Section + dual-class + formula (table above). |

---

## Verification WHAT / HOW / WHO

| Dimension | Plan requirement | Evidence on branch | Verdict |
|-----------|------------------|--------------------|---------|
| **WHAT** | Acceptance 1–7 | Mapping table above; feature code + tests present | Satisfied |
| **HOW** | `export MUSKOMETER_SKIP_LIVE_YAHOO=1; ./scripts/verify.sh` (or typecheck + xcodebuild test); 0 failures | `build/verify-derived-87263/` matches `scripts/verify.sh` derived-data naming (`verify-derived-$$`). `Logs/Test/LogStoreManifest.plist` for `Test-Muskometer-2026.08.08_00-02-30--0400.xcresult`: **totalNumberOfTestFailures = 0**, **totalNumberOfErrors = 0**, analyzer issues 0; 3 warnings (non-failing). Debug + tests products under that derived path. | Satisfied (green unit-test gate) |
| **WHO** | Task 7 implementer | Verification artifacts under worktree build tree from in-plan HOW | Satisfied by presence of artifacts |

Live Yahoo step may have been skipped via plan-allowed `MUSKOMETER_SKIP_LIVE_YAHOO=1`; acceptance-relevant gate is typecheck/unit tests, which the xcresult and derived path support.

---

## Findings

### Blocking

None.

### Non-blocking / notes

1. HOLDINGS curly apostrophes vs UI ASCII apostrophe — cosmetic docs/UI inconsistency only.  
2. DISCLAIMER.md not updated for issuer outstanding — out of Task 7 scope per design Compliance (HOLDINGS is the model doc; do not weaken DISCLAIMER).  
3. Test LogStore reports 3 warnings with status `W` — not failures; does not block acceptance.  
4. Plan commit message (“Document issuer outstanding for merger parity; verify build and tests”) is process; not re-verified as a separate gate for content compliance.

---

## Verdict

**PASS** — HOLDINGS.md meets design §6 and acceptance #7; branch evidence supports acceptance criteria 1–6; verification WHAT/HOW/WHO satisfied by green unit-test results under `build/verify-derived-87263` and matching product code/tests.

VERDICT: APPROVED

## Reviewed files

- `docs/HOLDINGS.md` — issuer outstanding vs Form 4; dual-class; formula; illustrative; defaults/reset/WASO  
- `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md` §6 Docs, Compliance, Acceptance 1–7  
- `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 7 (WHAT/HOW/WHO)  
- `docs/DISCLAIMER.md` — unchanged posture (context only)  
- `Muskometer/Services/NetWorthMilestoneTracker.swift` — Loneliest string  
- `Muskometer/Utilities/IssuerSharesOutstanding.swift` — bundled defaults / keys  
- `Muskometer/Utilities/MergerMarketCapParity.swift` — parity formula  
- `Muskometer/Views/PopoverContentView.swift` — card after stock rows  
- `Muskometer/Views/MergerParityCardView.swift` — title copy  
- `Muskometer/ViewModels/GainsViewModel.swift` — presentation wiring  
- `MuskometerTests/MuskometerTests.swift` — resolver, calculator, settings, VM, typo tests  
- `scripts/verify.sh` — HOW command contract  
- `build/verify-derived-87263/Logs/Test/LogStoreManifest.plist` — 0 test failures / 0 errors

VERDICT: APPROVED
