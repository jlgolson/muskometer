# Task 5 Code Quality Review — IssuerOutstandingSyncService + GainsViewModel wiring

**Role:** code-quality-reviewer  
**Task:** 5 (Best-effort companyfacts outstanding fetch; AppSettings persistence; Form 4 independence)  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 5  
**Date:** 2026-08-08  

## Scope reviewed

Quality axes only: naming, MainActor / concurrency, error isolation, injectability, tests, pbxproj `…53`, no drive-by.

Files:

- `Muskometer/Services/IssuerOutstandingSyncService.swift`
- `Muskometer/ViewModels/GainsViewModel.swift` (factory, `syncHoldingsFromSEC` tail, `syncIssuerOutstanding`)
- Related tests in `MuskometerTests/MuskometerTests.swift` (`GainsViewModelIssuerOutstandingSyncTests`, `MockIssuerOutstandingSyncService`, holdings-sync call sites that inject the factory)
- `Muskometer.xcodeproj/project.pbxproj` IDs `…53`

Did **not** re-review Task 4 resolver purity/fixtures or Task 6 presentation/UI beyond incidental adjacency.

## Findings

None.

### Naming

| Item | Assessment |
|------|------------|
| `IssuerOutstandingSyncService` / `…Protocol` | Clear domain: **issuer** shares outstanding (market-cap), not Form 4 ownership. Distinct from `SECHoldingsSyncService` / `shareCount`. |
| `fetchOutstanding(for:)` | Non-throwing, returns partial map — name matches best-effort contract. |
| `syncIssuerOutstanding(for:)` | Private VM helper; verb aligns with `syncHoldingsFromSEC` without overloading “holdings.” |
| `outstandingSyncServiceFactory` | Parallel to `holdingsSyncServiceFactory`; obvious DI hook. |
| `setSharesOutstanding` / `sharesOutstanding(for:)` (settings) | Orthogonal keys/API to ownership `setShareCount` / `shareCount(for:)`. |
| Test type `GainsViewModelIssuerOutstandingSyncTests` / mock | Mirror product types; no ownership vocabulary leakage. |

Symbol keys uppercased at service boundary; settings re-normalize — consistent, not confusing.

### MainActor / concurrency

| Check | Status |
|-------|--------|
| Network service not `@MainActor` | Pass — I/O off the UI actor model used by the VM |
| Protocol `Sendable`; impl `@unchecked Sendable` | Pass — same pattern as `SECHoldingsSyncService` (session-only state) |
| VM `@MainActor`; `syncIssuerOutstanding` writes `settings` on actor | Pass |
| `await` on `fetchOutstanding` / per-CIK fetch | Pass — MainActor can suspend during sleep + network |
| Sequential loop + 120ms spacing | Pass — mirrors SEC Form 4 crawl politeness |

`try? await Task.sleep` (vs Form 4’s `try await` inside a throwing API) is appropriate for a non-throwing best-effort method and matches other non-throwing sleeps in the app. Cancellation does not abort the outstanding loop early — acceptable for fire-and-forget companyfacts; not a quality defect.

### Error isolation

| Rule | Implementation | Assessment |
|------|----------------|------------|
| Never throw out of `fetchOutstanding` | Private fetch catches; bad HTTP → nil; omit key | Pass |
| Specs without CIK / empty CIK | `continue` | Pass |
| Non-positive resolved shares | `shares > 0` gate before insert | Pass |
| Independent of Form 4 outcome | Call sits **after** Form 4 `do/catch`; always runs when sync method proceeds | Pass |
| Does not mutate `holdingsSyncMessage` | Only `setSharesOutstanding` | Pass — covered by tests |
| Does not touch ownership share counts | Separate settings API | Pass — covered by tests |
| Persistence rejects non-positive | `AppSettings.setSharesOutstanding` guards `count > 0` | Pass — third layer with service + VM filter |

Triple positive-only filter (service → VM → settings) is belt-and-suspenders, not drive-by complexity.

### Injectability

| Check | Status |
|-------|--------|
| `IssuerOutstandingSyncServiceProtocol` | Pass — thin, `Sendable` |
| `URLSession` injectable on concrete type | Pass — `init(session:)` default `.shared` |
| VM factory `() -> any IssuerOutstandingSyncServiceProtocol` | Pass — default `{ IssuerOutstandingSyncService() }` |
| Factory takes no profile | Correct — service consumes `holdingSpecs`, not person CIK |
| Tests inject mock | Pass — dedicated outstanding tests + holdings backoff/success paths that call `syncHoldingsFromSEC` |

