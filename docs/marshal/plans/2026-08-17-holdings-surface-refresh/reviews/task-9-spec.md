Task 9 (Version 0.1.5 / build 26 and CHANGELOG from the branch diff) matches Design §6 version tick, Rollout, Non-goals (no git-tag / DMG), and acceptance criterion 11. Reviewed pbxproj version pairs, current-release strings, `AppVersion.short`, and CHANGELOG `0.1.5` at HEAD `50fd3ea9` against the Task 9 delta and the product that Tasks 1–8 actually landed.

What landed correctly

- All four `MARKETING_VERSION` assignments are `0.1.5` and all four `CURRENT_PROJECT_VERSION` assignments are `26` in `Muskometer.xcodeproj/project.pbxproj` (app + test, Debug + Release). No leftover `0.1.4` / `25` pairs.
- Current-release strings name **0.1.5**: README `Muskometer-0.1.5.dmg`; INSTALL DMG name; RELEASE “current: v0.1.5”, shipping-version examples, tag/`gh release` samples, and `CFBundleVersion` example **26**; SECURITY “Current public release line (0.1.5)”. PRIVACY “current public release” is **0.1.5** (already set in Task 7; not rewritten here).
- `AppVersion.short` / `build` still read `CFBundleShortVersionString` / `CFBundleVersion` from Info.plist macros (`$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`). SEC User-Agent interpolates `AppVersion.short`. No second hardcoded version source.
- CHANGELOG promotes an empty `## [Unreleased]` above `## [0.1.5] - 2026-08-17`. Historical `0.1.4` / `0.1.1` / `0.1.2` entries stay as history (comparison captions remain in 0.1.1 Added).
- CHANGELOG bullets describe the branch, not plan prose: TSLA **710,172,677** / SPCX **5,116,475,230** (tables **4,766,475,230** + vested options **350,000,000**) and the named Form 4 accessions; calculator options-in / remarks-out; fingerprint remigration of SPCX `6,068,734,060` / `6,068,547,515` / older prints plus TSLA `699,580,882` and outstanding `13,181,779,945` → **13,571,069,199**; Cursor 8-K `0001628280-26-056945` item (i) `389,289,254` with TSLA outstanding unchanged; 2028 NYSE table and no New Year’s 2028 session holiday; HOLDINGS / Settings / README **⌘⇧C** / PRIVACY / ARCHITECTURE; marketing PNGs + site copy (single Copy, 9:30, parity card; no Post to X / comparison / “minute by minute, every day”); version **0.1.5** / build **26**. Removed: `ComparisonCaptionView` + library/selector/history + VM debounce + `comparisonHistoryEntries` sweep on load and Reset; unused `MergerParityPresentation.currentTSLAPrice`. Those match Tasks 1–8 product already reviewed on this branch.
- No `v0.1.5` git tag (refs remain `v0.1.0`–`v0.1.2`, `v0.1.4`). No `dist/` tree and no DMG/zip artifact in the worktree. RELEASE.md examples that *mention* `dist/Muskometer-0.1.5.dmg` are maintainer instructions, not attached binaries.

Plan wording vs implementation

The plan listed `docs/PRIVACY.md` in files-touched. HEAD left PRIVACY at the Task 7 string **0.1.5**. That is the intended no-op once the release line is already current, not a missed tick. Do not rewrite PRIVACY just to appear in this delta.

CHANGELOG is authored from the landed integers, accessions, deleted types, and marketing constraints rather than a paraphrase of the plan checklist. Coverage matches Design §6’s required 0.1.5 topics. Confirm that authorship was from `git log` / `git diff` as dispatched; do not swap the bullets for shorter plan-prose stand-ins.

Next-request: these are static version strings and a dated changelog section. Retry, replay, and a second launch all see `AppVersion.short` `0.1.5` / build `26` from the same pbxproj macros. No persisted version state and no freshness window. Binary / git revert restores 0.1.4 / build 25 strings; UserDefaults seeds are unchanged by this task. Cutting the GitHub Release / unsigned DMG stays the post-merge maintainer path.

No missing §6 version/CHANGELOG requirements, no extra product work, no tag or `dist/` leak, no CHANGELOG claim that is not on the branch.

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
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-9-description.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-9-summary.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-9-round-1-quality-diff
- Muskometer.xcodeproj/project.pbxproj
- CHANGELOG.md
- README.md
- docs/INSTALL.md
- docs/RELEASE.md
- docs/PRIVACY.md
- SECURITY.md
- Muskometer/Utilities/AppVersion.swift
- Muskometer/Resources/Info.plist

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130

reviewed-content-sha256: STAMP

reviewed-content-sha256: a0d33f2a03555e87e11e005433e8159231e1d8e7c732c86de76286c0767c18d8

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
