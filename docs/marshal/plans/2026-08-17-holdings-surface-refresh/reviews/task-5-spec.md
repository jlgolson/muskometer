Task 5 (Delete comparison captions) matches Design §4, acceptance criterion 7, and the upgrade/persisted-state contract for comparison history. Reviewed the four deleted compile units, `PopoverContentView`, `GainsViewModel`, `AppSettings` load/reset sweep, pbxproj IDs, and comparison test types at HEAD `55a0205b` as the full Task 5 product.

What landed correctly

- Four sources are gone from disk and from the app target: `ComparisonLine.swift`, `ComparisonCaptionView.swift`, `ComparisonLineSelector.swift`, `ComparisonHistoryStore.swift`. pbxproj `PBXBuildFile` / `PBXFileReference` / group / Sources lines for `A100`/`A200` `…2B`, `2E`, `3A`, `3B` are removed. Those IDs are not reused (`2C`/`2D`/`2F`/`3C` remain the neighbors). `Muskometer.xcodeproj/project.pbxproj` has zero `Comparison*` strings.
- Feature is deleted, not hidden. `PopoverContentView.dataView` is ownership → combined → daily records (if any) → stock rows → parity. No `ComparisonCaptionView` call, no empty placeholder, no settings toggle. Share card was already caption-free and is unchanged. Product tree has zero “Today's loss” / “Today's gain” / “Today's move” strings.
- `GainsViewModel` has no `comparisonLine` API. `comparisonLineSelector`, `lastComparisonStateByPerson`, `updateComparisonLineIfNeeded`, and every call in `processSnapshotSideEffects` / `reloadPersistedDisplayState` / `reloadPersonScopedDisplayState` are gone. `tradingDayCalendar` stored property and constructor parameter are gone. Remaining `GainsViewModel(` sites (app + tests) no longer pass those arguments. `TradingDayCalendar` the type stays for records/sparkline; that is not the VM debounce dependency.
- `AppSettings.resetPersistedState` no longer calls `ComparisonHistoryStore.resetPersistedState`. Private `removeLegacyCaptionHistoryKeys` deletes `comparisonHistoryEntries` and `comparisonHistoryEntries_<personID>` for every `TrackedPersonProfile.registry` id plus `musk`. Called from `init` after share-count / outstanding migrations (load-time sweep) and from `resetPersistedState` (Reset). Fresh install writes no comparison keys.
- Test types deleted from `MuskometerTests.swift`: `ComparisonLibraryTests`, `ComparisonHistoryStoreTests`, `ComparisonLineSelectorTests`, `GainsViewModelComparisonDebounceTests`. `SeededComparisonRandomizer` / `ComparisonRandomizing` lived on the selector file and went with it. `Muskometer/` + `MuskometerTests/` grep for `ComparisonLine`, `comparisonLine`, `ComparisonCaption`, `ComparisonHistory`, `ComparisonLibrary`, `tradingDayCalendar` is zero except the two leftover key-name strings in the sweep helper.

Plan wording vs implementation

The plan said delete `comparisonHistoryEntries` and `comparisonHistoryEntries_<personID>` (at least `musk`; also the selected id if it is ever non-musk). HEAD sweeps the unscoped key plus every registry id (and inserts `musk` even though registry is still `[.musk]`). That is a considered improvement: it matches the two known key shapes, covers a future registry row without keeping the store type for names, and does not depend on `resetPersistedState`'s person argument after Reset has already forced `selectedPersonID` to musk. Confirm it was deliberate; do not keep `ComparisonHistoryStore` or limit the helper to a hardcoded musk-only pair.

Docs / site / CHANGELOG still mention comparison in `docs/index.html` (“comparison captions” in the features blurb). That is Tasks 7/8/9 (`index.html` + verify grep, ARCHITECTURE/PRIVACY, dated 0.1.5). `docs/DEVELOPING.md` and `docs/ARCHITECTURE.md` already have no selector mention. Not this dispatch.

Next-request: the sweep is delete-if-present on every `AppSettings` init and on Reset. Retry, replay, and a second init after the first persist all see the keys gone and do not rewrite other prefs. No comparison keys are written on a fresh suite. No TTL/freshness window. A leftover `comparisonHistoryEntries_other` from a non-registry test person is out of the accepted key shapes; production keys are the unscoped legacy key and `comparisonHistoryEntries_musk`. Binary revert would restore the caption UI against empty history until new lines are selected.

No missing §4 product requirements, no extra product work, no hide-the-view leftover.

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
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-5-description.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-5-summary.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-5-round-1-quality-diff
- Muskometer/Utilities/AppSettings.swift
- Muskometer/ViewModels/GainsViewModel.swift
- Muskometer/Views/PopoverContentView.swift
- Muskometer/App/MuskometerApp.swift
- Muskometer.xcodeproj/project.pbxproj
- MuskometerTests/MuskometerTests.swift
- Muskometer/Views/ShareCardView.swift
- Muskometer/Views/SettingsView.swift

reviewed-content-sha256: STAMP
plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130

reviewed-content-sha256: 5f84ae353d13ba8467d0ef647d3f360d2f32456dd5d932cf72a31a607866afe1

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
