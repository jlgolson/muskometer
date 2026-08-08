# Spec correctness review — round 1

**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md`  
**Role:** spec-correctness  
**Date:** 2026-08-07

## Summary

The problem framing, separation of issuer outstanding from Musk Form 4 ownership, pure calculator, graceful degrade, and typo fix are sound. The architecture sketch matches how Muskometer already works (Yahoo quotes + SEC cadence + `AppSettings` + popover cards).

What is **not** sound is the SPCX outstanding definition. As written, the card’s primary number — implied TSLA under SPCX market-cap parity — will be systematically wrong if implementers follow the concept priority and the bundled SPCX default. That is a product-correctness defect, not a polish nit.

## What’s strong

1. **Correct problem split.** Merger parity is company-level mcap math, not Musk stake math. Explicit non-goal of using Form 4 ownership as float is right; Form 4 XML truly has no issuer outstanding.
2. **Formula is the right shape** (given correct outstanding):  
   `impliedTSLAPrice = (SPCX.price × SPCX.outstanding) / TSLA.outstanding`.
3. **Issuer CIKs and endpoints.** TSLA `0001318605` / SPCX `0001181412` and `companyfacts` are the right SEC surface. TSLA’s `dei:EntityCommonStockSharesOutstanding` mid-2026 value `3_949_547_394` matches live companyfacts.
4. **Independence of sync paths.** “Form 4 must not fail solely because companyfacts fails; store outstanding even if Form 4 incomplete” is the correct completeness model relative to existing `applyHoldingsSync` all-or-nothing ownership gate.
5. **Resilience table.** Hide card when a quote leg is missing; keep prior/defaults on parse/network failure; do not overwrite good priors with ≤0. Matches app culture.
6. **UI placement.** After stock rows, Musk-first content order, no settings gear, no reverse toggle — good v1 scope.
7. **Testing intent.** Concept-priority fixtures + calculator edges + typo string match; no mandatory live SEC in CI.
8. **Typo fix scope.** Constant + assertion only; no behavior change.

## Critical: SPCX outstanding is the wrong quantity

### What the 10-Q cover says (point-in-time economic shares)

SpaceX Q2 2026 10-Q cover (as of July 28, 2026):

- Class A common: **7,696,293,669**
- Class B common: **5,485,486,276**
- **Total A+B ≈ 13.18B**

Balance-sheet share counts (in millions) for June 30, 2026 are the same order of magnitude (~7.6B Class A + ~5.6B Class B).

Class B is super-voting but **same economic claim per share** as Class A for standard dual-class mcap:  
`mcap ≈ SPCX_ClassA_price × (ClassA + ClassB outstanding)`.

### What the spec specifies

| Spec choice | Value / behavior | Problem |
|-------------|------------------|---------|
| Fallback concept | `us-gaap:WeightedAverageNumberOfSharesOutstandingBasic` | Period **average** for EPS, not period-end / cover-page outstanding used for market cap |
| Bundled SPCX default | `≈ 5_864_000_000` | ~**half** (or less) of true A+B outstanding → understates SPCX mcap ~2× → understates implied TSLA price ~2× |
| Priority order | Prefer `EntityCommonStockSharesOutstanding` then `CommonStockSharesOutstanding` then weighted average | Fine **if** multi-class is summed; disaster if a single-class member or weighted average is taken as “the” share count |

Musk Form 4 Class A-equivalent ownership defaults (~6.07B) already sit in the same ballpark as one class of SpaceX stock, not half of total company shares. Using 5.86B as **issuer** outstanding would also make Musk’s stake look like ~100%+ of the company on a naïve comparison — a smell the outstanding model is wrong.

### What the spec must require instead

For **market-cap parity**, outstanding must be:

1. **Point-in-time** (cover / period-end), not weighted-average basic/diluted.
2. For **multi-class issuers (SPCX):** sum of economically fungible common classes (Class A + Class B for SpaceX), not Class A alone and not EPS weighted average.
3. **Defaults** must match that definition (order of **~13.18B** for SPCX as of late July 2026 cover, not 5.864B). Re-verify the exact integer from the filing the default is pinned to; document the as-of date in the constant comment / HOLDINGS note.
4. **Resolver rules** must state:
   - Prefer `dei:EntityCommonStockSharesOutstanding` **aggregated across class members** when the taxonomy splits classes (sum members; do not pick the first/largest alone without a written rule).
   - Prefer **latest by `end` date, then `filed`**, restricted to shares units and reasonable forms (10-Q / 10-K / 10-K/A cover facts).
   - **Do not** use `WeightedAverageNumberOfSharesOutstandingBasic` (or Diluted) for mcap unless explicitly labeled a last-resort estimate with known bias — and even then the default should not pretend it is cover-page outstanding.
   - If companyfacts lacks a trustworthy point-in-time total for SPCX, **keep the hard-coded cover-derived default** rather than “succeeding” with a wrong weighted-average parse.

Without this, the feature ships a confident wrong number. That fails the goal statement.

## Technical feasibility

| Area | Assessment |
|------|------------|
| TSLA companyfacts | Feasible; single-class `EntityCommonStockSharesOutstanding` works; default matches. |
| SPCX companyfacts | Endpoint exists and returns XBRL facts; concept coverage for **point-in-time multi-class total** is the open risk. Spec assumes weighted-average fallback is “present and usable”; usable for EPS, **not** for this card. |
| Payload size | TSLA companyfacts is multi-MB. Fine on macOS at 24h cadence if parser only walks needed concept paths (do not invent a full taxonomy model). |
| SEC rate limits | +2 GETs next to Form 4 crawl is fine; keep User-Agent and modest delay if sequential. |
| Wiring into existing sync | Feasible if outstanding is **orthogonal** to `HoldingsSyncResult.sharesBySymbol` / `applyHoldingsSync` completeness. Bolting outstanding into the same all-symbols-complete gate would regress ownership sync — spec text forbids that; plan must preserve it in types. |
| UI | `MergerParityCardView` after stock rows is straightforward; `CurrencyFormatter.formatPrice` / `formatMarketValue` already fit. |

## Architectural risks

1. **Two meanings of “shares” in AppSettings.** Ownership (`shareCount_SYMBOL`) vs issuer outstanding must stay separate keys, loaders, and defaults. Spec says independent UserDefaults keys — good. Also specify: `resetToDefaults()` clears or re-seeds outstanding to bundled defaults; do not leave stale SEC values after reset.
2. **Service boundary ambiguity.** “Extend sync result or parallel call from GainsViewModel / sync service” leaves three shapes open. Prefer a **dedicated pure parser + small fetch** invoked from the existing daily SEC path without making Form 4 `throws` depend on companyfacts. Protocol surface for ownership should stay ownership-only unless a new result type is explicit.
3. **Hard-coded TSLA/SPCX card vs profile hooks.** Non-goal of multi-person is fine; still specify symbol keys (`"TSLA"` / `"SPCX"`) for presentation so a future second holding does not silently become a “merger” leg.
4. **Stale outstanding after split / IPO events.** 24h cadence + defaults is OK for v1; if companyfacts lags a recapitalization, wrong defaults hurt more — another reason defaults must be the **correct quantity**, not a convenient wrong concept.

## Missing considerations (actionable)

1. **Dual-class market-cap definition** (above) — must be in Goals / Design §2, not left to implementer judgment.
2. **“Latest usable value” algorithm** — end vs filed, duration vs instant facts, multi-member sum, form filter. Unit tests cannot be written without this.
3. **What price is used for SPCX mcap** — Class A Yahoo last (existing quote) × total A+B outstanding. State it so nobody multiplies Class A price by Class A-only shares.
4. **Footer / docs honesty** — popover footer today says “Holdings: SEC EDGAR”. Outstanding is issuer companyfacts, not Form 4. HOLDINGS.md update is required; consider one footer/source line so users do not think Musk ownership drives the merger card.
5. **Caption honesty (optional metadata)** — spec defers concept/filed date as nice-to-have; for SPCX, a one-line “illustrative; SEC outstanding as of …” may be needed so dual-class + lag are not misread as live float. Can stay v1-light if defaults + formula docs are right.
6. **Test rename** — `testSadMessageUsesLonliestNumberCopy` embeds the misspelling; update with the string so CI does not preserve the bug in the test name only (cosmetic; not blocking).

## Questions the spec should answer (and currently does not)

1. For SPCX, is outstanding **Class A only**, **A+B**, or **fully diluted (options/RSUs)**? (Answer for a merger mcap toy: **A+B common**, not fully diluted, not weighted average.)
2. If companyfacts returns only weighted-average shares for SPCX, do we **accept** that value or **reject** and keep default?
3. If `EntityCommonStockSharesOutstanding` appears as multiple class members, do we **sum** or take **max**?
4. How is “latest” ordered when both a 10-Q end date and a later-filed 10-K/A restatement exist?
5. On `resetToDefaults`, do outstanding counts reset to bundled constants?
6. Is the card shown when outstanding is **default-only** (never successfully synced)? (Implied yes via “card still works if defaults present” — make that explicit.)

## Deferral discipline

### `## Deferred`

