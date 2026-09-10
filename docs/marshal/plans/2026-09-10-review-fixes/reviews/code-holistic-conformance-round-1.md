# Cumulative conformance review — round 1

Author: `/root/execute_review_fixes_resume/code_conformance_round1`
Dispatch ID: `6b0f5adb-194e-45c3-8914-fc78557018a8-task-0`
Reviewed HEAD: `ecc673f9bc9f7a4e3987c8dcb415fb105df146f2`
Baseline: `b4ff901c56bef9302bad32b41a8fec9366182dee`

## Independent hypotheses recorded before reading the cumulative change

1. Partial ownership observations could erase unchanged buckets; filing order, amendment dates, ambiguous identities, scan boundaries, or numeric conversions could corrupt otherwise complete holdings.
2. Companyfacts grouping could still combine entity totals or silently substitute an older concept when the latest eligible data conflicts.
3. Notification awaits could reorder observable state, fail to reserve all crossings, consume a newer pending day, or let reset/rollover/old failures undo a later observation.
4. Decoupled holdings and quote tasks could recompute using stale holdings, duplicate work, block cadence, or survive stop/restart with authority to mutate new state.
5. Clock advancement could finalize synthetic or mislabeled stale data, lose a pending delivery after failure, or turn bounded closing/notification retries into overnight polling.
6. Height constraints could fail in the actual populated or embedded Settings view; login approval reconciliation could re-register or overwrite user preference; calendar changes could regress adjacent dates.
7. Test separation or harness adaptation could silently remove baseline assertions, and final verification might not correspond to the frozen cumulative source.

## Review result

The complete cumulative change conforms to the governing spec and plan. I found no blocking conformance defect or unresolved retry, error, race, or next-request defect. This is an independent source review of `origin/main..HEAD`, including the changed production code, preserved callers, tests, fixtures, project registration, documentation, and verification script. The additional Task 5 notification-service/test paths are within the authorization supplied in the dispatch.

The supplied cumulative patch's SHA-256 is `87252b5b83d45dc179190c857d60567e89763c4a5c97c11590a3d00adac91734`, matching its dispatch record. HEAD remained `ecc673f9bc9f7a4e3987c8dcb415fb105df146f2`. Production, test, project, script, and product-documentation files remained unchanged throughout this review.

## Hypothesis checks and cross-file conformance

1. **Ownership completeness, dates, and numbers.** `Form4OwnershipParser` produces normalized bucket identities and exact integer balances, and `SECHoldingsSyncService` reconstructs from immutable observations rather than feeding the previous sync result back into the next run. I independently extracted both XML fixtures' ownership rows and relevant conversion/vesting footnotes and compared them with `OwnershipAnchor`: the SPCX February report period is distinct from its later transaction dates and trusted undated June holding rows. The final direct TSLA observation is 710,172,677; the SPCX anchor preserves 13 buckets, including the zero balances and 350,000,000-option grant, totaling 5,116,475,230. Later partial reports replace only a known bucket. Ordinary same-day transaction order is local to its filing; ambiguous cross-filing totals are rejected. Amendments require a unique original bucket/date and cannot replace later effective observations. Unknown identities, absent dates, malformed relevant rows, missing anchors, and numeric overflow prevent application. The unchanged `AppSettings.applyHoldingsSync` requires all expected symbols and accepts explicit zero, so conservative omission preserves both prior holdings and provenance. Existing SPCX convenience-parser callers still use the table-total boundary; live synchronization uses the stricter dated boundary.

2. **Outstanding facts.** The resolver retains accession/form identity through preferred-form, latest-period, and filing-date selection. Equal whole-entity totals count once, while conflicting selected totals or invalid selected values resolve to no result. DEI ambiguity cannot fall through to an older GAAP value. The numeric-token parser preserves exact large integers and detects nonzero fractional digits beyond floating-point/Decimal precision. I traced the unchanged `IssuerOutstandingSyncService` and `GainsViewModel` persistence loop: unresolved facts are omitted, prior outstanding values survive, and ownership and outstanding/provenance keys remain separate.

