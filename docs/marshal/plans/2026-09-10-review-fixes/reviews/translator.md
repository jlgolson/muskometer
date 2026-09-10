# Plan translation and spec coverage

dispatch_id: efba3a08-bc6d-495c-976c-a66e12d3d9f4-task-0

Revalidated by reading the complete current plan at commit `50474f8` first, then its referenced spec. No other reviews or session memory were consulted. This assessment supersedes the verdict for the earlier plan revision.

- Plan SHA-256: `cdb6192c44be65243b8cefa00c7e9a6f5ce2cb2bac9dd8630cc96d5a5c584710`
- Spec SHA-256: `28a0c19a8ba6021ac4b3d724112df87612405ae1c3bac27b4e24337faa745be6`

## What executing the plan produces

A reviewable corrective branch containing six deliverables: a mechanical split preserving all 248 baseline tests; complete ownership reconstruction and companyfacts deduplication; notification/record APIs that tolerate overlapping work; a height-bounded interface, status-aware login preference, and corrected calendar; independently scheduled SEC/quote work with ordered snapshot state and clock-based finalization; and updated documentation plus integrated verification evidence. There is no release or deployment.

Each behavioral task requires a failing regression before the production change. Validation includes real SEC parser/transport fixtures, gated notification and refresh interleavings, actual SwiftUI sizing at four height limits, deterministic market-loop tests, cancellation/deallocation checks, the complete verification script, read-only public-data spot checks when available, and a final finding-to-test/result table. These are planned checks; this translation does not claim they have run.

## Coverage against the spec

The spec groups findings 4–6, so their three outcomes are shown without inventing a more precise report-ID mapping.

| Finding | Required outcome | Concrete plan delivery and tests | Coverage |
| --- | --- | --- | --- |
| 1 | Partial filings preserve complete holdings | Task 2 anchors, normalized buckets, A-only sale retaining B/options, completeness refusal | Covered |
| 2 | Historical amendments cannot replace newer effective balances | Task 2 dated reconstruction, unique correction targets, superseded/ambiguous amendment tests | Covered |
| 3 | Recognized zero balances remain valid | Task 2 explicit zeros, full-disposal regression, malformed/unrecognized values refused, checked bounds | Covered |
| 4–6: snapshot ordering | An older suspended refresh cannot overwrite newer samples, milestones, or records | Task 5 commits state before notification awaits and tests overlapping actual-view-model refreshes | Covered |
| 4–6: threshold ordering | Crossings are reserved before suspension; old completions preserve newer rearming and retries | Task 3 identities/versions, gated crossing tests, failure/multiple-preset/reset/rollover interleavings | Covered |
| 4–6: summary acknowledgement | In-flight delivery is distinct from terminal skip; only the matching pending day is consumed | Task 3 `inFlight`, identity-aware consumption, and explicit instance lifecycle invalidation; Task 5 overlapping/failing delivery and reset/stop/restart integration tests | Covered |
| 7 | Slow SEC work cannot block quotes or cause duplicate refreshes | Task 5 independent owned holdings task, current-count protection, gated SEC and lifecycle tests | Covered |
| 8 | Failed closing quotes still finalize real observations without presenting them as fresh closing prices | Tasks 3/5 clock advancement, preserved timestamp/staleness, bounded close retry, and real-loop tests; Task 3 qualifies summary text with the real observation time and captures requests; Task 5 verifies that content after a failed closing fetch | Covered |
| 9 | Popover and embedded Settings remain usable on constrained screens | Task 4 bounded scrolling and actual NSHostingView sizing at 600/700/800/900 points | Covered |
| 10 | Pending login approval preserves preference without repeat registration or later unintended unregister | Task 4 complete status model and pending/reopen/approve/error/restart mock tests | Covered |
| 11 | December 31, 2027 is a regular trading day | Task 4 removes holiday, corrects conflicting regression, verifies January 3 next open | Covered |
| 12 | Equal companyfacts totals deduplicate; ambiguous conflicts remain unresolved | Task 2 accession/form-aware selection, duplicate/conflict regressions, no older-concept fallback | Covered |

## Assessment

All twelve outcomes have concrete implementation responsibility and regression coverage. Task 3 now owns both day-close lifecycle invalidation and message content; Task 5 depends on it and verifies the consuming view-model behavior. The failed-closing-fetch scenario explicitly asserts the last-observed qualification and real sample time, satisfying the previously absent content requirement.

The plan also covers bounded state/scans, preservation of existing persisted interfaces, cancellation, all baseline tests, real-view checks, documentation, and independent integrated review. No remaining outcome coverage gaps found. Re-review is required if the plan changes; implementation correctness remains subject to the planned tests and final reviews.

VERDICT: APPROVED
