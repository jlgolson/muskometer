# Task 5 Spec Review — Issuer outstanding sync + GainsViewModel presentation

**Role:** spec-reviewer  
**Task:** 5 (IssuerOutstandingSyncService + `mergerParityPresentation`; design §2 sync orthogonality, §4 wiring, Error handling)  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md` §2, §4, Error handling, Acceptance 2–4  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 5  
**Date:** 2026-08-07  

## Scope checked

Design §2 / §4 / Error handling and plan Task 5 require (for this task only):

| Requirement | Expected |
|-------------|----------|
| Service API | `IssuerOutstandingSyncService` with `init(session:)`, `fetchOutstanding(for:) async -> [String: Int64]` |
| User-Agent | Same SEC pattern as Form 4: `Muskometer/\(AppVersion.short) (info@muskometer.org; https://muskometer.org)` |
| Fetch | Per-spec `issuerCIKPadded` → companyfacts `CIK{padded}.json`; parse via resolver; skip failures |
| Delay | ~120ms between requests (Form 4 crawl style) |
| Orthogonality | Not folded into `HoldingsSyncResult` / ownership completeness; Form 4 must not fail solely because companyfacts fails |
| Wire path | Best-effort outstanding from `syncHoldingsFromSEC` when Form 4 attempt runs (success, partial, or throw) |
| Persist | Positive results → `settings.setSharesOutstanding`; failures keep prior/default |
| Presentation | `mergerParityPresentation` keys live `"TSLA"` / `"SPCX"` quotes + settings outstanding |
| Defaults-only | Card/presentation still computable when outstanding never companyfacts-synced (bundled defaults) |
| Hide rules | `nil` only when snapshot/quote legs missing or calculator guards fail — **not** when outstanding is defaults-only |
| Inject (optional) | Factory / default service for tests |
| pbxproj | IDs `A1…53` / `A2…53` |
| Tests | Smoke presentation + orthogonal sync isolation |

Out of scope for Task 5 (deferred to Task 6): `MergerParityCardView`, popover placement, `HOLDINGS.md`.

## Findings

None.

## Compliance checklist

| Requirement | Status | Evidence |
|-------------|--------|----------|
| `IssuerOutstandingSyncService` + protocol | Pass | `IssuerOutstandingSyncServiceProtocol.fetchOutstanding(for:)`; concrete class with `init(session: URLSession = .shared)` |
| User-Agent matches Form 4 / plan | Pass | Identical string to `SECHoldingsSyncService.userAgent` |
| companyfacts URL + resolver | Pass | `https://data.sec.gov/api/xbrl/companyfacts/CIK\(cikPadded).json` → `CompanyFactsOutstandingResolver.resolveSharesOutstanding` |
| Skip empty CIK / failures; never throw out of `fetchOutstanding` | Pass | `guard let cik`; private `fetchOutstanding` catch → nil; public method returns partial dict only |
| Positive shares only in result map | Pass | `shares > 0` before insert; symbol uppercased |
| ~120ms inter-request delay | Pass | `Task.sleep(for: .milliseconds(120))` when `requestIndex > 0` |
| Orthogonal to Form 4 result type | Pass | Separate service; not part of `HoldingsSyncResult` or `applyHoldingsSync` |
| Always attempted after Form 4 attempt path | Pass | `await syncIssuerOutstanding` after `do/catch` in `syncHoldingsFromSEC` (success, partial message, or catch) |
| Outstanding failure does not rewrite Form 4 message | Pass | No writes to `holdingsSyncMessage` in `syncIssuerOutstanding`; test keeps `"SEC sync failed"` while outstanding applied |
| Persist via `setSharesOutstanding` | Pass | Loop `where shares > 0` → `settings.setSharesOutstanding` |
| Empty outstanding result keeps defaults | Pass | `testOutstandingEmptyResultDoesNotChangeDefaultsOrForm4SuccessMessage` |
| Presentation keys `"TSLA"` / `"SPCX"` | Pass | Exact symbol match on `snapshot.holdings` + `settings.sharesOutstanding(for: "TSLA"|"SPCX")` |
| Uses `MergerMarketCapParity.presentation` | Pass | Matches plan snippet (prices from quote legs, outstanding from settings) |
| Defaults-only still computable | Pass | `AppSettings.sharesOutstanding` falls back to `IssuerSharesOutstanding` defaults; `testPresentationUsesDefaultOutstandingWhenUnset` asserts equality with defaults math |
| Nil without snapshot | Pass | `testPresentationNilWithoutSnapshot` |
| Prices + settings outstanding wiring | Pass | `testPresentationUsesSnapshotPricesAndSettingsOutstanding` (100/50, 2/4 → implied 100) |
| Injectability | Pass | `outstandingSyncServiceFactory` default `{ IssuerOutstandingSyncService() }`; mock protocol in tests |
| pbxproj IDs 53 | Pass | Build file `A100…53`, fileRef `A200…53`, Services group + Sources |
| Ownership keys untouched by outstanding sync | Pass | Failure-path test asserts Form 4 share counts remain defaults while outstanding updates |

## Non-blocking notes

- Presentation nil when only one of TSLA/SPCX is present in the snapshot is implied by the dual `guard` but not covered by a dedicated unit test. Calculator already unit-tested; single-leg hide is straightforward. Optional follow-up.
- Outstanding runs after the Form 4 block (including after a complete-sync `refresh`). Plan prefers “always try when Form 4 attempt runs”; ordering after Form 4 is correct and keeps Form 4 message semantics isolated.

## VERDICT: APPROVED

## Reviewed files

- `Muskometer/Services/IssuerOutstandingSyncService.swift` — companyfacts fetch, User-Agent, delay, non-throwing map, resolver integration
- `Muskometer/ViewModels/GainsViewModel.swift` — factory inject; `syncHoldingsFromSEC` → `syncIssuerOutstanding`; `mergerParityPresentation` TSLA/SPCX keys + defaults via settings
- `Muskometer.xcodeproj/project.pbxproj` — IDs `A10000000000000000000053` / `A20000000000000000000053`
- `MuskometerTests/MuskometerTests.swift` — `GainsViewModelMergerParityPresentationTests`, `GainsViewModelIssuerOutstandingSyncTests`, `MockIssuerOutstandingSyncService`
- `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md` §2 orthogonality, §4 wiring, Error handling, Acceptance 2–4
- `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 5 steps

VERDICT: APPROVED
