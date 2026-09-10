# Integrated validation — all twelve review findings

The integrated tree at `943d5a11cf8327dd500bf6399a80570191a8971e` passed **391/391 XCTest cases, zero failures, skips, or expected failures**, plus Swift typecheck, Release build, sandbox/network-client entitlement checks, and marketing HTML checks. One final combined run was performed after the Task 6 documentation and verification-fixture edits. This is implementation evidence; independent task and cumulative reviews remain the runner's responsibility.

Worktree: `/Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/.worktrees/task-6`, branch `codex/review-fixes-task-6`. Cumulative comparison starts at `b4ff901c56bef9302bad32b41a8fec9366182dee`. Task 6 changes only the four documentation files, the Yahoo fixture in `scripts/verify.sh`, and this evidence directory. The approved plan/spec, product sources, tests, project settings, and version are unchanged by Task 6.

## Findings and observed outcomes

Every test below appears as Passed in the final result bundle. Full class counts and commands are in [verification-results.json](verification-results.json). Exact production/test SHA-256 values are in [source-manifest.json](source-manifest.json); the source column identifies the relevant files within that manifest. Historical red counts are grouped by their actual run below, not attributed individually to unrelated tests.

| Original finding | Specific regression evidence | Final outcome and relevant source |
|---|---|---|
| 1. Partial Form 4 replaces whole SPCX holding | `OwnershipReconciliationTests/testClassAOnlySalePreservesClassBTrustsAndOptionsAndIsIdempotent()`; `testVerifiedAnchorsRemainUnchangedDespiteFebruaryReportDate()` | PASS: dated bucket replacement preserves Class B/trust/options and replay totals. `SECHoldingsSyncService`, `Form4OwnershipParser`, `SPCXHoldings`, `SPCXOwnershipCalculator`. |
| 2. Historical amendment rolls holdings backward | `OwnershipReconciliationTests/testLateHistoricalAmendmentCannotReplaceNewerBalance()`; `testUniquelyTargetedAmendmentCorrectsOriginalBalance()`; `testAmendmentCannotChooseAmongMultipleOriginalRowsOnOneDay()` | PASS: effective dates win; only uniquely identified historical corrections apply. Same ownership sources. |
| 3. Full SPCX disposal restores positive balance | `OwnershipReconciliationTests/testRecognizedZeroDisposalSurvivesParser()`; `testFullDisposalZerosEveryPositiveAnchorBucket()` | PASS: recognized zero survives parsing/reconstruction; invalid or absent data remains unresolved. Same ownership sources. |
| 4. Older refresh overwrites newer samples/milestone | `GainsViewModelLifecycleRegressionTests/testOlderSuccessfulSummaryCannotOverwriteNewSamplesOrMilestone()`; `testOlderFailedSummaryRetainsPendingAndNewSamplesOrMilestone()`; `testThresholdObservationsFollowAcceptedSnapshotsWhileOldSummaryWaits()` | PASS: accepted snapshot state commits before delivery suspension. Original VM probe retains newest $1.001T, `aboveOneTrillion`, samples `[9B, 21B]`. `GainsViewModel`, `DailyRecordTracker`, threshold service. |
| 5. Overlap loses pending day-close notification | `NotificationSuspensionRegressionTests/testDayCloseInFlightFailureRetainsDurablePendingDay()`; `testIdentityConsumeRequiresExactFinalizedValueAndPersistsClear()`; `GainsViewModelLifecycleRegressionTests/testOlderDaySummaryCannotAcknowledgeNewPendingDay()` | PASS: in-flight/failure retains pending state; only exact confirmed/terminally skipped value is acknowledged. `DayCloseSummaryNotificationService`, `DailyRecordTracker`, `GainsViewModel`. |
| 6. Threshold completion erases rearm | `NotificationSuspensionRegressionTests/testOlderSuccessCannotEraseBelowThresholdRearm()`; `testFailureAfterNewerAboveObservationRemainsRetryable()`; `testEveryPresetObservationAndClaimIsCommittedBeforeFirstAwait()`; `BoundedThresholdObservationTests/testCoalescesRepeatedRecrossingsAndDeliversNewestPendingValue()` | PASS: newer observations and distinct crossings survive old completion; polling delivery remains bounded. `GainThresholdNotificationService`. |
| 7. SEC blocks quotes / duplicate refresh | `GainsViewModelLifecycleRegressionTests/testGatedSECDoesNotBlockInitialQuotesAndChangedCountsRefreshOnce()`; `testUnchangedSECSyncDoesNotAddQuoteRefresh()`; `testCountChangeDuringFetchUsesCurrentHoldings()` | PASS: one initial quote batch while SEC waits; changed counts cause one further batch, unchanged counts none. `GainsViewModel`. |
| 8. Failed close does not finalize day | `GainsViewModelLifecycleRegressionTests/testFailedClosingFetchFinalizesLastRealObservationAndUpdatesSession()`; `testLoopBoundsCloseRetryAndRefreshesImmediatelyNextOpen()`; `testLateClosingFailureStillGetsOneBoundedRecovery()`; `testStaleStatusUsesObservationTimeAndObservableCurrentClock()` | PASS: real last observation finalizes with timestamp/stale status preserved; bounded recovery and next-open scheduling progress independently. `GainsViewModel`, `DailyRecordTracker`, day-close service. |
| 9. Popover exceeds small screen | `PopoverLayoutRegressionTests/testPopulatedPopoverFitsAvailableHeightAndRetainsScrolling()` and actual NSHostingView captures at 600/700/800/900 | PASS: 360-wide main view and embedded Settings fit height constraints; scrolling and footer controls remain reachable. `PopoverContentView`, `SettingsView`, related views/glass utility. Hosted captures establish layout/controls only. |
| 10. Login approval mistaken for unregistered | `LoginStatusRegressionTests/testPendingRegistrationSurvivesReopenRestartAndApproval()`; `testRepeatedEnableDoesNotRegisterPendingOrEnabledServiceAgain()`; `testDisableUnregistersPendingAndEnabledOnlyOnce()`; `testUnavailableDoesNotAttemptRegistrationAndSurfacesError()` | PASS with boundary mocks: pending desired registration survives reopen/restart/approval; explicit disable and errors remain correct. `LaunchAtLoginManager`, `AppSettings`. |
| 11. December 31, 2027 skipped | `MarketHoursServiceTests/testDecember31_2027IsRegularTradingBeforeSaturdayNewYear()` | PASS: regular at 11 AM ET; next opening after close is January 3, 2028, 9:30 AM ET. `MarketHoursService`. |
| 12. Amended outstanding facts doubled | `CompanyFactsDeduplicationTests/testEqualOriginalAndAmendmentTotalsCountOnce()`; `testConflictingTiedFactsDoNotFallBackToOlderGAAP()`; `testFractionsBeyondDecimalPrecisionAreRejectedExactly()` | PASS: equal whole-entity facts count once; conflicts remain unresolved; exact integer validation rejects fractional/overflowing tokens. `CompanyFactsOutstandingResolver`. |

