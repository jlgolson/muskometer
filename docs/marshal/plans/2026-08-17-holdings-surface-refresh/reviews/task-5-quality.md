# Task 5 Code Quality Review — Delete comparison captions

Reviewed the Task 5 product at HEAD `55a0205b3da112583209d6de5dd5f0559c8b8a5f` (base `1949e2f8e66a7d39a9426dd6c8ef29f367a1ef30`): four comparison compile units and their pbxproj IDs removed, caption stripped from the popover, `GainsViewModel` comparison API and `tradingDayCalendar` gone, leftover `comparisonHistoryEntries` keys swept on load and Reset, and the four comparison test types deleted from `MuskometerTests.swift`.

## Strengths

The cut is closed. `ComparisonLine.swift`, `ComparisonCaptionView.swift`, `ComparisonLineSelector.swift` (including `SeededComparisonRandomizer`), and `ComparisonHistoryStore.swift` are gone from disk and from `project.pbxproj`. IDs `A100`/`A200` `…2B`, `2E`, `3A`, `3B` are not recycled. Grep of `Muskometer/` and `MuskometerTests/` for `ComparisonLine`, `comparisonLine`, `ComparisonCaption`, `ComparisonHistory`, `ComparisonLibrary`, and `tradingDayCalendar` is empty.

`PopoverContentView.dataView` is ownership → combined → daily records → stock rows → parity, with no empty placeholder. `GainsViewModel` lost `comparisonLine`, the selector, debounce state, `updateComparisonLineIfNeeded`, and the `tradingDayCalendar` stored property/parameter. Remaining VM tests and `MuskometerApp` construct without those arguments. Share card was already caption-free and stayed that way.

The UserDefaults sweep is a small private helper, not a kept store type. It deletes the legacy unscoped key and `comparisonHistoryEntries_<id>` for every registry person (today `musk`). Called last in `AppSettings.init` and from `resetPersistedState` after the other person-scoped resets.

## Plan alignment

Planned functionality landed in the nine named files. Approach matches Design §4: delete end-to-end, no replacement caption or toggle, sweep leftover keys on load and Reset.

One small deviation from the step sketch, a considered improvement:

- The helper iterates `TrackedPersonProfile.registry` (plus an explicit `musk` insert) instead of hardcoding only `comparisonHistoryEntries_musk`. Registry is `[.musk]` today, so the keys match the plan. A later profile is swept without editing the helper.

Do not rewrite it to the more literal two-string sketch. Site/CHANGELOG/DEVELOPING copy is Tasks 6–8; leaving those words in docs is correct.

## File organization

No new files or types. The four sources are deleted rather than stubbed. pbxproj drops the matching `PBXBuildFile` / `PBXFileReference` / group / Sources lines only. `removeLegacyCaptionHistoryKeys` sits next to `resetPersistedState`. Test deletions are the four named classes inside `MuskometerTests.swift`; `GainsViewModelResetTests` and `TradingDayCalendarTests` remain.

## Tests

Coverage matches the behavior that matters for a deletion task:

| Requirement | Where |
|-------------|--------|
| Four compile units gone | files + pbxproj |
| No product/test references | grep of `Muskometer/` / `MuskometerTests/` |
| Popover order, no caption view | `PopoverContentView.dataView` |
| VM has no comparison / calendar API | `GainsViewModel` init and side-effect path |
| Comparison test types gone | deleted `ComparisonLibraryTests`, `ComparisonHistoryStoreTests`, `ComparisonLineSelectorTests`, `GainsViewModelComparisonDebounceTests` |
| Remaining VM constructors still compile | `GainsViewModelResetTests` and other `GainsViewModel(` sites |

The plan asked to delete those suites, not to add a sweep case. The helper is `removeObject` on known keys; load and Reset both call it. A suite that seeds `comparisonHistoryEntries` / `comparisonHistoryEntries_musk` before `AppSettings` init and after `resetToDefaults` would lock the merge-hotspot (`AppSettings.init` / reset also edited by Tasks 3 and 4). Not required for this task.

## Clarity and patterns

Names stay in the existing settings vocabulary. Key strings are inlined in the helper — the spec said not to keep `ComparisonHistoryStore` just for names, and the keys never belonged in `AppSettings.Keys`. Comments earn their keep: load-time sweep and the helper docstring say leftover caption-history prefs.

No new I/O. `TradingDayCalendar` remains its own type for records/sparkline. No replacement caption API leaked onto the VM.

## Next-request / round-trip

Idempotent. `removeObject` on missing keys is a no-op, so a second `AppSettings` init or Reset does not rewrite anything. After the first sweep the keys stay gone; nothing in the remaining product writes them. `resetToDefaults` still reseeds ownership/outstanding and then runs the same helper.

## Assessment

Ready to merge on quality. Organization, the closed cut, and the leftover-key helper match the surrounding deletion/remigration pattern. No replacement surface. Docs mentions left for later tasks.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- Muskometer/Models/ComparisonLine.swift (deleted)
- Muskometer/Views/ComparisonCaptionView.swift (deleted)
- Muskometer/Services/ComparisonLineSelector.swift (deleted)
- Muskometer/Services/ComparisonHistoryStore.swift (deleted)
- Muskometer/Views/PopoverContentView.swift
- Muskometer/ViewModels/GainsViewModel.swift
- Muskometer/Utilities/AppSettings.swift
- Muskometer.xcodeproj/project.pbxproj
- MuskometerTests/MuskometerTests.swift
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-5-description.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-5-summary.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-5-round-1-quality-diff
- docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md

reviewed-content-sha256: 5f84ae353d13ba8467d0ef647d3f360d2f32456dd5d932cf72a31a607866afe1

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
