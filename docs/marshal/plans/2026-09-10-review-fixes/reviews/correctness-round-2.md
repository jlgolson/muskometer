# Plan correctness review — round 2

The plan is ready for implementation. I found no substantive correctness, dependency, ownership, or required-verification gap against the supplied corrective specification.

## Reviewed files

- `docs/marshal/plans/2026-09-10-review-fixes.md` — complete plan.
- `docs/marshal/specs/2026-09-10-review-fixes-design.md` — complete specification.
- `Muskometer/Services/SECHoldingsSyncService.swift`, `Form4OwnershipParser.swift`, `CompanyFactsOutstandingResolver.swift`, `HoldingsSyncServiceProtocol.swift`, and `IssuerOutstandingSyncService.swift`.
- `Muskometer/Utilities/SPCXHoldings.swift`, `SPCXOwnershipCalculator.swift`, `AppSettings.swift`, `LaunchAtLoginManager.swift`, and `TradingDayCalendar.swift`.
- `Muskometer/Services/GainThresholdNotificationService.swift`, `DayCloseSummaryNotificationService.swift`, `DailyRecordTracker.swift`, `MarketHoursService.swift`, and `IntradayGainSampleStore.swift`.
- `Muskometer/ViewModels/GainsViewModel.swift`, `Muskometer/Models/GainsSnapshot.swift`, and `Muskometer/Models/TrackedPersonProfile.swift`.
- `Muskometer/Views/PopoverContentView.swift` and the relevant sizing, login reconciliation, reset, and refresh callers in `Muskometer/Views/SettingsView.swift`.
- `MuskometerTests/MuskometerTests.swift` — test inventory, shared helpers, and relevant ownership, companyfacts, login, calendar, records, notification, and view-model regressions.
- `Muskometer.xcodeproj/project.pbxproj` and `scripts/verify.sh`.
- Original executable harnesses: `build/review-2026-09-10/evidence/data-probe.swift`, `view-model-probe.swift`, `ui-probe.swift`, and `records-main.swift` in the primary checkout.
- Public source XML fixtures: `/tmp/muskometer-review-tsla-form4.xml` and `/tmp/muskometer-review-spcx-form4.xml`.

## Correctness and dependency assessment

The declared graph is acyclic and all dependencies exist: `1 → {2,3,4}`, `{1,3} → 5`, and `{2,4,5} → 6`. Task 1 owns the shared test split and Xcode registration before behavioral work. Tasks 2, 3, and 4 then write disjoint production and test files. Task 5 consumes Task 3's explicit notification and tracker APIs; Task 6 follows every behavioral branch. Shared helper visibility changes are expressly permitted for the mechanical split. The plan prohibits competing writes to shared tests/project files and competing Xcode runs in one derived-data directory.

`HoldingsSyncResult.sharesBySymbol` and the existing AppSettings completeness check can accept recognized zero holdings without an interface change. The supplied TSLA fixture's last direct common transaction has 710,172,677 shares on June 16. SPCX's 13 final source buckets total 5,116,475,230, while its `periodOfReport` is February 2. Task 2 explicitly preserves those anchors and avoids treating that report date as the latest balance date.

The new `inFlight` outcome, matching pending-day acknowledgement, and person-scoped runtime invalidation address different state transitions and are all integrated by Task 5. Moving observable mutations before notification suspension is compatible with the existing tracker/store interfaces. The plan also requires threshold observations to begin in accepted-snapshot order, preventing merely moving the original ordering race behind another await.

## Corrective outcome coverage

| Finding | Planned implementation and regression evidence |
|---|---|
| 1 | Task 2 reconstructs dated buckets from the complete anchor; an A-only sale must preserve B/options. |
| 2 | Task 2 orders effective observations and tests historical amendments, supersession, unique corrections, and ambiguity refusal. |
| 3 | Task 2 distinguishes recognized zero from missing/invalid data and tests full disposal and integer bounds. |
| 4 | Task 5 tests overlapping actual view-model refreshes and requires synchronous sample/record/milestone commits before suspension. |
| 5 | Task 3 tests crossing reservation, rearm/recross, multiple presets, delivery failure, reset, and day rollover. |
| 6 | Tasks 3 and 5 test in-flight summary delivery, failure retention, matching acknowledgement, and stale completion invalidation. |
| 7 | Task 5 tests gated independent SEC work, quote progress, bounded extra refresh, current counts, cancellation, restart, and deallocation. |
| 8 | Tasks 3 and 5 test independent clock finalization, last-observed notification text/time, real-loop closing attempts/retry limits, next-open wake, and early close. |
| 9 | Task 4 checks actual populated NSHostingView fitting size at 600/700/800/900 points and keeps scrolling/footer/settings routes available. |
| 10 | Task 4 uses a full-status login mock for pending/reopen/approval, explicit disable, failure, and repeated reconciliation. |
| 11 | Task 4 corrects the December 31, 2027 expectation and tests the January 3, 2028 next open. |
| 12 | Task 2 deduplicates equal facts, refuses conflicting ties without stale concept fallback, and preserves preferred form/concept rules. |

The source inventory contains exactly 248 baseline test methods, matching Task 1's preservation target. Behavioral tasks require observed failing assertions before implementation and passing regressions afterward. Task 6 names the implementer, the full verification command, original source-path probes, actual SwiftUI sizing, and separately reported public-data availability. This review performed read-only structural/source checks; it does not claim the future implementation tests have run.

## Machine-readable verdict

```json
{
  "schema_version": 1,
  "dispatch_id": "f02f8205-5b9d-4f5e-bd3d-992dd104f00c-task-0",
  "verdict": "approved",
  "round": 2,
  "findings": []
}
```

## Findings

None.

VERDICT: APPROVED

reviewed-content-sha256: cdb6192c44be65243b8cefa00c7e9a6f5ce2cb2bac9dd8630cc96d5a5c584710

plan-graph-sha256: c5582aec64ba1273dc1ddb9487db6d546ccf6879bd93cdd16eda9a28cf89a760
