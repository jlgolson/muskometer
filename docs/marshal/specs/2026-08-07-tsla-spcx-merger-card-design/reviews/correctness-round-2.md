# Spec correctness review — round 2

**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md`  
**Role:** spec-correctness  
**Date:** 2026-08-07  
**Mode:** Independent full read against source (no reliance on prior review findings)

## Sources read

- Spec: `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md`
- `Muskometer/Services/SECHoldingsSyncService.swift`
- `Muskometer/Services/HoldingsSyncServiceProtocol.swift`
- `Muskometer/Services/NetWorthMilestoneTracker.swift`
- `Muskometer/Models/TrackedPersonProfile.swift`
- `Muskometer/Models/GainsSnapshot.swift`
- `Muskometer/ViewModels/GainsViewModel.swift`
- `Muskometer/Views/PopoverContentView.swift`
- `Muskometer/Utilities/AppSettings.swift`
- `docs/HOLDINGS.md`

## Summary

The design is implementable against the current architecture. Goals, non-goals, formulas, SEC vs Form 4 separation, card visibility rules, typo fix, error handling, and unit-test matrix are coherent. Bundled defaults make the card shippable when SPCX companyfacts lacks a trustworthy multi-class point-in-time total. Outstanding sync is correctly kept out of the ownership completeness gate. No blocking gaps for plan-writing.

## Feasibility

| Slice | Assessment |
|-------|------------|
| Typo fix | Trivial. Source has `belowTrillionMessage = "One Trillion Is the Lonliest Number"`; tests assert the misspelling and embed `Lonliest` in a test name — both covered. |
| Pure calculator | Pure `Double` / `Int64` math with `nil` guards; unit-testable without I/O. Fits existing pure-util patterns. |
| Issuer CIKs + companyfacts | Standard SEC endpoint; TSLA single-class path is routine. SPCX multi-class may stay unresolved → cover-derived default is an explicit, correct product fallback. |
| Settings keys | Parallel to `shareCount_*`: independent `sharesOutstanding_*`, load/default/reset paths extend `AppSettings` cleanly without touching ownership keys. |
| Daily SEC path | `GainsViewModel.syncHoldingsFromSEC` already owns the ~24h attempt; adding a best-effort companyfacts step beside Form 4 (without folding into `HoldingsSyncResult`) matches the existing control flow. |
| Snapshot / UI | `GainsSnapshot` already carries both legs when quotes succeed (all-or-nothing completeness today). Card after stock rows in `PopoverContentView.dataView` is a small SwiftUI addition; formatters (`formatCurrency` / `formatMarketValue`) already exist. |
| Payload size | Called out: multi-MB companyfacts, parse only target concepts, 24h cadence — acceptable for a macOS menu-bar app. |

## Architectural fit

**Correct separation of concerns**

- Form 4 → person beneficial ownership (`shareCount_*`, `applyHoldingsSync` completeness).
- Companyfacts / cover defaults → issuer outstanding (`sharesOutstanding_*`).
- Yahoo → Class A (primary) last price.
- Calculator → parity presentation only.

Folding outstanding into `HoldingsSyncResult.sharesBySymbol` would be wrong: `applyHoldingsSync` treats missing expected symbols as incomplete and refuses to update ownership. The spec forbids that fold and requires orthogonal persistence. That matches how `AppSettings` and `HoldingsSyncServiceProtocol` are structured today.

**Issuer CIK on `TrackedHoldingSpec` (or adjacent symbol map)** keeps person CIK (Musk Form 4) distinct from issuer CIKs (Tesla / SpaceX entities). Presentation hard-keys `"TSLA"` / `"SPCX"` for this card, consistent with non-goal of multi-person generalization.

**Outstanding is symbol-global, not person-scoped** — correct for issuer facts; UserDefaults key shape in the spec is appropriate.

## Strengths

1. **Mcap quantity is defined, not implied** — economically equivalent common (A+B for SPCX), Class A Yahoo price × that total; explicitly rejects WASO / diluted / Form 4 ownership as proxies.
2. **SPCX reality is acknowledged** — companyfacts may only yield WASO (~5.86B wrong for mcap); unresolved keeps prior/default; bundled default is cover A+B with accession.
3. **Card resilience** — defaults-only still shows when both quotes exist; hide only on missing quote legs or calculator guards. Matches “useful cold start / offline” product intent.
4. **Resolver rules are plan-ready** — concept priority, multi-member same-`end` sum, form preference, `(end, filed)` sort, finite `> 0`, WASO reject list.
5. **Sync completeness matrix is explicit** — Form 4 ⟂ companyfacts; outstanding never participates in ownership gate; Form 4 must not fail solely because companyfacts fails.
6. **Scope discipline** — reverse parity, manual outstanding UI, 10-Q HTML parse, legal merger modeling, Yahoo mcap summary all non-goals.
7. **Testing** focuses on pure resolver + calculator + settings isolation; no mandatory live SEC CI.
8. **`## Deferred` / `## Scale & Validation` form present** — Deferred empty is honest for a tight v1; scale notes multi-MB parse and no multi-tenant dimension.

