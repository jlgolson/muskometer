# Holistic plan review — round 1

Reviewed the current plan, its referenced design spec, and the actual source in the `codex/review-fixes-20260910` worktree. This is an independent pre-implementation review; no earlier verdicts or conversation history were consulted. No source or plan changes were made.

The plan is ready to execute. It covers all twelve approved outcomes, gives the coupled notification and refresh work a concrete producer/consumer contract, and ends with integrated verification rather than leaving real-source or interface validation until after delivery.

## Outcome coverage

| Report scope | Required result | Execution and verification |
| --- | --- | --- |
| 1–3: ownership | Partial filings preserve unchanged buckets; amendments respect effective dates; recognized zero balances remain valid. | Task 2 reconstructs from the identified immutable anchors and dated observations, retains original-submission and bucket identity, refuses incomplete or ambiguous reconstruction, and tests transport-boundary XML, amendments, disposals, idempotence, scan coverage and integer bounds. |
| 4–6: notifications and side effects | Older deliveries cannot regress threshold or visible state; concurrent summary attempts cannot consume pending work prematurely. | Task 3 reserves crossings before suspension, separates `inFlight` from terminal outcomes, invalidates lifecycle claims, and adds matching acknowledgement. Task 5 commits chart, record and milestone state before notification awaits and tests these APIs through the actual view model. |
| 7: independent SEC work | Slow or failing SEC requests cannot delay quote polling or restore old share counts. | Task 5 owns one independent holdings task, protects completion by lifecycle identity, removes duplicate refresh paths, and tests due sync, changed counts, SEC failure, stale quote completion and restart. |
| 8: close finalization | Failed closing quotes still finalize the last real regular-session observation, with bounded retry and accurate provenance. | Task 3 adds persisted-state clock advancement and observed-time summary content. Task 5 integrates clock advancement into the actual loop and failure paths, tests injected sleep/clock behavior, and verifies summary wording on a failed close. |
| 9: popover height | Main and embedded Settings content remain usable at constrained screen heights. | Task 4 owns both relevant views and verifies actual hosting-view fitting sizes at 600, 700, 800 and 900 points, including scrolling and reachable actions. Task 6 repeats the real-view probe on the integrated app. |
| 10: login approval | Pending registration preserves desired enabled state and does not repeatedly register; explicit disable remains effective. | Task 4 introduces complete relevant status, tests pending/reopen/approval/restart and errors with a controlled mock, and keeps real login items untouched. |
| 11: calendar | December 31, 2027 remains a regular trading day and its next opening is January 3, 2028. | Task 4 explicitly changes the contradictory existing assertion and holiday entry; Task 6 updates affected documentation. |
| 12: companyfacts | Repeated whole-entity totals do not inflate outstanding counts; ambiguous latest facts remain unresolved. | Task 2 retains accession/form identity, deduplicates equal facts, refuses conflicting ties and prevents ambiguous DEI data from falling through to an older GAAP total. |

## Source and contract checks

- `SECHoldingsSyncService.swift` currently stops after finding both symbols and returns the first parsed total. `Form4OwnershipParser.swift` has no observation dates, and `SPCXOwnershipCalculator.swift` aggregates only one filing. Task 2 addresses these actual failure paths while preserving `HoldingsSyncResult` and `AppSettings.applyHoldingsSync`'s all-symbol completeness boundary. Existing holdings documentation records the same anchor accessions and totals required by the plan.
- The current threshold service keeps a local state copy across delivery suspension. The current summary service returns `.skipped` for an occupied claim, and `GainsViewModel.processSnapshotSideEffects` consumes any nonfailed summary before appending chart/milestone state. Tasks 3 and 5 jointly cover these specific paths. `FinalizedTradingDay` already has `Equatable`, `Codable`, and the last real sample's `date`, so the planned acknowledgement and observation-time text require no incompatible persisted-record redesign.
- `start()` currently awaits SEC work before quotes, and the sync callee can initiate another quote refresh. Task 5 explicitly replaces this coupling and includes lifecycle guards for late completions and task-handle cleanup. Clock advancement can use the existing tracker/calendar primitives without taking a dependency on the independent calendar-table correction in Task 4.
- The main view currently has unbounded intrinsic height; Settings reports measured content size back into the popover. Task 4 owns both sides of that relationship and explicitly requires avoiding a sizing feedback loop. The login protocol currently exposes only `isEnabled`, matching the planned status correction.
- All named existing production paths and test classes were present. Static enumeration found 248 existing `func test` declarations, consistent with the plan's baseline count. This review did not rerun the suite or claim that implementation regressions already pass.

## Execution and verification assessment

The dependency graph is acyclic: Task 1 precedes Tasks 2, 3 and 4; Task 5 consumes Task 3; Task 6 waits for Tasks 2, 4 and 5. Task 1 owns the sole shared XCTest source split and project registration. Later tasks have distinct writable production/test files, with Task 2 reading the unchanged AppSettings contract while Task 4 edits only its login behavior. Child worktrees and separate derived-data paths prevent execution collisions.

The behavioral tasks require a failing assertion before production changes, then targeted and aggregate validation. Task 6 assigns WHAT/HOW/WHO explicitly, names the repository verification command, repeats the real parser/network and actual SwiftUI probes, records public-endpoint availability separately, and requires a twelve-finding results table plus independent final review. The existing verification script actually runs typecheck, XCTest, a Release build, signed-product entitlement checks and marketing checks. Live data and constrained-height probes remain explicit additional in-plan evidence. Test preservation, cancellation, the 100-accession budget, bounded notification state and the 400-sample cap all have owners. There are no deferred requirements.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON -->
```json
{
  "schema_version": 1,
  "dispatch_id": "73ff9b02-3d25-4ba8-9ca1-bb963e401a5d-task-0",
  "round": 1,
  "verdict": "APPROVED",
  "findings": []
}
```

## Findings

None.

VERDICT: APPROVED

reviewed-content-sha256: cdb6192c44be65243b8cefa00c7e9a6f5ce2cb2bac9dd8630cc96d5a5c584710

plan-graph-sha256: c5582aec64ba1273dc1ddb9487db6d546ccf6879bd93cdd16eda9a28cf89a760
