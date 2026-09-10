# Cumulative code-quality review

Author: `/root/execute_review_fixes_resume/code_quality_round1`
Role: `code-holistic-quality`
Round: 1
Dispatch ID: `83ef825c-31f1-4d0d-9c98-aa3e518280bb-task-0`
Reviewed HEAD: `ecc673f9bc9f7a4e3987c8dcb415fb105df146f2`
Cumulative baseline and upstream snapshot: `b4ff901c56bef9302bad32b41a8fec9366182dee`

This is an independent review of the cumulative change and relevant unchanged callers. I found no actionable code-quality defect in the reviewed scope. The supplied patch is byte-identical to a freshly reconstructed Git diff for its 31 paths at the reviewed HEAD. The explicitly authorized notification-service and notification-test changes are included.

## Cold hypotheses and results

Before reading the change, I recorded three hypotheses: shared refresh state could become inconsistent after failure; notification retries or concurrent observations could lose or duplicate work; and changed helpers could violate assumptions in existing callers or tests.

1. **Refresh state after failure.** I traced initial start, complete and partial quote batches, thrown failures, manual forced refresh, accepted SEC changes, close admission with full capacity, stop/reset/restart, and superseded completions. Snapshot acceptance checks lifecycle, generation, and selected person; accepted quotes use current holdings. Quote workers release capacity independently of suspended summaries. Old quote/SEC completions cannot clear current flags or apply obsolete values. The timer advances records and current session without replacing the last successful quote timestamp. The closing obligation persists when capacity is full and is cleared on stop or next open. The late-failure path spends one retry allowance.
2. **Notification retry and concurrency.** All threshold observations and reservations are committed synchronously. Polling delivery retains one physical worker and one replaceable pending claim per person/preset; a below observation retires the old claim, and a later recross can replace queued work. Completion checks claim and lifecycle identity before changing persisted retry state. Disable/reset/day rollover invalidate semantic claims while held transports retain their physical slots. Day-close claims distinguish in-flight work from terminal skip, preserve a monotonic confirmation watermark, and acknowledge the exact pending record. No async notification tail appends old chart samples or rewrites milestone state.
3. **Existing caller and test assumptions.** I checked Settings refresh/reset/sync routes, app startup/termination, quote batching, AppSettings completeness/backoff, record persistence, chart retention, milestones, and outstanding-count persistence. The direct awaitable threshold API remains separate from the bounded polling API used by the view model. The documented incomplete-quote path can start a summary without returning its handle; the implementation and documentation agree. The Boolean login adapter remains compatible, while the real status-aware implementation avoids registering an already-pending item. The new test files are registered in the test target.

## Cross-change and next-request tracing

- **Ownership replay and freshness expiry:** each synchronization reconstructs from immutable verified anchors, rather than feeding a previous total back into the next run. Recognized zero balances survive; missing coverage, unknown bucket identity, ambiguous amendments, invalid exact numbers, and arithmetic overflow omit the affected symbol. AppSettings then preserves both prior holdings and advances only the attempt/backoff state for an incomplete result. The next automatic attempt after the existing daily interval reruns the same bounded reconstruction. The convenience parser and strict synchronization path intentionally have different date/legacy-fixture requirements. Anchor XML, transcription, effective-date selection, preferred multipliers, and option identity were checked together.
- **Companyfacts and ownership integration:** original numeric tokens are retained through structural decoding, avoiding rounded fractional values and Int64 boundary traps. Equal tied entity totals are deduplicated; conflicting DEI values cannot silently select an older GAAP fact. The unchanged outstanding service and view-model persistence keep these values separate from ownership and ignore canceled/obsolete results.
- **Threshold success/failure followed by another observation:** repeated above-threshold samples share the existing claim; failure becomes retryable on a later accepted observation without an automatic tight loop. Below/recross changes the claim identity, so the older completion cannot undo the newer state. Cancellation/relaunch preserves an unconfirmed durable crossing as retryable, and a new trading day resets its lifecycle without inventing a crossing.
- **Day-close retry and replacement:** another request for the held same day returns in-flight and leaves pending work intact. Failure/cancellation retains the record; success or terminal skip consumes only a matching value. A newer finalized day survives an older completion. Clock advancement finalizes only persisted regular-session observations, including early closes and first wake on a later day.
- **Stop/restart and saturation:** quote, SEC, and summary slots are released when physical tasks return, including canceled transports; repeated reset cannot open unbounded workers. Weak view-model captures and service-owned threshold delivery prevent a suspended boundary from retaining the model. The controlled lifecycle tests exercise both late success and late failure, multiple resets, close admission before/after its recovery window, and prompt next-open refresh.
- **Interface and settings:** fixed outer height constrains scrolling content while footer actions remain outside the scroll region. Hosted tests exercise the actual populated main view and Settings/back route at 600, 700, 800, and 900 points. I also inspected the retained 600-point capture; its standalone color limitations are documented. Pending launch-at-login intent survives reconciliation and approval; explicit disable still unregisters a pending or enabled item.

