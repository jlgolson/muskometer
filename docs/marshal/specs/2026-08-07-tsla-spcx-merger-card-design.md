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

  ```
  SPCX.marketCap = SPCX.classAYahooPrice × SPCX.economicallyEquivalentCommonOutstanding
  impliedTSLAPrice = SPCX.marketCap / TSLA.sharesOutstanding
  ```

  For SpaceX (dual-class), **economically equivalent common outstanding** = **Class A + Class B** common shares outstanding (same economic claim per share; Class B is super-voting). Do **not** use Class A alone, fully diluted (options/RSUs), or EPS weighted-average share counts. SPCX mcap multiplies the existing Yahoo **Class A** last price by that A+B total.
- Source **issuer shares outstanding** from **SEC** point-in-time figures (not Yahoo, not Musk Form 4 ownership, not period-average EPS share counts).
- Surface it as a **card on the main menu-bar popover**, visually distinct from Musk ownership / paper-gain rows.
- Fix the loneliest spelling in product copy and tests.
- Keep the feature resilient when SEC outstanding data is missing or incomplete (no crash; hide or degrade gracefully). **Defaults-only outstanding still shows the card** when both quote legs are present.

## Non-goals

- Modeling a legal merger, exchange ratio, dilution, preferred classes, control premium, or fully diluted share counts.
- Reverse direction (SPCX priced at TSLA mcap) in v1.
- Using Musk’s Form 4 stake counts as a proxy for company float.
- Pulling market cap from Yahoo `quoteSummary` (currently 401 without auth cookies).
- Settings UI to edit outstanding shares manually (defaults + SEC sync only for v1).
- Multi-person profile generalization beyond the data hooks needed for Musk’s TSLA/SPCX pair.
- Parsing 10-Q HTML cover pages in v1 (bundled cover-derived defaults cover SPCX until companyfacts exposes point-in-time multi-class totals).

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

**Definition (market-cap quantity):** Point-in-time **economically equivalent common shares outstanding** — the share count you multiply by the primary trading-class price to approximate equity market cap.

| Issuer | Rule |
|--------|------|
| **TSLA** (single class) | Common shares outstanding (cover / `EntityCommonStockSharesOutstanding`). |
| **SPCX** (dual-class) | **Class A + Class B** common outstanding. Class C (if any, zero on recent cover) is not required for v1. Prefer cover-page totals over balance-sheet “in millions” rounding. |

**Reject for mcap (do not accept as a successful resolve):**

- `WeightedAverageNumberOfSharesOutstandingBasic`
- `WeightedAverageNumberOfDilutedSharesOutstanding`
- Any other period-average / EPS denominator concept

If companyfacts only yields those (current SPCX companyfacts as of 2026-08), **keep prior or bundled default** — do not “succeed” with a wrong ~5.86B WASO figure.

**Issuer CIKs** (company entities, not Musk):

| Symbol | Issuer CIK (padded) | Notes |
|--------|---------------------|--------|
| TSLA | `0001318605` | Tesla, Inc. |
| SPCX | `0001181412` | Space Exploration Technologies Corp |

Attach issuer CIK on `TrackedHoldingSpec` (or a small adjacent map keyed by symbol) so sync code is not hard-coded only in one service. Presentation always keys on `"TSLA"` / `"SPCX"` explicitly for this card.

**Bundled defaults** (cold start, offline, failed resolve; card **is** shown with these):

| Symbol | Default | Source |
|--------|---------|--------|
| TSLA | `3_949_547_394` | `dei:EntityCommonStockSharesOutstanding`, end 2026-07-16 (companyfacts / 10-Q) |
| SPCX | `13_181_779_945` | 10-Q cover as of **2026-07-28**: Class A `7_696_293_669` + Class B `5_485_486_276` (accession `0001628280-26-052535`) |

Comment constants with as-of / accession. `AppSettings.resetToDefaults()` **reseeds** outstanding keys to these bundled defaults (independent of Musk `shareCount_*` ownership keys).

**Fetch:** On the existing SEC holdings sync path (same ~24h cadence, same SEC User-Agent), after or alongside Form 4 ownership — **orthogonal** types: do not fold outstanding into `HoldingsSyncResult.sharesBySymbol` or `applyHoldingsSync`’s all-symbols-complete ownership gate. Prefer a dedicated pure companyfacts parser + small fetch invoked from the daily SEC path so Form 4 `throws` never depends on companyfacts.