## Missing considerations (non-blocking)

These are residual plan/implementation notes, not missing capabilities in the design:

1. **Form 4 throw path ordering** — Spec requires companyfacts not to poison Form 4 `throws`, and outstanding success not to require Form 4 success. Plan should still attempt companyfacts when Form 4 fails (catch / parallel / always-run best-effort), so outstanding can refresh on a bad Form 4 day. Defaults keep the card usable either way.
2. **Dimensional double-count edge** — “Sum members with the same `end`” is right for pure A+B members; if a fact set ever includes both class members *and* a total row as separate members, naive sum over-counts. Current SPCX companyfacts is WASO-only (unresolved → default); fixtures should encode the expected member shapes so the plan-writer does not invent a fragile full taxonomy.
3. **SEC polite spacing** — Form 4 already sleeps ~120ms between accessions; two additional companyfacts GETs should reuse the same User-Agent and not stampede. Unstated but implied by “same SEC User-Agent” / existing service norms.
4. **UI honesty after outstanding refresh** — Partial Form 4 skips ownership refresh; outstanding can still change under settings. Next quote refresh (~RTH interval) or a lightweight re-derive of presentation is enough; no special event bus required.
5. **Footer / docs** — HOLDINGS.md update is required and sufficient for v1; optional footer tweak (“outstanding: issuer companyfacts”) is polish, not a correctness gate.

## Architectural risks (accepted for v1)

| Risk | Why acceptable |
|------|----------------|
| Stale outstanding after recap / split until next daily sync or default bump | 24h cadence + comment-sourced bundled constants; no Settings editor is an explicit non-goal. |
| SPCX companyfacts never gains trustworthy multi-class totals | Product still correct via cover defaults; resolver must not “succeed” with WASO. |
| Card confusable with ownership rows | Placement after stock rows + explicit title about market-cap parity; distinct from Musk stake math. |
| Multi-MB JSON on main thread if mis-placed | Spec says dedicated fetch/parser on daily SEC path; plan should keep parse off UI-critical path (existing Form 4 work is already async). |

## Open questions

None that block plan-writing. Implementation choices (exact type names, whether `mergerParityCard` is a `GainsViewModel` computed property vs pure function in the view) are deliberately left as sketch-level and do not change behavior.

## Deferral discipline

- **`## Deferred`:** `None.` — Appropriate; reverse parity, manual outstanding edit, 10-Q HTML, multi-person UI, Yahoo mcap API are non-goals rather than silent deferrals.
- **`## Scale & Validation`:** Present; two issuer CIKs, local parse, multi-MB caution, no CI live network test. No false multi-tenant claims.

## Alignment with current source (spot checks)

- `HoldingsSyncResult` is ownership-only (`sharesBySymbol`) — do not extend for outstanding without a separate type (spec agrees).
- `applyHoldingsSync` all-symbols-complete gate — outstanding must stay outside (spec agrees).
- `TrackedHoldingSpec` today has person parse strategy + default ownership counts, not issuer outstanding — adding issuer CIK / outstanding defaults is a clean extension.
- `GainsViewModel.refresh` requires complete quote set for both holdings — in practice both TSLA and SPCX are present or the snapshot fails; card “missing one leg” is still the right guard for partial presentation models.
- `PopoverContentView.dataView` ends with stock rows + optional error caption — natural insertion point for `MergerParityCardView`.
- `resetToDefaults()` resets ownership to profile defaults and clears sync metadata — must also reseed outstanding keys (spec requires).

## Findings

None.

## Findings (machine-readable)

```json
{
  "schema_version": 1,
  "round": 2,
  "role": "spec-correctness",
  "verdict": "APPROVED",
  "findings": []
}
```

VERDICT: APPROVED
