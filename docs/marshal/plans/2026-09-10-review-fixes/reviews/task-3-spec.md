# Task 3 spec compliance review

Reviewed commit `4a7c66c519970186a9758af34dd4e5d6d652eff7` against base `38ae64739615d72d23fa8ee77ddd6aee0c5a54c5`, using `docs/marshal/specs/2026-09-10-review-fixes-design.md` (Notification and refresh ordering; Refresh scheduling and close finalization; Tests and integration; Scale & Validation), the approved plan's Task 3, and `build/task3-description.md`, including its additional overlapping-day requirement. The actual diff contains exactly the four declared source/test files. No missing, extra, or misinterpreted Task 3 requirements were found; GainsViewModel integration remains correctly assigned to Task 5.

## Independent hypotheses and traces

Before reading the change, I considered lost below-threshold observations, duplicate overlapping crossings, later presets evaluated after suspension, failed claims becoming non-retryable, stale failures erasing a newer crossing, stale reset/rollover completions, mistaken in-flight day acknowledgements, cross-day confirmation regression, and clock-only finalization inventing or replacing samples. I then traced the source and the next observation, retry, cancellation, reset, rollover, and delayed completion for each applicable path.

`GainThresholdNotificationService.swift:92–169` advances existing lifecycles on day changes, commits every enabled preset's observation and reservation before suspension, and checks lifecycle plus claim identity before changing completion state. Above-threshold overlap retains the current claim; a failure releases it with retry intent; a below-threshold observation rearms and supersedes it. A later recross owns a different claim, so an older success or failure cannot overwrite that observation or release the replacement. Cancellation leaves unconfirmed claims retryable, and reset/rollover prevents stale state writes. State remains one entry per preset/person with a bounded claims array per call and no spawned task queue. The optional persisted `retryPending` field preserves legacy decoding (`:172–195`).

`DayCloseSummaryNotificationService.swift:17–25,42–108` distinguishes in-flight, failed, skipped, and confirmed outcomes. Runtime reset invalidates only the selected person's claims. Both success and failure release only their own UUID; stale completion cannot release a replacement or persist confirmation. Different days have separate claims and successful completion advances the persisted day monotonically. `DailyRecordTracker.swift:112–115` acknowledges only full equality with the supplied finalized value, so an older acknowledgement cannot remove a newer pending value. Existing static persisted-reset APIs and the original consume overload are retained.

`DailyRecordTracker.swift:120–129,157–220` loads durable unfinished/pending state, rejects backward-day advancement, and finalizes real observations using the stored session's regular/early close even at the next session's open. It creates no quote and retains the actual last gain, extremes, and observation date (`:223–239`). Day-close content explicitly identifies the last observed session result and formats that date in Eastern time (`DayCloseSummaryNotificationService.swift:64–74`).

## Verification and coverage

Read the regression source and supplied assertion evidence, not only the implementer's summary. `NotificationServicesTests.swift:842–1375` covers the required 9→11(await)→8→complete→12 sequence, overlapping above-threshold updates, all gain/loss presets, failure/above/below/recross interleavings, replacement claims, cancellation/reset/day rollover, legacy decoding, both overlapping-day completion orders, exact pending acknowledgement, message wording/time, ordinary and early close, relaunch, next-day clock advancement, and empty/backward clock updates.

The persisted red-result artifacts record assertion failures for the original behaviors (21 failures initially, 27 in the expanded run, and the later closed-market rollover assertion). Recorded final results are 54/54 targeted and 278/278 full-suite tests passing, with zero failures/skips. The test inventory retains all 248 baseline methods and adds 30. The sole changed baseline assertion is the intended concurrent day-close result from `.skipped` to `.inFlight`. I independently ran the commit-range whitespace check and verified the reviewed HEAD; I did not rerun app/test hosts. The exact Task 5 API handoff is present in `build/task3-evidence/assertion-summary.md`.

## Reviewed files

- Muskometer/Services/GainThresholdNotificationService.swift
- Muskometer/Services/DayCloseSummaryNotificationService.swift
- Muskometer/Services/DailyRecordTracker.swift
- MuskometerTests/NotificationServicesTests.swift

## Findings

None.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"9886454f-c0d6-46fd-9a3e-1f5b686af399-task-3","verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

reviewed-content-sha256: 281c1921bfd9a5b20296793f5ffc0cd9eff4c62879b19e60a7a06fcc92554889

plan-graph-sha256: c5582aec64ba1273dc1ddb9487db6d546ccf6879bd93cdd16eda9a28cf89a760
