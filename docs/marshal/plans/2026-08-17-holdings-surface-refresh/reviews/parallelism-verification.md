# Parallelism verification

**Role:** parallelism-verifier
**Plan:** `docs/marshal/plans/2026-08-17-holdings-surface-refresh.md`
**Analysis:** `docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/parallelism-analysis.md`
**Date:** 2026-08-17
**Threshold:** `MARSHAL_PARALLELISM_MIN_RATIO` = 0.25

## Hypotheses checked

Before accepting the analysis, the plausible failure modes were: (1) declared graph or ready-set misparsed from `**Depends on:**`; (2) a concurrent pair omitted or a serial pair listed as concurrent; (3) `component_size` counted as edges instead of nodes (or vice versa) so a ratio is actually `< 0.25`; (4) a `VERIFIED` pair that still write-collides (`README.md` vs `docs/README.md`, `verify.sh`, `AppSettings` init); (5) an `UNVERIFIED-UNSAFE` flag that is only a read, not a write; (6) T7’s “already updated for 2028 in Task 2” sentence implying a missing `2→7` edge the analyst treated as mere docs color.

None of those overturn the analysis.

## Graph check

Re-derived from each task body’s `**Depends on:**` line (empty = no deps):

`1:[] 2:[] 3:[] 4:[1] 5:[] 6:[] 7:[3,4,5] 8:[5] 9:[1,2,3,4,5,6,7,8] 10:[9]`

Ready-set `{1, 2, 3, 5, 6}` matches the plan Self-review line. Transitive ancestors match the analyst (4 after 1; 7 after 1 via 4, plus 3/4/5; 8 after 5; 9 after 1–8; 10 after 1–9).

`C(10,2) = 45`. Ancestor–descendant pairs are exactly the 23 listed as serialized. The remaining **22** concurrent pairs are:

`{1,2} {1,3} {1,5} {1,6} {1,8} {2,3} {2,4} {2,5} {2,6} {2,7} {2,8} {3,4} {3,5} {3,6} {3,8} {4,5} {4,6} {4,8} {5,6} {6,7} {6,8} {7,8}`

The analysis lists all 22 and no others.

`component_size` = longest node-count path through that task. Longest path `1→4→7→9→10` (5). Sizes `1:5, 2:3, 3:4, 4:5, 5:4, 6:3, 7:5, 8:4, 9:5, 10:5` recomputed independently. Every concurrent `min/max` is ≥ 0.600. No LOW-VALUE pair. No declared serial edge is a missed opportunity: 4 consumes 1’s seed math and the same test file; 7 cites 3/4 integers and 5’s deletion; 8 is the post-5 popover mock; 9 authors CHANGELOG from the landed diff; 10 verifies the versioned tree.

## Pair-by-pair confirmation

Product writes (plan Files touched, confirmed on disk):

| Task | Product / docs writes |
|------|------------------------|
| 1 | `SPCXOwnershipCalculator.swift` + `MuskometerTests.swift` |
| 2 | `MarketHoursService.swift` + `MuskometerTests.swift` + `docs/ARCHITECTURE.md` |
| 3 | `IssuerSharesOutstanding.swift` + `AppSettings.swift` + `MuskometerTests.swift` |
| 4 | `SPCXHoldings.swift` + `TrackedPersonProfile.swift` + `AppSettings.swift` + `MuskometerTests.swift` |
| 5 | comparison sources + `PopoverContentView.swift` + `GainsViewModel.swift` + `AppSettings.swift` + `project.pbxproj` + `MuskometerTests.swift` |
| 6 | `MergerMarketCapParity.swift` + `MergerParityCardView.swift` + `MuskometerTests.swift` |
| 7 | `SettingsView.swift` + `docs/HOLDINGS.md` + root `README.md` + `docs/PRIVACY.md` + `docs/ARCHITECTURE.md` |
| 8 | `docs/screenshots/*` + `docs/index.html` + `docs/README.md` + `scripts/verify.sh` |

`MuskometerTests.swift` is one XCTest compilation unit. Live class anchors: `MarketHoursServiceTests` L105, `AppSettingsTests` L977 (`testDefaultShareCounts` L988–995), `IssuerSharesOutstandingTests` L1054, `MergerMarketCapParityTests` L1157 (`currentTSLAPrice` L1172 / L1287; `defaultSPCX` L1267–1268), `GainsViewModelMergerParityPresentationTests` L1466 (`currentTSLAPrice` L1504), `GainsViewModelIssuerOutstandingSyncTests` L1537 (seed asserts L1566–1567), `SPCXHoldingsTests` L1945, `SPCXOwnershipCalculatorTests` L1996, comparison suite L3661–3997. `AppSettings.loadShareCounts` L342–365 vs `loadSharesOutstanding` L367+; `resetPersistedState` still calls `ComparisonHistoryStore.resetPersistedState` at L506. `docs/ARCHITECTURE.md` L118–132 is still “2026 and 2027” / “after 2027”.

