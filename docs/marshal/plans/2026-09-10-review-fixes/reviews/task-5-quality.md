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
## Round 2

Independent cold review for dispatch `8e5305d2-8b37-4f4e-992c-c7f162ab71df-task-5` of the full cumulative Task 5 range `68cccc9aa2033295dbb10b1a8f7bbd8963d99d75..c524e6a6d11e7ee7313018caa4f8a6826a23d1b0`. I generated failure hypotheses before inspecting the implementation and did not read prior verdicts, sibling reports, or controller transcripts.

**Scope and classification.** This is a Swift code change, so organization, behavioral tests, clarity, and surrounding patterns all apply. The source/test write set is the original GainsViewModel/RefreshLifecycleTests pair plus the service/test extension explicitly authorized in `build/task5-evidence/authorized-integration-scope.md`, which I read in full. The frozen plan and spec are unchanged. Committed review/provenance records are workflow evidence, not executable implementation; executable-test requirements do not apply to those records. There is no SQL migration.

**Strengths.** Snapshot, record, sample, milestone, and threshold observations commit synchronously before deliveries suspend. Quote generations, lifecycle IDs, and matching day acknowledgments prevent old completions from overwriting current state. The view model keeps explicit physical quote, holdings, and summary slots across reset/cancellation; the background threshold path likewise retains an occupied per-preset slot and only one replaceable queued claim. I traced normal completion, current failure followed by another above-threshold observation, below/recross, reset, day rollover, closing retries, next-open supersession, and stop/deallocation. The new synchronous observation interface leaves the original awaitable `processUpdate` implementation behavior intact, and its existing service regressions remain byte-for-byte unchanged.

The added scheduling methods have clear ownership boundaries, despite the substantial increase in lifecycle code. The timer remains independent of quote and notification suspension. Observation time and the separately observable market clock serve their respective presentation roles. The actual-loop tests exercise early close, stalled initial/closing requests, newer generations, and multiple market days; service tests inspect persisted state and delivered content as well as request counts.

**Verification.** I directly parsed the original test logs: `build/task5-evidence/round-2/green-final.log` contains 78 distinct passing test cases, zero failed cases, and `TEST SUCCEEDED`; `full-suite-final.log` contains 327 distinct passing cases, zero failures, and the same success banner. Both logged commands use the declared Task 5 derived directory and disabled parallel testing. I verified that the original contents of both changed test files are exact prefixes of the current files: RefreshLifecycleTests grows from 23 to 60 test methods, NotificationServicesTests from 54 to 59, with no removed baseline tests or modified baseline assertions. The cumulative source/test diff passes `git diff --check`.

I additionally compiled the actual unchanged service and its actual dependencies into an isolated, mocked delivery probe, using the required escalated `run-aggregate.py` launcher, Xcode developer directory, and a dedicated module cache. No real notification or login-service action was performed. Probe source, runner, and exact output are in `build/task5-evidence/quality-review-r2/threshold-disable-probe.swift`, `run-probe.py`, and `threshold-disable-probe.log`.

**Important issue — disabled alerts can drain queued crossings.** In `GainThresholdNotificationService.swift:119–135`, worker completion starts the next queued delivery after checking only claim identity. `setEnabledThresholdIDs` at lines 80–81 updates defaults without invalidating that queue, and the worker does not reread enabled IDs before starting delivery. Reproduction through the new polling API: enable +$10B; observe 9→11 and hold delivery 1; observe 8→12 to queue a distinct crossing; disable +$10B; release delivery 1 before another observation. The probe reports `requestsAfterDisable: 2`: delivery 2 starts after the user disabled the alert. This is a new request, not the unavoidable completion of an already submitted notification. An app clock/quote observation eventually clears disabled queued work, but that makes the outcome depend on whether it wins the race with the old completion.

Reconcile disabling with pending semantic claims immediately and check current enablement before a queued worker submits, while retaining occupied physical capacity until the real deliverer returns. Add gated tests for disabling before a worker first runs and while an older delivery blocks a queued recross; cover enabling again so queue cleanup cannot leave a claim with no worker. The probe's observation-while-disabled variant also demonstrates that queue removal currently leaves persisted `retryPending: true` while a subsequent above observation starts no delivery, so cleanup needs coherent claim handling rather than just dropping the task/queue handle.

**Assessment.** The cumulative implementation is substantially covered and its principal lifecycle/resource protections are coherent. The confirmed settings/delivery race requires correction before approval. No other critical, important, or minor issue is raised by this review.

**Extension provenance independently computed by this reviewer.** Exact reviewed source HEAD: `c524e6a6d11e7ee7313018caa4f8a6826a23d1b0`. I read the actual disk bytes, computed SHA-256, and compared each byte-for-byte with `git show <HEAD>:<path>`; both comparisons passed:

