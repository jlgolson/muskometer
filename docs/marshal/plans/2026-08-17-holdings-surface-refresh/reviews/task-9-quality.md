# Task 9 Code Quality Review — Version 0.1.5 / build 26 and CHANGELOG

Reviewed the Task 9 product at HEAD `50fd3ea97d76f7799ea4363c48cb96fcf768f7ca`: four pbxproj `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` pairs, current-release strings in README / INSTALL / RELEASE / SECURITY, and a dated `## [0.1.5] - 2026-08-17` CHANGELOG authored from the landed branch (PRIVACY already 0.1.5 from Task 7).

## Strengths

The shipping identity is one source. All four pbxproj assignments (app + test, Debug + Release) are `MARKETING_VERSION = 0.1.5` and `CURRENT_PROJECT_VERSION = 26`. `Info.plist` still substitutes `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`. `AppVersion.short` / `AppVersion.build` still read those plist keys; SEC User-Agent and Settings/About display pick up 0.1.5 / 26 with no second hardcoded source. `package-dmg.sh` still names the DMG from the built plist, so a later maintainer cut becomes `Muskometer-0.1.5.dmg` without another string edit.

Current-release docs moved together: README and INSTALL DMG examples, RELEASE “current: v0.1.5” plus tag / `gh release` / version-bump examples (including build **26**), SECURITY “Current public release line (0.1.5)”. PRIVACY’s “current public release is **0.1.5**” was left as Task 7 set it. Historical `## [0.1.4]` stays. No `v0.1.5` tag and no `dist/` tree.

CHANGELOG numbers match the product, not the plan’s rounded prose: TSLA **710,172,677** (`0001104659-26-075213`), SPCX **5,116,475,230** = **4,766,475,230** + **350,000,000** (`0001628280-26-044069`), outstanding remigration `13,181,779,945` → **13,571,069,199** (10-Q cover + Cursor `0001628280-26-056945` item (i) 389,289,254), fingerprints `6,068,734,060` / `6,068,547,515` / TSLA `699,580,882`. Arithmetic is exact. `## [Unreleased]` is empty above the new section.

## Plan alignment

Planned functionality landed in the named files. Approach matches Design §6 / AC11: tick the four pbxproj pairs and the current-release strings; promote Unreleased into a dated 0.1.5 section; do not git-tag or attach artifacts.

Deviations from the step sketch, all considered improvements — do not rewrite them back:

- CHANGELOG uses the landed integers, accessions, and file names (`ComparisonCaptionView`, `comparisonHistoryEntries`, `MergerParityPresentation.currentTSLAPrice`, `app-capture` / `app-preview` / `og-image`) instead of the plan’s “710.2M / 5.116B” paraphrase. The task asked for the branch diff, not the plan prose.
- PRIVACY was not re-touched. Task 7 already set 0.1.5; a no-op edit would have been noise.

`docs/README.md` “post-0.1.4 popover” is chrome description, not a current-release string. Marshal specs/reviews still name 0.1.4 as the previous ship. Leave both.

## File organization

No new files or types. Version lives only in the existing pbxproj build settings. Docs edits stay inside the same headings the 0.1.4 tick used (Download, current: v…, Supported versions, Version bump examples). CHANGELOG keeps the repo’s Keep-a-Changelog-loose shape: one-line lede, `### Changed` / `### Removed`, bold lead-ins.

## Tests

None required. This is a version-string + notes task. The behavior that matters is grep-level:

| Requirement | Where |
|-------------|--------|
| Four `MARKETING_VERSION = 0.1.5` | `project.pbxproj` app/test Debug/Release |
| Four `CURRENT_PROJECT_VERSION = 26` | same |
| No leftover `0.1.4` / `25` as current identity | pbxproj + README / INSTALL / RELEASE / PRIVACY / SECURITY |
| Runtime version is the plist macros | `AppVersion`, `Info.plist` |
| Dated 0.1.5 notes, empty Unreleased | `CHANGELOG.md` |
| No tag / no `dist/` | `refs/tags` has no `v0.1.5`; no `dist/` directory |

`AppVersion` / SemanticVersion unit tests still use synthetic `0.1.0` fixtures and should.

## Clarity and patterns

Names stay in the existing holdings vocabulary (sellable ownership, last-row-wins, cover+Cursor, fingerprint remigration). CHANGELOG voice matches 0.1.4 (bold topic — one sentence of what shipped). Removed vs Changed is split the same way 0.1.0 split the META cut.

## Next-request / round-trip

N/A. These are compile-time strings. `AppVersion.short` rereads the built plist; a later request sees 0.1.5 / 26 until the next tick. UserDefaults are unchanged by this task.

## Assessment

Ready to merge on quality. Version surface, notes, and surrounding docs voice match the 0.1.4 tick pattern. No second source of truth, no release artifacts, no leftover current-release 0.1.4.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- Muskometer.xcodeproj/project.pbxproj
- CHANGELOG.md
- README.md
- docs/INSTALL.md
- docs/RELEASE.md
- docs/PRIVACY.md
- SECURITY.md
- Muskometer/Resources/Info.plist
- Muskometer/Utilities/AppVersion.swift
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-9-description.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-9-summary.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-9-round-1-quality-diff
- docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md

reviewed-content-sha256: STAMP

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130

reviewed-content-sha256: a0d33f2a03555e87e11e005433e8159231e1d8e7c732c86de76286c0767c18d8

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
