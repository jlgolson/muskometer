# Plan correctness review

The chart and composition instructions cover the requested behavior. The referenced view and test paths exist, the internal `SparklineLayout` seam matches the source, and the supplied nine-point regression will fail on the existing zero-forced domain. The proposed range, padding, timestamp spacing, first-viewport geometry checks, asset-backed export captures, and independent image review provide concrete acceptance criteria. The single-task graph is valid, verification has WHAT/HOW/WHO within Task 1, the full check matches CI, the 391 baseline cases are explicitly retained, and nothing is deferred.

One execution-safety issue blocks acceptance. The plan's fixture isolation applies to the `GainsViewModel` constructed inside the test method, but the configured XCTest host is the production application: `Muskometer.xcodeproj/project.pbxproj:643–654` sets `BUNDLE_LOADER` and `TEST_HOST` to `Muskometer.app/Contents/MacOS/Muskometer`. Hosted unit tests run within an application launch, as described in [Apple's test-hosting material](https://devstreaming-cdn.apple.com/videos/wwdc/2016/409jh83sf1h8dqrt00q/409/409_advanced_testing_and_continuous_integration.pdf).

Before that fixture exists, `Muskometer/App/MuskometerApp.swift:8–15` accesses `AppSettings.shared`, reconciles the real login service, and starts the real update coordinator. `AppSettings` defaults to `.standard`, performs preference migrations/cleanup, and persists login reconciliation; the updater can perform network/notification work when the user's preference is enabled. `MenuBarLabelView` also starts the production view model on appearance, which begins holdings synchronization and quote refresh. Neither the scheme nor `build/run-aggregate.py` suppresses this startup: the launcher serializes applications and disables parallel tests but does not isolate application services or defaults. Consequently, adding an isolated suite and mock manager inside `PopoverLayoutRegressionTests` does not meet the plan's stated prohibition against changing real preferences/login state or initiating SEC/update work during captures.

Before the red run, specify and include a concrete test-host/bootstrap mechanism that prevents production startup side effects before `AppSettings.shared` is initialized, or an equivalently isolated host with the compiled assets. Apply that isolation to the focused red/green runs and the full hosted suite, and make the necessary capture/bootstrap files part of the allowed work. Verify the host isolation itself in the evidence manifest. Keep the final user preview's normal production startup separate from this test configuration. This is a correction to the proposed validation path, not a request to revisit unrelated application behavior.

This was a static source and plan review, with inspection of the supplied before images. No application, test suite, or build was run.

## Findings

- [docs/marshal/plans/2026-09-10-popover-visual-correction.md:Task 1 / Execution and launch discipline] host-isolation-gap: Isolated fixture defaults do not suppress the production XCTest host's real preferences, login reconciliation, and background-service startup; define and verify host-level isolation before the red, green, and full-suite capture runs.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{
  "schema_version": 1,
  "dispatch_id": "8834fb0e-9685-4df6-8cee-9ec5cdbfef04-task-0",
  "verdict": "needs_fixes",
  "round": 1,
  "findings": [
    {
      "file_path": "docs/marshal/plans/2026-09-10-popover-visual-correction.md",
      "line_range": [43, 45],
      "category": "host-isolation-gap",
      "severity": "important",
      "summary": "Isolated fixture defaults do not suppress the production XCTest host's real preferences, login reconciliation, and background-service startup; define and verify host-level isolation before the red, green, and full-suite capture runs.",
      "persisted_from_prior_round": false,
      "resolved_in_this_round": false
    }
  ]
}
```

VERDICT: NEEDS_FIXES: The prescribed hosted test and capture commands do not yet enforce the required isolation from the user's real preferences and services.

reviewed-content-sha256: c7500ed6ff3896b0fc38b1276e72ce52cac5090fdc640b8ac0c6a3fdf0785b23

plan-graph-sha256: fd23b401975af35e58c9733b7010aa731197d806b8cea1c4ebe43ca7cbc0d6e3
