# Persistence objective review — round 1

- Role: objective-reviewer (persistence)
- PR: https://github.com/jlgolson/muskometer/pull/4
- Plan: `docs/marshal/plans/2026-08-17-holdings-surface-refresh.md` (Tasks 3–5)
- Spec: `docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md` §1–§2, §4, Upgrade contract
- Diff basis: cumulative vs `origin/main` (product sources; `.marshal-cache/pr.diff` hunks for `AppSettings` / `SPCXHoldings` / `IssuerSharesOutstanding` / deleted `ComparisonHistoryStore`)

Write↔verify on the three remigration keys is closed: persist is always `String(Int64)` under `shareCount_<SYM>` / `sharesOutstanding_<SYM>`; load is `string(forKey:)` → `Int64`; remigrate is exact-integer equality; persist-if-changed writes the same decimal form. Targets `{5_116_475_230, 710_172_677, 13_571_069_199}` are not members of their legacy sets, so a second `AppSettings` init parses the new decimal, `migrated == value`, and skips the write. Unknown / current / custom values pass through. Fresh suites leave keys missing and serve spec/bundled fallbacks. Comparison history has no remaining write path; load + Reset `removeObject` the two key shapes the deleted store actually wrote.

## Findings

None.

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"e114dd80-3dcb-4334-b137-d3175cc2c21b","verdict":"approved","round":1,"role":"objective-reviewer","objective":"persistence","pr_number":4,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- Muskometer/Utilities/AppSettings.swift
- Muskometer/Utilities/SPCXHoldings.swift
- Muskometer/Utilities/IssuerSharesOutstanding.swift
- Muskometer/Models/TrackedPersonProfile.swift
- Muskometer/Models/PortfolioHolding.swift
- Muskometer/Utilities/ShareCountTextInput.swift
- Muskometer/Services/Form4OwnershipParser.swift
- Muskometer/Services/IssuerOutstandingSyncService.swift
- Muskometer/Services/CompanyFactsOutstandingResolver.swift
- Muskometer/ViewModels/GainsViewModel.swift
- Muskometer/Views/SettingsView.swift
- MuskometerTests/MuskometerTests.swift (`IssuerSharesOutstandingTests`, `SPCXHoldingsTests`, `AppSettingsTests` seed/reset/round-trip cases)
- Muskometer/Services/ComparisonHistoryStore.swift (deleted; keys confirmed via `.marshal-cache` copy + `pr.diff`)
- docs/marshal/plans/2026-08-17-holdings-surface-refresh.md
- docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md