3. **Notification suspension and state ownership.** `acceptQuotes` synchronously commits the snapshot and record/chart/milestone side effects; the quote task then calls synchronous `observeUpdate` before any newly created delivery task can suspend the actor. Every enabled preset records its observation and reserves a crossing before delivery. Claim and lifecycle identities prevent an older success/failure from writing captured observations over a newer rearm or crossing. The production polling path has one physical worker and one replaceable pending claim per person/preset. The compatible awaitable `processUpdate` also reserves all presets first and protects completion state. Persisted retry state decodes older records without the new optional field. Day-close delivery distinguishes `.inFlight` from a terminal skip, and the view model consumes only `.delivered`/`.skipped` using the exact finalized value. Reset/stop invalidate service claims and the view-model lifecycle, so old completions cannot recreate notified-day state or acknowledge replacement pending work.

4. **Independent refresh and cancellation.** `start()` begins SEC and quotes separately and the timer owns clock advancement without awaiting either boundary. The SEC guard admits one current-lifecycle synchronization on the existing `needsHoldingsSync` cadence. Accepted changed counts request one additional refresh; unchanged counts do not. Quote acceptance reads current holdings and checks person, generation, and lifecycle, preventing an earlier fetch from resurrecting old counts. Canceled physical requests retain bounded capacity until their transports return; stop/reset do not abandon handles and create an unlimited restart queue. Old completions remove only their own physical task entry and cannot clear a new lifecycle's loading/sync flags. Weak captures and the gated deallocation tests cover quote, holdings, outstanding, summary, and gain-delivery ownership. The unchanged Settings SEC action still refreshes its local text fields when synchronization finishes.

5. **Close finalization and the next session.** `DailyRecordTracker.advanceClock` loads real unfinished state and finalizes it at regular/early close without adding a quote or synthetic zero. `GainsViewModel.advanceTradingClock` changes the current session and current-clock-dependent next-open text while preserving the successful quote timestamp. Failed and partial quotes retain the prior snapshot and mark it stale. The day-close request describes the last observed session result and includes its actual observation date/time. One closing obligation waits for physical quote capacity; the recovery state allows at most one additional bounded retry. Off-market scheduling sleeps until the next regular open, whose new session supersedes old close work and triggers a prompt refresh. An incomplete quote can start a summary without returning its task handle to `refresh()`; the final documentation accurately describes this return behavior, and existing callers do not use the return as proof of notification delivery.

6. **Interface, login state, and calendar.** The main popover keeps its 360-point width, uses a screen-height bound, and places its header/footer around a scrolling region. Embedded Settings remains within that bound, with scrolling tab pages and a working Back route. The hosted regression exercises 600/700/800/900-point limits, actual scrolling, footer bounds, Settings entry, and Back clicks. I also inspected the saved 600- and 900-point hosted captures; they support layout/control placement, with the documented standalone asset-color limitation. Login reconciliation uses full registration status: pending desired registrations preserve intent without another `register`, approval becomes enabled, explicit disable unregisters, and errors are visible. The unchanged app launch and Settings activation/reopen callers reach that reconciliation. The only full-holiday edit removes December 31, 2027; its updated test proves regular trading, a 16:00 close, and January 3, 2028 at 09:30 as the next open. Other holiday and early-close entries remain intact.

7. **Tests, scope, and documentation.** I independently enumerated the baseline and current test methods and inspected every changed baseline body. All 248 baseline cases are accounted for: 243 method bodies remain identical, and the five changes are the requested calendar/companyfacts behavior (including two renamed tests), the in-flight day-close outcome, the unnecessary login-service call assertion, and a missing XML closing tag in an old fixture. The net addition is 143 tests, bringing the suite to 391. The four subsystem files are registered once in the test target, and shared helpers remain accessible. The architecture, holdings, developing guide, changelog, and bundled verification counts describe the final implementation without a version or release change. The archived plan snapshots differ only in the later explicit reset/content requirements already present in the governing plan.

