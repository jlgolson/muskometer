# Task 5 spec compliance review

Reviewed immutable range `68cccc9aa2033295dbb10b1a8f7bbd8963d99d75..cc22b82ec5d4aae1650f57667a33b658213e4932` against `docs/marshal/specs/2026-09-10-review-fixes-design.md` (Notification and refresh ordering; Refresh scheduling and close finalization; Scale & Validation) and Task 5 of `docs/marshal/plans/2026-09-10-review-fixes.md`.

The implementation substantially meets the ordering and lifecycle requirements. Snapshot, record, sample, and milestone updates now occur before notification suspension. Quote and SEC acceptance guard lifecycle/generation identities, accepted quotes use current holdings, pending-day acknowledgments match the delivered value, and stop/reset invalidates both notification services. The diff is confined to the two planned files. Independent byte comparison confirms the original refresh test file is an exact prefix of the revised file: 23 original methods remain and 25 were added. I found no extra product scope.

Three important requirements remain unmet.

### 1. Repeated crossings accumulate suspended refresh tasks without a bound

`Muskometer/ViewModels/GainsViewModel.swift:202-226` creates and retains one quote task for each refresh, and keeps that task alive through threshold delivery. Completing the quote phase releases the scheduler, but a below-threshold observation permits another distinct crossing while the previous delivery remains suspended. Each further below/above cycle creates another task awaiting `processUpdate`; `finishQuoteTask` cannot remove it until that delivery returns. The one-current-claim-per-preset state in the dependency does not bound these already-suspended tasks or their delivery calls.

The independent probe drives the actual scheduled loop with one enabled threshold, alternating 9B/11B and holding notification delivery at its mock boundary. After 3, 6, 9, and 12 crossings it observes respectively 3, 6, 9, and 12 suspended deliveries and owned `quoteTasks`. Thus the next crossing grows retained work again; neither normal polling nor a day change provides a fixed limit. This directly contradicts the spec's “Do not accumulate an unbounded queue of per-refresh tasks” and bounded notification-state requirement. Bound delivery ownership/coalesce pending delivery work while preserving synchronous observation ordering and the required latest crossing/retry semantics, and add a repeated-crossing regression that checks the bound before old deliveries finish.

### 2. An initial request spanning close loses the closing-request schedule

`Muskometer/ViewModels/GainsViewModel.swift:94-97` initializes `sessionClose` only after the initial quote has completed. If that request starts during the regular session and times out just after close, `currentRegularClose()` now returns nil. The close branch at lines 127-136 can no longer run, so the next request is deferred until the next regular open.

The independent probe records a real June 30 3:58 PM ET sample, starts the loop at 3:59 PM, and holds the initial quote until it fails at 4:01 PM. There are exactly two quote calls (the seed and pre-close initial request), followed immediately by a 62,940-second sleep until July 1's opening; no quote is attempted after the observed regular session closes. The real record is eventually finalized on failure, but the spec/Task 5 also requires a closing request upon leaving an observed regular session and bounded transient-close recovery. Capture the session boundary independently of initial-quote completion and cover an initial request whose success/failure spans close. The probe additionally records that while this initial request is suspended past close, the clock and displayed session have not advanced.

### 3. Advancing the current session mislabels an old regular quote as the previous day's close

`Muskometer/ViewModels/GainsViewModel.swift:616-617` correctly preserves the observation timestamp while changing the snapshot's current session to closed, but its consumers at lines 415-434 still treat `snapshot.lastUpdated` as the market-clock reference. `marketCloseStatusLabel` resolves the last market close preceding that regular-session observation, and `marketStatusDetail` asks for the next open from a time when the market was open.

After the same failed close, the actual view model retains `2026-06-30 19:58:00 +0000` as its observation, but returns `As of 4:00 PM EDT on June 29` as the visible status and nil as the next-opening detail. Repeated failures preserve that wrong date. These properties feed the popover/tooltip, so retaining the timestamp internally is insufficient to meet the spec's distinct quote-time, stale-status, and current-session requirements. Display the real last-observed time for a retained stale quote, calculate current-market scheduling information from the current clock, and test those presentation properties after closing failures/partial responses.

### Evidence and next-request checks

The independently authored hypotheses and executable harness are in `build/task5-evidence/spec-review-r1/`. `review-probe.swift` compiles the actual current application sources (excluding its app entry point), with mock quote, notification, SEC, outstanding, and login boundaries; `probe.log` contains the observations above. The probe completed successfully through the required escalated aggregate launcher with the Xcode developer directory and its own `build/task5-spec-r1-derived` cache. No real notifications/login changes, source edits, app/test-host launch outside that launcher, or remote writes were performed. No automatic approval-review rejection occurred.

