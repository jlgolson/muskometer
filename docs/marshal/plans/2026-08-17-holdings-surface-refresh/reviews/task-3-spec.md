Task 3 (Issuer outstanding Cursor bump + remigration) matches Design §2, acceptance criteria 1 (outstanding half) and 4, and the upgrade/persisted-state contract for outstanding. Reviewed `IssuerSharesOutstanding`, `AppSettings.loadSharesOutstanding`, and `IssuerSharesOutstandingTests` at HEAD `866381f` as the full Task 3 product.

What landed correctly

- `defaultSPCX` is the pinned expression `13_181_779_945 + 389_289_254`. That sum is **13,571,069,199** (`7_696_293_669 + 389_289_254 = 8_085_582_923`; `+ 5_485_486_276 = 13_571_069_199`). `testBundledDefaultsAndKeys` pins the integer.
- Comment names both accessions (10-Q `0001628280-26-052535`, Cursor 8-K `0001628280-26-056945` item (i) Class A `389_289_254`), the new Class A/B split (`8_085_582_923` + `5_485_486_276`), and explicitly excludes item (ii) `1_752_426`. Item (iii) assumed unvested RSUs/options are not present. No 8-K HTML parser.
- TSLA `defaultTSLA` stays `3_949_547_394`. Unknown symbols still return `nil` / getter `0`.
- `migrateStoredOutstanding` remigrates **only** stored `13_181_779_945` for SPCX to `defaultSPCX`. Any other positive stored value passes through, including the new default, a test override `8_888_888_888`, and the old cover integer on **TSLA**. Missing `sharesOutstanding_*` keys are not written; `sharesOutstanding(for:)` falls back to the new bundled default.
- `AppSettings.loadSharesOutstanding` remigrates after a stored positive parse and persists only when the integer changes — same pattern as SPCX share-count remigration. Ownership `shareCount_*` / Form 4 paths are untouched (reset still expects Task-4 seeds `699_580_882` / `6_068_734_060`).
- Tests cover the plan cases: helper rewrite (including `spcx`), helper pass-through, load remigrate + persist of `sharesOutstanding_SPCX` while leaving a custom TSLA outstanding, missing key → new default. Existing reset/round-trip/non-positive tests now ride `defaultSPCX`.
- No new compile unit. Helper lives on `IssuerSharesOutstanding` as spec §7 preferred. HOLDINGS.md still shows the pre-Cursor cover total; that is Task 7, not this dispatch.

Plan wording vs implementation

The plan step said `if symbol == "SPCX"` and return the integer literal `13_571_069_199`. HEAD uppercases the symbol and returns `defaultSPCX` against `legacySPCXCoverDefault`. That is a considered improvement: it matches `defaultOutstanding(for:)`, keeps one source of truth for the new total, and follows the `SPCXHoldings` legacy-constant pattern. Confirm it was deliberate; do not tighten the compare to a case-sensitive `"SPCX"` or duplicate the sum.

Next-request: remigration is a pure exact-integer rewrite on `AppSettings` init. Retry, replay, and a second init after persist all see `13_571_069_199` and do not rewrite again (target ∉ legacy set). A later companyfacts/manual positive outstanding is left alone. No TTL/freshness window; no Form 4 coupling. Fingerprint-only overreach of a user who typed the old cover default is the accepted spec risk.

No missing §2 outstanding requirements, no extra product work, no item (ii)/(iii) leakage.

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
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-3-description.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-3-summary.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-3-round-1-quality-diff
- Muskometer/Utilities/IssuerSharesOutstanding.swift
- Muskometer/Utilities/AppSettings.swift
- MuskometerTests/MuskometerTests.swift

reviewed-content-sha256: 21d85c8cab90fba9b7ff13db52320abe007031f358d5dcb5f68519af9f1d7b30

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
