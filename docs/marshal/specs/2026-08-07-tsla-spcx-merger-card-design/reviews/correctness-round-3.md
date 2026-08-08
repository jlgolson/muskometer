# Spec correctness review — round 3

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
- `Muskometer/Models/StockQuote.swift`
- `Muskometer/ViewModels/GainsViewModel.swift` (refresh + `syncHoldingsFromSEC`)
- `Muskometer/Views/PopoverContentView.swift`
- `Muskometer/Utilities/AppSettings.swift` (share keys, `applyHoldingsSync`, `resetToDefaults`)
- `docs/HOLDINGS.md`

## Summary

The design is implementable and product-correct against current architecture. Issuer outstanding is cleanly separated from Form 4 ownership; SPCX dual-class mcap uses Class A Yahoo price × (A+B) with a cover-derived ~13.18B default and an explicit WASO reject; card visibility with defaults-only is consistent; typo fix is scoped; framing sections (Risks, Acceptance, Observability, Rollout, Compliance, Dependencies, Alternatives) are present and coherent. No blocking gaps for plan-writing.

## Feasibility

| Slice | Assessment |
|-------|------------|
| Typo | Source has `belowTrillionMessage = "One Trillion Is the Lonliest Number"`; tests assert that string and embed `Lonliest` in a test name. Spec requires product + tests → `Loneliest` and rename of misspelled test names. Trivial, well-scoped. |
| Pure calculator | `Double` / `Int64` math with `nil` on non-finite / `≤ 0` inputs. Unit-testable; fits existing pure-util style (`CurrencyFormatter`, ownership calculators). |
| Outstanding defaults | TSLA `3_949_547_394` and SPCX `13_181_779_945` (A `7_696_293_669` + B `5_485_486_276`, accession pinned) fit `Int64`; cold start shows the card without network. |
| Companyfacts fetch | Same SEC User-Agent / ~24h cadence as Form 4; two issuer GETs; parse only target concepts (multi-MB payloads called out). Orthogonal to `HoldingsSyncResult`. |
| Settings | Parallel to `shareCount_*`: `sharesOutstanding_*`, getters/setters, reset reseeds — no ownership key collision. |
| Snapshot / UI | Snapshot already carries both quote legs when complete; insert `MergerParityCardView` after stock rows in `PopoverContentView.dataView`; formatters already exist (`formatPrice` / `formatMarketValue`). |
| Docs | `HOLDINGS.md` today is Form 4–only; required section is a small, clear addition. |

## Architectural fit

**Three data planes stay distinct**

| Plane | Source | Keys / type | Use |
|-------|--------|-------------|-----|
| Ownership | Form 4 person CIK (`0001494730`) | `shareCount_*` | Paper gains / ownership card |
| Issuer outstanding | companyfacts issuer CIKs + bundled cover defaults | `sharesOutstanding_*` | Mcap parity only |
| Price | Yahoo chart | `StockQuote.currentPrice` | Both ownership and parity |

Folding outstanding into `HoldingsSyncResult.sharesBySymbol` would break `applyHoldingsSync`’s all-symbols-complete gate (missing expected symbols → incomplete, no ownership write). Spec forbids that fold and requires Form 4 ⟂ companyfacts completeness. Matches `HoldingsSyncServiceProtocol` and `AppSettings` as written.

**Issuer CIK on `TrackedHoldingSpec` (or adjacent symbol map)** keeps person CIK separate from Tesla (`0001318605`) / SpaceX (`0001181412`) entities. Card presentation hard-keys `"TSLA"` / `"SPCX"`, consistent with multi-person non-goal.

**Outstanding is symbol-global, not person-scoped** — correct for issuer facts; UserDefaults shape in the spec is appropriate.

**Invocation boundary** — dedicated pure companyfacts parser + small fetch on the daily SEC path, without making Form 4 `throws` depend on companyfacts. Plan must still attempt outstanding when Form 4 fails (spec: outstanding success must not require Form 4 success); defaults keep the card usable either way.

## Product-correctness checks

| Claim | Verdict |
|-------|---------|
| Implied TSLA = SPCX Class A price × SPCX A+B / TSLA outstanding | Correct mcap-parity toy; stated in Goals, calculator, acceptance. |
| SPCX outstanding = Class A + Class B (not Class A alone, not WASO, not fully diluted) | Explicit; cover default + accession; reject list for WASO concepts. |
| Card shows with defaults-only outstanding when both quotes exist | Goals, Design §4, error table, acceptance #2 agree. |
| Card hides only when quote leg missing or calculator guards fail | Consistent across sections. |
| Form 4 ownership path independent of companyfacts | Design §2 + error table + acceptance #4. |
| `resetToDefaults()` reseeds outstanding; ownership keys separate | Explicit; extends current reset which only reseeds ownership today. |
| Typo exact string | Acceptance #1 + Testing. |
| Illustrative parity, not deal announcement | Compliance + Risks + copy title. |

