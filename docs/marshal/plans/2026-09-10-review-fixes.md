---
slug: 2026-09-10-review-fixes
plan_date: 2026-09-10
spec_path: docs/marshal/specs/2026-09-10-review-fixes-design.md
gate: review
---

# Review fixes implementation plan

**Goal:** Correct all twelve reproduced full-codebase review findings, preserve existing behavior outside those fixes, and verify the complete integrated app.

**Architecture:** Keep the current protocols and UserDefaults keys. Reconstruct complete ownership from a verified bucket baseline and dated changes. Commit observable state synchronously before notification awaits; protect delivery completions with identity/version state. Run SEC and quote work independently and advance the trading clock even on quote failures. Bound the popover and preserve complete login-service status.

**Tech Stack:** Swift 5 language mode, SwiftUI/AppKit, Foundation async networking, XCTest, Xcode 26.6/macOS 26.

**Authorization:** User approved all concrete findings/remedies in the preceding review. This plan executes that scope without a redundant intent question. No release/deployment, real login-item changes, or real notification sends are required for validation. Keep tracker/message integrations out of this code-fix task.

**Controller worktree:** `/Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910`, branch `codex/review-fixes-20260910`. Base b4ff901c56bef9302bad32b41a8fec9366182dee. All implementers use their own child worktrees based on approved dependencies; parent integrates and runs aggregate validation. No concurrent writes to a shared test file or Xcode project.

