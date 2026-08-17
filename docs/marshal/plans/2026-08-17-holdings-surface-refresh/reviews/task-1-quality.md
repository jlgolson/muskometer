# Task 1 Code Quality Review — SPCX calculator: options in, remarks out

Reviewed the full Task 1 product at HEAD `5949b71c516ed23af246f7d2930cc1d26a2c9f8c`: parent commit `9936d4b` (options counted, remarks RSUs ignored, June 2026 fixture + two focused tests) plus this dispatch’s docstring and leftover `Form4OwnershipParserTests` expected-value fix.

## Strengths

The calculator stays a single pure enum with one public entry point. Options are counted by an explicit `title.contains("option")` → `shares` branch, remarks are ignored by deleting the `restrictedShares` addend, and last-row-wins per `(title, nature)` is unchanged. That matches Design §1 sellable-ownership without touching Task 4 seeds (`6_068_734_060` left in `SPCXHoldings` / profile / migration tests).

Tests exercise the real XML path, not mocks. The June 2026 fixture includes the live-shaped later By Trust `0`, `Option to Buy (Class B Common Stock)` at `350_000_000`, and the remarks 1.302B paragraph, and expects `5_116_475_230`. `testOptionTitleCountsUnderlyingShares` uses a class-less `Option to Buy` title so the option rule is proven independently of the Class B substring. `testRemarksPerformanceSharesAreNotAdded` locks the deleted remarks addend. The leftover parser aggregator assert is now `7_402_770 + 1_000_000_000 = 1_007_402_770` with a comment that matches the new rule.

The type-level docstring now states vested option underlying shares in and remarks performance/restricted awards out. `restrictedShares` is gone from `Muskometer/`.

## Plan alignment

Plan step said delete `if title.contains("option") { return 0 }` and let Class B in the live title fall through, then still return `shares` for a synthetic `Option to Buy` with no class. The implementation keeps an option check but inverts it to `return shares` and places it first. That is a considered improvement, not a shortcut: one branch encodes “option underlying counts 1:1,” covers both the live Class B option title and the class-less synthetic title, and avoids implying options only count because the title happens to contain `class b common`. Confirming it was deliberate is unnecessary — `testOptionTitleCountsUnderlyingShares` cannot pass without a positive option path.

Updating `testSPCXUsesOwnershipAggregatorNotSingleRow` is slightly ahead of Task 10’s residual-suite note and is the right leftover fix for a calculator that no longer adds remarks.

## File organization

No new files. Change is confined to `SPCXOwnershipCalculator.swift` and the existing `SPCXOwnershipCalculatorTests` / `Form4OwnershipParserTests` in `MuskometerTests.swift`. Public API and `Form4OwnershipParser` delegation are unchanged. Growth is a few fixture rows, two small tests, a docstring, and one expected integer.

## Tests

Coverage matches the behavior that matters: live last-row-wins + option + remarks-ignore, option-only, remarks-only-not-added, and the parser’s aggregator contract. Existing last-row / full-disposal / preferred ×50 cases still pin the rest of the calculator. Seeds that still expect `6_068_734_060` belong to Task 4 and were correctly left alone.

## Clarity and patterns

Names still describe sellable Class A-equivalent totals. Title matching stays `contains` on a lowercased security title — the same pattern as Class A / Class B / preferred. Deleting `restrictedShares` is the existing “do not invent a second parser” path. Pure function, no persistence, no I/O.

## Next-request / round-trip

N/A. `totalPublicShares(from:)` is a pure XML → `Int64?` fold. Same input yields the same total; empty/zero buckets still return nil. Nothing is written for a later request to reread.

## Assessment

Ready to merge on quality. Organization, tests, naming, and surrounding patterns are sound. The option-first `return shares` branch is clearer than the plan’s fall-through sketch and is covered.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- Muskometer/Utilities/SPCXOwnershipCalculator.swift
- MuskometerTests/MuskometerTests.swift
- Muskometer/Services/Form4OwnershipParser.swift
- docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md

reviewed-content-sha256: 47a7cc94dcd6fd1e66e13f6ab7cd3b985142e93398791b138b9cba7769cebd3b

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
