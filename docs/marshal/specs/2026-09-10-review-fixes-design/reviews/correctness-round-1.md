# Correctness review

dispatch_id: c7d4c48a-18e9-4b75-89b2-81d61cded024-task-0
MARSHAL_ROLE: spec-correctness
MARSHAL_TASK_ID: 0
MARSHAL_PLAN_SLUG: 2026-09-10-review-fixes-design
MARSHAL_ROUND: 1

The spec is ready for implementation planning. I read the full spec and checked the relevant source, existing tests, executable reproduction fixtures, recorded probe output, and cited external contracts. This is a specification assessment; it does not claim that the proposed fixes have been implemented or verified.

The failure hypotheses checked were incomplete ownership reconstruction, amendment ordering overriding newer balances, ambiguous companyfacts totals, stale asynchronous completions rewriting accepted state, lost pending notifications, quote polling blocked by SEC work, failure to advance the trading clock after a quote error, unconstrained embedded content, and confusion between desired login preference and actual registration status.

The strongest requirements should remain: a verified dated ownership baseline with conservative omission; explicit separation of ownership and issuer outstanding; synchronous state acceptance before notification suspension; completion identity checks and retry preservation; clock-driven finalization using the actual last sample; lifecycle cancellation of independently owned SEC work; and tests of the actual populated SwiftUI views. These requirements address the source-level defects without requiring unrelated product changes.

The interface boundaries are compatible with the codebase. AppSettings already accepts recognized zero holdings and applies only complete expected-symbol results. DailyRecordTracker already persists unfinished and pending days, and its finalized record carries the last sample date, so the proposed clock advancement and specific-day acknowledgment can preserve existing records. The notification deliverer protocols and quote/SEC service boundaries support deterministic suspended-completion tests. The proposed sleeper injection addresses the missing real-loop test seam. The current login abstraction exposes only a Boolean, so the specified status expansion is necessary and directly testable.

The test movement is explicitly an initial assertion-preserving step; the subsequent corrective work must update assertions that encode the reviewed bugs. The new behavior, boundary inputs, interleavings, cancellation, bounds, and UI constraints are sufficiently specified for the implementation plan to select concrete fixtures and mechanics. The required `Scale & Validation` and `Deferred` sections are present, and `Deferred` uses the canonical `None.` body.

The external assumptions are sourced. SEC Form 4 separates transaction dates from amendment filing dates and reports ownership by security class ([Form 4](https://www.sec.gov/files/form4.pdf)). SEC's XBRL APIs describe facts applying to the entire filing entity ([EDGAR API documentation](https://www.sec.gov/search-filings/edgar-application-programming-interfaces)). NYSE explicitly lists no observed New Year's holiday for January 1, 2028 ([NYSE calendar](https://www.nyse.com/trade/hours-calendars)). The installed Apple SDK header confirms that requires-approval services are registered and registration of an already registered service can fail; the spec supplies Apple's canonical status and registration links as well.

## Reviewed files

- `docs/marshal/specs/2026-09-10-review-fixes-design.md` — full spec.
- `Muskometer/Services/Form4OwnershipParser.swift`
- `Muskometer/Services/SECHoldingsSyncService.swift`
- `Muskometer/Utilities/SPCXOwnershipCalculator.swift`
- `Muskometer/Utilities/SPCXHoldings.swift`
- `Muskometer/Services/CompanyFactsOutstandingResolver.swift`
- `Muskometer/Services/GainThresholdNotificationService.swift`
- `Muskometer/Services/DayCloseSummaryNotificationService.swift`
- `Muskometer/Services/DailyRecordTracker.swift`
- `Muskometer/ViewModels/GainsViewModel.swift`
- `Muskometer/Utilities/AppSettings.swift` — holdings, persistence, login reconciliation, and reset paths.
- `Muskometer/Utilities/LaunchAtLoginManager.swift`
- `Muskometer/Utilities/TradingDayCalendar.swift`
- `Muskometer/Services/MarketHoursService.swift`
- `Muskometer/Views/PopoverContentView.swift` — containing layout and populated content.
- `Muskometer/Views/SettingsView.swift` — containing layout, embedded route, and reconciliation hooks.
- `Muskometer/App/MenuBarPopoverPresenter.swift`
- `MuskometerTests/MuskometerTests.swift` — relevant ownership, companyfacts, login, concurrency, record, and scheduling coverage.
- `docs/HOLDINGS.md`
- `scripts/verify.sh`
- `/Users/jlgolson/grok/muskometer/build/review-2026-09-10/evidence/data-probe.swift`
- `/Users/jlgolson/grok/muskometer/build/review-2026-09-10/evidence/view-model-output.txt`
- `/Users/jlgolson/grok/muskometer/build/review-2026-09-10/evidence/ui-output.txt`
- `/tmp/muskometer-review-spcx-form4.xml` — report and row date fields.
- `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/ServiceManagement.framework/Headers/SMAppService.h` — status and registration contracts.

## Findings

None.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"c7d4c48a-18e9-4b75-89b2-81d61cded024-task-0","verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

reviewed-content-sha256: 28a0c19a8ba6021ac4b3d724112df87612405ae1c3bac27b4e24337faa745be6
