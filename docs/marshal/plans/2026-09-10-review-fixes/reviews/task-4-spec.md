# Task 4 spec-compliance review

Reviewed implementation `e89dcce91420ec5fbcb7c7414a27339eab418999` against base `38ae64739615d72d23fa8ee77ddd6aee0c5a54c5`, the complete design spec, and Task 4 of the implementation plan. The supplied review diff exactly matches that commit range; the current production/test files match the implementation commit. The implementation summary is supporting evidence, not the basis of the source conclusions below.

## Independent hypotheses checked

I checked whether approval-pending reconciliation could register twice or erase the desired preference, whether a failed service operation could leave the next reconciliation acting on the wrong state, whether a year-boundary calendar correction could change other sessions, and whether fixed outer dimensions could conceal unreachable content or break Settings/Back/share routing.

## Compliance assessment

The design's “Popover and login state (findings 9–10)” and Task 4 require full login status, pending-preserving reconciliation, bounded actual-view sizing at four heights, and preserved actions. `LaunchAtLoginManager.swift:4–35` exposes all four required states and preserves existing Boolean-only conformers through the default protocol implementation. `AppSettings.swift:460–522` reconciles pending and enabled registrations without another registration call, makes an already-unregistered disable a no-op, unregisters pending/enabled registrations on explicit disable, and adopts actual registered state after failures. The changes are confined to login logic in this otherwise shared settings file.

Next-request traces are sound for the required transitions: enabling an unregistered service persists true after approval-pending success; repeated reconciliation and restart remain true without another register; external approval takes the enabled no-op path; successful disable persists false and subsequent disable/reconcile performs no call. Failed disable while pending restores true, so a subsequent reconciliation keeps the existing registration rather than losing it; a later explicit disable can try again. Failed enable with an unregistered service restores false and a later explicit enable can retry. Unavailable state surfaces an error without a service operation. The reconciliation is synchronous and introduces no suspended completion, task queue, or freshness window. Existing startup and Settings activation/reopen call sites remain connected (`MuskometerApp.swift:10`, `SettingsView.swift:45–58`). Tests exercise the documented-behavior status mock and the retained Boolean mock; no real login-item operation is used by these regressions.

`PopoverContentView.swift:9–61` bounds main content to the available height, retains 360-point width, and places scrolling cards between the unchanged header and footer. Embedded Settings has the same outer screen limit. `SettingsView.swift:19–44,80–92` preserves initializer compatibility and uses scrollable tab content with a bounded layout, removing the preference-size feedback path. The original share, refresh, Settings, Quit, Back/Done, and field-commit actions remain present. Existing accessibility labels and values are retained; the scrolling container receives an identifier.

The design's “Calendar (finding 11)” is implemented by removing only `2027-12-31` from the full-holiday set (`MarketHoursService.swift:248–258`). The updated regression checks 11 AM regular trading, a 16:00 close, and the next opening at January 3, 2028, 09:30 ET (`InterfaceAndCalendarTests.swift:129–139`). All other holiday and early-close entries and tests are retained. The contradictory architecture wording at `docs/ARCHITECTURE.md:118` is outside Task 4's six-file ownership and is explicitly assigned to Task 6's documentation work; it is not a missing Task 4 change.

No missing, extra, or misinterpreted Task 4 requirement was found. The source/test change set contains exactly the six assigned files. The original shared test file and project file are unchanged. Test-name comparison confirms 37 existing interface/calendar tests become 44: the calendar test is renamed/corrected and seven new tests are added. The reset assertion adjustment follows the requested not-registered no-op behavior.

## Verification and limits

I inspected the saved red result (31 tests, 8 assertion failures), final targeted result (44 passed, zero failed or skipped), full final log (255 passed, zero failures, TEST SUCCEEDED), exact rendered-height log, and the actual regression source. Saved fitting sizes are main 360×600/700/800/900 and Settings 592×600/650/650/650. The actual-host test scrolls the document to its bottom, checks footer frames remain inside the host, opens Settings, and sends mouse events to Back to confirm return to 360-point width (`InterfaceAndCalendarTests.swift:800–910`).

I visually inspected the saved main-600-scrolled and settings-600 bitmap attachments. They support geometry inspection but omit some composited native labels/glass, as the implementation summary discloses. This review does not claim pixel-perfect live UI or accessibility-tree validation. Fresh read-only checks confirmed the diff matches the commit, production/test files match the reviewed head, and `git diff --check` passes. I launched no app, Xcode test host, or probe during this review; the passing runtime results are the saved pre-pause evidence. A subsequent coordination message released the pause, but no unresolved concern justified repeating those tests.

## Findings

None.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"f46d09d4-e528-4155-a842-f7cc86f81136-task-4","verdict":"approved","round":1,"findings":[]}
```

## Reviewed files

- `docs/marshal/specs/2026-09-10-review-fixes-design.md`
- `docs/marshal/plans/2026-09-10-review-fixes.md` (Task 4 and downstream integration ownership)
- `docs/marshal/plans/2026-09-10-review-fixes/reviews/.tmp-task-4-description.md`
- `docs/marshal/plans/2026-09-10-review-fixes/reviews/.tmp-task-4-summary.md`
- `docs/marshal/plans/2026-09-10-review-fixes/reviews/.tmp-task-4-round-1-quality-diff`
- `Muskometer/Utilities/LaunchAtLoginManager.swift`
- `Muskometer/Utilities/AppSettings.swift`
- `Muskometer/Views/PopoverContentView.swift`
- `Muskometer/Views/SettingsView.swift`
- `Muskometer/Views/SettingsContentHeightKey.swift`
- `Muskometer/Services/MarketHoursService.swift`
- `Muskometer/App/MuskometerApp.swift`
- `MuskometerTests/InterfaceAndCalendarTests.swift`
- `docs/ARCHITECTURE.md` (calendar wording and ownership check)
- `build/task-4-evidence/red-summary.json`
- `build/task-4-evidence/targeted-final-summary.json`
- `build/task-4-evidence/targeted-final.log`
- `build/task-4-evidence/full-final.log`
- `build/task-4-evidence/rendered-heights.txt`
- `build/task-4-evidence/test-pause-status.json`
- `build/task-4-evidence/targeted-final-snapshots/main-600-scrolled.png`
- `build/task-4-evidence/targeted-final-snapshots/settings-600.png`

VERDICT: APPROVED

reviewed-content-sha256: 6a7d92eaf4dc538eae57c8995ce2e1f39151a680b604b81aa7ffb592ea952d2e

plan-graph-sha256: c5582aec64ba1273dc1ddb9487db6d546ccf6879bd93cdd16eda9a28cf89a760
