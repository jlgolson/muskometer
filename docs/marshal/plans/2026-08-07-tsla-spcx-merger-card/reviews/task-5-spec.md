# Task 5 — Spec review (cold)

**Lens:** Plan Task 5 steps + design §2 (orthogonality / sync completeness) + §4 (VM wiring) + Error handling table.  
**Not reviewed:** prior `task-5-spec.md` / `task-5-quality.md` contents; UI Task 6 placement.

## Checklist

| Requirement | Status |
|-------------|--------|
| `IssuerOutstandingSyncService` with `init(session:)`, User-Agent matching Form 4, `fetchOutstanding` never throws | Pass |
| GET `companyfacts/CIK{padded}.json`; resolve via pure resolver; skip failures | Pass |
| ~120ms delay between issuer requests | Pass |
| Invoked from `syncHoldingsFromSEC` after Form 4 path (success, partial, or catch) | Pass |
| Positive results → `setSharesOutstanding`; non-positive not persisted | Pass |
| Outstanding failure does not rewrite Form 4 `holdingsSyncMessage` | Pass |
| `mergerParityPresentation` keys `"TSLA"` / `"SPCX"` from snapshot + settings outstanding | Pass |
| Defaults-only outstanding still yields presentation when both quote legs present | Pass |
| pbxproj IDs `…53` for service | Pass |
| Tests cover presentation + Form 4 / outstanding independence | Pass |

## Findings

None.

## Notes (non-blocking)

- Dedicated protocol + `outstandingSyncServiceFactory` satisfy the plan’s optional injectability; mock-backed tests assert outstanding still runs after Form 4 throw and empty companyfacts leave Form 4 success messaging and bundled defaults intact.
- Service and `AppSettings.setSharesOutstanding` both gate on `> 0`, matching error-table “zero/negative → do not overwrite.”
- Presentation does not depend on companyfacts success: `settings.sharesOutstanding(for:)` falls back to bundled defaults (covered by `testPresentationUsesDefaultOutstandingWhenUnset`).

VERDICT: APPROVED

## Reviewed files

- `Muskometer/Services/IssuerOutstandingSyncService.swift`
- `Muskometer/ViewModels/GainsViewModel.swift` (`init` factory, `syncHoldingsFromSEC`, `syncIssuerOutstanding`, `mergerParityPresentation`)
- `Muskometer/Utilities/AppSettings.swift` (`sharesOutstanding(for:)`, `setSharesOutstanding` positive-only — settings surface used by Task 5 wiring)
- `Muskometer/Models/TrackedPersonProfile.swift` (issuer CIKs on holding specs — fetch input)
- `Muskometer.xcodeproj/project.pbxproj` (`A100…53` / `A200…53`)
- `MuskometerTests/MuskometerTests.swift` (`GainsViewModelMergerParityPresentationTests`, `GainsViewModelIssuerOutstandingSyncTests`, `MockIssuerOutstandingSyncService`)
- Plan Task 5 steps in `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md`
- Spec §2 orthogonality, §4 wiring, Error handling in `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md`

VERDICT: APPROVED
