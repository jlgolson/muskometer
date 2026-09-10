## Parallelism analysis

The declared graph safely supports Tasks 2, 3, and 4 after Task 1, and Task 5 after Task 3 while Tasks 2 and/or 4 remain active. There are five unordered concurrent pairs: {2, 3}, {2, 4}, {2, 5}, {3, 4}, and {4, 5}. This approval relies on the stated execution model: separate implementer worktrees, dependency results present before dispatch, exclusive source-file ownership, controller integration, and serialized aggregate Xcode validation. No additional dependency edge is required.

This is an independent static analysis of the plan and current source/test dependencies, not a claim that the future split or fixes already pass tests. The suspected failure modes checked were incomplete helper extraction, conflicting project/resource edits, new APIs consumed before definition, concurrent edits to shared settings/calendar contracts, and shared mutable test state. The constraints below make the existing boundaries concrete without changing the plan.

MARSHAL_TASK_ID: 0
MARSHAL_PLAN_SLUG: 2026-09-10-review-fixes
MARSHAL_ROLE: parallelism-analyst
MARSHAL_ROUND: 1
dispatch_id: ac6e9023-6c65-4ae7-95d4-d1d0b607cb78-task-0

Reviewed plan: `docs/marshal/plans/2026-09-10-review-fixes.md`

Plan Git blob: `c11d925adad41791ea9360c36ba53b926bba2fba`

Source checkout HEAD at inspection: `50474f800c1364a49ff4b71e1bd78d2b55aace07`

Plan-graph-sha256: c5582aec64ba1273dc1ddb9487db6d546ccf6879bd93cdd16eda9a28cf89a760

The requested `scripts/plan_graph.py` is absent from Marshal 0.37.0. The digest above was computed using the inspected, available `scripts/_plan_graph_hash.py` API, `compute_plan_graph_hash(Path(...))`. Its files-block parser also captures checklist bullets until the next section heading in this plan's layout; consequently some checklist edits will invalidate this digest as well. The Git blob identifies the entire exact reviewed plan.

## DAG and allowed batches

Declared predecessors:

| Task | Predecessors | Required artifact or contract |
| --- | --- | --- |
| 1 | None | Mechanical split and registered test sources |
| 2 | 1 | Ownership test file and shared helper visibility |
| 3 | 1 | Notification/record test file and shared helper visibility |
| 4 | 1 | Interface/calendar test file and moved login mock |
| 5 | 1, 3 | Refresh test file plus completed notification/record APIs |
| 6 | 2, 4, 5 | All fixes integrated; Task 3 is a transitive prerequisite |

The effective structure is `1 → {2, 3, 4}`, `3 → 5`, `{2, 4, 5} → 6`. The explicit `1 → 5` edge is redundant transitively but harmless. Task 1 is a real prerequisite because it owns every initial test-file creation and project registration. Task 3 is a real prerequisite of Task 5 because it supplies `inFlight`, matching pending-day consumption, clock advancement, and instance day-close lifecycle invalidation. Task 6 must remain after the complete fan-in because its verification, documentation, and possible integration fixes read/write prior task outputs.

Allowed maximal work sets are `{1}`, then `{2, 3, 4}`, then `{2, 4, 5}` once Task 3 has completed its review gate. Any ready subset is also safe; Task 5 need not wait for either Task 2 or Task 4. Task 6 begins only after Tasks 2, 4, and 5 pass and are integrated. “After” includes the plan's required reviews and delivery of the actual prerequisite changes into the child's starting tree, not merely receipt of an implementer's message.

For the cost-benefit heuristic, remove common prerequisite Task 1 and final integration Task 6. The independent work components are ownership `{2}` (size 1), notification/refresh `{3, 5}` (size 2), and interface/calendar `{4}` (size 1). Ratios below use these component sizes. The installed threshold resolver returns `0.25`; all ratios meet it. These are structural estimates, not promises about wall-clock duration, especially for the larger SEC task.

## Explicit write and read sets

Paths below are repository-relative. Each task additionally reads its own write set, the plan/spec, and the existing target configuration. Building reads the complete target; that read-only build dependency does not grant write ownership.

