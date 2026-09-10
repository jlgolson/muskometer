# Task 6 spec compliance review

Reviewed Task 6 against `docs/marshal/plans/2026-09-10-review-fixes.md:128` and the complete approved spec, particularly its Tests and integration and Scale & Validation sections (`docs/marshal/specs/2026-09-10-review-fixes-design.md:50,60`). Review scope is source base `943d5a11cf8327dd500bf6399a80570191a8971e` through frozen source `e97685443d43c63895795c91e940b6c1aca8cb34`. The cumulative product changes were inspected to check the documentation and evidence claims; this verdict does not replace the separately assigned cumulative review.

Before reading the diff, I recorded independent hypotheses about scope expansion, inaccurate behavioral documentation, mismatched or incomplete test evidence, incompatible reused probes, missing finding coverage, and weakened verification. The hypothesis record and independently authored audit are under `build/task6-spec-evidence/`.

## Conformance assessment

No missing, extra, or misinterpreted Task 6 requirement was found. The frozen diff contains the four permitted documentation files, the verification fixture correction, eight validation records, and generated dispatch metadata. Product code, tests, project settings, approved spec/plan, and version remain unchanged from the Task 6 base. `scripts/verify.sh:74` changes only its two share counts to the actual bundled values, retaining the existing live-check logic and failure propagation. The changelog records the cumulative fixes under Unreleased without a release bump.

The ownership text at `docs/ARCHITECTURE.md:104` and `docs/HOLDINGS.md:13` matches the actual anchor/bucket reconstruction, effective-date ordering, unique amendment targeting, explicit-zero handling, conservative omission, whole-entity companyfacts deduplication, and request budgets. I checked these against the SEC service/reconstruction, companyfacts resolver, anchor fixtures, and corresponding assertions in `OwnershipSyncTests.swift`. This supports spec findings 1–3 and 12 without claiming that ambiguous filings can always be reconstructed.

The lifecycle text at `docs/ARCHITECTURE.md:112` accurately distinguishes synchronous snapshot/threshold acceptance, asynchronous bounded gain workers, awaitable explicit day-close work, independent SEC/quote scheduling, real-sample close finalization, bounded closing recovery, and physical slots retained by cancellation-unaware transports. Source tracing and controlled regression assertions support findings 4–8 and the required work bounds. The distinction between one current-lifecycle SEC sync and two physically outstanding transports is documented explicitly.

For findings 9–11, the actual hosted test at `MuskometerTests/InterfaceAndCalendarTests.swift:802` exercises 600/700/800/900-point main and embedded Settings layouts, scroll movement, visible footer controls, and the Back route. I inspected the original 600/900 PNGs and the hosted-probe source/output; these support the documented layout limitation. Login tests exercise pending registration through reopening/restarting and subsequent approval without duplicate registration. The calendar test at line 129 checks December 31, 2027 regular trading and the January 3, 2028 opening. Documentation agrees with those implemented behaviors.

## Independent evidence checks

The raw `verify.log` and `xcresult-summary.json` report the full deterministic verification command completed successfully: typecheck, XCTest, Release, Debug sandbox/network-client entitlements, and marketing checks. Live Yahoo was explicitly skipped in that command. I independently traversed `xcresult-tests.json` and extracted current source declarations: **391 cases, all Passed, each declaration executed exactly once**, with no skipped or expected failures. Every one of the README's 47 named regression references appears in the passing result data; its table covers original report IDs 1–12.

An independent comparison against the original `b4ff901c56bef9302bad32b41a8fec9366182dee` test source accounts for all **248 baseline methods: 243 exact unchanged declaration/bodies and five documented corrective changes**, including two renamed tests. There are no unaccounted removals. The final log hash is `71c7e292585a3a4d642b8bdc97f1de1981a58120885fbb808bbee86b3bd04c1e`.

I recomputed all **83 source-manifest hashes**, all relevant reused-source hashes (**SEC 5, Yahoo 6, VM 7, UI 12**), all **13 original probe/result/image hashes**, and all **13 historical result-artifact hashes**; each matched. I read the original public/VM/hosted result contents rather than treating the implementer summary as authority. Reuse is justified for the unchanged relevant source. Public results remain point-in-time evidence; standalone images do not establish asset color fidelity or every physical display. Notification/login boundary mocks do not establish real authorization or system-item behavior. The delivery record states these limits and makes no Instruments-soak or deployment claim.

