# Parallelism verification

MARSHAL_TASK_ID: 0
MARSHAL_PLAN_SLUG: 2026-09-10-review-fixes
MARSHAL_ROLE: parallelism-verifier
MARSHAL_ROUND: 1
dispatch_id: 17691b9e-14c2-4b83-a836-1d49f1b7fce5-task-0

Reviewed the complete current plan, its design specification, the analyst artifact, and the existing source/test boundaries independently. The analyst's five concurrent-pair recommendations are supported. No extra dependency edge or write-set change is needed.

Reviewed plan: `docs/marshal/plans/2026-09-10-review-fixes.md`
Plan Git blob: `c11d925adad41791ea9360c36ba53b926bba2fba`
Source checkout HEAD: `50474f800c1364a49ff4b71e1bd78d2b55aace07`

Plan-graph-sha256: c5582aec64ba1273dc1ddb9487db6d546ccf6879bd93cdd16eda9a28cf89a760

The digest was generated with the installed `scripts/_plan_graph_hash.py` `compute_plan_graph_hash(Path(...))` API and matches the analyst artifact. The helper includes checklist bullets within this plan's Files touched sections, so it also detects changes to those instructions. No session or conversation history was consulted.

## Dependency graph

Independent extraction of every Depends on field yields `1: []`, `2: [1]`, `3: [1]`, `4: [1]`, `5: [1, 3]`, `6: [2, 4, 5]`. Every reference exists and precedes its consumer; there are no cycles. Transitive reachability leaves exactly the unordered pairs `{2, 3}`, `{2, 4}`, `{2, 5}`, `{3, 4}`, and `{4, 5}`. The analyst lists every permitted pair and no extra one.

Task 1 must complete and pass review before the initial `{2, 3, 4}` ready set. Once Task 3 has passed and its actual changes are present, Task 5 may join unfinished Tasks 2 and 4. Task 6 waits for the complete fan-in, including Task 3 transitively through Task 5. Its permission to repair prior task files cannot overlap an active implementation task. The redundant direct `1 → 5` edge does not hide a missed opportunity.

## Test ownership prerequisite

The existing `MuskometerTests/MuskometerTests.swift` contains 248 test methods in 50 XCTest classes by static enumeration. This verifies the plan's inventory target; it does not replace Task 1's required pre/post discovery comparison and passing full suite.

The six shared declarations named in Task 1 exist at the cited baseline positions: `MockHoldingsSyncService` (1025), `MockIssuerOutstandingSyncService` (1757), `MockStockService` (2877), `FixedMarketHours` (3004), `EasternTestDates` (3386), and `MutableMockStockService` (4936). Their type-level private visibility is the obstacle to moving callers across files. The planned internal visibility and preserved actor annotations address it without production edits. `FixedMarketHours` and `EasternTestDates` have callers both inside and outside the moved classes.

`MockLaunchAtLoginManager` at 2081 is used by the moved login tests and can move into `InterfaceAndCalendarTests.swift`. The threshold deliverer at 3882 is used by the moved threshold tests and belongs in `NotificationServicesTests.swift`. Day-close deliverers are nested in the service tests at 4201 and independently in the view-model tests at 4371, so there is no cross-file deliverer extraction dependency. The shared mock classes contain mutable instance fields such as call counts and quote arrays; their safety comes from separate test instances and read-only source ownership, not from every helper being an immutable value.

Task 1 exclusively creates and registers all four new test files and edits `project.pbxproj`. Tasks 2–5 subsequently own separate test files and do not own the original file or target registration. Task 2's optional source-relative fixture directory requires no resource registration. The existing `MockURLProtocol` at 5292 has mutable static handler state and stays private in the original test file. A Task 2-local SEC transport adapted from `FixtureURLProtocol` in the original data probe avoids coupling to that handler. No shared helper changes or project registrations are needed for the fixes as scoped.

## API and runtime boundaries

The `3 → 5` edge is necessary and sufficient for the new notification/record contract. Task 3 defines `DeliveryOutcome.inFlight`, `consumePendingFinalizedDay(for:matching:)`, `advanceClock(personID:at:)`, and the instance day-close `resetRuntimeState(for:)`; Task 5 consumes them. Current `GainsViewModel.swift:532` uses `outcome != .failed`, so adding an enum case causes no exhaustive-switch compilation failure, while its incorrect treatment of in-flight delivery is explicitly assigned to Task 5. Keeping the current consumption overload and compatible `processUpdate` entry point preserves intermediate callers.

The new instance reset invalidates delivery identities entirely inside Task 3's service. Existing static persisted reset APIs used by `AppSettings.swift:577–582` remain. Task 5 owns the stop/reset call sites and gated old-completion integration regressions. Last-observed notification wording also belongs to Task 3; `DailyRecordTracker.FinalizedTradingDay.date` already exists and is populated with the last actual sample at finalization. Task 5's failed-closing-fetch assertion consumes that content without needing a new shared model or persistence file.

