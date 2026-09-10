# Task 1 spec compliance review

Reviewed commit range `308bb9fb5510f9c6300f558c05dbb4f014c4daa4..0c085d8b3c1936592fd059ea441115f906580787` against `docs/marshal/plans/2026-09-10-review-fixes.md:24` (Task 1) and `docs/marshal/specs/2026-09-10-review-fixes-design.md:50` (Tests and integration). The spec requires moving the existing tests without changing assertions, preserving all 248 baseline tests and shared helpers. The fixture/discovery risk at spec line 58 is also satisfied.

Before inspecting the changes, I considered these failure hypotheses: tests lost or duplicated; assertions or actor annotations changed; helpers exposed beyond the required moves; files registered in the wrong target or more than once; and execution evidence not covering the reviewed source. No hypothesis produced a finding.

## Conformance evidence

- The actual commit changes only the six Task 1 paths: the original test file, four new subsystem files, and the Xcode project. It contains no production change or unrelated committed artifact. The split is committed as `0c085d8`.
- An independent comparison against source obtained directly from the base commit found the same 61 top-level declarations. Every complete declaration, including annotations and test/helper bodies, is byte-identical after allowing only the six explicitly requested removals of top-level `private`. Remaining non-declaration content is the original imports and one unchanged section comment. Current source files match the reviewed head commit.
- The exact 248 class/method identifiers survive. All test bodies and XCTest calls remain unchanged. The independent identifier comparison includes tests retained in the original file and tests moved into each of the four destinations.
- The class destinations match the plan exactly: six ownership classes at `MuskometerTests/OwnershipSyncTests.swift:6`; three notification classes and their private delivery helper at `MuskometerTests/NotificationServicesTests.swift:6`; two interface/calendar classes and the private login helper at `MuskometerTests/InterfaceAndCalendarTests.swift:6`; and all eleven GainsViewModel test classes at `MuskometerTests/RefreshLifecycleTests.swift:6`.
- The six shared helpers remain single definitions with internal visibility in `MuskometerTests/MuskometerTests.swift` at lines 448, 872, 1025, 1152, 1534, and 1963. Their uses cross the new file boundaries. Their member visibility, instance/static state, initializers, and actor annotations are unchanged; there is no new shared fixture state.
- Inspection of the actual project diff and independent parsing of `Muskometer.xcodeproj/project.pbxproj` confirmed all four new file references, test-group entries, and Sources entries. The test target contains exactly the original file plus those four files. All 179 project object declarations have unique IDs. Registration is at lines 79, 159, 240, and 529. `git diff --check` passes.
- I read `build/task-1-evidence/test-results.xcresult` directly with `xcresulttool get test-results summary` and `get test-results tests`, without running another build. The bundle reports 248 passed, zero failed, zero skipped, and zero expected failures. Its individual executed identifiers exactly equal the independently extracted 248 baseline source identifiers, with every result Passed. The saved exported tree matches the bundle. The build log names this worktree and the resulting split-source line locations; the saved pre-split source equals the base commit.

No missing requirement, unrequested behavior, or misinterpreted requirement was found within Task 1. The later behavioral fixes and full integrated validation belong to later plan tasks and are outside this review.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{
  "schema_version": 1,
  "dispatch_id": "917acb58-18dc-4c2c-a2c7-e986c0404ddb-task-1",
  "verdict": "approved",
  "round": 1,
  "findings": []
}
```

VERDICT: APPROVED

reviewed-content-sha256: fa346817a19b1317522807ca3f571bae558ae60f398affa44ce7d872953b886f

plan-graph-sha256: c5582aec64ba1273dc1ddb9487db6d546ccf6879bd93cdd16eda9a28cf89a760