1. For each expected symbol with an issuer CIK, `GET https://data.sec.gov/api/xbrl/companyfacts/CIK{padded}.json` (parse only target concept paths; payloads can be multi-MB).
2. **Resolve** point-in-time outstanding:

   **Concept priority** (first that yields a usable value under the selection rules below):
   1. `dei:EntityCommonStockSharesOutstanding`
   2. `us-gaap:CommonStockSharesOutstanding`

   **Multi-class / multi-member:** If a concept has multiple members (e.g. per share class), **sum** members that share the same `end` date for the chosen “latest” instant. Do not take max/first alone. If the taxonomy does not expose a trustworthy multi-class total for SPCX, leave unresolved and keep default.

   **Latest usable row selection** (only `shares` unit; only point-in-time facts with an `end` date — reject duration-only rows that lack an instant `end` usable as outstanding):
   1. Prefer forms in `{10-Q, 10-K, 10-K/A, 10-Q/A}` when `form` is present.
   2. Sort candidates by `(end desc, filed desc)`; take the first after form preference.
   3. Value must be finite and `> 0`.

3. Persist resolved counts under **independent** UserDefaults keys (e.g. `sharesOutstanding_TSLA`), never ownership keys.
4. On successful resolve for a symbol, overwrite that symbol’s outstanding; on failure, keep prior/default.

**Sync completeness:** Outstanding is **best-effort relative to Form 4**. Form 4 ownership sync must not fail solely because companyfacts is missing. Outstanding success for a symbol must not require Form 4 success for that symbol. Outstanding **never** participates in the ownership completeness gate.

Optional metadata (nice-to-have, not required for v1 UI): concept name + filed/end date for caption honesty.

### 3. Pure market-cap parity calculator

New pure type (e.g. `MergerMarketCapParity` or free functions in a small util), unit-tested:

```
// SPCX: Class A Yahoo price × (Class A + Class B) outstanding
spcxMarketCap = spcxClassAPrice × Double(spcxOutstandingAPlusB)
tslaMarketCap = tslaPrice × Double(tslaOutstanding)
impliedTSLAPrice = spcxMarketCap / Double(tslaOutstanding)
```

Guards: return `nil` if any input is non-finite, `≤ 0`, or outstanding `≤ 0`.

### 4. Snapshot / view-model wiring

- Read outstanding counts from settings (defaults if never synced).
- Inputs: live `"TSLA"` / `"SPCX"` prices from current `GainsSnapshot` + outstanding for those symbols.
- Presentation model, e.g. `mergerParityCard: MergerParityPresentation?`:
  - `impliedTSLAPrice`
  - `tslaMarketCap`, `spcxMarketCap` (caption)
  - `currentTSLAPrice` for contrast

Card **hidden** only when presentation is `nil` because a **quote** leg is missing or calculator guards fail. Card **shown** when outstanding is defaults-only (never successfully companyfacts-synced).

### 5. UI — main popover card

New SwiftUI view (e.g. `MergerParityCardView`) placed on the main panel **after stock rows** (keeps Musk-centric content first; merger is “also interesting”).

Content (copy can be refined in implementation if tighter):

- **Title:** “If TSLA matched SPCX’s market cap”
- **Primary:** implied TSLA price (currency format, monospaced digits, same animation patterns as other cards where cheap)
- **Secondary:** short caption with SPCX and TSLA market caps (compact `CurrencyFormatter.formatMarketValue`) and/or current TSLA price for contrast
- Visual language: same card background / corner radius family as `StockRowView` / ownership card so it feels native

No navigation, no settings gear, no reverse-direction toggle in v1.

### 6. Docs

- Update `docs/HOLDINGS.md` with a short section covering:
  - Issuer outstanding (companyfacts / cover defaults) vs Form 4 **ownership**
  - Dual-class SPCX convention: mcap ≈ Class A price × (A+B)
  - Formula for implied TSLA under SPCX mcap parity
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
| Companyfacts 404 / network error | Keep prior outstanding; Form 4 path unaffected |
| Only weighted-average / non-mcap concepts present | Treat as unresolved; keep prior / bundled default (do not store WASO) |
| Multi-class facts incomplete / unsummable | Unresolved; keep prior / default |
| Concept list all missing | Keep prior / defaults; **card still shows** with defaults |
| One of TSLA/SPCX quotes missing from snapshot | Hide card |
| Outstanding zero/negative after parse | Ignore; do not overwrite good prior |
| `resetToDefaults()` | Reseed outstanding to bundled constants; clear any stale SEC value |

## Testing

- **Unit:** companyfacts resolver — TSLA-style single `EntityCommonStockSharesOutstanding` row accepted.
- **Unit:** multi-member same-`end` sum for dual-class-style fixtures.
- **Unit:** WASO-only fixture → unresolved (nil), does not beat default.
- **Unit:** latest selection by `(end, filed)` and form preference.
- **Unit:** calculator edges (zero outstanding, non-finite price); A+B mcap math smoke.
- **Unit:** typo string exact match `Loneliest` (update any test whose **name** embeds `Lonliest`).
- **Unit:** AppSettings outstanding keys independent of ownership; reset reseeds defaults.
- No mandatory live SEC integration test in CI.

## Implementation sketch (files)

