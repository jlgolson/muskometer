# Task 3 Code Quality Review — Issuer outstanding Cursor bump + remigration

Reviewed the Task 3 product at HEAD `866381fbdce8d33089ee253190285e96ada2e2db` (base `1a7bc5787ff19f5deaebd589a4bab6f31ecf247c`): `defaultSPCX` Cursor bump, `migrateStoredOutstanding`, `loadSharesOutstanding` persist-if-changed remigration, and `IssuerSharesOutstandingTests` coverage.

## Strengths

The change is a small, exact-integer seed + remigration on the existing outstanding path. `defaultSPCX` is the planned sum `13_181_779_945 + 389_289_254` (`13_571_069_199`). The comment names both accessions, the Class A/B split (`8_085_582_923` + `5_485_486_276`), Cursor 8-K item (i) `389_289_254`, and the exclusion of item (ii) `1_752_426`. TSLA stays `3_949_547_394`. Ownership keys, `SPCXHoldings`, and Form 4 parsing are untouched.

`migrateStoredOutstanding` is a pure helper next to the enum. It remigrates only the prior bundled SPCX fingerprint and passes everything else through. `loadSharesOutstanding` copies the live share-count persist-if-changed pattern: parse a stored positive `Int64`, remigrate, write only when the integer changes, keep the migrated value in memory. Missing keys are not written; `sharesOutstanding(for:)` still falls back to the bundled default.

Tests pin the new default, helper rewrite / pass-through (including lowercase `spcx` and a TSLA value equal to the SPCX fingerprint), load-path rewrite + persist, and missing-key fallback. `testRealishOrdersOfMagnitude` already reads `defaultSPCX`, so the calculator stays coupled to the constant rather than a stale literal.

## Plan alignment

Planned functionality landed in the three named files. Approach matches the architecture: helper on `IssuerSharesOutstanding`, remigration inside `loadSharesOutstanding`, no new compile unit.

Two small deviations from the step sketch, both considered improvements:

- The helper compares against `legacySPCXCoverDefault` and returns `defaultSPCX` instead of repeating the two literals. Same single-source style as `SPCXHoldings.migrateStoredShareCount`.
- The load loop remigrates every stored positive outstanding through the symbol-aware helper, rather than a SPCX-only branch like `loadShareCounts`. Persist still runs only when the integer changes, so TSLA and custom SPCX values are no-ops.

Do not rewrite either to the more literal plan sketch. Confirming they were deliberate is unnecessary: the tests cannot pass unless the helper is both symbol-gated and exact-integer.

HOLDINGS.md is Task 7; leaving it stale here is correct.

## File organization

No new files or types. `legacySPCXCoverDefault` sits under `defaultSPCX`. The helper is the last member of the enum. The load-path edit is a four-line swap inside the existing `value > 0` parse. New tests sit at the end of `IssuerSharesOutstandingTests`, before `MergerMarketCapParityTests`.

## Tests

Coverage matches the behavior that matters:

| Requirement | Where |
|-------------|--------|
| New bundled `13_571_069_199`; TSLA unchanged | `testBundledDefaultsAndKeys` |
| Stored `13_181_779_945` → `13_571_069_199` (incl. `spcx`) | `testMigrateStoredOutstandingRewritesPriorSPCXCoverDefault` |
| Custom / already-new / TSLA-with-legacy-int pass through | `testMigrateStoredOutstandingLeavesOtherValues` |
| Load remigrates SPCX and persists; TSLA override stays | `testLoadRemigratesPriorSPCXCoverOutstandingAndPersists` |
| Missing key → new default, no write | `testMissingOutstandingKeyReturnsNewBundledDefault` |

`testLoadRemigrates…` seeds UserDefaults *before* `AppSettings` init (it cannot use `makeSettings()`, which constructs immediately). That is the right isolation. `testMissingOutstandingKeyReturnsNewBundledDefault` overlaps `testDefaultsReturnedWhenNoKeySet`; the plan asked for the missing-key case explicitly, and the new test also asserts the keys stay nil.

A custom SPCX `8_888_888_888` is proven on the helper, not on a second `AppSettings` load. That is enough: persist-if-changed is a `!=` on the helper result, and the load test already proves the write path for a real rewrite.

## Clarity and patterns

Names read as the existing outstanding vocabulary (`defaultSPCX`, `migrateStoredOutstanding`, `legacySPCXCoverDefault`). Persistence still uses `String(Int64)` under `sharesOutstanding_<SYM>`, independent of `shareCount_*`. The helper uppercases the symbol; the load path already normalizes, so the extra `uppercased()` is harmless and keeps the helper safe if called directly.

Comments earn their keep: the default documents the 8-K bump and the excluded item; the helper docstring states exact-fingerprint remigration. No new I/O, no companyfacts / 8-K parse, no ownership coupling.

## Next-request / round-trip

Idempotent after the first rewrite. Target `13_571_069_199` is not a legacy fingerprint, so a second `AppSettings` init parses the new decimal, `migrated == value`, and skips the write. `String(Int64)` ↔ `Int64(String)` is bijective on this domain. Missing keys stay missing. `resetToDefaults` still reseeds via `defaultOutstanding`, which now returns the Cursor total. A later companyfacts hit or a test override is left alone.

## Assessment

Ready to merge on quality. Organization, tests, naming, and the surrounding remigration pattern are sound. Ownership and TSLA outstanding were not rewritten.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- Muskometer/Utilities/IssuerSharesOutstanding.swift
- Muskometer/Utilities/AppSettings.swift
- MuskometerTests/MuskometerTests.swift
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-3-description.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-3-summary.md
- docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md

reviewed-content-sha256: 21d85c8cab90fba9b7ff13db52320abe007031f358d5dcb5f68519af9f1d7b30

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