- `Muskometer/Services/GainThresholdNotificationService.swift` — SHA-256 `45b50ae62ea3ff9a535945f4396c94ae52ba551087542ac468486ed83ae9aed2`.
- `MuskometerTests/NotificationServicesTests.swift` — SHA-256 `7ed4b823613bd98585227b9bbad714e3bf8638c66d563337855646ce6bc7b5f3`.

The same check passed for GainsViewModel and RefreshLifecycleTests. Full four-file evidence is recorded in `build/task5-evidence/quality-review-r2/source-provenance.json`; this explicitly supplements the default stamp's original-plan file set.

ADJUDICATED: adjudicate-error — (fixed: c524e6a6d11e7ee7313018caa4f8a6826a23d1b0)
ADJUDICATED: adjudicate-retry — (fixed: c524e6a6d11e7ee7313018caa4f8a6826a23d1b0)

## Findings

- [Muskometer/Services/GainThresholdNotificationService.swift:119-135] adjudicate-race: A queued recross starts a new notification after its threshold is disabled because worker drainage checks claim identity but not current enablement.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"8e5305d2-8b37-4f4e-992c-c7f162ab71df-task-5","verdict":"needs_fixes","round":2,"findings":[{"file_path":"Muskometer/Services/GainThresholdNotificationService.swift","line_range":[119,135],"category":"adjudicate-race","severity":"important","summary":"A queued recross starts a new notification after its threshold is disabled because worker drainage checks claim identity but not current enablement.","persisted_from_prior_round":false,"resolved_in_this_round":false}]}
```

VERDICT: NEEDS_FIXES: Disabling a threshold does not prevent its queued crossing from starting a new notification delivery.

## Reviewed files

- Muskometer/ViewModels/GainsViewModel.swift
- Muskometer/Services/GainThresholdNotificationService.swift
- MuskometerTests/RefreshLifecycleTests.swift
- MuskometerTests/NotificationServicesTests.swift
- Muskometer/Services/DayCloseSummaryNotificationService.swift
- Muskometer/Services/DailyRecordTracker.swift
- Muskometer/Services/MarketHoursService.swift
- Muskometer/Utilities/TradingDayCalendar.swift
- Muskometer/Models/GainNotificationThreshold.swift
- Muskometer/Utilities/CurrencyFormatter.swift
- Muskometer/Utilities/NotificationAuthorization.swift
- Muskometer/Utilities/MuskometerNetworking.swift
- Muskometer/App/MuskometerApp.swift
- Muskometer/Views/SettingsView.swift
- scripts/verify.sh
- docs/marshal/specs/2026-09-10-review-fixes-design.md
- docs/marshal/plans/2026-09-10-review-fixes.md
- build/task5-evidence/authorized-integration-scope.md
- build/task5-evidence/done-summary.md
- build/task5-evidence/round-2/scope-and-api.md
- build/task5-evidence/round-2/validation-results.json
- build/task5-evidence/round-2/validation-commands.txt
- build/task5-evidence/round-2/source-manifest.json
- build/task5-evidence/round-2/green-final.log
- build/task5-evidence/round-2/full-suite-final.log
- build/task5-evidence/quality-review-r2/hypotheses.md
- build/task5-evidence/quality-review-r2/source-provenance.json
- build/task5-evidence/quality-review-r2/threshold-disable-probe.swift
- build/task5-evidence/quality-review-r2/run-probe.py
- build/task5-evidence/quality-review-r2/threshold-disable-probe.log

reviewed-content-sha256: 4bfcfcfa794c8d2b393271df71ad991f22620c09806452a929d557615c299b33

plan-graph-sha256: c5582aec64ba1273dc1ddb9487db6d546ccf6879bd93cdd16eda9a28cf89a760
## Round 3

### Independent review scope

Cold, full cumulative code-quality review of Task 5 from `68cccc9aa2033295dbb10b1a8f7bbd8963d99d75` through exact reviewed source HEAD `adab4cb0efa2142900cac456abf817b97e315d14`. Dispatch: `a4d10f29-8ab4-4f7d-9d90-9dbe07e98473-task-5`.

Classification: Swift production and test code change; file organization, tests, clarity, and patterns all apply. Supporting review/evidence files have no executable-test requirement. Independent hypotheses were recorded in `build/task5-evidence/quality-review-r3/cold-hypotheses.md` before source/diff-body inspection. This assessment used the full cumulative change and preserved Task 3 contracts, without consulting prior verdicts or sibling reviews.

### Strengths

The acceptance path commits records, samples, milestone state, and threshold observations synchronously before notification suspension. Quote generations and lifecycle tokens isolate obsolete completion from current state. Quote acceptance reads current holdings, preserving count updates made while transport waits. Polling owns a timer separate from SEC and delivery work, while task completion frees only its own physical slot.

Threshold delivery has one worker plus one replaceable pending claim per person/preset. Below observations rearm; reset, rollover, and disable invalidate semantic reservations while retaining occupied physical capacity until the boundary returns. A failed current crossing waits for a later above observation; an older failure cannot erase a newer crossing. The awaitable `processUpdate` API retains its direct-caller behavior and existing Task 3 regression coverage.

Closing scheduling separates a pending obligation from an admitted request. Capacity release can admit the pending close after the recovery window; failure then permits one delayed retry. The actual loop tests cover normal and early closes, saturation, next opening, success/failure, and stop/restart. Clock-only advancement finalizes real stored observations without fabricating samples or changing their observation time. Summary consumption requires delivery/intentional skip and exact pending-value identity; failure, in-flight duplication, and obsolete completion preserve pending work.

The added helpers separate admission, acceptance, cleanup, and recovery with clear responsibilities. Existing protocol injection and actor isolation remain consistent. Physical request dictionaries are capped at two each in the view model; the threshold worker/pending maps are bounded by the preset set. Tests verify actual held boundary calls through repeated recrossings/resets and weak-reference deallocation, in addition to checking observable and persisted outcomes. The unchanged sample store retains its 400-sample cap.

### Issues

Critical: none. Important: none. Minor: none.

### Verification and assessment

Independently parsed the supplied raw logs: `round-3/green.log` contains 87 unique passed test cases and zero failed cases; `round-3/full-suite.log` contains 336 unique passed test cases and zero failed cases. Both contain `TEST SUCCEEDED`, agree with `validation-results.json`, and record task-local derived data with parallel testing disabled. The red assertions exercise the revised admission and disable/re-enable behavior. No broad successful-suite rerun was performed because there was no new concrete failure or source change requiring one.

The entire BASE version of each test file is a byte-identical prefix of reviewed HEAD: all 23 existing refresh tests and 54 existing notification/record tests are preserved, including the Task 3 suspension, reset, rollover, legacy-decoding, exact-acknowledgment, and clock cases. The cumulative additions bring both files to 64 tests. This independently verifies preservation more broadly than the supplied round-3-only preservation report. The cumulative four-file source diff passes `git diff --check`.

All four disk files independently match `git show` bytes from the exact reviewed HEAD and the supplied source manifest. The implementation summaries contain earlier pre-freeze HEAD references; the verified source-byte match establishes the review and validation identity. Detailed traces and verification are retained in `build/task5-evidence/quality-review-r3/assessment.md` and `independent-attestation.json`.

Assessment: approve the full cumulative implementation. No actionable error/retry/race/next-request finding remained after independent tracing. Controlled boundary evidence does not claim actual system notification delivery or a long-duration memory profile.

### Mandatory added-path source attestation

Explicit scope authority: `build/task5-evidence/authorized-integration-scope.md` authorizes the service and service-test additions to Task 5 alongside its original two plan files. The frozen plan/spec remain unchanged. I independently read each added path from disk, computed SHA256, and compared its bytes against `git show adab4cb0efa2142900cac456abf817b97e315d14:<path>`; both comparisons are equal.

- `Muskometer/Services/GainThresholdNotificationService.swift` — SHA256 `f233c20585caf3855355ee412b8d989d4f1bd216b14da60e0cae0554db0c7dfd`.
- `MuskometerTests/NotificationServicesTests.swift` — SHA256 `72a7dbf8be71cbf6d3b7572c48b8968a007d9d2bcafa0f3d4dd0336ebfc671ad`.

These independent hashes attest the authorized added paths at reviewed HEAD `adab4cb0efa2142900cac456abf817b97e315d14` separately from the standard original-plan-files trailer.

## Findings

None.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"a4d10f29-8ab4-4f7d-9d90-9dbe07e98473-task-5","verdict":"approved","round":3,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- Muskometer/ViewModels/GainsViewModel.swift
- Muskometer/Services/GainThresholdNotificationService.swift
- MuskometerTests/RefreshLifecycleTests.swift
- MuskometerTests/NotificationServicesTests.swift
- Muskometer/Services/DayCloseSummaryNotificationService.swift
- Muskometer/Services/DailyRecordTracker.swift
- Muskometer/Services/IntradayGainSampleStore.swift
- Muskometer/Utilities/AppSettings.swift
- Muskometer/Models/TrackedPersonProfile.swift
- docs/marshal/specs/2026-09-10-review-fixes-design.md
- docs/marshal/plans/2026-09-10-review-fixes.md
- build/task5-evidence/authorized-integration-scope.md
- build/task5-evidence/done-summary.md
- build/task5-evidence/round-2/scope-and-api.md
- build/task5-evidence/round-3/completion-api.md
- build/task5-evidence/round-3/validation-commands.txt
- build/task5-evidence/round-3/green.log
- build/task5-evidence/round-3/full-suite.log
- build/task5-evidence/round-3/red-assertions.txt
- build/task5-evidence/round-3/validation-results.json
- build/task5-evidence/round-3/source-manifest.json
- build/task5-evidence/round-3/test-preservation.json

reviewed-content-sha256: ab68db21231972418c4ca07a1550614843ee1426ecfa1821a9df8eaac506c931

plan-graph-sha256: c5582aec64ba1273dc1ddb9487db6d546ccf6879bd93cdd16eda9a28cf89a760