## Next-request tracing

Task 6 introduces no application state mutation. The changed verification fixture is recreated on each invocation; the subsequent run still enters the same typecheck/build/test/live checks and preserves their existing error behavior.

For the stateful behavior described by Task 6, I traced the subsequent calls through the actual code: an in-flight/failed day-close attempt leaves durable work for a later admitted attempt; exact-value acknowledgment cannot erase a newer pending record; threshold completion checks claim/lifecycle identity, retains a failed crossing for a later above-threshold observation, and preserves intervening rearm/recross; stop invalidates old completions while their physical slots remain occupied until return; the close obligation/recovery is bounded and the next regular opening supersedes it. SEC reconstruction starts from immutable anchors on replay, while an incomplete result preserves existing counts through AppSettings' completeness policy. These paths match the documentation and regression evidence; no concrete retry/error/race discrepancy was found within this review's scope.

No additional app launch, live request, notification, login change, or broad test rerun was needed. The independent audit scripts and output are retained in `build/task6-spec-evidence/`.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"f10ffd98-a952-4e04-b327-b93a8c8208f5-task-6","verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- `docs/marshal/specs/2026-09-10-review-fixes-design.md`
- `docs/marshal/plans/2026-09-10-review-fixes.md`
- `docs/ARCHITECTURE.md`
- `docs/HOLDINGS.md`
- `docs/DEVELOPING.md`
- `CHANGELOG.md`
- `scripts/verify.sh`
- `docs/marshal/plans/2026-09-10-review-fixes/reviews/task-6-validation/README.md`
- All seven JSON evidence records in that validation directory
- `Muskometer/Services/SECHoldingsSyncService.swift`
- `Muskometer/Services/CompanyFactsOutstandingResolver.swift`
- `Muskometer/Services/GainThresholdNotificationService.swift`
- `Muskometer/Services/DayCloseSummaryNotificationService.swift`
- `Muskometer/Services/DailyRecordTracker.swift`
- `Muskometer/Services/IntradayGainSampleStore.swift`
- `Muskometer/ViewModels/GainsViewModel.swift`
- `Muskometer/Views/PopoverContentView.swift`
- `Muskometer/Views/SettingsView.swift`
- `Muskometer/Utilities/LaunchAtLoginManager.swift`
- `Muskometer/Utilities/AppSettings.swift`
- All five `MuskometerTests/*.swift` declaration/body inventories, with targeted assertion reads in the four subsystem files
- `build/task6-evidence/implementer-summary.md`, raw verification log, result summary/test tree, and public/VM/hosted result copies
- `build/task6-runner-evidence/round-1-freeze.json` and `independent-verification-audit.json`
- Original `ui-hosted-probe.swift` and `popover-hosted-600.png` / `popover-hosted-900.png` under `/Users/jlgolson/grok/muskometer/build/review-fix-validation/`

reviewed-content-sha256: 3227744f027299e885ca5aefd3828a6d6fb317dfae99bd997c5ab56f875ca60b

plan-graph-sha256: c5582aec64ba1273dc1ddb9487db6d546ccf6879bd93cdd16eda9a28cf89a760
## Round 2

MARSHAL_TASK_ID: 6
MARSHAL_PLAN_SLUG: 2026-09-10-review-fixes
MARSHAL_ROLE: spec-reviewer
dispatch_id: 2e853deb-f691-45cb-a6bc-08a45eadca9e-task-6

Independent, narrow review of `523b3d2c72b8291dc0e83b14b233ef03e1db4652..81d0f6278cf976d5fb3c76d8ab7401a9378641b4`. Current HEAD `c4cbf59035798f0bae95cdb77c834a9a7e45ea10` adds only provenance. I formed four hypotheses before inspecting the delta: an overstated refresh-completion guarantee, conflation of synchronous state and delivery completion, broken verification provenance, and inconsistent or unrelated documentation changes. Those hypotheses and fresh integrity results are preserved under `build/task6-spec-round2-evidence/`. Prior reviewer findings were not consulted.

The change satisfies the Task 6 requirement to document shipped scheduling and close behavior (`docs/marshal/plans/2026-09-10-review-fixes.md:140`) and the spec's notification/refresh ordering, clock-finalization, and verification requirements (`docs/marshal/specs/2026-09-10-review-fixes-design.md:26`, `:32`, `:50`). This is a clarification of the existing API boundary, with no additional product behavior, test changes, version bump, or release work.

