# Task 5 code quality review

Reviewed commit `cc22b82ec5d4aae1650f57667a33b658213e4932` against `68cccc9aa2033295dbb10b1a8f7bbd8963d99d75`. Classification: executable Swift production and test changes; file organization, tests, clarity, and patterns all apply. Review was independent, with no sibling review or orchestrator-memory access.

## Cold hypotheses

Before reading the diff, I identified four failure classes: old completions interfering with restarted work; suspended notifications blocking quotes or retaining work; changed holdings leaving stale counts; and closing failures losing finalization or mis-scheduling the next request. I traced the acceptance, failure, cancellation, restart, and subsequent request paths, including day advancement and the persisted pending-summary acknowledgement.

## Strengths

Snapshot, sample, milestone, and record mutations now complete synchronously before delivery suspension. Quote generations and lifecycle/holdings tokens prevent stale success/failure cleanup from clearing restarted work. Current holdings are read when quotes are accepted. Exact-value pending acknowledgement matches the tracker persistence contract, and notification lifecycle invalidation correctly protects reset/restart.

The existing 23 refresh tests remain byte-for-byte intact, verified independently against the base, and 25 behavioral regressions were appended. The new actor gates exercise cancellation-unaware services and assert application state, rather than only mock call counts. I inspected the recorded Xcode outputs: targeted 109/109 and full 310/310 pass. The additional private scheduling and acceptance helpers keep responsibilities distinguishable, although the task ownership still needs the correction below. The injected sleeper follows the existing boundary-injection pattern.

## Issues

### Important: stale closing observations produce the wrong market status

`advanceTradingClock()` now changes a retained in-session snapshot to `.closed` without changing `lastUpdated` (lines 611–618), but its consumers still use that observation time to compute the latest market close and next opening (`marketCloseStatusLabel`, lines 414–420; `marketStatusDetail`, lines 431–434). With a real June 30 15:59 ET observation and a failed fetch at 16:01, the actual view model returns `As of 4:00 PM EDT on June 29` and no next-open detail. That is the previous day's close, not the retained observation. The next failed request preserves the same wrong label. Retain the observation timestamp, display it honestly for stale data, and calculate the upcoming session from the current trading clock. Add assertions on these public presentation properties to the failed/partial-closing regressions.

### Important: the initial await can erase the observed closing transition

`start()` records `sessionClose` only after awaiting the initial request (lines 94–96). Starting during a regular session with a slow initial quote that fails just after close leaves `currentRegularClose()` nil. The closing branch then never runs, and the loop immediately sleeps until the next opening, without a closing request or bounded retry. I reproduced this after a real July 1 15:58 ET sample: start at 15:59, release the failed initial request at 16:00:01, and the result is one request since start followed by a 62,999-second sleep. Finalization succeeds, but the intended closing quote recovery is lost. Capture the observed session before suspending and preserve it across the first completion; test this startup/restart boundary explicitly.

### Important: suspended recrossings retain an unbounded set of refresh tasks

Every accepted refresh creates an entry in `quoteTasks`, and that entry is removed only after `thresholds.processUpdate` finishes (lines 202–226, 230–233). A below-threshold observation rearms the preset while an earlier delivery remains suspended, so each later recrossing starts another suspended delivery and retains another full refresh task. The real view model retained 12 quote tasks after 12 alternating 9B→11B→9B sequences with one enabled threshold and gated delivery. Nothing in the next refresh bounds or replaces those older tails; only eventual delivery completion or stop clears the dictionary. This violates the explicit bounded-work requirement even though the threshold service's current state is bounded. Give delivery work bounded ownership/coalescing while preserving the latest observations and retry semantics, and add a repeated-crossing resource-bound regression. Merely preserving the 400 chart samples does not bound these tasks.

## Validation and assessment

I compiled and ran an independent source probe using unchanged application sources, excluding the application entry point, with mocked quote, notification, login, and outstanding boundaries. It ran under `require_escalated` through the required aggregate launcher with the Xcode developer directory and a task-specific module cache. It did not launch an app/test host or use real notification/login operations. Probe source and exact output are in `build/task5-evidence/quality-review-r1/probe.swift` and `probe-output.txt`; the reproducible compiler/runner is `run-probe.py`. The probe exited 0 and reported:

