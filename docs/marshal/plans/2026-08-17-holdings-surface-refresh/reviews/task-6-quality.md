# Task 6 Code Quality Review — Drop unused currentTSLAPrice

Reviewed the Task 6 product at HEAD `d396a5d1fd2391d77893fccd44c5b7354bde0050` (base `d09f58ad9ed14e11786c71a9668df09b94db1936`): `currentTSLAPrice` removed from `MergerParityPresentation`, from `presentation(...)` construction, from the card preview, and from the three passthrough asserts.

## Strengths

The cut is closed. The struct is three fields — `impliedTSLAPrice`, `tslaMarketCap`, `spcxMarketCap` — `Equatable` and `Sendable` unchanged. `presentation(...)` still takes `tslaPrice` because it is the input to `tslaMarketCap`; it no longer echoes that quote onto the DTO. Grep of `Muskometer/` and `MuskometerTests/` for `currentTSLAPrice` is empty.

The card never read the field. Caption stays `SPCX … · TSLA …` from the two market caps. Preview memberwise init dropped the extra argument and nothing else. `GainsViewModel.mergerParityPresentation` is untouched: snapshot quotes + settings outstanding still flow into the same calculator signature.

Tests keep the behavior that matters. Happy-path and realish cases still pin implied + both mcaps. The VM case still `XCTAssertEqual`s the whole presentation against a calculator result, so Equatable covers the remaining fields without a passthrough assert.

## Plan alignment

Planned functionality landed in the three named files. Approach matches Design §6 / AC10: delete the dead field, do not invent replacement contrast copy.

No product deviation. Marshal plan/spec/reviews still name `currentTSLAPrice` (the work to do / the CHANGELOG bullet for Task 9). That is correct — the plan’s “grep zero remaining” is a product/test check, not a rewrite of the planning docs. CHANGELOG / version tick stay Task 9.

## File organization

No new files or types. The field is deleted rather than deprecated or zeroed. Preview and tests only lose the one argument / three asserts. Calculator guards, formula, and VM wiring are unchanged.

## Tests

Coverage matches the behavior that matters for a deletion task:

| Requirement | Where |
|-------------|--------|
| Field gone from DTO + constructor | `MergerParityPresentation`, `presentation(...)` |
| No product/test references | grep of `Muskometer/` / `MuskometerTests/` |
| Preview compiles without the argument | `MergerParityCardView_Previews` |
| Implied + both mcaps still pinned | `testHappyPath…`, `testRealishOrdersOfMagnitude` |
| VM presentation still matches calculator | `testPresentationUsesSnapshot…`, `testPresentationUsesDefaultOutstandingWhenUnset` |

The plan asked to delete the three passthrough asserts, not to add a “field does not exist” compile test. Remaining cases already fail to compile if the field is reintroduced at a call site that still uses the old memberwise init.

## Clarity and patterns

Names stay in the existing parity vocabulary. `tslaPrice` on the calculator is still the live quote used for TSLA market cap — not a leftover of the dropped field. No new comments. No I/O. Card body and popover placement are unchanged.

## Next-request / round-trip

N/A. The field was never persisted. Same inputs still yield the same implied price and market caps. Nothing for a later request to reread.

## Assessment

Ready to merge on quality. Organization, the closed cut, and the remaining tests match the surrounding deletion pattern. Calculator math and card chrome were not rewritten. Docs mentions left for Task 9 CHANGELOG.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- Muskometer/Utilities/MergerMarketCapParity.swift
- Muskometer/Views/MergerParityCardView.swift
- MuskometerTests/MuskometerTests.swift
- Muskometer/ViewModels/GainsViewModel.swift
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-6-description.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-6-summary.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-6-round-1-quality-diff
- docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md

reviewed-content-sha256: STAMP
plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130

reviewed-content-sha256: a97444f220d39a60a0c94fe7674949dd1ec7cbbce510129bd6125eca6606a70a

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