The corrected wording at `docs/ARCHITECTURE.md:120`, `docs/DEVELOPING.md:80`, and `docs/marshal/plans/2026-09-10-review-fixes/reviews/task-6-validation/README.md:49` agrees with the actual branches. `GainsViewModel.refresh()` awaits the admitted quote task, then only its optional returned summary handle (`Muskometer/ViewModels/GainsViewModel.swift:244–257`). Accepted complete quotes can return the summary handle (`:289–298`); an accepted thrown failure can also return one (`:299–303`, `:348–356`). Incomplete quotes advance the clock, call `beginPendingSummary()`, and return nil from `acceptQuotes` (`:329–336`), causing the quote worker's guard to return nil (`:289–290`). The explicit caller can therefore finish while that day-close delivery is suspended. Non-admission and stale/canceled work also make no universal delivery promise.

The clarification preserves the distinction between committed state and asynchronous effects. Accepted snapshot side effects run synchronously (`:338–345`, `:656–697`); threshold observation uses the synchronous API that owns background workers (`Muskometer/Services/GainThresholdNotificationService.swift:118–168`). Summary tasks remain separately owned and acknowledge the matching pending value only for delivered/skipped outcomes (`Muskometer/ViewModels/GainsViewModel.swift:715–736`). Scheduled quote completion does not await summary completion (`:260–266`, `:281–303`). The documentation consistently directs callers/tests needing delivery effects to the controlled delivery boundary. No newly introduced retry, error, race, or next-request mismatch was found in this delta.

Fresh static verification passed with `python3 build/task6-spec-round2-evidence/check-integrity.py` and revision/worktree whitespace checks. The delta contains exactly the three documentation files, the current manifest update, and the historical manifest copy. All 83 current manifest entries and the additional README hash match; all 77 executable inputs match both manifests and verified commit `e97685443d43c63895795c91e940b6c1aca8cb34`. The historical manifest is byte-identical to its original committed/raw copies (SHA-256 `899526fa2f80b902607386e5c8b63863916feda0c0d89dd19cba1e548534ae57`).

The unchanged verification record reports 391 passed, zero failed/skipped, and passing deterministic stages. Its original raw log still hashes to `71c7e292585a3a4d642b8bdc97f1de1981a58120885fbb808bbee86b3bd04c1e`; all 13 referenced original probe artifacts retain their recorded hashes. The round-2 README explicitly identifies this as retained evidence. I inspected the implementer's historical documentation-check script and results, then performed my own current-revision integrity check. No test-suite reparsing, new test/app/probe launch, or network request was needed or performed. Broader cumulative conformance remains the separately assigned review scope.

## Findings

None.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"2e853deb-f691-45cb-a6bc-08a45eadca9e-task-6","verdict":"approved","round":2,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- docs/marshal/specs/2026-09-10-review-fixes-design.md
- docs/marshal/plans/2026-09-10-review-fixes.md
- build/task6-evidence/round-2/implementer-summary.md
- docs/ARCHITECTURE.md
- docs/DEVELOPING.md
- docs/marshal/plans/2026-09-10-review-fixes/reviews/task-6-validation/README.md
- docs/marshal/plans/2026-09-10-review-fixes/reviews/task-6-validation/source-manifest.json
- docs/marshal/plans/2026-09-10-review-fixes/reviews/task-6-validation/source-manifest-round-1.json
- docs/marshal/plans/2026-09-10-review-fixes/reviews/task-6-validation/verification-results.json
- docs/marshal/plans/2026-09-10-review-fixes/reviews/task-6-validation/probe-source-reuse.json
- build/task6-evidence/round-2/validation-results.json
- build/task6-evidence/round-2/check-documentation.py
- Muskometer/ViewModels/GainsViewModel.swift (refresh, acceptance, clock, side-effect and summary paths)
- Muskometer/Services/GainThresholdNotificationService.swift (observation/delivery entry paths)

reviewed-content-sha256: e1d8501ac5523f7b2ddda164e1c134fad7429eb4a56058b9ef501c435fdc4b4e

plan-graph-sha256: c5582aec64ba1273dc1ddb9487db6d546ccf6879bd93cdd16eda9a28cf89a760