| Task | Exclusive write set | Relevant external read set |
| --- | --- | --- |
| 1 | `MuskometerTests/MuskometerTests.swift`; create `MuskometerTests/OwnershipSyncTests.swift`, `NotificationServicesTests.swift`, `InterfaceAndCalendarTests.swift`, `RefreshLifecycleTests.swift`; `Muskometer.xcodeproj/project.pbxproj` | All existing test identifiers/bodies and production signatures required to preserve the split |
| 2 | `Muskometer/Services/SECHoldingsSyncService.swift`, `Form4OwnershipParser.swift`, `CompanyFactsOutstandingResolver.swift`; `Muskometer/Utilities/SPCXHoldings.swift`, `SPCXOwnershipCalculator.swift`; `MuskometerTests/OwnershipSyncTests.swift`; optional `MuskometerTests/Fixtures/Ownership/*` | `HoldingsSyncServiceProtocol.swift`, `IssuerOutstandingSyncService.swift`, `AppSettings.swift` holdings application/migration APIs, `TrackedPersonProfile.swift`, immutable shared test helpers, original `build/review-2026-09-10/evidence/data-probe.swift`, public anchor XML |
| 3 | `Muskometer/Services/GainThresholdNotificationService.swift`, `DayCloseSummaryNotificationService.swift`, `DailyRecordTracker.swift`; `MuskometerTests/NotificationServicesTests.swift` | `TradingDayCalendar.swift`, existing `MarketHoursServiceProtocol`, `GainNotificationThreshold.swift`, notification formatting/routing constants, `DailyGainRecord.swift`, current `GainsViewModel.swift` callers, immutable `EasternTestDates`, original records probe |
| 4 | `Muskometer/Views/PopoverContentView.swift`; optional height/routing-only `SettingsView.swift`; `Muskometer/Utilities/LaunchAtLoginManager.swift`; login-only `AppSettings.swift`; `Muskometer/Services/MarketHoursService.swift`; `MuskometerTests/InterfaceAndCalendarTests.swift` | Existing `GainsViewModel` initialization/display/action APIs, current notification/record services used by populated-view setup, `SettingsContentHeightKey.swift`, holdings defaults used by unchanged settings initialization, immutable test helpers, original sizing probe |
| 5 | `Muskometer/ViewModels/GainsViewModel.swift`; `MuskometerTests/RefreshLifecycleTests.swift` | Approved Task 3 service APIs and implementation; `StockPriceServiceProtocol.swift`, `HoldingsSyncServiceProtocol.swift`, `IssuerOutstandingSyncServiceProtocol`, existing `MarketHoursServiceProtocol`, `AppSettings.swift` holdings/settings APIs, `IntradayGainSampleStore.swift`, `NetWorthMilestoneTracker.swift`, immutable test helpers, original `build/review-2026-09-10/evidence/view-model-probe.swift` |
| 6 | `docs/ARCHITECTURE.md`, `docs/HOLDINGS.md`, optional `docs/DEVELOPING.md`, `CHANGELOG.md`; compatibility-only `scripts/verify.sh`; independently reviewed integration fixes in Tasks 2–5 owned files | Entire cumulative branch diff, all completed test suites, original review probes and public data for optional spot checks |

The four task-specific test filenames in Task 1's row all live under `MuskometerTests/`. Unqualified production filenames in the remaining rows retain the directory named immediately before their group. New helpers for Tasks 2–5 belong inside that task's owned Swift file. Additional production/test source files requiring target registration would exceed these sets and require coordination before editing.

## Helper and API evidence

Task 1 names the actual cross-file helpers needed by the moved tests: `MockHoldingsSyncService` (baseline tests line 1025), `MockIssuerOutstandingSyncService` (1757), `MockStockService` (2877), `FixedMarketHours` (3004), `EasternTestDates` (3386), and `MutableMockStockService` (4936). They currently have private visibility; making those declarations internal in Task 1 resolves the split. `FixedMarketHours` and `EasternTestDates` also have callers that remain in the original file. Their methods require no semantic change. After Task 1, that original file is read-only for Tasks 2–5.

