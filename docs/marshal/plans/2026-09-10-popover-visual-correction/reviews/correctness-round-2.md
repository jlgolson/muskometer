# Plan correctness review

The presentation work is executable as one coupled task. The plan identifies the existing view and test seams, gives a concrete chart regression that fails the current zero-forced domain, requires actual pre-scroll parity geometry at all four heights, and makes asset-backed main/Settings/export image inspection an execution gate. Timestamp decoding matches the supplied nine-point JSON. The proposed chart domain, visible-zero behavior, fixture matrix, retained scrolling assertions, baseline preservation, one final aggregate verification, and local preview handoff cover the specification. WHAT/HOW/WHO is explicit, the single-task graph has no dependency errors, and Deferred is `None.`.

One blocking test-runner defect remains in the bootstrap prerequisite. Task 1 adds an unconditional `XCTAssertTrue(MuskometerApp.isIsolatedTestHost)`, while the production Debug branch explicitly defines that value as `false`. The only mechanism enabling the isolated branch is an edit to the controller's ignored `build/test-tools/xcodebuild` wrapper. The checked-in CI workflow calls `./scripts/verify.sh` directly (`.github/workflows/ci.yml:19`), whose XCTest command (`scripts/verify.sh:21–26`) supplies no isolation condition. Consequently the existing checked-in verification path will build the production entry point and deterministically fail the newly committed assertion. It can also execute production startup before reaching that assertion. Passing the private-wrapper path does not resolve this introduced failure in the repository's test entry point.

Amend Task 1's narrow bootstrap exception so the test-only compilation condition is supplied by a checked-in test path used by `scripts/verify.sh` and CI, while normal builds, Release, and the user preview remain unflagged. For example, permit adding the literal compiler setting only to the existing script's `xcodebuild test` invocation, retain the controller wrapper for focused local commands, and verify the settings reach the app target as well as the test target. Include that checked-in change in source-hash evidence and the final single aggregate verification. Do not weaken the isolation assertion or conditionally omit it to mask the mismatch. This requires no publication or CI dispatch.

Reviewed the complete current plan/spec and all five named views, `MuskometerTests/InterfaceAndCalendarTests.swift`, both application files, `ShareImageExporter.swift`, `IntradayGainSampleStore.swift`, the existing aggregate launcher and wrapper, `scripts/verify.sh`, and the checked-in CI invocation. Also inspected the referenced before images, observed sample/analysis files, existing baseline result-bundle path, and relevant view-model/configuration declarations. No app, build, executable probe, or test was launched; no product files or historical reviews were changed.

## Findings

- [docs/marshal/plans/2026-09-10-popover-visual-correction.md:Test-host bootstrap prerequisite] test-runner-mismatch: The unconditional isolated-host assertion depends solely on an ignored local wrapper, so the checked-in verify/CI path selects production startup and fails; supply the test-only flag through the checked-in test runner as well.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{
  "schema_version": 1,
  "dispatch_id": "27459e38-30c5-4b54-b1b6-7bb4466be9ec-task-0",
  "verdict": "needs_fixes",
  "round": 2,
  "findings": [
    {
      "file_path": "docs/marshal/plans/2026-09-10-popover-visual-correction.md",
      "line_range": [156, 168],
      "category": "test-runner-mismatch",
      "severity": "important",
      "summary": "The unconditional isolated-host assertion depends solely on an ignored local wrapper, so the checked-in verify/CI path selects production startup and fails; supply the test-only flag through the checked-in test runner as well.",
      "persisted_from_prior_round": false,
      "resolved_in_this_round": false
    }
  ]
}
```

VERDICT: NEEDS_FIXES: Make the isolated test-host bootstrap work through the checked-in verification path.

reviewed-content-sha256: 328e9ad85ce8acba06d583ff49f88031d0888c62aeb164c8a5a9ce8a59b0092d

plan-graph-sha256: f10c3899ca6b0b2dffde07f086ac7df02642f933cad6463065b270c11b6e2037
