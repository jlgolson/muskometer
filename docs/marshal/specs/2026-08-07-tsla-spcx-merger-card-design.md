---
slug: 2026-08-07-tsla-spcx-merger-card-design
title: TSLA↔SPCX merger market-cap card + trillion easter-egg typo
date: 2026-08-07
branch: jordan/tsla-spcx-merger-card
status: design
---

# TSLA↔SPCX merger market-cap card + trillion easter-egg typo

**Date:** 2026-08-07  
**Branch:** `jordan/tsla-spcx-merger-card`  
**Status:** design (brainstormed)

## Problem

1. **Merger scenario.** Readers want a quick answer to: *if Tesla had the same market cap as SpaceX, what would TSLA be worth per share?* That is independent of Musk’s personal holdings and is not shown today.
2. **Typo.** When net worth falls below $1T, the easter-egg copy is `"One Trillion Is the Lonliest Number"` — missing the second **e** in *Loneliest*.

## Goals

- Show a live **implied TSLA price** under company market-cap parity:  
  `impliedTSLAPrice = (SPCX.price × SPCX.sharesOutstanding) / TSLA.sharesOutstanding`
- Source **issuer shares outstanding** from **SEC** (not Yahoo, not Musk Form 4 ownership).
- Surface it as a **card on the main menu-bar popover**, visually distinct from Musk ownership / paper-gain rows.
- Fix the loneliest spelling in product copy and tests.
- Keep the feature resilient when SEC outstanding data is missing or incomplete (no crash; hide or degrade gracefully).

## Non-goals

- Modeling a legal merger, exchange ratio, dilution, preferred classes, or control premium.
- Reverse direction (SPCX priced at TSLA mcap) in v1.
- Using Musk’s Form 4 stake counts as a proxy for company float.
- Pulling market cap from Yahoo `quoteSummary` (currently 401 without auth cookies).
- Settings UI to edit outstanding shares manually (defaults + SEC sync only for v1).
- Multi-person profile generalization beyond the data hooks needed for Musk’s TSLA/SPCX pair.

## Current architecture (relevant)

- **Quotes:** `YahooFinanceStockPriceService` → `StockQuote` (price only; no mcap/outstanding).
- **Musk holdings:** `SECHoldingsSyncService` walks **person** Form 4s (CIK `0001494730`) → ownership counts in `AppSettings`.
- **Snapshot:** `GainsSnapshot` / `HoldingGain` combine ownership × price for paper gains and Musk stake value.
- **UI:** `PopoverContentView` main panel (ownership, combined, comparison, daily records, stock rows).
- **Easter egg:** `NetWorthMilestoneTracker.belowTrillionMessage` → `GainsViewModel.trillionEasterEggMessage` → ownership card caption.

Form 4 XML does **not** include issuer shares outstanding. Outstanding must come from **issuer** SEC XBRL (companyfacts / 10-Q concepts).

## Design

### 1. Typo fix

| Location | Change |
|----------|--------|
| `NetWorthMilestoneTracker.belowTrillionMessage` | `"Lonliest"` → `"Loneliest"` |
| Matching unit test assertion | same string |

No behavior change beyond spelling.

### 2. Issuer outstanding shares (SEC)

**Issuer CIKs** (company entities, not Musk):

| Symbol | Issuer CIK (padded) | Notes |
|--------|---------------------|--------|
| TSLA | `0001318605` | Tesla, Inc. |
| SPCX | `0001181412` | Space Exploration Technologies Corp |

Attach issuer CIK on `TrackedHoldingSpec` (or a small adjacent map keyed by symbol) so sync code is not hard-coded only in one service.

**Fetch:** On the existing SEC holdings sync path (same ~24h cadence, same SEC User-Agent), after or alongside Form 4 ownership:

1. For each expected symbol with an issuer CIK, `GET https://data.sec.gov/api/xbrl/companyfacts/CIK{padded}.json`
2. Resolve shares outstanding with **priority** (first concept that has a usable latest `shares` unit value):
   1. `dei:EntityCommonStockSharesOutstanding` (preferred; present for TSLA)
   2. `us-gaap:CommonStockSharesOutstanding`
   3. `us-gaap:WeightedAverageNumberOfSharesOutstandingBasic` (fallback; present for SPCX as of 2026-08 10-Q)