## Next-request and boundary traces

- **Incomplete SEC response → immediate retry → daily expiry:** the incomplete attempt records backoff but leaves prior whole holdings and successful provenance intact. Forced retry reconstructs from the same immutable baseline; expiry re-enables the existing daily attempt rule. Replaying recognized zero remains zero. The tests cover both successful newer holdings followed by missing/empty issuer or table evidence and repeated post-backoff attempts.
- **Crossing → concurrent above observation → failure:** the existing claim suppresses duplicate submission, records the newer observation, and becomes retryable when the failed current delivery finishes. The next accepted above observation reserves a retry. A below observation clears that claim and rearms; a later distinct recross has a different identity that an old completion cannot clear. A day rollover, reset, or disable invalidates obsolete semantic claims while retaining occupied physical slots until completion.
- **Finalized day → in-flight overlap → failed or old completion:** overlap returns `.inFlight` and keeps durable pending work. Failure leaves it available after a new refresh or tracker reload. A successful old delivery cannot remove a newer pending day because acknowledgment compares the complete value; confirmation storage advances monotonically. Stop/reset invalidate outstanding claims and prevent old completions from confirming replacement work.
- **Slow quote/SEC → close → stop/restart or next open:** clock finalization proceeds independently. Saturated quote capacity retains one close obligation, and freeing capacity admits that obligation without an overnight polling loop. Recovery is bounded to one extra attempt. Lifecycle/generation checks reject stale results, physical completion frees only its slot, and next open cancels obsolete close recovery. The unchanged intraday store still caps the series at 400 samples, keeps the prior regular session overnight, and clears it on the next regular-session append.
- **Pending login approval → reopen/activation/relaunch → approval/disable:** repeated reconciliation avoids registration, preserves the desired preference, and accepts subsequent enabled status. Explicit disable unregisters pending/enabled state; a failed disable retains the still-registered service reality and an explanatory error.

## Verification inspected

I read the preserved full `verify.log`, its exit record, the raw `.xcresult` summary through `xcresulttool`, the exported result tree, and the source manifests. The recorded verification exits 0: typecheck, all XCTest cases, Release build, sandbox/network entitlements, and marketing checks pass. Live Yahoo was explicitly skipped in that deterministic verification. The raw result bundle reports **391 passed, 0 failed, 0 skipped, 0 expected failures**. My independent comparison of source declarations with the result tree found exactly 391 executions, with no missing, extra, duplicate, or nonpassing cases.

All **83 current manifest file hashes** match. The raw verification log digest matches the recorded digest. The SEC fixture/live snapshot's eight hashes, view-model snapshot's seven behavior hashes, and Yahoo snapshot's six behavior hashes also match the frozen checkout. The separate public SEC probe records TSLA 710,172,677 and SPCX 5,116,475,230, with TSLA outstanding 3,949,547,394; the separate Yahoo probe records successful TSLA/SPCX quotes. Those are dated public endpoint checks, not a guarantee of future availability. Controlled tests establish notification/login behavior without claiming actual system authorization or delivery.

No new concrete concern required an additional product probe, so I did not rerun a broad green suite or launch another app/test host. This follows the supplied verification contract. There is no unbounded persisted filing history, per-refresh alert task queue, or new long-duration memory-profile claim.

## Findings