Body is `None.` Form is fine. Substance: nothing important is falsely parked there. The dual-class / weighted-average issue is **not** a deferral candidate — it is in-scope for v1 correctness. Acceptable true deferrals (if listed later): reverse-direction parity, manual outstanding settings UI, concept/filed-date caption metadata, multi-person generalization.

### `## Scale & Validation`

“Not applicable” is acceptable for two issuer CIKs and local parse. Optional one-liner that would strengthen it without inventing multi-tenant scope: companyfacts JSON can be multi-MB; parse only target concepts; no CI live network test. Not a blocking finding.

## Recommended spec edits (minimum to APPROVE)

1. Redefine SPCX outstanding as **point-in-time Class A + Class B common** (or equivalent cover total); fix default to cover-derived ~13.18B with citation/as-of.
2. Drop or demote weighted-average concepts out of the mcap priority list (or mark reject-for-mcap).
3. Specify multi-member sum + latest selection rules for the resolver.
4. Explicitly: default-only outstanding still shows the card; reset reseeds defaults; outstanding never gates Form 4 completeness.
5. One HOLDINGS.md sentence on issuer outstanding vs Form 4 ownership and the dual-class mcap convention.

## Findings

- [design.md:§2 Issuer outstanding / defaults]: correctness: SPCX default `5_864_000_000` and `WeightedAverageNumberOfSharesOutstandingBasic` fallback are EPS/period-average figures, not market-cap share count; SpaceX A+B outstanding is ~13.18B — card would understate implied TSLA ~2×.
- [design.md:§2 concept priority]: correctness: resolver does not require summing multi-class `EntityCommonStockSharesOutstanding` members or rejecting weighted-average for mcap; dual-class SPCX will resolve wrong without an explicit rule.
- [design.md:§2 “latest usable”]: ambiguity: no order key (end vs filed), form filter, or duration-vs-instant rule — plan-writers can diverge on which companyfacts row wins.
- [design.md:§2 / AppSettings]: missing: `resetToDefaults` and cold-start behavior for outstanding keys (reseed bundled defaults; card visible on defaults-only) not specified.
- [design.md:Goals / §3 calculator]: missing: state that SPCX mcap uses Class A Yahoo price × total economically equivalent common (A+B), not Class A float alone.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{
  "schema_version": 1,
  "dispatch_id": null,
  "verdict": "needs_fixes",
  "round": 1,
  "findings": [
    {
      "id": "spcx-outstanding-wrong-quantity",
      "severity": "blocking",
      "category": "correctness",
      "refs": ["design.md:§2 Issuer outstanding shares (SEC)", "design.md:Goals"],
      "summary": "SPCX default ~5.864B and WeightedAverageNumberOfSharesOutstandingBasic fallback are not market-cap outstanding; A+B cover total is ~13.18B — implied TSLA would be ~2× low.",
      "fix_hint": "Define outstanding as point-in-time economically equivalent common (SPCX Class A+B); set default from 10-Q cover with as-of; demote/reject weighted-average for mcap."
    },
    {
      "id": "multi-class-resolver-unspecified",
      "severity": "blocking",
      "category": "correctness",
      "refs": ["design.md:§2 concept priority"],
      "summary": "No rule to sum multi-class EntityCommonStockSharesOutstanding members or to refuse weighted-average for dual-class issuers.",
      "fix_hint": "Document sum-of-class-members for multi-class; only accept point-in-time share concepts for mcap; keep prior/default if only EPS averages exist."
    },
    {
      "id": "latest-value-selection-underspecified",
      "severity": "major",
      "category": "ambiguity",
      "refs": ["design.md:§2 Fetch step 2"],
      "summary": "“Latest usable shares unit value” lacks end/filed ordering, form filter, and instant vs duration handling.",
      "fix_hint": "Specify sort by end date then filed date; prefer 10-Q/10-K; require end (instant) facts for mcap."
    },
    {
      "id": "outstanding-lifecycle-defaults-reset",
      "severity": "major",
      "category": "missing",
      "refs": ["design.md:§2 Persist", "design.md:Error handling", "AppSettings.resetToDefaults"],
      "summary": "Unspecified whether defaults-only shows the card and whether reset reseeds outstanding independently of ownership.",
      "fix_hint": "Card shows when defaults present; reset reseeds bundled outstanding; keys independent of shareCount_*."
    },
    {
      "id": "spcx-price-times-which-shares",
      "severity": "major",
      "category": "missing",
      "refs": ["design.md:Goals formula", "design.md:§3 calculator"],
      "summary": "Formula does not state Class A quote × (A+B) outstanding for dual-class mcap.",
      "fix_hint": "One sentence in Goals/§3: SPCX mcap = Yahoo Class A price × total A+B common outstanding."
    }
  ]
}
```

VERDICT: NEEDS_FIXES: SPCX outstanding defined as weighted-average ~5.86B instead of point-in-time Class A+B (~13.18B); dual-class resolver and latest-value rules underspecified for correct mcap parity.
