# Security objective review — round 1

Role: objective-reviewer (security)  
PR: https://github.com/jlgolson/muskometer/pull/4  
Plan: `docs/marshal/plans/2026-08-17-holdings-surface-refresh.md`  
Spec: `docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md`  
Diff basis: `origin/main...HEAD` via `.marshal-cache/pr.diff` (product/tests/docs/scripts; marshal review trees ignored)

This is a local, sandboxed, single-user menu-bar app. The change reseeds public Form 4 / outstanding integers, remigrates exact UserDefaults fingerprints, drops the comparison-caption stack, and refreshes static marketing HTML. I generated attacker hypotheses first (injection into the Form 4 string parser, remigration overwrite, comparison-key wipe, fail-open sync, entitlement/dependency growth, HTML/WKWebView XSS), then traced load → remigrate → persist → next-launch → Form 4 retry / outstanding fetch against those classes.

What held: remigration is exact `Int64` match and pass-through otherwise; incomplete Form 4 sync still refuses to write; remarks regex that minted share counts from untrusted text is gone; comparison history is deleted by exact keys only; entitlements stay `app-sandbox` + `network.client`; no new packages or ATS exceptions; marketing HTML has no scripts; the WKWebView PNG helper is docs-only, JS-disabled, `loadHTMLString` with `baseURL: nil`.

## Findings

None.

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"d509355d-0d0b-4e55-8e24-394b3fbc9050","verdict":"approved","round":1,"role":"objective-reviewer","objective":"security","pr_number":4,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- `docs/marshal/plans/2026-08-17-holdings-surface-refresh.md`
- `docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md`
- `.marshal-cache/pr.diff`
- `Muskometer/Utilities/AppSettings.swift`
- `Muskometer/Utilities/SPCXOwnershipCalculator.swift`
- `Muskometer/Utilities/SPCXHoldings.swift`
- `Muskometer/Utilities/IssuerSharesOutstanding.swift`
- `Muskometer/Utilities/ShareCountTextInput.swift`
- `Muskometer/Utilities/MergerMarketCapParity.swift`
- `Muskometer/Models/TrackedPersonProfile.swift`
- `Muskometer/Services/Form4OwnershipParser.swift`
- `Muskometer/Services/SECHoldingsSyncService.swift`
- `Muskometer/Services/IssuerOutstandingSyncService.swift`
- `Muskometer/Services/CompanyFactsOutstandingResolver.swift`
- `Muskometer/Services/MarketHoursService.swift`
- `Muskometer/ViewModels/GainsViewModel.swift`
- `Muskometer/Views/SettingsView.swift`
- `Muskometer/Views/PopoverContentView.swift`
- `Muskometer/Views/MergerParityCardView.swift`
- `Muskometer/Muskometer.entitlements`
- `Muskometer/Resources/Info.plist`
- `Muskometer.xcodeproj/project.pbxproj`
- `scripts/verify.sh`
- `docs/screenshots/render-pngs.swift`
- `docs/screenshots/render-capture.html`
- `docs/screenshots/render-popover.html`
- `docs/screenshots/render-og.html`
- `docs/index.html`
- `docs/PRIVACY.md`
- `SECURITY.md`