## Verification inspected

I inspected the raw combined verification log and its exit record, freshly queried the preserved `.xcresult` with `xcresulttool`, compared declared and executed identifiers, and independently recomputed the source fingerprints. The results are 391 passed, 0 failed, 0 skipped, with successful typecheck, Release build, entitlement checks, and marketing checks. All 77 product/test/project/verification-script fingerprints match the verification source manifest at this HEAD. The raw log hash matches the recorded verification result. The combined run intentionally skipped live Yahoo; separate retained public SEC/Yahoo probe outputs report successful execution, and are treated as point-in-time evidence.

An independent comparison against the original test file found 248 baseline tests and 391 current tests. Of the original methods, 243 bodies are byte-identical. Two explicitly incorrect tests were renamed and corrected (companyfacts summation and December 31, 2027); three retained methods changed for the in-flight outcome, login no-op behavior, and a missing closing XML tag. I inspected those five differences. The moved shared helpers retain the necessary visibility and actor isolation.

I did not rerun a broad green suite: the packet requires reuse of the fresh combined proof unless a new concrete concern warrants a focused execution, and this review found no such concern. No product source, other verdict, ledger, or Git state was changed. Source remained identical to the reviewed HEAD throughout the review.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"83ef825c-31f1-4d0d-9c98-aa3e518280bb-task-0","verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- CHANGELOG.md
- Muskometer.xcodeproj/project.pbxproj
- Muskometer/Services/CompanyFactsOutstandingResolver.swift
- Muskometer/Services/DailyRecordTracker.swift
- Muskometer/Services/DayCloseSummaryNotificationService.swift
- Muskometer/Services/Form4OwnershipParser.swift
- Muskometer/Services/GainThresholdNotificationService.swift
- Muskometer/Services/MarketHoursService.swift
- Muskometer/Services/SECHoldingsSyncService.swift
- Muskometer/Utilities/AppSettings.swift
- Muskometer/Utilities/LaunchAtLoginManager.swift
- Muskometer/Utilities/SPCXHoldings.swift
- Muskometer/Utilities/SPCXOwnershipCalculator.swift
- Muskometer/ViewModels/GainsViewModel.swift
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
- docs/marshal/plans/2026-09-10-review-fixes.md
- docs/marshal/plans/2026-09-10-review-fixes/.round-1-plan.md
- docs/marshal/plans/2026-09-10-review-fixes/.round-2-plan.md
- docs/marshal/specs/2026-09-10-review-fixes-design.md
- scripts/verify.sh
- Muskometer/App/MuskometerApp.swift
- Muskometer/Models/GainsSnapshot.swift
- Muskometer/Services/IntradayGainSampleStore.swift
- Muskometer/Services/NetWorthMilestoneTracker.swift
- Muskometer/Services/IssuerOutstandingSyncService.swift
- Muskometer/Services/YahooFinanceStockPriceService.swift
- Muskometer/Utilities/TradingDayCalendar.swift
- Muskometer/Utilities/MuskometerNetworking.swift
- build/final-review/code-holistic-quality-round-1-prompt.md
- build/final-review/code-round-1-cumulative.patch
- build/execution-evidence/task-6/task6-evidence/verify.log
- build/execution-evidence/task-6/task6-evidence/verify.xcresult
- build/execution-evidence/task-6/task6-evidence/xcresult-summary.json
- build/execution-evidence/task-6/task6-evidence/declared-test-identifiers.txt
- build/execution-evidence/task-6/task6-evidence/executed-test-identifiers.txt
- build/execution-evidence/task-6/task6-evidence/shared-launch-events.json
- build/execution-evidence/task-6/task6-evidence/delivery-file-hashes.json
- build/execution-evidence/task-6/task6-evidence/task-status.json
- build/execution-evidence/task-6/task6-evidence/ui-hosted-fixed-probe-result.json
- build/execution-evidence/task-6/task6-evidence/sec-round5-probe-result.json
- build/execution-evidence/task-6/task6-evidence/yahoo-final-probe-result.json
- build/execution-evidence/task-6/task6-evidence/view-model-round3-probe-result.json
- docs/marshal/plans/2026-09-10-review-fixes/reviews/task-6-validation/source-manifest.json
- docs/marshal/plans/2026-09-10-review-fixes/reviews/task-6-validation/verification-results.json
- /Users/jlgolson/grok/muskometer/build/review-fix-validation/popover-hosted-600.png

Diff-sha256: bcf8f833144c39c5e5623d35b42d92e2f3663f759ec84f8d104e8dc0c700df1f