## Baseline and bounded-work checks

The mechanical test split passed all 248 original cases with byte-identical method bodies. The final audit accounts for all 248: **243 unchanged bodies**, plus these five reviewed corrections:

- Companyfacts summation test renamed/replaced by conflicting-total refusal.
- December 31 holiday test renamed/replaced by the correct regular-session expectation.
- Concurrent day-close test expects `.inFlight` rather than terminal `.skipped`.
- Already-unregistered login reset clears stale error without another service call.
- SPCX XML fixture closes its missing `ownershipNature` tag; expected total stays 5,116,475,230.

There are exactly two identifier replacements and no unaccounted removals. All **391 current declarations were matched one-for-one to executed cases**. [baseline-preservation.json](baseline-preservation.json) records before/after method hashes, assertion counts, and the original split evidence. The final declaration audit includes extension methods and excludes nested helper class names.

| Bound / lifecycle behavior | Passing final regression |
|---|---|
| 400 current chart samples | `IntradayGainSampleStoreTests/testCapsAt400Samples()` |
| 100 accession, 10 archive-page, 100 descriptor, 10,000-observation budgets; at most 211 HTTP requests per sync; cancellable pacing | `OwnershipReconciliationTests/testHundredAccessionBudgetDoesNotClaimTruncatedCoverage()`, `testCancellationStopsTheBoundedScan()`; all 6 `OwnershipArchiveBudgetTests` |
| One physical polling worker plus one latest pending claim per person/preset, including reset and repeated recrossing | All 10 `BoundedThresholdObservationTests`; `GainsViewModelLifecycleRegressionTests/testRepeatedRecrossingsBoundActualSuspendedDeliveriesAndRetainedWork()` |
| Maximum two quote batches, two SEC synchronization tasks, and two summary tasks physically outstanding per VM; only one current-lifecycle SEC sync | `GainsViewModelLifecycleRegressionTests/testRestartStormBoundsCancellationUnawareQuoteAndSECRequests()`; `testRepeatedResetBoundsDayClosePhysicalWorkWithoutBlockingQuotes()` |
| Stop cancels/invalidates work and permits VM release despite slow services | `testStoppedOwnedServicesDoNotRetainViewModel()`, `testStoppedOutstandingServiceDoesNotRetainViewModel()`, `testStoppedSummaryDeliveryDoesNotRetainViewModel()`, `testRepeatedModelResetsBoundPhysicalGainDeliveryAndAllowDeallocation()` in `GainsViewModelLifecycleRegressionTests` |
| One deferred close obligation and at most one recovery retry | `testSaturatedCloseAdmitsWhenCapacityFreesBeforeRecoveryWindow()`, `testSaturatedCloseAdmitsAfterWindowAndRetainsOneRetry()`, `testSuccessfulDeferredCloseDoesNotAddRetry()`, `testStopCancelsSaturatedCloseObligation()` in the same class |