```text
STALE_CLOSE observation=2026-06-30 19:59:00 +0000 current=2026-06-30 20:01:00 +0000 session=closed stale=true label=As of 4:00 PM EDT on June 29 nextOpen=nil
INITIAL_SPANS_CLOSE requestsSinceStart=1 firstSleep=62999.0 finalized=true
SUSPENDED_RECROSSES acceptedCrossings=12 deliveryCalls=12 retainedQuoteTasks=12
```

These are independently observed incorrect outcomes, not failed XCTest assertions. No additional Xcode suite was run; the existing suite results were checked directly in its logs. `git diff --check` passed. No application source or test source was changed. No critical or separate minor issues were identified. The three important findings block approval.

## Findings

- [Muskometer/ViewModels/GainsViewModel.swift:611-618] adjudicate-error: Changing the retained snapshot to closed makes presentation report the previous day's close and omit the next opening after closing quote failure.
- [Muskometer/ViewModels/GainsViewModel.swift:94-96] adjudicate-retry: Capturing the regular-session close after the initial await skips closing recovery when that request spans the close.
- [Muskometer/ViewModels/GainsViewModel.swift:202-226] adjudicate-race: Each suspended threshold recrossing retains another refresh task without a fixed ownership bound.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"b57bd83b-c44b-4f63-bfca-2ea5881ef089-task-5","verdict":"needs_fixes","round":1,"findings":[{"file_path":"Muskometer/ViewModels/GainsViewModel.swift","line_range":[611,618],"category":"adjudicate-error","severity":"important","summary":"Changing the retained snapshot to closed makes presentation report the previous day's close and omit the next opening after closing quote failure.","persisted_from_prior_round":false,"resolved_in_this_round":false},{"file_path":"Muskometer/ViewModels/GainsViewModel.swift","line_range":[94,96],"category":"adjudicate-retry","severity":"important","summary":"Capturing the regular-session close after the initial await skips closing recovery when that request spans the close.","persisted_from_prior_round":false,"resolved_in_this_round":false},{"file_path":"Muskometer/ViewModels/GainsViewModel.swift","line_range":[202,226],"category":"adjudicate-race","severity":"important","summary":"Each suspended threshold recrossing retains another refresh task without a fixed ownership bound.","persisted_from_prior_round":false,"resolved_in_this_round":false}]}
```

VERDICT: NEEDS_FIXES: Correct stale-close presentation, retain the initial session transition, and bound suspended refresh delivery work.

## Reviewed files

- Muskometer/ViewModels/GainsViewModel.swift
- MuskometerTests/RefreshLifecycleTests.swift
- Muskometer/Services/GainThresholdNotificationService.swift
- Muskometer/Services/DayCloseSummaryNotificationService.swift
- Muskometer/Services/DailyRecordTracker.swift
- Muskometer/Services/MarketHoursService.swift
- Muskometer/Utilities/MarketStatusFormatter.swift
- Muskometer/Utilities/MuskometerNetworking.swift
- Muskometer/Models/GainsSnapshot.swift
- Muskometer/Views/PopoverContentView.swift
- Muskometer/App/MuskometerApp.swift
- Muskometer.xcodeproj/project.pbxproj
- scripts/verify.sh
- docs/marshal/specs/2026-09-10-review-fixes-design.md
- docs/marshal/plans/2026-09-10-review-fixes.md
- build/task5-evidence/done-summary.md
- build/task5-evidence/validation-results.json
- build/task5-evidence/validation-commands.txt
- build/task5-evidence/test-preservation.json
- build/task5-evidence/green-final-targeted.log
- build/task5-evidence/full-suite.log
- build/task5-evidence/run-baseline-red.py
- build/task5-evidence/quality-review-r1/probe.swift
- build/task5-evidence/quality-review-r1/run-probe.py
- build/task5-evidence/quality-review-r1/probe-output.txt
- /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/execution-evidence/task-3/assertion-summary.md
- /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/run-aggregate.py
- /Users/jlgolson/grok/muskometer/build/review-2026-09-10/evidence/view-model-probe.swift

reviewed-content-sha256: 3a8a0ce4089db17f069453dbf0b753f58607f12839e545e9a6197cbb05c5e9eb

plan-graph-sha256: c5582aec64ba1273dc1ddb9487db6d546ccf6879bd93cdd16eda9a28cf89a760
