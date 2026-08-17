Task 6 (Drop unused currentTSLAPrice) matches Design §6’s dead-field rule and acceptance criterion 10. Reviewed the presentation struct, calculator construction, card preview, and the three passthrough asserts at HEAD `d396a5d1` as the full Task 6 product.

What landed correctly

- `MergerParityPresentation` is three fields: `impliedTSLAPrice`, `tslaMarketCap`, `spcxMarketCap`. `currentTSLAPrice` is gone (`MergerMarketCapParity.swift:4-8`). `Equatable, Sendable` stay.
- `presentation(...)` still takes `tslaPrice` (needed for `tslaMarketCap = tslaPrice * tslaShares`) and no longer copies it onto the struct (`MergerMarketCapParity.swift:44-48`). Guard rules are unchanged: non-finite or ≤ 0 inputs, or a non-finite / ≤ 0 implied, still return `nil`.
- `MergerParityCardView` preview constructs the three-field struct only. The card body never read `currentTSLAPrice`; it still shows implied price plus the `SPCX $X · TSLA $Y` mcap caption.
- The three named asserts are gone: `MergerMarketCapParityTests.testHappyPathImpliedEqualsSPCXMarketCapOverTSLAShares`, `testRealishOrdersOfMagnitude`, and `GainsViewModelMergerParityPresentationTests.testPresentationUsesSnapshotPricesAndSettingsOutstanding`. Remaining asserts still pin implied + both mcaps. The default-outstanding VM case still `XCTAssertEqual`s the full presentation against `MergerMarketCapParity.presentation(...)`.
- `Muskometer/` and `MuskometerTests/` have zero `currentTSLAPrice` / `currentTSLA` strings. The only two `MergerParityPresentation(` constructions are the calculator return and the DEBUG preview. `GainsViewModel.mergerParityPresentation` still forwards snapshot prices + settings outstanding into `presentation(...)`; it never read the dropped field.
- `docs/ARCHITECTURE.md` has no `currentTSLA` mention. CHANGELOG / version tick of the drop is Task 9. Historical `2026-08-07-tsla-spcx-merger-card` design still names the field as then-shipped; that is a prior cycle, not a live product leftover.

Plan wording vs implementation

The plan said grep `currentTSLAPrice` — zero remaining. HEAD is zero in product and tests. Remaining hits are this cycle’s spec/plan (the work description) and prior-cycle marshal docs. That is the intended grep scope; do not rewrite the 2026-08-07 design to match today’s struct.

No considered divergence from Design §6. The calculator signature was not narrowed; dropping the unused output field and leaving the `tslaPrice` input is the spec.

Next-request: `presentation(...)` is a pure function over four arguments. Retry, replay, and concurrent card/VM reads of the same snapshot all see the same three-field value (or `nil`). No persisted presentation state and no freshness window, so no TTL hazard. Binary revert would restore the unused field; nothing in UserDefaults depends on it.

No missing §6 dead-field requirements, no extra product work, no leftover passthrough.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-6-description.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-6-summary.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-6-round-1-quality-diff
- Muskometer/Utilities/MergerMarketCapParity.swift
- Muskometer/Views/MergerParityCardView.swift
- Muskometer/ViewModels/GainsViewModel.swift
- MuskometerTests/MuskometerTests.swift

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130

reviewed-content-sha256: a97444f220d39a60a0c94fe7674949dd1ec7cbbce510129bd6125eca6606a70a

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
