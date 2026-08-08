# Security objective review — round 1

**Role:** objective-reviewer (security)  
**PR:** https://github.com/jlgolson/muskometer/pull/3  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md`  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md`  
**Date:** 2026-08-08  
**Diff basis:** `.marshal-cache/pr.diff` / `origin/main...HEAD` (product + tests + docs for merger parity card + Loneliest typo)

## Scope

Cold security review of the cumulative PR surface (new network path, JSON parse, settings persistence, UI sinks, project/entitlements). Checklist focus:

| Area | Surfaces reviewed |
|------|-------------------|
| Secrets / keys | Product sources, User-Agent strings, logs |
| Network | `IssuerOutstandingSyncService` → `https://data.sec.gov/api/xbrl/companyfacts/…`; existing Yahoo/Form 4 clients for parity |
| Parsing | `CompanyFactsOutstandingResolver` (`JSONSerialization`) |
| Untrusted → sinks | Remote JSON → Int64 → UserDefaults → calculator → SwiftUI `Text` |
| Entitlements / sandbox | `Muskometer/Muskometer.entitlements`, Info.plist ATS, pbxproj `CODE_SIGN_ENTITLEMENTS` |

Out of scope for fix bar: marshal plan/spec prose, historical reviews, `build/` artifacts, unsigned-DMG distribution tradeoff already documented in `SECURITY.md`.

## Failure hypotheses (generated, not assumed)

| ID | Hypothesis | Result |
|----|------------|--------|
| H1 | API keys / secrets committed or logged | **Not found** — public SEC/Yahoo only; no Keychain/token use; no `print`/`NSLog`/`Logger` in product code |
| H2 | SEC companyfacts calls omit required User-Agent (fair-access / abuse risk) | **Mitigated** — same descriptive UA as Form 4: `Muskometer/<ver> (info@muskometer.org; https://muskometer.org)` |
| H3 | Entitlements widened (file, keychain, server, temporary exception) | **Not found** — entitlements file unchanged; still app-sandbox + network.client only |
| H4 | SSRF / open URL via CIK interpolation | **Not exploitable today** — `issuerCIKPadded` is compile-time constants on musk TSLA/SPCX only; same URL-build pattern as existing person CIK |
| H5 | Remote strings injected into unsafe UI sinks (HTML/JS/attributed) | **Not found** — card shows fixed copy + `CurrencyFormatter` over local `Double`s only |
| H6 | Hostile companyfacts JSON causes crash, XXE, or type confusion | **Mitigated** — JSON only (no XML); invalid/missing structure → `nil`; val finite & positive; sum clamped to `Int64.max` |
| H7 | Unbounded response body → memory pressure / self-DoS | **Residual minor** — full body loaded via `URLSession.data`; companyfacts can be multi-MB; two CIKs on ~24h cadence |
| H8 | Cleartext HTTP or ATS exceptions for new host | **Not found** — HTTPS `data.sec.gov` only; no `NSAppTransportSecurity` exceptions in Info.plist |
| H9 | Outstanding map keys taken from remote payload (key injection into UD) | **Not found** — result keys are `spec.symbol.uppercased()` (local), values only from resolver |
| H10 | Sandbox / process escape via new code paths | **Not found** — no shell, no file APIs, no new listeners, no entitlement expansion |

## Network & sandbox

New outbound path:

```
IssuerOutstandingSyncService
  → GET https://data.sec.gov/api/xbrl/companyfacts/CIK{padded}.json
  → User-Agent: Muskometer/<short> (info@muskometer.org; https://muskometer.org)
  → 120 ms spacing between issuer requests
  → non-2xx / transport errors → omit symbol (never throws out of fetchOutstanding)
```

- Covered by existing `com.apple.security.network.client` (outbound client only).
- No new hosts beyond the same SEC `data.sec.gov` already used by Form 4 submissions.
- Yahoo path unchanged in this PR.
- Rate spacing matches Form 4 client; two fixed CIKs keeps load trivial.
- Default `URLSession` TLS validation retained (no custom trust / pinning changes).

## Parsing & data flow safety

```
companyfacts Data
  → JSONSerialization (try? → nil on failure)
  → walk only dei/us-gaap point-in-time outstanding concepts (WASO never read)
  → Int64? (finite, >0, ≤ Int64.max)
  → AppSettings.setSharesOutstanding (rejects ≤0)
  → UserDefaults string under sharesOutstanding_<SYMBOL>
  → MergerMarketCapParity (finite / >0 guards on prices & caps)
  → MergerParityCardView (SwiftUI Text of formatted numbers)
```

No remote free-text is rendered. Caption is a local template with formatted market values/prices. Form 4 ownership keys (`shareCount_*`) remain orthogonal — companyfacts cannot overwrite ownership counts.

## Entitlements / packaging

`Muskometer/Muskometer.entitlements` (unchanged in diff):

- `com.apple.security.app-sandbox` = true  
- `com.apple.security.network.client` = true  

pbxproj still points both Debug/Release app targets at that entitlements file. Info.plist gains no ATS exceptions and no new privacy-usage strings. Feature is pure client HTTPS + local UserDefaults; no Keychain, no file bookmarks, no server socket.

## Critical findings

None.

## Important findings

None.

## Minor findings

1. **No response size cap on companyfacts download** (`IssuerOutstandingSyncService.fetchData`): entire body is retained for `JSONSerialization`. Real companyfacts payloads can be multi-MB. Impact is local memory/CPU only (two hardcoded issuers, ~daily), same architectural class as existing EDGAR fetches. Optional harden: reject `Content-Length` above a ceiling or stream-parse only the needed concepts. Non-blocking for this PR.

2. **CIK string not format-validated before URL interpolation** (`fetchOutstanding(cikPadded:)`): currently safe because values are static `"0001318605"` / `"0001181412"`. If a future profile path ever accepts untrusted CIKs, prefer `\A\d{10}\z` (or numeric-only) validation before building the URL. Residual note only.

3. **Contact email in User-Agent** is intentional SEC fair-access policy (mirrors Form 4 service and `SECURITY.md` posture), not a secret leak. No additional logging of response bodies.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{
  "schema_version": 1,
  "dispatch_id": null,
  "verdict": "approved",
  "round": 1,
  "role": "objective-reviewer-security",
  "pr_number": 3,
  "plan_slug": "2026-08-07-tsla-spcx-merger-card",
  "findings": [
    {
      "severity": "minor",
      "id": "SEC-M1",
      "title": "Unbounded companyfacts response body",
      "path": "Muskometer/Services/IssuerOutstandingSyncService.swift",
      "summary": "Full HTTPS body loaded without size guard; residual self-DoS only, two CIKs on ~24h cadence."
    },
    {
      "severity": "minor",
      "id": "SEC-M2",
      "title": "CIK not format-validated before URL build",
      "path": "Muskometer/Services/IssuerOutstandingSyncService.swift",
      "summary": "Safe with hardcoded issuer CIKs today; validate if CIKs ever become untrusted input."
    }
  ]
}
```

VERDICT: APPROVED