Factory recreates the service per sync (same style as holdings). Fine for this stateless HTTP client.

### Tests

| Requirement / behavior | Coverage | Status |
|------------------------|----------|--------|
| Outstanding applied after Form 4 **failure**; message still “SEC sync failed…” | `testOutstandingAppliedAfterForm4FailureWithoutChangingMessage` | Pass |
| Ownership counts unchanged when outstanding applied | Same test asserts default share counts | Pass |
| Empty outstanding map leaves defaults; Form 4 success message intact | `testOutstandingEmptyResultDoesNotChangeDefaultsOrForm4SuccessMessage` | Pass |
| Outstanding still invoked once when Form 4 fails / succeeds | `callCount == 1` both tests | Pass |
| Holdings backoff tests avoid live SEC companyfacts | Inject `MockIssuerOutstandingSyncService(result: [:])` | Pass |
| Mock is protocol-backed, file-private | `MockIssuerOutstandingSyncService` | Pass |

**Non-blocking gaps (optional follow-ups, not fix-required):**

- No pure unit tests on the HTTP wrapper itself (URL shape, skip-no-CIK, rate-limit index). Acceptable: resolver is Task 4–tested; this type is a thin sequential fetcher.
- No explicit “Form 4 success **and** non-empty outstanding → message still success” case. Message isolation is already proven on the failure path; empty-result success path covers non-interference the other way.
- Broader `GainsViewModel` suites that only `refresh` need not inject the factory (outstanding runs only from `syncHoldingsFromSEC`). Correct default scope.

### pbxproj (`…53`)

| Check | Status |
|-------|--------|
| `PBXBuildFile` `A10000000000000000000053` | Pass |
| `PBXFileReference` `A20000000000000000000053` | Pass |
| Services group child | Pass — next to `CompanyFactsOutstandingResolver` (`…52`) |
| App target Sources (`A60000000000000000000002`) entry | Pass |

IDs `…50`–`…52` and `…54` appear as sibling plan tasks; expected in this worktree, not Task 5 ID misuse.

### Drive-by / scope

Task 5 surface is tight:

1. Protocol + service file (network + resolver handoff only).
2. VM: factory property/init param, post–Form 4 `syncIssuerOutstanding`, settings writes.
3. Tests: mock + isolation cases; necessary factory injection on existing sync tests.
4. pbxproj registration for `…53` only for this file.

No unrelated renames, no Form 4 parser edits, no UI layout changes in the Task 5 slice. `mergerParityPresentation` lives adjacent in the VM (Task 6 consumer of settings outstanding) and is out of this quality pass’s ownership.

### Pattern alignment

| Pattern | Peer | Match |
|---------|------|-------|
| SEC User-Agent | `SECHoldingsSyncService` | Same string shape via `AppVersion.short` |
| 120 ms inter-request delay | Form 4 accession walk | Same duration |
| `@unchecked Sendable` session client | Holdings sync | Same |
| Factory DI on `GainsViewModel` | `holdingsSyncServiceFactory` | Same inject-for-tests style |
| Best-effort never throws | Documented on protocol + call site | Explicit |

## Summary

Clean Task 5 quality: best-effort contract is enforceable from types and tests, naming keeps issuer outstanding off ownership paths, MainActor usage is conventional, errors cannot poison Form 4 messaging, and DI matches existing holdings sync. No blocking nits.

VERDICT: APPROVED

## Reviewed files

- `/Users/jlgolson/grok/muskometer/.worktrees/tsla-spcx-merger-card/Muskometer/Services/IssuerOutstandingSyncService.swift`
- `/Users/jlgolson/grok/muskometer/.worktrees/tsla-spcx-merger-card/Muskometer/ViewModels/GainsViewModel.swift`
- `/Users/jlgolson/grok/muskometer/.worktrees/tsla-spcx-merger-card/MuskometerTests/MuskometerTests.swift` (issuer outstanding sync tests + mock + holdings factory inject sites)
- `/Users/jlgolson/grok/muskometer/.worktrees/tsla-spcx-merger-card/Muskometer.xcodeproj/project.pbxproj` (`…53` entries)
- `/Users/jlgolson/grok/muskometer/.worktrees/tsla-spcx-merger-card/Muskometer/Utilities/AppSettings.swift` (`setSharesOutstanding` / `sharesOutstanding` contract, referenced for isolation)

VERDICT: APPROVED
