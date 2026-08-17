# Task 4 Code Quality Review — Ownership seeds and fingerprint remigration

Reviewed the Task 4 product at HEAD `36799e97f0d01f66c8fdce534ea5d0c2de538e2e` (base `6e8a4152c800763189c0fc582aa6215c518c0c36`): TSLA/SPCX seed rewrite, inverted `SPCXHoldings.migrateStoredShareCount`, TSLA load-path remigration of `699_580_882`, and the matching `SPCXHoldingsTests` / seed-assert updates.

## Strengths

The change is a small, exact-integer seed + remigration on the existing ownership path. Both live seeds moved together: `TrackedPersonProfile.musk` TSLA `710_172_677` / SPCX `5_116_475_230`, and `SPCXHoldings.defaultShareCount` `5_116_475_230`. The default comment is the plan sentence (June 17 tables + vested 350M options; no remarks RSUs). Outstanding, Form 4 parsing, and the calculator are untouched.

`migrateStoredShareCount` now treats `6_068_734_060` as `legacyBundledWithPerformanceRSUs` alongside the four prior fingerprints and returns `defaultShareCount`. `5_116_475_230` is not a case. Named legacy constants keep the historical meaning next to the integers. `loadShareCounts` adds a TSLA persist-if-changed branch that remigrates only `699_580_882` to `spec.defaultShareCount` — same write-if-changed shape as SPCX, on the load path rather than the one-shot `migrateLegacyShareCounts` copy.

Seed asserts in AppSettings reset / no-key / outstanding-sync cases now expect the new defaults. `CurrencyFormatter`, paper-gain math, Form 4 XML fixtures, `ShareCountTextInput`, and `ShareImageExporter` still use `699_580_882` (and the exporter’s SPCX `6_068_734_060`) as arbitrary fixtures. Unused `PortfolioHolding.defaults` was correctly left alone — it is not a seed or remigration path.

## Plan alignment

Planned functionality landed in the four named files. Approach matches the architecture: invert the existing helper, remigrate TSLA inside `loadShareCounts`, no new compile unit.

Two small deviations from the step sketch, both considered improvements:

- TSLA remigration writes `spec.defaultShareCount` instead of repeating `710_172_677`. Same single-source style as `SPCXHoldings.migrateStoredShareCount` / Task 3’s `defaultSPCX`.
- Tests introduce `sellableDefault` and a dedicated `testMigratesLegacyMisparseLastRow` for `7_402_770`. The plan listed that fingerprint; a named case is clearer than folding it into another assert.

Do not rewrite either to the more literal sketch. Confirming they were deliberate is unnecessary: the new default cannot pass unless profile, `SPCXHoldings`, and remigration targets agree.

HOLDINGS.md is Task 7; leaving it stale here is correct.

## File organization

No new files or types. `legacyBundledWithPerformanceRSUs` sits with the other private fingerprints. The TSLA edit is an `else if` next to the existing SPCX branch. New tests sit in `SPCXHoldingsTests` after the SPCX load-path cases, as the plan asked.

## Tests

Coverage matches the behavior that matters:

| Requirement | Where |
|-------------|--------|
| New bundled `5_116_475_230` | `testDefaultShareCountIsSellableOwnership` |
| All five legacy fingerprints → sellable default | `testMigratesLegacyScaledDefault` / `SingleRowParse` / `MisparseLastRow` / `PartialAggregateDefault` / `PriorBundledDefaultWithPerformanceRSUs` |
| Current default + unknown `6_068_547_514` pass through | `testLeavesSellableDefaultAndUnknownUntouched` |
| Load remigrates stored `6_068_547_515` and persists | `testAppSettingsRewritesLegacyFingerprintUnderNewKey` |
| Stored TSLA `699_580_882` → `710_172_677` + persist | `testAppSettingsRewritesLegacyTSLAFingerprintUnderNewKey` |
| Stored current / custom TSLA stay | `testAppSettingsLeavesCurrentTSLADefaultUntouched` / `LeavesCustomTSLAShareCountUntouched` |
| Missing key → new TSLA default | `testEmptySuiteReturnsNewTSLADefault`, `testDefaultShareCounts` |
| Reset reseeds both symbols | `testResetToDefaultsReseedsOutstanding` |

`testEmptySuiteReturnsNewTSLADefault` overlaps `testDefaultShareCounts`; the plan asked for the empty-suite case explicitly. Custom SPCX `6_068_547_514` is still proven on the load path; custom TSLA `123_456` is proven on load + persist. Persist-if-changed for a real rewrite is covered on both symbols.

## Clarity and patterns

Names stay in the existing ownership vocabulary (`defaultShareCount`, `migrateStoredShareCount`, `legacyBundledWithPerformanceRSUs`). TSLA’s single fingerprint is a local `legacyTSLADefault` in `loadShareCounts` — the planned one-fingerprint form, not a second enum. Persistence still uses `String(Int64)` under `shareCount_<SYM>`, independent of outstanding keys.

Comments earn their keep: the default documents sellable ownership; the two newest legacy constants distinguish last-row-wins + remarks vs the prior bundled total. No new I/O, no calculator / outstanding coupling.

## Next-request / round-trip

Idempotent after the first rewrite. Targets `{5_116_475_230, 710_172_677}` are not legacy fingerprints, so a second `AppSettings` init parses the new decimal, `migrated == value`, and skips the write. `String(Int64)` ↔ `Int64(String)` is bijective on this domain. Missing keys stay missing. `resetToDefaults` reseeds via `spec.defaultShareCount`. A later Form 4 or a test override is left alone.

## Assessment

Ready to merge on quality. Organization, tests, naming, and the surrounding remigration pattern are sound. Outstanding and Form 4 parsing were not rewritten. Fixture uses of `699_580_882` were left as arbitrary math / XML / render inputs.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- Muskometer/Utilities/SPCXHoldings.swift
- Muskometer/Models/TrackedPersonProfile.swift
- Muskometer/Utilities/AppSettings.swift
- MuskometerTests/MuskometerTests.swift
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-4-description.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-4-summary.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-4-round-1-quality-diff
- docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130

reviewed-content-sha256: 522ced397bf3aa1d06de84590e886b55c794b00ea1cf81728583294f2be82863

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
