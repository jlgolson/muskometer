# Task 5 Code Quality Review — Issuer outstanding sync + GainsViewModel presentation

**Role:** code-quality-reviewer  
**Task:** 5 (IssuerOutstandingSyncService + GainsViewModel presentation wiring)  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 5  
**Date:** 2026-08-07  

## Scope reviewed

Quality axes: MainActor / concurrency, error isolation from Form 4, SEC User-Agent, injectability, tests, pbxproj, no drive-by UI. Task adds a small network service + VM hooks for presentation; pure calculator/resolver already landed in T3/T4.

## Findings

None blocking.

### MainActor / concurrency

| Check | Status |
|-------|--------|
| `GainsViewModel` remains `@MainActor` | Pass — settings writes and `holdingsSyncMessage` stay on main actor |
| Network service off UI types | Pass — `IssuerOutstandingSyncService` is a plain `final class`, not MainActor-isolated |
| `Sendable` surface | Pass — protocol `IssuerOutstandingSyncServiceProtocol: Sendable`; concrete `@unchecked Sendable` mirrors `SECHoldingsSyncService` |
| Async composition | Pass — `await service.fetchOutstanding` from MainActor async method; suspension during I/O is correct |
| Inter-request delay | Pass — `try? await Task.sleep(for: .milliseconds(120))`; cancellation/sleep failure does not abort the batch |
| Session injection | Pass — `init(session: URLSession = .shared)` enables future URLProtocol tests without changing call sites |

No concurrent mutation of VM state from the service: it only returns a value dictionary; the VM applies results on MainActor.

### Error isolation

| Condition | Behavior | Assessment |
|-----------|----------|------------|
| HTTP non-2xx / transport error | private `fetchData` throws → caught → symbol omitted | Solid |
| Bad URL / empty CIK | skip symbol | Solid |
| Resolver nil / non-positive | omit symbol | Solid |
| `fetchOutstanding` public API | never throws; partial map | Matches plan “never throw out of fetchOutstanding” |
| Form 4 `throws` | catch records attempt + message; then still runs outstanding | Orthogonal — companyfacts independent of Form 4 |
| Outstanding empty `[:]` | no `setSharesOutstanding`; defaults preserved; Form 4 success message unchanged | Test-backed |
| Outstanding success after Form 4 failure | applies outstanding; message still “SEC sync failed…” | Test-backed |
| Double positive guard | VM `shares > 0` + `AppSettings.setSharesOutstanding` guard | Defensive, not redundant noise |

`holdingsSyncMessage` is only written in the Form 4 `do/catch` path. Outstanding path is silent on failure — correct for best-effort issuer data.

### User-Agent

| Check | Status |
|-------|--------|
| SEC descriptive UA | Pass — `Muskometer/\(AppVersion.short) (info@muskometer.org; https://muskometer.org)` |
| Matches Form 4 service | Pass — character-for-character with `SECHoldingsSyncService` |
| Applied on request | Pass — `request.setValue(userAgent, forHTTPHeaderField: "User-Agent")` before `session.data` |

### Injectability

| Check | Status |
|-------|--------|
| Protocol abstraction | Pass — `IssuerOutstandingSyncServiceProtocol` with single async method |
| Factory default | Pass — `outstandingSyncServiceFactory: () -> any IssuerOutstandingSyncServiceProtocol = { IssuerOutstandingSyncService() }` |
| Test mock | Pass — `MockIssuerOutstandingSyncService` returns canned map, counts calls |
| Existing Form 4 tests updated | Pass — holdings backoff tests inject empty outstanding mock so tests do not hit live SEC |
| Production call site | Pass — `MuskometerApp` continues default `GainsViewModel(...)` (factory default) |

Factory is created per `syncIssuerOutstanding` invocation (new service each sync) — fine for stateless fetch; avoids retaining a long-lived session wrapper on the VM.

### Tests

| Scenario | Test | Status |
|----------|------|--------|
| Presentation nil without snapshot | `testPresentationNilWithoutSnapshot` | Pass |
| Live prices + settings outstanding | `testPresentationUsesSnapshotPricesAndSettingsOutstanding` | Pass — asserts full presentation fields |
| Defaults-only outstanding | `testPresentationUsesDefaultOutstandingWhenUnset` | Pass — compares to pure calculator with `IssuerSharesOutstanding.defaultTSLA/SPCX` |
| Form 4 fail + outstanding still applied | `testOutstandingAppliedAfterForm4FailureWithoutChangingMessage` | Pass — isolation + ownership keys unchanged |
| Form 4 success + empty outstanding | `testOutstandingEmptyResultDoesNotChangeDefaultsOrForm4SuccessMessage` | Pass |

Tests are `@MainActor` XCTestCase classes, use isolated `UserDefaults` suites, and never call live SEC. No mandatory integration test — matches design Testing “No mandatory live SEC integration test in CI.”

**Non-blocking gaps:** no unit coverage of `IssuerOutstandingSyncService` HTTP path (URLProtocol); no single-leg missing-quote presentation nil test. Both are low risk given pure resolver/calculator coverage and thin glue.

### Structure & naming

| Item | Assessment |
|------|------------|
| `IssuerOutstandingSyncService` | Clear domain; distinct from Form 4 `SECHoldingsSyncService` |
| `fetchOutstanding` | Returns symbol→shares; non-throwing contract documented |
| `syncIssuerOutstanding` | Private VM helper; keeps `syncHoldingsFromSEC` readable |
| `mergerParityPresentation` | Matches plan API name for Task 6 consumers |
| Protocol + factory | Consistent with existing `holdingsSyncServiceFactory` pattern |

### pbxproj

| Check | Status |
|-------|--------|
| Build file ID `A10000000000000000000053` | Pass — plan table exact |
| File ref ID `A20000000000000000000053` | Pass |
| Services group child | Pass |
| Sources entry | Pass |
| No Task 6 UI file (`…54`) | Pass — no drive-by card view |

### Drive-by / scope

| Check | Status |
|-------|--------|
| No `MergerParityCardView` / popover UI | Pass |
| No `HOLDINGS.md` (Task 6/docs scope) | Pass |
| No resolver/calculator reimplementation | Pass — reuses T3/T4 types |
| Product surface = service + VM wiring + tests + pbxproj | Pass |

## Quality checklist

| Axis | Result |
|------|--------|
| MainActor / concurrency | VM MainActor; network service Sendable; await boundaries correct |
| Error isolation | Outstanding never throws into Form 4; messages and ownership path untouched on companyfacts failure |
| User-Agent | SEC-compliant; matches Form 4 crawl |
| Injectability | Protocol + factory + mock; live SEC avoided in unit tests |
| Tests | Presentation (nil / prices / defaults) + sync orthogonality (fail+apply / success+empty) |
| Scope | No UI creep; pbxproj IDs correct |

## VERDICT: APPROVED

## Reviewed files

- `Muskometer/Services/IssuerOutstandingSyncService.swift` — session inject, User-Agent, non-throwing fetch, delay, resolver
- `Muskometer/ViewModels/GainsViewModel.swift` — factory, `syncIssuerOutstanding`, `mergerParityPresentation`
- `MuskometerTests/MuskometerTests.swift` — presentation + issuer outstanding sync tests; mock; backoff tests updated
- `Muskometer.xcodeproj/project.pbxproj` — IDs `…53`, Services group + Sources

VERDICT: APPROVED