**Commands:** Set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` for all Xcode/Swift invocations. Tests: `xcodebuild test -scheme Muskometer -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/task-tests -quiet`. Append `-only-testing:MuskometerTests/ClassName` for targeted red/green. Full validation: `MUSKOMETER_SKIP_LIVE_YAHOO=1 scripts/verify.sh`. Capture test results and exact failed assertions; compilation errors are not the red phase. Build/test commands may need normal Xcode cache/test-runner permissions. Do not run competing Xcode tests against the same derived-data path.

**TDD rule:** For each behavioral change, write a regression first, run it against unchanged production code, and record the expected failing assertion before implementing. Preserve existing regressions, updating only assertions explicitly encoding the reviewed bug. Never weaken tests to hide an unrelated failure.

## Task 1: Separate test ownership without changing behavior

**Depends on:**

### Files touched

- MuskometerTests/MuskometerTests.swift
- MuskometerTests/OwnershipSyncTests.swift (create)
- MuskometerTests/NotificationServicesTests.swift (create)
- MuskometerTests/InterfaceAndCalendarTests.swift (create)
- MuskometerTests/RefreshLifecycleTests.swift (create)
- Muskometer.xcodeproj/project.pbxproj

- [ ] Capture all current XCTest class/method identifiers and count: the baseline suite has 248 passing tests.
- [ ] Move `AppSettingsHoldingsSyncTests`, `CompanyFactsOutstandingResolverTests`, `SPCXHoldingsTests`, `SPCXOwnershipCalculatorTests`, `SECHoldingsSyncServiceFormTypeTests`, and `Form4OwnershipParserTests` verbatim into OwnershipSyncTests.swift.
- [ ] Move `DailyRecordTrackerTests`, `GainThresholdNotificationServiceTests`, `DayCloseSummaryNotificationServiceTests`, and their exclusively used mock delivery helper into NotificationServicesTests.swift.
- [ ] Move `MarketHoursServiceTests`, `AppSettingsLaunchAtLoginTests`, and `MockLaunchAtLoginManager` into InterfaceAndCalendarTests.swift.
- [ ] Move all `GainsViewModel*Tests` classes into RefreshLifecycleTests.swift. Keep their cross-file shared helpers in the original file with internal visibility: MockStockService, MockHoldingsSyncService, MockIssuerOutstandingSyncService, MutableMockStockService, FixedMarketHours, EasternTestDates. Other helper visibility changes are allowed only when needed for these exact moves.
- [ ] Add `import AppKit`, `import UserNotifications`, `import XCTest`, and `@testable import Muskometer` to the new test files as required; preserve actor annotations. Register the four files in the test target's Sources/group/file references with unique IDs.
- [ ] Compare pre/post test identifiers and assertions; no removals or behavior changes. Run the full XCTest suite and require exactly the same 248 tests passing.
- [ ] Commit only the test split/project registration. This is a mechanical prerequisite for independent fixes, not a production behavior change.

## Task 2: Reconcile dated ownership and deduplicate companyfacts

**Depends on:** 1

### Files touched

- Muskometer/Services/SECHoldingsSyncService.swift
- Muskometer/Services/Form4OwnershipParser.swift
- Muskometer/Services/CompanyFactsOutstandingResolver.swift
- Muskometer/Utilities/SPCXHoldings.swift
- Muskometer/Utilities/SPCXOwnershipCalculator.swift
- MuskometerTests/OwnershipSyncTests.swift
- MuskometerTests/Fixtures/Ownership/* (create only if needed; load via source-relative path in tests, no project resource edits)

- [ ] Add regression tests using fixture URLProtocol at the SEC transport boundary. The original probe source is `/Users/jlgolson/grok/muskometer/build/review-2026-09-10/evidence/data-probe.swift`. Adapt fixtures to explicit valid transaction dates and anchor coverage; assertions cover A-only sale preserving B/options, a late historical amendment, and recognized zero disposal. Confirm those failures before production edits.
- [ ] Introduce structured observations inside the existing parser/utilities files, with normalized bucket identity (class, D/I, ownership nature, and option strike/expiry where applicable), absolute post-transaction quantity, optional effective transaction date, row kind/order, original-submission date, and unresolved-relevant-row status. Parse XML robustly; missing/malformed/overflow/nonintegral values must not silently become zero or trap. Keep `parse()` convenience behavior for existing tests where applicable.
- [ ] Bundle the verified SPCX anchor accession 0001628280-26-044069, filed 2026-06-17, and TSLA direct-common anchor 0001104659-26-075213, effective 2026-06-16, in existing utilities files. Derive bucket values from the public anchor XML fixtures, not from a newly guessed total. SPCX total must be 5,116,475,230; TSLA 710,172,677. Undated trusted anchor holding rows use the anchor observation date without inventing transaction dates.
- [ ] Decode submission date/acceptance metadata and scan all later relevant Form 4/4A entries back to the verified anchors, bounded by the current 100-accession limit and rate-limited/cancellable requests. Do not stop after two symbols. Missing anchor coverage makes the affected reconstruction incomplete.
- [ ] Reconstruct each sync from the immutable baseline plus collected observations. Replace only observed buckets in effective-date order. Within one ordinary filing use row order for same-day transactions. Ignore truly superseded older observations. Resolve a correction only when its original bucket/date is uniquely identifiable; unknown targets, conflicting unorderable same-day rows, new unknown identities, missing dates, unsupported securities, or incomplete coverage omit the affected symbol. Preserve all unchanged baseline buckets, including explicit zeros.
- [ ] Keep `HoldingsSyncResult` and AppSettings interfaces unchanged. No side effect to stored holdings occurs until the existing completeness check accepts the result. Repeated input produces identical totals.
- [ ] For companyfacts, retain accession/form metadata; select the latest preferred period/filing group, return equal repeated totals once, and return unresolved for conflicting totals. Do not fall through from an ambiguous DEI result to an older GAAP value. Do not sum rows solely because dates match.
- [ ] Add coverage for unchanged live anchors despite SPCX's February report date, valid newer ordinary updates, idempotence, amendments both superseded and uniquely correctable, ambiguous correction refusal, unknown/undated/malformed updates, bounded scan truncation, all-bucket disposal to zero, duplicate equal companyfacts totals, conflicting tied totals, and safe Int64 bounds. Run OwnershipSyncTests classes red/green and all tests after implementation.

## Task 3: Make notification state safe across suspension

**Depends on:** 1

### Files touched

- Muskometer/Services/GainThresholdNotificationService.swift
- Muskometer/Services/DayCloseSummaryNotificationService.swift
- Muskometer/Services/DailyRecordTracker.swift
- MuskometerTests/NotificationServicesTests.swift

- [ ] Add gated-deliverer regression tests from the review's records probe. For +10B, assert 9→11(await)→8→complete11→12 produces the second crossing; overlapping above-threshold observations cannot submit the same crossing twice. Verify failing expected assertions first.
- [ ] Evaluate every preset and commit observations/claims before awaiting any delivery. Use identities/versions for completion and failure handling. A successful older delivery must not overwrite newer observations; a failed crossing remains retryable above the threshold, without undoing a newer rearm/recross. Keep bounded per-preset state and backward-compatible persisted decoding. Reset/day change invalidate stale completion effects.
- [ ] Add explicit `DeliveryOutcome.inFlight` to day-close delivery. Keep `.delivered`, `.skipped` for disabled/already-confirmed, and `.failed` distinct. Assert concurrent duplicate returns inFlight, one actual add occurs, and failure does not mark the day delivered.
- [ ] Add identity-aware `consumePendingFinalizedDay(for:matching:)` to DailyRecordTracker (retain current overload for compatibility). Only consume when pending equals the supplied finalized day. Test an older acknowledgement cannot clear a newer pending day.
- [ ] Add `advanceClock(personID:at:) -> Snapshot` that loads persisted unfinished state and finalizes completed real trading days without recording an artificial quote/sample or regressing the current day. Test close, early close, relaunch, and new-day behavior with no quote fetch.
- [ ] Add multi-preset interleaving, delivery failure followed by newer above/below/recross samples, and reset/rollover tests; confirm all relevant notification/record tests pass.
- [ ] Report the exact new API contract to the parent for Task 5. Do not change GainsViewModel in this task; its integration is Task 5.

## Task 4: Bound the interface, preserve login status, correct the calendar

**Depends on:** 1

### Files touched

- Muskometer/Views/PopoverContentView.swift
- Muskometer/Views/SettingsView.swift (only screen constraint/routing if needed)
- Muskometer/Utilities/LaunchAtLoginManager.swift
- Muskometer/Utilities/AppSettings.swift (only login-state logic)
- Muskometer/Services/MarketHoursService.swift
- MuskometerTests/InterfaceAndCalendarTests.swift

- [ ] Add a status-aware login mock reproducing pending→reopen→approve. Assert desired preference remains true, no repeated register while pending, and no unregister after approval. Watch the current code fail. Preserve backward mock compatibility with a default status implementation if needed.
- [ ] Expose notRegistered/enabled/requiresApproval/unavailable status through LaunchAtLoginManaging. Reconcile against status, preserve pending desired=true, and avoid duplicate register. Explicit disable unregisters pending/enabled; notRegistered disable is a no-op. Verify error cases, restart, approval, and repeated reconciliation without real system changes.
- [ ] Reuse the populated-view review probe with an injectable available-height constraint. Assert actual NSHostingView fitting height fits 600/700/800/900 point limits and scrolling content/footer remain available. Add the bounded main scrolling area and account for embedded Settings without introducing a preference-size feedback loop. Preserve current width and all actions.
- [ ] Change the existing December 31, 2027 test to expect regular trading (confirm red), remove the holiday entry, and assert next open after its close is Jan 3, 2028. Preserve all other holiday/early-close tests.
- [ ] Run InterfaceAndCalendarTests and the actual-view sizing probe. Report the rendering evidence and any platform-testing limitations.

## Task 5: Integrate ordered side effects and independent refresh scheduling

**Depends on:** 1, 3

### Files touched

- Muskometer/ViewModels/GainsViewModel.swift
- MuskometerTests/RefreshLifecycleTests.swift

- [ ] Add actual-view-model regression tests adapted from `/Users/jlgolson/grok/muskometer/build/review-2026-09-10/evidence/view-model-probe.swift`: gated SEC does not block snapshot; due sync causes at most one extra quote refresh; overlapping day-close delivery leaves newest sample/milestone state; failed overlapping summary retains pending; failed closing fetch still finalizes real records. Confirm current production assertions fail.
- [ ] Commit snapshot/record/sample/milestone state synchronously before the first notification await. Start threshold observation processing in accepted-snapshot order. Use Task 3's inFlight outcome and matching acknowledgement; no older async tail may overwrite new observable or durable state.
- [ ] Own a separate weakly captured holdings task with one-at-a-time guard and lifecycle token; start it without awaiting it before initial/regular quotes. Trigger only on existing needs-sync/force rules. A changed accepted holding schedules one refresh/recomputation; remove caller/callee duplicate refresh. Verify late quote results cannot resurrect pre-sync counts.
- [ ] On stop, cancel all owned tasks and invalidate generations/tokens. On restart, old completions cannot clear new task handles or flags. Add cancellation and deallocation tests using gated services.
- [ ] Advance the trading clock independently in the actual loop and on refresh failures. Preserve quote timestamp and stale indication while updating current market session; use last observed regular record for finalization. Use Task 3's advanceClock and matching pending-day delivery.
- [ ] Schedule one closing request after a regular session; on transient failure allow at most one extra bounded retry before off-market sleep. Do not continuously poll Yahoo overnight. Keep durable notification retry pending, with a bounded off-market retry policy if implemented. Ensure next-open immediate refresh and early-close behavior remain correct. Inject a sleeper for deterministic loop tests rather than real long sleeps.
- [ ] Test stopped/restarted in-flight work, SEC errors, partial quote responses, settings-count updates during fetch, consecutive market days, close failures, and sleep cancellation. Run all RefreshLifecycleTests classes plus existing quote/record/notification regressions.

## Task 6: Integrate, document, and verify all twelve fixes

**Depends on:** 2, 4, 5

### Files touched

- docs/ARCHITECTURE.md
- docs/HOLDINGS.md
- docs/DEVELOPING.md (if changed test layout needs mention)
- CHANGELOG.md
- scripts/verify.sh (only if real verification compatibility requires it)
- Task 2–5 files only for independently reviewed integration fixes

- [ ] Inspect the actual cumulative branch diff from b4ff901; update architecture/holdings docs to reflect the shipped ownership algorithm, new scheduling/close policy, login status, correct calendar, and bounded interface. Write changelog entries from the actual diff, without a version/release bump.
- [ ] WHAT: all 12 reproduced failures are resolved while baseline functionality remains. HOW: run the targeted regression suites and `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer MUSKOMETER_SKIP_LIVE_YAHOO=1 scripts/verify.sh` on the fully integrated worktree. WHO: this task's implementer, with independent parent verification of output and review.
- [ ] WHAT: real parser/network paths and actual SwiftUI layout work. HOW: compile/run the original review probes against the changed source, adapting harnesses for deliberate API changes; perform read-only public SEC/Yahoo spot-checks where available, and actual NSHostingView/ImageRenderer sizing at constrained height. Record network unavailability explicitly rather than treating it as a deterministic code failure. WHO: this task's implementer.
- [ ] Confirm the 400-sample cap and per-person/per-threshold bounds remain; demonstrate stop releases the view model with slow services canceled. No claim of an exhaustive Instruments soak is required.
- [ ] Produce a finding-to-test/result table covering each report ID 1–12 and list all validation commands/results. Parent dispatches independent final conformance and quality reviews, resolves any findings, and preserves a reviewable branch. No production deployment or release.

## Deferred

None.

## Scale & Validation

Task 2 covers the 100-accession budget and representative full filings; Task 3 covers bounded preset state and interleaving; Task 5 covers ownership of long-lived tasks, clock transitions, and cancellation; Task 6 verifies integrated source/build/UI/public-data paths. Existing sample retention remains capped at 400. All external side-effect tests use controlled boundary mocks.
