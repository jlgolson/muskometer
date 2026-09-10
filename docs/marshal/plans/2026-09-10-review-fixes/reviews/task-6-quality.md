# Task 6 code-quality review

Reviewer: `/root/execute_review_fixes_resume/task6_runner/task6_quality_round1`  
Dispatch: `7301028f-8815-4597-aee4-fc8724c28cb1-task-6`  
Base: `943d5a11cf8327dd500bf6399a80570191a8971e`  
Reviewed source freeze: `e97685443d43c63895795c91e940b6c1aca8cb34`

## Scope and independent hypotheses

This is a documentation/evidence change with one executable fixture correction: two numeric constants in `scripts/verify.sh`. No product source, XCTest source, project setting, approved plan/spec, or release version changes in this task. The dispatch breadcrumb is metadata.

N/A: the documentation and JSON evidence have no executable behavior, so the Tests section's per-code-change requirement and logic-decomposition portion of File organization do not apply. For the shell fixture, I checked the actual diff, the current bundled defaults, and preservation of the surrounding verification logic. No additional test or broad rerun is warranted for changing these constants.

Before reading the diff I recorded six hypotheses: stale behavior descriptions; results bound to different source or missing tests; a fixture hiding a regression; incomplete probe reuse or inflated public/UI claims; absent or weak finding-to-test references; and changed behavior on a later verification invocation. The pre-diff record is `build/task6-quality-evidence/failure-hypotheses.md`. The return-contract overstatement below is the one confirmed issue.

## Strengths

- The documents separate dated ownership buckets, complete-result application, companyfacts totals, physical task bounds, cancellation identities, close recovery, and the limits of hosted/public evidence. The ownership budgets, screen dimensions, login states, and 400-sample limit match the inspected source.
- Independent recomputation matched all 83 manifest hashes to both the worktree and frozen commit. The raw log hash is `71c7e292585a3a4d642b8bdc97f1de1981a58120885fbb808bbee86b3bd04c1e`; its typecheck, XCTest, Release, Debug entitlement, and marketing stages pass. Its live Yahoo stage is explicitly skipped, as the documentation reports.
- I parsed the raw XCTest result tree independently: 391 unique declared cases match 391 passing executions, with no duplicate, missing, extra, failed, or skipped cases. The 47 individually named regression references in the validation README exist in that passing set. Comparing original Git source to current methods independently confirms 248 baseline cases, 243 unchanged method bodies, and exactly the five documented corrections, including two renamed cases.
- All 13 referenced probe/image artifacts and 13 historical regression artifacts match their recorded hashes. Relevant current probe sources match SEC 5/5, Yahoo 6/6, VM 7/7, and hosted UI 12/12. I read the original public/VM/UI outputs and visually inspected the 600- and 900-point hosted captures. The actual hosted XCTest also checks scrolling to the end, footer bounds, embedded Settings bounds, and the Back action. The asset-catalog, real MenuBarExtra, notification/login, and long-duration profiling limitations are stated accurately.
- The shell change matches `TrackedPersonProfile.musk` exactly and leaves endpoint requests, failure handling, gain calculation, and stage gating intact. Its next invocation creates the same fresh local constants; no new durable state, retry mechanism, or concurrency surface is introduced. File responsibilities and existing Markdown/JSON patterns remain clear.

## Issues

Critical: none. Important: none.

Minor — the new awaitable day-close contract overstates the incomplete-quote path. `docs/ARCHITECTURE.md:120` says explicit `refresh()` awaits the admitted day-close attempt it starts, and `task-6-validation/README.md:47` repeats that promise. With a pending/finalizable record and a partial quote response, `GainsViewModel.acceptQuotes` calls `advanceTradingClock()` and `beginPendingSummary()` at lines 329–336, then returns `nil`. The guard at lines 289–290 consequently returns a nil summary handle, so `refresh()` at lines 244–257 awaits no summary even though it just admitted one. A caller can return while delivery remains suspended. A following refresh can then see the existing delivery as in flight; the earlier return was not a delivery-completion barrier.

Correct both documentation statements to describe this exception and direct callers that need delivery effects to await the delivery boundary. A documentation correction is sufficient within Task 6; this review does not require expanding Task 6 into a production behavior change. This error-path contract finding is unresolved and uses the required `adjudicate-error` category. It is not self-adjudicated here.

## Assessment

The evidence is traceable, the fixture correction is narrow, and the documentation otherwise reflects the inspected implementation. The return-contract statement needs correction before approval. I performed read-only source/evidence audits and image inspection; no new app/test/probe launch, public request, notification, login change, source edit, or commit was made. Own audit outputs are under `build/task6-quality-evidence/`.

## Findings

- [docs/ARCHITECTURE.md:120] adjudicate-error: The refresh() day-close completion guarantee excludes the incomplete-quote path in code but not in this statement or task-6-validation/README.md:47.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{
  "schema_version": 1,
  "dispatch_id": "7301028f-8815-4597-aee4-fc8724c28cb1-task-6",
  "verdict": "needs_fixes",
  "round": 1,
  "findings": [
    {
      "file_path": "docs/ARCHITECTURE.md",
      "line_range": [
        120,
        120
      ],
      "category": "adjudicate-error",
      "severity": "minor",
      "summary": "The documented refresh() day-close completion guarantee is false for incomplete quote responses; the same overstatement appears in task-6-validation/README.md:47.",
      "persisted_from_prior_round": false,
      "resolved_in_this_round": false
    }
  ]
}
```

VERDICT: NEEDS_FIXES

## Reviewed files

- `docs/marshal/plans/2026-09-10-review-fixes.md`
- `docs/marshal/specs/2026-09-10-review-fixes-design.md`
- `build/task6-evidence/implementer-summary.md`
- `CHANGELOG.md`
- `docs/ARCHITECTURE.md`
- `docs/HOLDINGS.md`
- `docs/DEVELOPING.md`
- `scripts/verify.sh`
- All eight files in `docs/marshal/plans/2026-09-10-review-fixes/reviews/task-6-validation/`
- `build/task6-evidence/verify.log`, `verify.xcresult`, `xcresult-summary.json`, `xcresult-tests.json`, declared/executed identifier lists
- `build/task6-runner-evidence/round-1-freeze.json`, `independent-verification-audit.json`
- `Muskometer/Models/TrackedPersonProfile.swift`
- `Muskometer/ViewModels/GainsViewModel.swift`
- `Muskometer/Services/SECHoldingsSyncService.swift`
- `Muskometer/Services/CompanyFactsOutstandingResolver.swift`
- `Muskometer/Services/GainThresholdNotificationService.swift`
- `Muskometer/Services/IntradayGainSampleStore.swift`
- `Muskometer/Utilities/LaunchAtLoginManager.swift`, relevant `AppSettings.swift` status handling
- `Muskometer/Views/PopoverContentView.swift`, `SettingsView.swift`
- All five XCTest files for declarations and baseline method comparison; hosted layout regression body in `InterfaceAndCalendarTests.swift`
- Original SEC/Yahoo/VM/UI result JSON and 600/900 hosted PNGs under `/Users/jlgolson/grok/muskometer/build/review-fix-validation/`

reviewed-content-sha256: 3227744f027299e885ca5aefd3828a6d6fb317dfae99bd997c5ab56f875ca60b

plan-graph-sha256: c5582aec64ba1273dc1ddb9487db6d546ccf6879bd93cdd16eda9a28cf89a760