- `{1, 2}` `{1, 3}` `{1, 5}` `{1, 6}` `{2, 3}` `{2, 4}` `{2, 5}` `{2, 6}` `{3, 6}` `{4, 6}` `{5, 6}`: both sides **write** `MuskometerTests.swift` (not read). T5’s deletion of L3661–3997 vs any insertion is a guaranteed merge conflict; T4’s “update every seed assert” pass can land inside classes T6 also edits. Hidden runtime coupling is absent (calculator vs holiday table vs outstanding vs parity field vs comparison types). Ratios 0.600–1.000. Risk is a real write collision → **UNVERIFIED-UNSAFE**. Not spurious.

- `{3, 4}` `{3, 5}` `{4, 5}`: same test-file collision **plus** all three write `AppSettings.swift` `init` / load / reset (`loadSharesOutstanding` remigrate, `loadShareCounts` TSLA remigrate, comparison-key sweep + drop `ComparisonHistoryStore.resetPersistedState`). Orthogonal UserDefaults keys, but one type’s initializer is a single hunk. → **UNVERIFIED-UNSAFE**.

- `{2, 7}`: both write `docs/ARCHITECTURE.md`. T7’s step literally assumes “already updated for 2028 in Task 2” while `Depends on` is only 3, 4, 5. Undeclared write-order dependency. Ratio 0.600. → **UNVERIFIED-UNSAFE**.

- `{1, 8}` `{2, 8}` `{3, 8}` `{4, 8}` `{6, 8}`: T8 paths (`docs/screenshots/*`, `docs/index.html`, `docs/README.md`, `scripts/verify.sh`) share no path with T1–4/T6 product or test files. T8’s `verify.sh` grep is scoped to `docs/index.html` and `docs/screenshots/render-*.html`. Mock may hardcode pinned integers from the plan; it does not import calculator / AppSettings / calendar / parity types. `currentTSLAPrice` is not screenshot-visible. Ratios 0.750–1.000. → **VERIFIED**.

- `{6, 7}`: T6 product files are only `MergerMarketCapParity.swift` + `MergerParityCardView.swift` (`currentTSLAPrice` at parity L8/L49 and card preview L56). T7 does not touch those files or the test file. Settings/HOLDINGS copy does not mention the dead field. Ratio 0.600. → **VERIFIED**.

- `{7, 8}`: root `README.md` ≠ `docs/README.md`. T7’s HOLDINGS/PRIVACY/ARCHITECTURE/Settings vs T8’s HTML/PNG/`verify.sh`. T8 forbids “Post to X” / “comparison caption” only in site HTML, not in ARCHITECTURE. Ratio 0.800. → **VERIFIED**.

No pair is downgraded or upgraded. Serialized set of 23 is complete; no extra concurrent pair exists.

## Summary

Analyst’s 22 / 7 / 15 / 0 / 0 split is correct. Safe remaining lanes: **T8 ∥ {1,2,3,4,6}** and **T6 ∥ T7**. Ready-set `{1,2,3,5,6}` cannot run together because all six write `MuskometerTests.swift`.

## Findings

None.

## Per-pair verdicts

- {1, 2}: UNVERIFIED-UNSAFE
- {1, 3}: UNVERIFIED-UNSAFE
- {1, 5}: UNVERIFIED-UNSAFE
- {1, 6}: UNVERIFIED-UNSAFE
- {1, 8}: VERIFIED
- {2, 3}: UNVERIFIED-UNSAFE
- {2, 4}: UNVERIFIED-UNSAFE
- {2, 5}: UNVERIFIED-UNSAFE
- {2, 6}: UNVERIFIED-UNSAFE
- {2, 7}: UNVERIFIED-UNSAFE
- {2, 8}: VERIFIED
- {3, 4}: UNVERIFIED-UNSAFE
- {3, 5}: UNVERIFIED-UNSAFE
- {3, 6}: UNVERIFIED-UNSAFE
- {3, 8}: VERIFIED
- {4, 5}: UNVERIFIED-UNSAFE
- {4, 6}: UNVERIFIED-UNSAFE
- {4, 8}: VERIFIED
- {5, 6}: UNVERIFIED-UNSAFE
- {6, 7}: VERIFIED
- {6, 8}: VERIFIED
- {7, 8}: VERIFIED

VERDICT: APPROVED

Reviewed-files: docs/marshal/plans/2026-08-17-holdings-surface-refresh.md, docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/parallelism-analysis.md, Muskometer/Utilities/AppSettings.swift, MuskometerTests/MuskometerTests.swift, docs/ARCHITECTURE.md, Muskometer/Utilities/MergerMarketCapParity.swift, Muskometer/Views/MergerParityCardView.swift

reviewed-content-sha256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130

Plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
