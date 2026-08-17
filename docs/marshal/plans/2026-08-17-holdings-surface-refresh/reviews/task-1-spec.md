Task 1 (SPCX calculator: options in, remarks out) matches Design §1’s sellable-ownership rule and acceptance criterion 5. Reviewed the calculator and tests at HEAD `5949b71` as the full Task 1 product (parent `9936d4b` plus this dispatch’s docstring and leftover aggregator expectation), not only the last delta.

What landed correctly

- `classAEquivalentShares` now counts any `securityTitle` containing `"option"` as 1:1 Class A-equivalent shares (`SPCXOwnershipCalculator.swift:38`). The live title `Option to Buy (Class B Common Stock)` and the synthetic title `Option to Buy` both count. Strike is not subtracted.
- `restrictedShares(from:)` is gone. Remarks are not parsed. `Muskometer/` has zero remaining `restrictedShares` references.
- `testAggregatesJune2026Form4Holdings` mirrors the live June 17 Form 4 shape: existing Class A/B last-row holdings, later By Trust Class A `0`, `Option to Buy (Class B Common Stock)` at `350000000`, remarks `1302072285` still present. Expected total is `5_116_475_230` (`4_766_475_230` tables + `350_000_000` options; remarks not added).
- Focused tests exist: `testOptionTitleCountsUnderlyingShares` (`Option to Buy` / `100` → `100`) and `testRemarksPerformanceSharesAreNotAdded` (Class A `1000` + remarks 1.302B → `1000`).
- Last-row-wins per `(title, nature)` and preferred ×50 are unchanged. Preferred leftover rows stay 0-contribution on this filing.
- Leftover `Form4OwnershipParserTests.testSPCXUsesOwnershipAggregatorNotSingleRow` now expects `1_007_402_770` (7,402,770 + 1e9 Class B; remarks 500M not added). That is the same calculator rule, not a new product path.
- Seeds / `migrateStoredShareCount` still use `6_068_734_060`. That is Task 4, correctly left alone.

Plan wording vs implementation

The plan step said delete `if title.contains("option") { return 0 }` and fall through to the Class B matcher, plus still count a class-less `Option to Buy`. HEAD keeps the option branch and returns `shares`. That is a considered improvement: it is the spec table (`securityTitle` containing `"option"` → count) and is the only way the required synthetic title works. Confirm the invert was deliberate; do not revert it to a delete-only change.

Next-request: `totalPublicShares(from:)` is a pure function. `Form4OwnershipParser` SPCX path calls it on each parse. Retry, replay, and concurrent syncs over the same XML all see `5_116_475_230` (or the table+options total of that XML), never a remarks-inflated or option-zeroed figure. No persisted calculator state, so no TTL/freshness hazard.

No missing §1 calculator requirements, no extra product work, no misunderstood rule.

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
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-1-description.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-1-summary.md
- Muskometer/Utilities/SPCXOwnershipCalculator.swift
- MuskometerTests/MuskometerTests.swift
- Muskometer/Services/Form4OwnershipParser.swift
- Muskometer/Utilities/SPCXHoldings.swift
- Muskometer/Models/TrackedPersonProfile.swift

reviewed-content-sha256: 47a7cc94dcd6fd1e66e13f6ab7cd3b985142e93398791b138b9cba7769cebd3b

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
