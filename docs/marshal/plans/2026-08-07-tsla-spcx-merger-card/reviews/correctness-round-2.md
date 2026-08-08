# Plan correctness review — round 2

**Role:** plan-correctness  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md`  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md`  
**Date:** 2026-08-07  
**Context:** Independent fresh re-read after Task 4 form-preference unit test was made **Required** (was “if easy; else document” in the round-1 plan snapshot).

## Scope checked

File paths against current tree, type consistency, placeholders, task ordering, full Goals/Design §§1–6/Error handling/Testing/Acceptance coverage, form-preference test requirement, verification WHAT/HOW/WHO, pbxproj ID free range, source hooks (`syncHoldingsFromSEC`, `dataView`, `resetToDefaults`, `HoldingGain.quote.currentPrice`), and deferral discipline.

## Round-1 gap closure

| Prior soft gap | Current plan |
|----------------|--------------|
| T4 form-preference fixture optionalized vs design **Testing** “latest selection by `(end, filed)` **and form preference**” | T4 step now: “**Required:** Prefer 10-Q/10-K form rows over older non-preferred forms when both present (assert the 10-Q value wins even if a non-preferred row has a later `filed` or competing `end` per resolver rules).” |

Behavior was already mandated in resolver rules; test optionality was the only Testing-section miss. **Closed.**

## Systematic checklist

### File paths

| Plan path | Status |
|-----------|--------|
| `Muskometer/Services/NetWorthMilestoneTracker.swift` | Exists; `belowTrillionMessage` still `Lonliest` as T1 target |
| `MuskometerTests/…` `testSadMessageUsesLonliestNumberCopy` | Present; rename/assert planned |
| `Muskometer/Utilities/AppSettings.swift` | Exists; ownership `shareCount_*` + `resetToDefaults` / `applyHoldingsSync` patterns match T2 isolation |
| `Muskometer/Models/TrackedPersonProfile.swift` | Two `TrackedHoldingSpec(...)` sites (TSLA/SPCX); `issuerCIKPadded` extension site correct |
| `Muskometer/ViewModels/GainsViewModel.swift` | `syncHoldingsFromSEC` + `snapshot` / `HoldingGain.quote.currentPrice` match T5 |
| `Muskometer/Views/PopoverContentView.swift` | `dataView` ForEach stock rows then error caption — T6 insert site correct |
| `Muskometer/Services/SECHoldingsSyncService.swift` | User-Agent + ~120ms delay match T5 |
| `Muskometer.xcodeproj/project.pbxproj` | Highest product source IDs `…46`; plan `…50`–`…54` free/unique |
| `docs/HOLDINGS.md` | Exists; T7 target |
| New Utilities/Services/Views files | Layout consistent with existing module |

### Type consistency

- `MergerParityPresentation` fields match spec §4.
- Formula: `spcxPrice × spcxOutstanding / tslaOutstanding` with Class A Yahoo × A+B default for SPCX — matches Goals/§3.
- Happy-path test (100/50, 2/4 → implied 100) arithmetically correct.
- Outstanding keys `sharesOutstanding_SYMBOL` distinct from ownership `shareCount_SYMBOL`.
- Presentation uses quote prices only; does not misuse Musk `shareCount` as company outstanding.
- Bundled defaults exact: TSLA `3_949_547_394`, SPCX `13_181_779_945` + accession comments.

### Placeholders

- No TBD/TODO/FIXME in task steps.
- Calculator body intentionally sketched with comments; guards and formula complete.
- Resolver rules complete: concept priority, shares unit, WASO reject, form preference, max `(end, filed)`, multi-member sum, nil on bad JSON.

### Task ordering

```
1 → 2 → (3 ∥ 4) → 5 → 6 → 7
```

Matches foundation → pure layers → wiring → UI → verify. T4 no longer soft-skips a Testing requirement.

### Spec coverage map

| Spec | Plan |
|------|------|
| §1 Typo | T1 |
| §2 Defaults, CIKs, keys, reset, WASO reject, multi-member, form preference, latest end/filed | T2, T4 (form-preference test **Required**), T5 |
| §3 Calculator | T3 |
| §4 VM presentation; defaults-only show | T5 |
| §5 UI after stock rows | T6 |
| §6 HOLDINGS | T7 |
| Error table / Form 4 independence | T5 (never-throw fetch; silent outstanding; try outstanding even after Form 4 throw) |
| Testing matrix (incl. form preference) | T1–T4; T4 form preference Required |
| Acceptance 1–7 | T7 WHAT + prior tasks |
| Non-goals | Deferred None; not in task bodies |

### Verification (WHAT / HOW / WHO)

- **WHAT:** AC 1–7 explicit.
- **HOW:** `MUSKOMETER_SKIP_LIVE_YAHOO=1 ./scripts/verify.sh` (script exists; typecheck + xcodebuild test) with typecheck/test fallback.
- **WHO:** Task 7 implementer.

### Imports / pbxproj

- App module only; tests `@testable import Muskometer`.
- Five new files with unique IDs `50`–`54`; PBXBuildFile + FileReference + group + Sources entry specified.

### Deferral discipline

- Deferred: None (matches design).
- Reverse parity, HTML 10-Q, manual outstanding UI, Yahoo mcap not smuggled into tasks.
- Optional observability / concept-metadata captions correctly omitted.

## Non-blocking notes (do not block execute)

- Multi-member sum: plan sums same `(end, filed)` pair; design multi-class prose says sum same `end` for the chosen latest instant. Same-filing dual-class rows match; residual edge if members share `end` with divergent `filed` is rare and SPCX primary path remains cover-derived default when companyfacts multi-class is untrustworthy.
- T3/T4 Depend on 2 though pure types do not need AppSettings — conservative gate, fine.
- T4 does not list a separate pure “two preferred-form rows, later `end` wins” fixture beyond the required form-preference case; form-preference assertion with competing later non-preferred `filed`/`end` plus rules still satisfy design Testing spirit and AC6.
- Outstanding-only update without a subsequent quote refresh may defer card number refresh until next snapshot cycle — acceptable for daily SEC cadence.

## Findings

None.

## Findings (machine-readable)

```json
{
  "schema_version": 1,
  "round": 2,
  "role": "plan-correctness",
  "plan_slug": "2026-08-07-tsla-spcx-merger-card",
  "verdict": "APPROVED",
  "prior_gap_closed": [
    "T4 form-preference unit test made Required (was optionalized vs design Testing)"
  ],
  "findings": []
}
```

VERDICT: APPROVED
