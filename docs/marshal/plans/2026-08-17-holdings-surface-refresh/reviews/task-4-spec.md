Task 4 (Ownership seeds and fingerprint remigration) matches Design §1 seeds/migration, acceptance criteria 1–3 (ownership half), and the upgrade/persisted-state contract for ownership. Reviewed `SPCXHoldings`, `TrackedPersonProfile.musk` holding specs, `AppSettings.loadShareCounts`, and `SPCXHoldingsTests` / seed asserts at HEAD `36799e97` as the full Task 4 product.

What landed correctly

- Dual SPCX seeds are the same sellable integer: `SPCXHoldings.defaultShareCount` and musk SPCX `defaultShareCount` are both `5_116_475_230`. Comment names June 17 Form 4 tables + vested 350M options and excludes remarks performance RSUs. TSLA has no parallel enum; musk TSLA `defaultShareCount` is the single seed `710_172_677` (Form 4 last direct common).
- `migrateStoredShareCount` treats as legacy and returns `defaultShareCount`: `60_685_475`, `842_091_670`, `7_402_770`, `6_068_547_515`, and the inverted prior bundled `6_068_734_060`. `5_116_475_230` is not a case. Unknown `6_068_547_514` and any other stored integer pass through. 13G `6_418_547_515` is not a fingerprint.
- `AppSettings.loadShareCounts` remigrates SPCX through that helper (persist-if-changed). New TSLA branch remigrates stored `699_580_882` to `spec.defaultShareCount` (`710_172_677`) with the same persist-if-changed pattern. Any other stored TSLA count stays. Missing keys are not written; `shareCount(for:)` falls back to the spec defaults. `resetToDefaults` reseeds both via `spec.defaultShareCount`.
- `migrateLegacyShareCounts` is still the one-shot old-key copy. SPCX remigrates on that copy via the helper; TSLA copies then remigrates on the load path. That is the spec rule (“not only the one-shot”).
- Tests cover the plan cases: helper migrate of every listed fingerprint (including standalone `7_402_770` and inverted `6_068_734_060`); helper pass-through of `5_116_475_230` and `6_068_547_514`; AppSettings rewrite of stored `6_068_547_515` to `SPCXHoldings.defaultShareCount`; TSLA stored `699_580_882` → `710_172_677` + persist; stored `710_172_677` and `123_456` stay; empty suite → TSLA `710_172_677`. Seed asserts in `testDefaultShareCounts`, outstanding reset, and outstanding-sync ownership-unchanged now expect `710_172_677` / `5_116_475_230`.
- CurrencyFormatter / paper-gain `699_580_882` left as math fixtures. Form 4 last-row XML, `ShareCountTextInput`, and `ShareImageExporter` samples that reuse the old integers are the same class of fixture, not seed paths. Calculator / outstanding / HOLDINGS.md were not rewritten (Tasks 1, 3, 7).

Plan wording vs implementation

The plan step said remigrate TSLA when stored equals `699_580_882`. HEAD inlines that compare and writes `spec.defaultShareCount` rather than a second `710_172_677` literal. That is a considered improvement: one source of truth, same shape as SPCX returning `defaultShareCount`. Confirm it was deliberate; do not split a TSLA helper or duplicate the new seed.

`PortfolioHolding.defaults` still hardcodes TSLA `699_580_882`. Spec current-architecture names the seeds as the musk holding specs + `SPCXHoldings.defaultShareCount`; `AppSettings.holdings` builds from those. The static is unused. Not a seed or remigration path; leave it for a later cleanup if desired.

Next-request: remigration is a pure exact-integer rewrite on `AppSettings` init. Retry, replay, and a second init after persist all see `5_116_475_230` / `710_172_677` and do not rewrite again (targets ∉ legacy set; TSLA compare is `== 699_580_882` only). A later Form 4 or a manual override is left alone. Missing keys stay missing and the getter returns the new spec defaults. No TTL/freshness window. Fingerprint-only overreach of a user who typed an old default is the accepted spec risk. Old-binary rollback may still lift stored `6_068_547_515` up to `6_068_734_060`; stored `5_116_475_230` / `710_172_677` stay.

No missing §1 seed/migration requirements, no extra product work, no 13G or table-only leakage into the fingerprint set.

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
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-4-description.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-4-summary.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-4-round-1-quality-diff
- Muskometer/Utilities/SPCXHoldings.swift
- Muskometer/Models/TrackedPersonProfile.swift
- Muskometer/Utilities/AppSettings.swift
- MuskometerTests/MuskometerTests.swift
- Muskometer/Models/PortfolioHolding.swift

reviewed-content-sha256: 522ced397bf3aa1d06de84590e886b55c794b00ea1cf81728583294f2be82863

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