## Strengths

1. **Mcap quantity is defined, not implied** — economically equivalent common; dual-class rule written for implementers.
2. **SPCX companyfacts reality handled** — WASO-only → unresolved → keep cover default; do not “succeed” with ~5.86B.
3. **Resolver rules are plan-ready** — concept priority, multi-member same-`end` sum, form preference, `(end, filed)` sort, finite `> 0`, duration-only reject.
4. **Scope discipline** — reverse parity, manual outstanding UI, 10-Q HTML parse, legal merger modeling, Yahoo mcap summary all non-goals; Deferred honestly empty.
5. **Test matrix** maps to resolver, calculator, typo, settings isolation; no mandatory live SEC CI.
6. **Framing completeness** — Risks, Acceptance, Observability, Rollout, Compliance, Dependencies, Alternatives all named and usable for plan-writing.

## Residual notes (non-blocking)

These are plan/implementation reminders, not missing design:

1. **Form 4 throw vs companyfacts ordering** — Implement best-effort outstanding even when Form 4 throws (catch / parallel / always-run), so a bad Form 4 day does not skip issuer refresh.
2. **Dimensional double-count** — “Sum same-`end` members” is right for pure A/B members; fixtures should avoid inventing a total row + class members in the same fact set unless the resolver has a documented de-dupe rule. Current SPCX companyfacts is WASO-only → default path.
3. **Form preference soft vs hard filter** — “Prefer {10-Q, 10-K, …} when form is present” is enough for unit fixtures; plan can treat preferred forms as primary candidates then fall back, or filter strictly — either is testable.
4. **SEC polite spacing** — Reuse User-Agent; modest delay before/after companyfacts GETs next to Form 4’s 120ms accession spacing.
5. **UI refresh after outstanding-only update** — Ownership apply may skip refresh on partial Form 4; outstanding can still change. Next quote cycle (~RTH interval) or lightweight re-derive is enough.

## Architectural risks (accepted for v1)

| Risk | Why acceptable |
|------|----------------|
| Stale outstanding after recap/split until daily sync or default bump | 24h cadence + accession-pinned constants; no Settings editor is a non-goal. |
| SPCX companyfacts never exposes trustworthy multi-class totals | Product remains correct via cover defaults; WASO must not overwrite. |
| “Merger” wording misread as deal news | Title/caption as parity; Compliance + HOLDINGS + existing disclaimer. |
| Multi-MB JSON parse cost | Daily only; walk target concepts; async path like Form 4. |

## Deferral discipline

- **`## Deferred`:** `None.` — Appropriate; reverse parity, HTML cover parse, manual outstanding edit, multi-person UI, Yahoo mcap API are non-goals (also listed under Alternatives).
- **`## Scale & Validation`:** Present; two issuer CIKs, local parse, multi-MB caution, no CI live network test.

## Alignment with current source (spot checks)

- `HoldingsSyncResult` is ownership-only (`sharesBySymbol`) — do not extend for outstanding without a separate type (spec agrees).
- `applyHoldingsSync` all-symbols-complete gate — outstanding must stay outside (spec agrees).
- `TrackedHoldingSpec` today has parse strategy + default **ownership** counts only — adding issuer CIK / outstanding defaults (or adjacent map) is a clean extension; do not overload `defaultShareCount`.
- `GainsViewModel.refresh` requires complete quote set for all holdings — both legs present when a fresh snapshot succeeds; card’s per-symbol quote guard remains correct defensive design.
- `PopoverContentView.dataView` ends with stock rows + optional error caption — natural insertion for `MergerParityCardView`.
- `resetToDefaults()` resets ownership to profile defaults and clears sync metadata — must also reseed outstanding keys (spec requires).
- `NetWorthMilestoneTracker.belowTrillionMessage` and `testSadMessageUsesLonliestNumberCopy` match the misspelling the spec fixes.

## Findings

None.

## Findings (machine-readable)

```json
{
  "schema_version": 1,
  "round": 3,
  "role": "spec-correctness",
  "verdict": "APPROVED",
  "findings": []
}
```

VERDICT: APPROVED
