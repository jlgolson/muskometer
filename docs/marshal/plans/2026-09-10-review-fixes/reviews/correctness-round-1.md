# Plan correctness review — round 1

dispatch_id: 6e65f835-905d-49aa-a77e-3b18853622d7-task-0
MARSHAL_ROLE: plan-correctness
MARSHAL_TASK_ID: 0
MARSHAL_PLAN_SLUG: 2026-09-10-review-fixes
MARSHAL_ROUND: 1

## Reviewed files

- `docs/marshal/plans/2026-09-10-review-fixes.md`
- `docs/marshal/specs/2026-09-10-review-fixes-design.md`
- `Muskometer/Services/SECHoldingsSyncService.swift`
- `Muskometer/Services/Form4OwnershipParser.swift`
- `Muskometer/Services/CompanyFactsOutstandingResolver.swift`
- `Muskometer/Utilities/SPCXHoldings.swift`
- `Muskometer/Utilities/SPCXOwnershipCalculator.swift`
- `Muskometer/Services/GainThresholdNotificationService.swift`
- `Muskometer/Services/DayCloseSummaryNotificationService.swift`
- `Muskometer/Services/DailyRecordTracker.swift`
- `Muskometer/ViewModels/GainsViewModel.swift`
- `Muskometer/Models/GainsSnapshot.swift`
- `Muskometer/Utilities/MarketStatusFormatter.swift`
- `Muskometer/Services/MarketHoursService.swift`
- `Muskometer/Utilities/AppSettings.swift`
- `Muskometer/Utilities/LaunchAtLoginManager.swift`
- `Muskometer/Views/PopoverContentView.swift`
- `Muskometer/Views/SettingsView.swift` (layout and lifecycle sections)
- `MuskometerTests/MuskometerTests.swift` (class/helper inventory and affected regression sections)
- `Muskometer.xcodeproj/project.pbxproj` (source/file registrations)
- `scripts/verify.sh`, `docs/HOLDINGS.md`, `docs/ARCHITECTURE.md`
- Original evidence harnesses: `/Users/jlgolson/grok/muskometer/build/review-2026-09-10/evidence/{data-probe,view-model-probe,ui-probe,records-main}.swift`
- Cached source fixtures: `/tmp/muskometer-review-{tsla,spcx}-form4.xml`, `/tmp/muskometer-review-submissions.json`

## Assessment

The declared graph is acyclic and references existing task IDs. The shared-helper moves are feasible with the stated visibility changes, and the existing file contains 248 test methods. The test split isolates subsequent file ownership; Task 5 correctly depends on the notification/record APIs from Task 3. The original probes exercise the relevant actual transport, view-model, and SwiftUI boundaries. The cached submissions contain both named anchors, and their actual XML supplies the bucket data needed by Task 2, including dated transactions and undated anchor holdings. No production/source edits or builds were performed for this plan review.

Two concrete requirements are not assigned sufficiently to the task that owns the required service file.

### 1. Day-close completion invalidation needs a Task 3 API and Task 5 integration

Task 3's identity/version/reset instructions describe threshold state and per-preset processing. Its day-close step only adds `.inFlight` and checks duplicate/failure outcomes. Task 5 promises cancellation and that old asynchronous work cannot overwrite durable state, but owns only `GainsViewModel.swift` and its tests.

In the actual `DayCloseSummaryNotificationService`, the successful completion writes `dayCloseSummaryNotifiedDay_*` after `await deliverer.add` (lines 68–72). The static reset only removes the persisted key (lines 79–80); it cannot invalidate an active instance's completion. A view-model generation check after awaiting this service is too late to prevent that write. A gated delivery that succeeds after reset can therefore recreate erased notification state; cancellation that does not make the deliverer throw has the same problem. Matching tracker acknowledgement fixes a different write and does not protect this service state.

Assign service-level completion identity/lifecycle invalidation to Task 3, expose the exact instance API to Task 5, and require Task 5 to invoke it at reset/stop boundaries. Test a gated success after reset and stopped/restarted delivery interleavings, asserting stale completions neither persist a notified day nor release a newer claim. This implements the spec's explicit cancellation/reset requirement without crossing task ownership.

### 2. Last-observed day-close wording is missing

The spec explicitly requires day-close text to identify the last observed sample and its time when finalization uses that record. Task 5 adds finalization after a failed closing fetch, but neither its steps nor Task 3's notification steps change or test notification content. The current service uses the title `day close` and a body with only P&L/high/low (lines 50–55); `FinalizedTradingDay.date` is not used. Executing the listed changes can therefore send a midday or pre-close observation as an unqualified day-close summary after Yahoo fails.

Assign the wording change to Task 3, which owns `DayCloseSummaryNotificationService.swift`, using the existing finalized sample date. Add a captured-request content assertion, and have Task 5's failed-closing-fetch regression verify that the displayed observation time remains the last real sample time. No new persisted field is required for this fix.

## Findings

- [docs/marshal/plans/2026-09-10-review-fixes.md:Task 3 and Task 5] interface-gap: Day-close delivery needs service-level completion invalidation plus an explicit API wired to reset/stop; view-model tokens cannot prevent the service's post-await persistence.
- [docs/marshal/plans/2026-09-10-review-fixes.md:Task 3 and Task 5] coverage-gap: No task changes or tests day-close notification text to identify the last observed sample and time as the spec requires.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{
  "schema_version": 1,
  "dispatch_id": "6e65f835-905d-49aa-a77e-3b18853622d7-task-0",
  "verdict": "needs_fixes",
  "round": 1,
  "findings": [
    {
      "file_path": "docs/marshal/plans/2026-09-10-review-fixes.md",
      "line_range": [81, 86],
      "category": "interface-gap",
      "severity": "important",
      "summary": "Assign day-close service completion invalidation to Task 3 and wire its explicit lifecycle API from Task 5; view-model generation checks cannot prevent the service's post-await persistence.",
      "persisted_from_prior_round": false,
      "resolved_in_this_round": false
    },
    {
      "file_path": "docs/marshal/plans/2026-09-10-review-fixes.md",
      "line_range": [82, 84],
      "category": "coverage-gap",
      "severity": "important",
      "summary": "Assign and test day-close text that identifies the last observed sample and its time, including finalization after a failed closing fetch.",
      "persisted_from_prior_round": false,
      "resolved_in_this_round": false
    }
  ]
}
```

VERDICT: NEEDS_FIXES

reviewed-content-sha256: e5c96f6a35ebbe085848a28711df3d0d74febe509b0550f0603079a2d77afac3

plan-graph-sha256: 59c907e0f4d911017e21abd7f2d95dcaf33fec574819ef39c43e0060b538d6c0