`MockLaunchAtLoginManager` (baseline tests line 2081) is used only by the moved login tests. `MockGainThresholdNotificationDeliverer` (3882) is used only by the moved threshold tests. Day-close delivery helpers are nested in their test classes/functions (4201 onward); the view-model day-close helpers are independently nested under `GainsViewModelDayCloseNotificationTests` (4371 onward). Moving complete declarations preserves helper ownership without creating a dependency between Tasks 3 and 5's test files. All corresponding `@MainActor` annotations and imports must travel with those declarations as Task 1 already requires.

The existing `MockURLProtocol` (5292) remains private in the original file and has mutable static `requestHandler` state shared by the existing Yahoo/update tests. Task 2 must use its own private SEC fixture transport, adapted from the probe's `FixtureURLProtocol`, inside `OwnershipSyncTests.swift`; it must not expand or reuse the original mutable handler. Ownership fixtures are source-relative and exclusively owned, so they require no new project resource registration.

Task 3's `DeliveryOutcome.inFlight` is additive and does not break an exhaustive switch in the current view model: `GainsViewModel.swift:532` uses `outcome != .failed`. That existing condition still treats an in-flight result incorrectly until Task 5 changes the consumer; this is the already-planned integration requirement, not an omitted concurrency edge. Retaining the old `consumePendingFinalizedDay(for:)` overload keeps current callers compiling. The exact new contract must be delivered with the approved Task 3 source before Task 5 starts. Task 3 must retain the current public `processUpdate` call shape or provide compatibility if it adds a synchronous observation API.

Fresh review of plan commit `50474f800c1364a49ff4b71e1bd78d2b55aace07`: Task 3 now explicitly adds `DayCloseSummaryNotificationService.resetRuntimeState(for personID: String)`; Task 5 calls it at stop/reset boundaries and verifies that an older completion cannot restore notified-day state, consume pending work, or remove a newer claim. This additive instance API is defined wholly in Task 3’s existing service/test write set and consumed wholly in Task 5’s existing view-model/test write set. The existing `3 → 5` edge therefore covers the dependency. Task 3 also owns last-observed wording and formatting of existing `FinalizedTradingDay.date`; Task 5 captures that content after a failed closing fetch. The existing date field avoids a model/persistence edit, and content assertions remain in each task’s owned test file. No new write-set overlap or dependency on Tasks 2 or 4 is introduced.

Task 2 expressly retains `HoldingsSyncResult` and AppSettings interfaces. Task 5 can therefore implement scheduling against existing holdings/outstanding protocols while Task 2 changes reconstruction behind those protocols. Task 4 changes AppSettings only in login behavior; Task 2's holdings tests and Task 5's refresh code read a separate, unchanged part of that type. Task 4's calendar correction changes one holiday entry, not `MarketHoursServiceProtocol`, whose existing `regularCloseDate(on:)` already supports Tasks 3 and 5.

For login mocks defined in Task 5's adapted probe, Task 4 should use the plan's backward-compatible default status implementation while retaining the existing `isEnabled` and `setEnabled(_:)` surface. The original view-model probe contains `ReviewLoginManager: LaunchAtLoginManaging`; a new required status property without a default would create an avoidable integration edit in Task 5's file. Likewise, Task 5's injected sleeper must have a default and existing view-model display/action/init calls used by Task 4's view must remain valid. These are consequences of the plan's compatibility scope, not new feature requirements.

## Concurrent pair claims

- Tasks {2, 3}: declared concurrent.
  - Files touched disjoint: yes; Task 2 owns SEC/parsing/ownership utilities and `OwnershipSyncTests.swift`; Task 3 owns notification/record services and `NotificationServicesTests.swift` (plan Tasks 2–3).
  - Test-fixture overlap: no; SEC fixtures and private URLProtocol state are Task 2-local, while delivery gates and per-test UserDefaults suites are Task 3-local. Shared Task 1 helpers are read-only.
  - Hidden runtime coupling: no unsafe coupling; the notification services do not consume reconstruction implementation details, and unchanged profile/formatting types are shared reads.
  - Chain-length ratio: 0.5 (1 / 2).
  - Cost-benefit assessment: meets the 0.25 threshold.
  - Recommendation: VERIFIED