None.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"6b0f5adb-194e-45c3-8914-fc78557018a8-task-0","verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- CHANGELOG.md
- Muskometer.xcodeproj/project.pbxproj
- Muskometer/App/MuskometerApp.swift
- Muskometer/Models/GainsSnapshot.swift
- Muskometer/Models/StockQuote.swift
- Muskometer/Services/CompanyFactsOutstandingResolver.swift
- Muskometer/Services/DailyRecordTracker.swift
- Muskometer/Services/DayCloseSummaryNotificationService.swift
- Muskometer/Services/Form4OwnershipParser.swift
- Muskometer/Services/GainThresholdNotificationService.swift
- Muskometer/Services/IntradayGainSampleStore.swift
- Muskometer/Services/IssuerOutstandingSyncService.swift
- Muskometer/Services/MarketHoursService.swift
- Muskometer/Services/SECHoldingsSyncService.swift
- Muskometer/Services/StockPriceServiceProtocol.swift
- Muskometer/Utilities/AppSettings.swift
- Muskometer/Utilities/LaunchAtLoginManager.swift
- Muskometer/Utilities/SPCXHoldings.swift
- Muskometer/Utilities/SPCXOwnershipCalculator.swift
- Muskometer/Utilities/TradingDayCalendar.swift
- Muskometer/ViewModels/GainsViewModel.swift
- Muskometer/Views/MenuBarLabelView.swift
- Muskometer/Views/PopoverContentView.swift
- Muskometer/Views/SettingsView.swift
- MuskometerTests/Fixtures/Ownership/spcx-anchor.xml
- MuskometerTests/Fixtures/Ownership/tsla-anchor.xml
- MuskometerTests/InterfaceAndCalendarTests.swift
- MuskometerTests/MuskometerTests.swift
- MuskometerTests/NotificationServicesTests.swift
- MuskometerTests/OwnershipSyncTests.swift
- MuskometerTests/RefreshLifecycleTests.swift
- docs/ARCHITECTURE.md
- docs/DEVELOPING.md
- docs/HOLDINGS.md
- docs/marshal/specs/2026-09-10-review-fixes-design.md
- docs/marshal/plans/2026-09-10-review-fixes.md
- docs/marshal/plans/2026-09-10-review-fixes/.round-1-plan.md
- docs/marshal/plans/2026-09-10-review-fixes/.round-2-plan.md
- scripts/verify.sh
- build/final-review/code-holistic-conformance-round-1-prompt.md
- build/final-review/code-round-1-cumulative.patch
- build/final-review/code-round-1-dispatch.json
- docs/marshal/plans/2026-09-10-review-fixes/reviews/task-6-validation/source-manifest.json
- docs/marshal/plans/2026-09-10-review-fixes/reviews/task-6-validation/verification-results.json
- build/execution-evidence/task-6/task6-evidence/verify.log
- build/execution-evidence/task-6/task6-evidence/verify.xcresult
- build/execution-evidence/task-6/task6-evidence/xcresult-summary.json
- build/execution-evidence/task-6/task6-evidence/xcresult-tests.json
- build/execution-evidence/task-6/task6-evidence/task-status.json
- build/execution-evidence/task-6/task6-evidence/delivery-file-hashes.json
- build/execution-evidence/task-6/task6-evidence/sec-round5-snapshot.json
- build/execution-evidence/task-6/task6-evidence/sec-round5-probe-result.json
- build/execution-evidence/task-6/task6-evidence/view-model-round3-snapshot.json
- build/execution-evidence/task-6/task6-evidence/view-model-round3-probe-result.json
- build/execution-evidence/task-6/task6-evidence/yahoo-final-snapshot.json
- build/execution-evidence/task-6/task6-evidence/yahoo-final-probe-result.json
- build/execution-evidence/task-6/task6-evidence/live-yahoo-final.json
- build/execution-evidence/task-6/task6-evidence/ui-hosted-fixed-probe-result.json
- /Users/jlgolson/grok/muskometer/build/review-fix-validation/popover-hosted-600.png
- /Users/jlgolson/grok/muskometer/build/review-fix-validation/popover-hosted-900.png

Diff-sha256: bcf8f833144c39c5e5623d35b42d92e2f3663f759ec84f8d104e8dc0c700df1f