Task 2 keeps `HoldingsSyncResult` and AppSettings' holdings interface unchanged. `AppSettings.swift:602` already accepts complete nonnegative symbol results, including zero. Task 5 can work against the existing sync protocols while Task 2 changes reconstruction internally. Task 4's AppSettings writes are limited to login state, outside these holdings methods.

Tasks 3 and 5 consume `MarketHoursServiceProtocol`, whose existing `regularCloseDate(on:)` has both a production implementation and a default mock implementation. Task 4 removes one holiday-table entry without changing that protocol. Task 4's views consume existing view-model display/actions and initialization; Task 5's sleeper injection must preserve existing callers with a default. Task 4's login status extension must retain the legacy `isEnabled`/`setEnabled` surface and a compatible default status for existing conformers, including `ReviewLoginManager` in the view-model probe. These compatibility boundaries are already stated in the plan and analyst constraints.

## Pair evidence

| Pair | Independent write/fixture/coupling check | Chain ratio |
| --- | --- | --- |
| {2, 3} | SEC service, parser, companyfacts resolver, SPCX utilities, ownership tests, and SEC fixtures are disjoint from threshold/day-close/record services and notification tests. SEC transport state and gated delivery state have separate owners; notification services do not require the ownership implementation. | 1/2 = 0.5 |
| {2, 4} | Task 2 never edits AppSettings; Task 4 exclusively changes its login portion plus views, login manager, calendar, and interface tests. Ownership tests read the retained holdings APIs; Task 4 retains verified anchor totals during settings construction. Separate fixture/defaults instances prevent runtime test sharing. | 1/1 = 1.0 |
| {2, 5} | Ownership implementation/tests and view-model/refresh tests are disjoint. Task 5 reads stable holdings/outstanding protocols and uses its own gated conformers. Task 2's future implementation is unnecessary to define the scheduler, and integrated behavior is checked after fan-in. | 1/2 = 0.5 |
| {3, 4} | Notification/record service files and tests are disjoint from UI/login/settings/calendar files and tests. Their shared calendar protocol, constructors, and static reset entry points remain compatible. Private delivery gates and moved login mocks are separate; date helpers are read-only. | 1/2 = 0.5 |
| {4, 5} | View/settings/login/calendar writes and interface tests are disjoint from GainsViewModel and refresh tests. Existing display/action/init APIs, holdings settings methods, and calendar methods remain compatible; default login status and default sleeper preserve probe conformances and caller compilation. UI and lifecycle helpers remain task-local. | 1/2 = 0.5 |

The installed `resolve_parallelism_min_ratio.py` returns `0.25`. Removing common prerequisite Task 1 and final fan-in Task 6 leaves components `{2}`, `{3, 5}`, and `{4}`, with lengths 1, 2, and 1. All five ratios are correctly computed and meet the configured threshold. This is the structural cost heuristic, not a timing guarantee for the much larger ownership task.

## Execution constraints verified

Separate child worktrees must contain all approved prerequisites before tests or implementation begin. Integrate only each child's owned diff into the controller; do not replace entire source trees or overwrite another task's file with a stale copy. Freeze the original test file and Xcode project after the mechanical split. New gates, sleepers, transports, and fixtures belong to the creating task's files.

Worktree-local `build/task-tests` paths isolate build products when commands run from each child's root. Aggregate Xcode tests, controller integration, and app-host/UI/pasteboard verification remain serialized. The scheme itself marks the test target parallelizable, and existing copy/share tests touch `NSPasteboard.general`; separate worktrees alone do not isolate that global surface. Any selected tests with shared system state must likewise be scheduled serially. New tests use unique defaults suites and controlled login/notification boundaries. Child targeted tests can overlap only when their runtime fixtures are isolated, not merely because derived-data paths differ.

Task 6 runs the cumulative verification and actual-view probes after all fixes are present. Build/result/probe outputs remain worktree-local, and original evidence files are read-only. An implementation that needs an expanded write set, altered retained protocol, or additional project registration must coordinate before that edit; this approval covers the present scope only.

This is a static plan and source verification. No Xcode suite or live external request was run in this review, and this verdict does not certify future implementation correctness or a completed mechanical split.

## Findings

None.

## Per-pair verdicts

- {2, 3}: VERIFIED
- {2, 4}: VERIFIED
- {2, 5}: VERIFIED
- {3, 4}: VERIFIED
- {4, 5}: VERIFIED

VERDICT: APPROVED

reviewed-content-sha256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

plan-graph-sha256: c5582aec64ba1273dc1ddb9487db6d546ccf6879bd93cdd16eda9a28cf89a760
