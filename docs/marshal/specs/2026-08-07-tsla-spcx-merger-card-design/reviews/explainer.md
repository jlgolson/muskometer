# Spec explainer: TSLA↔SPCX merger market-cap card + trillion easter-egg typo

## 1. What is this document?

This is a **design-stage product/engineering spec** for the **Muskometer** macOS menu-bar app (branch `jordan/tsla-spcx-merger-card`). Status is “design (brainstormed)” — decisions and acceptance criteria are written down, but implementation is not claimed done.

Scope is deliberately narrow: (1) a new **illustrative market-cap parity card** on the main popover that answers “if Tesla had SpaceX’s market cap, what would TSLA be per share?”, and (2) a one-line **spelling fix** on the below-$1T net-worth easter-egg string. It touches data sourcing (issuer shares outstanding from SEC), pure calculation, settings storage, popover UI, unit tests, and a short `HOLDINGS.md` update. It does not redesign holdings, quotes, multi-person profiles, or the marketing site.

## 2. What problem is the spec trying to solve?

Two separate issues:

**Merger / parity scenario.** Users care about company-level size comparison: if TSLA’s market cap equaled SPCX’s, what is the implied TSLA share price? Today the app only shows Musk’s **personal** ownership × price (Form 4 stakes and paper gains). That is a different question; company outstanding and market cap are not surfaced.

**Typo.** When Musk’s tracked net worth falls below $1T, the easter-egg reads `"One Trillion Is the Lonliest Number"` — missing the second “e” in *Loneliest*. Product copy and a matching unit test assert the misspelling.

**Goal state:** the main popover shows a live implied TSLA price under SPCX market-cap parity whenever both quote legs are available (including when outstanding is still only bundled defaults), and the easter-egg string is spelled correctly in product and tests.

## 3. What are the main architectural choices?

1. **Implied price formula:** `SPCX Class A Yahoo price × (SPCX Class A + Class B outstanding) / TSLA outstanding`. Dual-class SPCX uses A+B economically equivalent common, not Class A alone or fully diluted.

2. **Outstanding from issuer SEC, not ownership or Yahoo.** Point-in-time companyfacts (or cover-derived bundled defaults). Form 4 is person ownership only and has no issuer outstanding. Yahoo `quoteSummary` market cap is rejected (401 without cookies).

3. **Reject WASO / EPS share concepts.** Weighted-average basic/diluted must never “succeed” as outstanding (would undercount SPCX badly). Unresolved → keep prior/default.

4. **Orthogonal sync paths.** Companyfacts outstanding is best-effort beside the daily Form 4 path (~24h, same User-Agent). Do not fold into `HoldingsSyncResult.sharesBySymbol` or `applyHoldingsSync`’s all-symbols-complete gate. Form 4 must not fail because companyfacts fails, and vice versa.

5. **Separate persistence.** UserDefaults keys like `sharesOutstanding_TSLA` vs ownership `shareCount_*`. `resetToDefaults()` reseeds outstanding to bundled constants independently of ownership.

6. **Card visibility rule.** Hide only when a quote leg is missing or calculator guards fail. **Defaults-only outstanding still shows the card** if both prices exist and counts are positive.

7. **Hard-keyed presentation.** Card always keys `"TSLA"` / `"SPCX"`; multi-person generalization is out of scope beyond optional issuer CIK on `TrackedHoldingSpec` (or a symbol map).

8. **Placement.** New `MergerParityCardView` after stock rows on the main popover — Musk-centric content first; no separate panel, settings gear, or reverse-direction toggle in v1.

9. **Messaging.** Copy frames illustrative parity (“If TSLA matched SPCX’s market cap”), not a deal or valuation advice; existing disclaimer posture stays.

10. **Always on.** No settings toggle or kill switch; hide only via missing quotes / bad inputs.

## 4. What will have to actually get built / changed?

| Area | Shape |
|------|--------|
| Typo | `NetWorthMilestoneTracker.belowTrillionMessage` + tests (including rename of any test name embedding `Lonliest`) |
| Model | Issuer CIKs on holdings specs/map; bundled outstanding defaults (TSLA ~3.95B, SPCX A+B ~13.18B with as-of/accession comments) |
| SEC | Dedicated companyfacts fetch/parser for two issuer CIKs; invoke from daily SEC path without coupling Form 4 result types |
| Settings | `sharesOutstanding(for:)` / `setSharesOutstanding`; reset reseeds outstanding keys |
| Calc | Pure util (e.g. `MergerMarketCapParity`) + unit tests for math and guards |
| VM / snapshot | Presentation model (`mergerParityCard` with implied price, both mcaps, current TSLA) from live quotes + outstanding |
| UI | `MergerParityCardView` in `PopoverContentView` after stock rows |
| Docs | Section in `docs/HOLDINGS.md` (issuer outstanding vs Form 4; dual-class mcap; formula) |
| Tests | Resolver (TSLA-style accept, multi-member sum, WASO reject, form/date selection), calculator edges, key independence, typo string |

## 5. What does the spec explicitly defer, exclude, or acknowledge as gaps?

**Deferred section:** None.

**Non-goals / exclusions (v1):**

- Legal merger modeling, exchange ratios, dilution, preferred classes, control premium, fully diluted share counts  
- Reverse card (SPCX priced at TSLA mcap)  
- Using Musk Form 4 stakes as company float / mcap proxy  
- Yahoo `quoteSummary` market cap  
- Settings UI to edit outstanding manually (defaults + SEC only)  
- Multi-person profile generalization beyond data hooks for Musk’s TSLA/SPCX pair  
- Parsing 10-Q HTML cover pages every sync (bundled cover defaults cover SPCX until companyfacts exposes multi-class totals)  
- Marketing site changes  
- Distinguishing defaults-only vs SEC-updated outstanding in the popover caption  
- User-facing error toast for companyfacts-only failure; analytics SDK  

**Risk-acceptances / residual gaps called out:**

- Wrong outstanding still yields a confident implied price → mitigated by A+B rule, WASO rejection, pinned defaults, tests; residual remains  
- Companyfacts lag after split/IPO/recap → 24h sync + defaults; **defaults can go stale until a release updates constants**  
- Users may read “merger” as a real deal → title/caption framing + existing disclaimer  
- Multi-MB companyfacts parse cost / flaky SEC → daily cadence, parse only target concepts, Form 4 independent  

## Summary

This design spec adds a main-popover **market-cap parity card** to Muskometer so users see an implied TSLA price if Tesla’s equity value matched SpaceX’s: SpaceX Class A Yahoo price times Class A+B outstanding, divided by Tesla shares outstanding. Outstanding is a new **issuer** data path (SEC companyfacts + cover-derived bundled defaults), stored separately from Musk Form 4 ownership and kept off the ownership sync completeness gate so Form 4 and companyfacts fail independently. The card stays visible on defaults-only outstanding as long as both quotes exist. The same change set fixes the below-trillion easter-egg to *Loneliest*.

The load-bearing decision is **how SPCX market cap is defined**: Class A last price × **A+B** point-in-time common, never WASO, never Form 4 stake counts, never Yahoo mcap APIs. The main constraint is residual accuracy: if companyfacts cannot resolve dual-class totals, the app relies on pinned defaults that can drift until constants are updated, and the UI does not tell the user whether the number is SEC-fresh or defaulted.
