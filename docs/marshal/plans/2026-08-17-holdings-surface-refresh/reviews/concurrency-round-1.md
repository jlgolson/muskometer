# Concurrency objective review — round 1

Role: objective-reviewer (concurrency)  
PR: https://github.com/jlgolson/muskometer/pull/4  
Plan: `docs/marshal/plans/2026-08-17-holdings-surface-refresh.md`  
Spec: `docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md`  
Diff basis: cumulative vs `origin/main` (product paths in `.marshal-cache/pr.diff`)

Checked the next-request adversary on AppSettings remigration, Form 4 / outstanding apply, caption-key sweep, and the MainActor sync loop. Fingerprint remigrations persist-if-changed then assign the in-memory maps as a single init step; missing keys read the new bundled defaults. Partial Form 4 still does not write counts. `isSyncingHoldings` still serializes auto + manual sync. Outstanding remains orthogonal and fail-omits. Caption writers are gone; leftover keys are delete-if-present. Calendar and calculator are stateless.

## Findings

None.

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"2ccf9355-c419-4d9d-8522-cb2e72a02a4f","verdict":"approved","round":1,"role":"objective-reviewer","objective":"concurrency","pr_number":4,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- `Muskometer/Utilities/AppSettings.swift`
- `Muskometer/Utilities/SPCXHoldings.swift`
- `Muskometer/Utilities/IssuerSharesOutstanding.swift`
- `Muskometer/Utilities/SPCXOwnershipCalculator.swift`
- `Muskometer/Models/TrackedPersonProfile.swift`
- `Muskometer/ViewModels/GainsViewModel.swift`
- `Muskometer/Services/SECHoldingsSyncService.swift`
- `Muskometer/Services/IssuerOutstandingSyncService.swift`
- `Muskometer/Services/CompanyFactsOutstandingResolver.swift`
- `Muskometer/Services/Form4OwnershipParser.swift`
- `Muskometer/Services/HoldingsSyncServiceProtocol.swift`
- `Muskometer/Services/MarketHoursService.swift`
- `Muskometer/Views/SettingsView.swift`
- `MuskometerTests/MuskometerTests.swift` (remigration + applyHoldingsSync + outstanding suites)
- `docs/marshal/plans/2026-08-17-holdings-surface-refresh.md`
- `docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md`
- `.marshal-cache/pr.diff` (product hunks: AppSettings, holdings seeds, calculator, GainsViewModel, SettingsView)