The two physical slots are real transport/task bounds, not discarded handles: canceled transports retain capacity until completion. `refresh()` awaits admitted quote work and the admitted day-close attempt it starts, but does not await background gain delivery. `observeUpdate` records threshold state synchronously; direct `processUpdate` remains awaitable. Tests/probes wait for actual controlled delivery effects when asserting them. These are bounded regression checks, not an exhaustive Instruments or long-duration soak certification.

## Commands and results

The one final combined command (exit **0**) was:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer MUSKOMETER_SKIP_LIVE_YAHOO=1 python3 /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/run-aggregate.py /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/.worktrees/task-6 scripts/verify.sh > build/task6-evidence/verify.log 2>&1
```

The shared launcher serialized this run, gracefully quit any existing Muskometer with NSWorkspace, verified an empty app listing, and inserted `-parallel-testing-enabled NO` for the nested XCTest command. `scripts/verify.sh` ran Swift typecheck, the complete Debug XCTest target, Release build, Debug-product sandbox/network entitlements, and marketing checks. Live Yahoo was intentionally skipped in this deterministic command; unchanged-source public evidence below supplies that separate check.

Result bundle inspection used `xcrun xcresulttool get test-results summary` and `tests`, with `--path` and `--format json`; exact argument arrays and stage output are in [verification-results.json](verification-results.json). Raw output and a preserved 5.1 MB `.xcresult` are under `build/task6-evidence/`. No derived-data build cache belongs in Git. The log has existing async NSLock warnings in the unchanged shared mock, four weak-variable suggestions in reviewed lifecycle tests, and Xcode destination-selection warnings; no compiler error or failed assertion. Initial result extraction misattributed methods to nested helper classes; correcting the inspection script and reading the same completed bundle resolved that audit error without rerunning tests.

Historical red/green evidence is preserved under `/Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/execution-evidence/`. [historical-regression-results.json](historical-regression-results.json) records exact source-artifact pointers and SHA-256 values; these counts belong to their earlier branch states and are not additional final integrated runs.

| Historical run | Actual result | Artifact relative to preserved evidence root |
|---|---|---|
| Task 1 mechanical split, full XCTest | 248 pass / 0 fail | `task-1/verification-summary.json` |
| Task 2 original ownership/companyfacts red | 18 fail / 6 control pass | `task-2/red-assertions.json`, `red-valid-accessions.log` |
| Task 2 final-round parser red → green | 5 fail / 3 control pass → 8 pass; complete ownership suite 93 pass | `task-2/round-5/validation-results.json` (189 red assertion failures) |
| Task 3 notification red → green | 21 fail / 5 control pass; expanded red 27 fail / 5 pass; closed-rollover red 1 fail → final targeted 54 pass | `task-3/red-summary.json`, `red-additional-summary.json`, `red-closed-rollover-summary.json`, `green-final-summary.json` |
| Task 4 interface/calendar red → green | 8 fail / 23 control pass → 44 targeted pass | `task-4/red-summary.json`, `targeted-final-summary.json` |
| Task 5 lifecycle initial red | 13 fail / 0 pass | `task-5/red-summary.json` |
| Task 5 final-round bounded work red → green | 9 tests, 22 assertion failures → 87 targeted pass; branch full suite 336 pass | `task-5/round-3/validation-results.json` |
| Final integrated Task 6 | **391 pass / 0 fail / 0 skip**, plus all deterministic script stages | [verification-results.json](verification-results.json) |

These are real Xcode assertion failures, not compilation failures counted as red. Task 6 adds no product behavior or tests. Its compatibility correction changes only the stale live-math share counts from 699,580,882 / 6,068,734,060 to the current bundled 710,172,677 / 5,116,475,230; [fixture-compatibility.json](fixture-compatibility.json) records the source check. Existing live verification assertions remain.

## Reused production probes

[probe-source-reuse.json](probe-source-reuse.json) independently compares every relevant source hash and hashes the original results/images. Original probe root: `/Users/jlgolson/grok/muskometer/build/review-fix-validation/`. Small JSON copies are in `build/task6-evidence/`; original image pointers remain valid. No duplicate network/VM/UI run was needed.

| Probe and source identity | Matching source files | Observed result |
|---|---:|---|
| SEC final round 5, `sec-round5-snapshot.json`; Task 2 source `fb92ee462cf9dda9980f18e3096b86e67f436eec` | 5/5 | September 10, 09:03:26Z: TSLA 710,172,677; SPCX 5,116,475,230; TSLA outstanding 3,949,547,394, period 2026-07-16/filed 2026-07-23. SPCX absent uses existing fallback. Production service time 1.606s; compile/run exit 0; 19.886s total. |
| Yahoo final, source `50d7946cb694e44c39ab04484ead60fd7c3b3e2c` | 6/6 | September 10, 09:06:42Z: TSLA 367.81 / previous 368.16; SPCX 147.55 / previous 153.47; USD, finite positive. Service time 0.266s; compile/run exit 0; 18.036s total. |
| Original VM reproduction, source `adab4cb0efa2142900cac456abf817b97e315d14` | 7/7 | Initial quote before gated SEC; changed 2 batches/unchanged 1; failed close preserves timestamp/stale/finalized record; Monday 9:30 next-open label; newest milestone/samples; failed summary stays pending. Compile/run exit 0, 16.184s. |
| Actual hosted UI, source `e89dcce91420ec5fbcb7c7414a27339eab418999` | 12/12 (11 view files + glass utility) | 360×600/700/800/900 fitting and captures passed, compile/run exit 0, 20.787s. Task 6 re-inspected the actual 600/900 PNGs: Refresh, Settings, Quit and footer remain visible. |

The public checks are point-in-time results, not endpoint availability guarantees. Hosted CLI evidence lacks the asset catalog: layout and controls are validated; color fidelity and real MenuBarExtra interaction on every physical display are unverified. ImageRenderer placeholder outputs are excluded. Notification/login boundaries were mocked, with no real alerts, login changes, external messages, release, or deployment.