Exact review command:

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/run-aggregate.py /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/.worktrees/task-5 python3 build/task5-evidence/spec-review-r1/run-probe.py`

I inspected the existing targeted log (109 tests, zero failures) and full-suite log (310 tests, zero failures); those suites were not rerun for this review. `git diff --check` passes, and `source-verification.json` confirms the reviewed source matches the stated implementation HEAD. The three probe cases are absent from the added regressions.

Other next-request traces were consistent with the contract: a late success/failure cannot overwrite a newer quote generation; a canceled/restarted SEC completion cannot clear the replacement token; failed or in-flight summaries remain pending; older acknowledgments cannot consume a newer pending value; completed/failed SEC attempts preserve existing daily backoff; and a normal already-initialized session close makes at most two attempts before overnight sleep. Those passing paths do not resolve the findings above.

## Findings

- [Muskometer/ViewModels/GainsViewModel.swift:215-226] adjudicate-race: Repeated threshold recrossings retain an unbounded number of refresh tasks while prior deliveries remain suspended.
- [Muskometer/ViewModels/GainsViewModel.swift:94-97] adjudicate-error: Initial quote completion after close loses the observed session boundary and skips the required closing request until the next open.
- [Muskometer/ViewModels/GainsViewModel.swift:616-617] adjudicate-error: Advancing a retained regular quote to closed produces a previous-day close label and omits current next-open information.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"7a49ec67-72f0-4d7a-9c8e-ee72811a4260-task-5","verdict":"needs_fixes","round":1,"findings":[{"file_path":"Muskometer/ViewModels/GainsViewModel.swift","line_range":[215,226],"category":"adjudicate-race","severity":"important","summary":"Repeated threshold recrossings retain an unbounded number of refresh tasks while prior deliveries remain suspended.","persisted_from_prior_round":false,"resolved_in_this_round":false},{"file_path":"Muskometer/ViewModels/GainsViewModel.swift","line_range":[94,97],"category":"adjudicate-error","severity":"important","summary":"Initial quote completion after close loses the observed session boundary and skips the required closing request until the next open.","persisted_from_prior_round":false,"resolved_in_this_round":false},{"file_path":"Muskometer/ViewModels/GainsViewModel.swift","line_range":[616,617],"category":"adjudicate-error","severity":"important","summary":"Advancing a retained regular quote to closed produces a previous-day close label and omits current next-open information.","persisted_from_prior_round":false,"resolved_in_this_round":false}]}
```

VERDICT: NEEDS_FIXES: Bound suspended refresh work, preserve the initial session close boundary, and correct stale-quote time presentation.

## Reviewed files

- Muskometer/ViewModels/GainsViewModel.swift
- MuskometerTests/RefreshLifecycleTests.swift
- Muskometer/Services/GainThresholdNotificationService.swift
- Muskometer/Services/DayCloseSummaryNotificationService.swift
- Muskometer/Services/DailyRecordTracker.swift
- Muskometer/Services/MarketHoursService.swift
- Muskometer/Services/UpdateCoordinator.swift
- Muskometer/Utilities/AppSettings.swift
- Muskometer/Utilities/MarketStatusFormatter.swift
- Muskometer/Models/GainsSnapshot.swift
- Muskometer/App/MuskometerApp.swift
- Muskometer/Views/SettingsView.swift
- Muskometer/Views/PopoverContentView.swift
- Muskometer/Views/MenuBarLabelView.swift
- scripts/verify.sh
- docs/marshal/specs/2026-09-10-review-fixes-design.md
- docs/marshal/plans/2026-09-10-review-fixes.md
- build/task5-evidence/done-summary.md
- build/task5-evidence/validation-results.json
- build/task5-evidence/test-preservation.json
- build/task5-evidence/validation-commands.txt
- build/task5-evidence/green-final-targeted.log
- build/task5-evidence/full-suite.log
- build/task5-evidence/spec-review-r1/hypotheses.md
- build/task5-evidence/spec-review-r1/review-probe.swift
- build/task5-evidence/spec-review-r1/run-probe.py
- build/task5-evidence/spec-review-r1/probe.log
- build/task5-evidence/spec-review-r1/source-verification.json
- /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/execution-evidence/task-3/assertion-summary.md
- /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/run-aggregate.py
- /Users/jlgolson/grok/muskometer/build/review-2026-09-10/evidence/view-model-probe.swift

reviewed-content-sha256: 3a8a0ce4089db17f069453dbf0b753f58607f12839e545e9a6197cbb05c5e9eb

plan-graph-sha256: c5582aec64ba1273dc1ddb9487db6d546ccf6879bd93cdd16eda9a28cf89a760