- Tasks {2, 4}: declared concurrent.
  - Files touched disjoint: yes; AppSettings ownership belongs only to Task 4 and is restricted to login; Task 2 does not edit that file (plan Tasks 2 and 4).
  - Test-fixture overlap: no; ownership/network tests and interface/login/calendar tests have separate files, transports, and defaults suites.
  - Hidden runtime coupling: no unsafe coupling; Task 2 reads AppSettings holdings application and Task 4 reads bundled ownership during settings construction, but neither changes the other's consumed contract. The anchor totals are preserved.
  - Chain-length ratio: 1.0 (1 / 1).
  - Cost-benefit assessment: meets the 0.25 threshold.
  - Recommendation: VERIFIED

- Tasks {2, 5}: declared concurrent.
  - Files touched disjoint: yes; SEC implementation and ownership tests versus `GainsViewModel.swift` and refresh tests (plan Tasks 2 and 5).
  - Test-fixture overlap: no; transport fixtures remain Task 2-local and Task 5 owns its gated protocol conformers. Existing shared holdings/outstanding mocks are read-only.
  - Hidden runtime coupling: no unsafe coupling; Task 5 reads stable `HoldingsSyncResult`, holdings-sync and outstanding-sync contracts. Task 2's implementation is not required to define the scheduler. Fully integrated tests remain a Task 6 obligation.
  - Chain-length ratio: 0.5 (1 / 2).
  - Cost-benefit assessment: meets the 0.25 threshold.
  - Recommendation: VERIFIED

- Tasks {3, 4}: declared concurrent.
  - Files touched disjoint: yes; notification/record services versus views/login/settings/calendar sources, plus distinct tests (plan Tasks 3–4).
  - Test-fixture overlap: no; shared date helpers are immutable, nested notification deliverers do not escape their owned test file, and the login mock moves into Task 4's file.
  - Hidden runtime coupling: no unsafe coupling; DailyRecordTracker reads an unchanged market-hours protocol and Task 4's correction is confined to the calendar table. AppSettings reads existing reset APIs that Task 3 must retain. UI setup uses existing compatible service constructors.
  - Chain-length ratio: 0.5 (1 / 2).
  - Cost-benefit assessment: meets the 0.25 threshold.
  - Recommendation: VERIFIED

- Tasks {4, 5}: declared concurrent.
  - Files touched disjoint: yes; view/settings/login/calendar sources and interface tests versus view-model/refresh tests (plan Tasks 4–5).
  - Test-fixture overlap: no; Task 1's shared mocks are immutable inputs, and new login/height helpers and loop/delivery gates stay in their respective owned files.
  - Hidden runtime coupling: no unsafe coupling under the specified compatible APIs: Task 4 consumes the view model's existing display/actions and Task 5 consumes existing settings/calendar interfaces. Preserve default initialization and legacy login mock conformances as described above. Rendering and loop tests are re-run after integration.
  - Chain-length ratio: 0.5 (1 / 2).
  - Cost-benefit assessment: meets the 0.25 threshold.
  - Recommendation: VERIFIED

## Execution constraints

1. Do not start the fan-out until Task 1 is approved, the complete original test identifier set is preserved, and all 248 baseline tests pass. Parent integration must not copy one child's stale version of another task's file.
2. Freeze `MuskometerTests.swift` and `project.pbxproj` after Task 1. Keep new task helpers private/nested in their owned files; do not modify shared helpers to support new gates, sleepers, or transports.
3. Child worktrees must start from their completed prerequisites. Integrate only their owned diffs. Task 5 must include approved Task 3 changes before its red/green cycle; Task 6 must include all approved fixes.
4. Keep aggregate Xcode tests/controller integration serialized. Targeted child tests must have worktree-specific derived data. Build products, result bundles, and adapted probe outputs stay in the child's own paths; the original review evidence is read-only.
5. Use per-test UserDefaults suites, private transport handlers, and controlled delivery/login mocks for new tests. Separate worktrees do not isolate system preferences, the pasteboard, or real notification/login services. Existing UI/pasteboard tests and aggregate app-host runs remain serialized under the controller's validation policy.
6. If implementation requires editing a different task's source, changing a retained protocol contract, or adding project registration, stop that overlapping edit and coordinate ownership/dependencies before proceeding. This approval does not extend to an expanded write set.

## Findings

None.

VERDICT: APPROVED