| Area | Likely touch |
|------|----------------|
| Typo | `NetWorthMilestoneTracker.swift`, tests |
| Model | `TrackedHoldingSpec` + issuer CIK; outstanding defaults (~13.18B SPCX) |
| SEC | dedicated companyfacts fetch/parser; invoke from daily SEC path without coupling Form 4 result type |
| Settings | `sharesOutstanding(for:)` / `setSharesOutstanding`; reset reseeds |
| Calc | new pure util + tests |
| UI | `MergerParityCardView`, `PopoverContentView` |
| Docs | `HOLDINGS.md` |

## Acceptance criteria

Ship when all of the following hold:

1. Typo string is exactly `One Trillion Is the Loneliest Number` (product + tests).
2. Main popover shows merger parity card after stock rows when TSLA and SPCX quotes are present and outstanding counts are positive (including **defaults-only** outstanding).
3. Implied price uses `SPCX Class A price × SPCX A+B outstanding / TSLA outstanding` (or equivalent pure calculator); WASO-only companyfacts must not overwrite the SPCX default.
4. Form 4 ownership sync still completes and applies without depending on companyfacts success.
5. `resetToDefaults()` reseeds outstanding to bundled constants; ownership keys remain separate.
6. Unit tests cover resolver (accept TSLA-style, reject WASO-only, multi-member sum), calculator guards, typo, and outstanding key independence.
7. `docs/HOLDINGS.md` documents issuer outstanding vs Form 4 ownership and the dual-class mcap convention.

## Risks

| Risk | Mitigation / residual |
|------|------------------------|
| Wrong outstanding (esp. SPCX dual-class / WASO) produces a confident wrong implied price | Spec hard-requires A+B point-in-time; reject WASO; pin cover-derived default with accession; unit tests |
| Companyfacts lag after split/IPO/recap | 24h sync + correct defaults; residual: defaults can go stale until next release updates constants |
| Users treat “merger” parity as a deal announcement or valuation advice | Title/caption as illustrative parity; existing app disclaimer; HOLDINGS note; non-goal of legal merger modeling |
| Outstanding keys collide with ownership keys | Separate UserDefaults keys; independent loaders; reset reseeds both intentionally |
| Companyfacts multi-MB parse cost / flaky SEC | Daily cadence only; walk target concepts; Form 4 path independent |
| Typo fix regresses via test name or alternate copy paths | Exact string assertion; rename tests that embed misspelling |

## Compliance & messaging

- Card is **illustrative market-cap parity only** — not a merger announcement, fairness opinion, or investment advice.
- Prefer copy like “If TSLA matched SPCX’s market cap” over language that implies a pending corporate transaction.
- No new legal surface beyond existing app disclaimer posture; do not weaken `docs/DISCLAIMER.md` language.

## Observability

- Outstanding path is best-effort: failures keep prior/default (no user-facing error toast required for companyfacts-only failure).
- Optional v1-light: retain last successful outstanding sync timestamp in UserDefaults (not required to surface in UI).
- Implementer may log parse miss / concept unresolved at debug level; no analytics SDK.
- Defaults-only vs SEC-updated outstanding need not be distinguished in the popover caption for v1 (HOLDINGS documents the model).

## Rollout

- **Always on** when quote legs + positive outstanding exist — no settings toggle / kill switch in v1 (hide only via missing quotes or bad inputs).
- Changelog / release notes: mention the card + typo fix when shipping a release that includes this branch.
- No phased rollout or remote config.

## Dependencies / external contracts

| Contract | Assumption |
|----------|------------|
| Yahoo chart quote for `TSLA`, `SPCX` | Existing price path; Class A last for SPCX |
| SEC companyfacts | `https://data.sec.gov/api/xbrl/companyfacts/CIK{padded}.json` + User-Agent policy already used for EDGAR |
| Issuer CIKs | TSLA `0001318605`, SPCX `0001181412` on holding specs / map |
| Point-in-time concepts | `dei:EntityCommonStockSharesOutstanding`, `us-gaap:CommonStockSharesOutstanding` only for mcap resolve |
| Bundled defaults | Updated in-repo when cover/companyfacts drift materially |

## Alternatives considered

1. **Yahoo marketCap / quoteSummary** — rejected (401 without cookies; SPCX coverage unclear).
2. **Musk Form 4 stake parity** — rejected (different question; not company mcap).
3. **WASO as SPCX outstanding** — rejected (~2× undercount vs A+B cover).
4. **Parse 10-Q HTML cover every sync** — deferred cost higher than pinned default + companyfacts when available; not in v1.
5. **Separate “Merger” popover panel** — rejected for v1; card on main panel is enough.

## Deferred

None.

## Scale & Validation

Not applicable: UI + local SEC parse with two issuer CIKs; no multi-tenant dimension. Companyfacts JSON can be multi-MB — parse only target concept paths; no CI live network test.