3. Persist resolved counts per symbol (UserDefaults), independent of Musk ownership keys.
4. Bundled **defaults** for cold start / offline (last-known-good style constants, updated when SEC succeeds):
   - TSLA ≈ `3_949_547_394` (EntityCommonStockSharesOutstanding, mid-2026)
   - SPCX ≈ `5_864_000_000` (WeightedAverageNumberOfSharesOutstandingBasic, Q2 2026 10-Q)

**Sync completeness:** Outstanding is **best-effort relative to Form 4**. A full Form 4 ownership sync must not fail solely because companyfacts is missing for one issuer. Conversely, if companyfacts succeeds for a symbol, store it even when Form 4 for that symbol is still pending.

Optional metadata to store (nice-to-have, not required for v1 UI): concept name + filed date for caption honesty (“SEC 10-Q …”).

### 3. Pure market-cap parity calculator

New pure type (e.g. `MergerMarketCapParity` or free functions in a small util), unit-tested:

```
marketCap(price, outstanding) = price × Double(outstanding)
impliedTSLAPrice(spcxPrice, spcxOutstanding, tslaOutstanding) =
    marketCap(spcxPrice, spcxOutstanding) / Double(tslaOutstanding)
```

Guards: return `nil` if any input is non-finite, ≤ 0, or outstanding ≤ 0.

### 4. Snapshot / view-model wiring

- Read outstanding counts from settings (or dedicated store) when building the popover model.
- Inputs for the card: live TSLA/SPCX prices from the current `GainsSnapshot` (same quotes as stock rows) + outstanding counts.
- Expose a small view model property or computed presentation model, e.g. `mergerParityCard: MergerParityPresentation?` with:
  - `impliedTSLAPrice`
  - `tslaMarketCap`, `spcxMarketCap` (for caption)
  - optional `currentTSLAPrice` for comparison

Card hidden when presentation is `nil` (missing quote leg or outstanding).

### 5. UI — main popover card

New SwiftUI view (e.g. `MergerParityCardView`) placed on the main panel **after stock rows** (keeps Musk-centric content first; merger is “also interesting”).

Content (copy can be refined in implementation if tighter):

- **Title:** “If TSLA matched SPCX’s market cap”
- **Primary:** implied TSLA price (currency format, monospaced digits, same animation patterns as other cards where cheap)
- **Secondary:** short caption with SPCX and TSLA market caps (compact `CurrencyFormatter.formatMarketValue`) and/or current TSLA price for contrast
- Visual language: same card background / corner radius family as `StockRowView` / ownership card so it feels native

No navigation, no settings gear, no reverse-direction toggle in v1.

### 6. Docs

- Short note in `docs/HOLDINGS.md` (or a one-paragraph addition) explaining issuer outstanding vs Form 4 ownership and the formula.
- No marketing site change required for v1.

## Data flow

```
SEC companyfacts (issuer CIKs) ──► sharesOutstandingBySymbol (UserDefaults)
Yahoo chart prices ──────────────► GainsSnapshot quotes
                                         │
                                         ▼
                              Merger parity calculator
                                         │
                                         ▼
                              MergerParityCardView (popover)
```

## Error handling

| Condition | Behavior |
|-----------|----------|
| Companyfacts 404 / network error | Keep prior outstanding; log/ignore; Form 4 path unaffected |
| Concept list all missing | Keep prior / defaults; card still works if defaults present |
| One of TSLA/SPCX quotes missing from snapshot | Hide card |
| Outstanding zero/negative after parse | Ignore that value; do not overwrite good prior |

## Testing

- **Unit:** priority resolver for companyfacts JSON fixtures (TSLA-style dei concept; SPCX-style weighted-average only).
- **Unit:** calculator edge cases (zero outstanding, missing price).
- **Unit:** typo string exact match `Loneliest`.
- **Unit (optional):** AppSettings round-trip for outstanding keys.
- No mandatory live SEC integration test in CI (network flaky); local verify may remain quote-focused.

## Implementation sketch (files)

| Area | Likely touch |
|------|----------------|
| Typo | `NetWorthMilestoneTracker.swift`, tests |
| Model | `TrackedHoldingSpec` + issuer CIK; outstanding defaults |
| SEC | companyfacts client/parser; extend sync result or parallel call from `GainsViewModel` / sync service |
| Settings | `sharesOutstanding(for:)` / `setSharesOutstanding` |
| Calc | new pure util + tests |
| UI | `MergerParityCardView`, `PopoverContentView` |
| Docs | `HOLDINGS.md` |

## Deferred

None.

## Scale & Validation

Not applicable: UI + local SEC parse with two issuer CIKs; no data-volume or multi-tenant dimension.
