# Holdings and quotes

Muskometer tracks Musk's paper gains on **TSLA** and **SPCX** using SEC-reported share counts and live Yahoo Finance quotes.

## Share counts

Share counts come from Elon Musk's **SEC Form 4** filings. The app checks EDGAR once per day and reconstructs each ticker from verified baseline buckets plus later dated Form 4/4A observations, scanning back through both anchors. Defaults below are **sellable ownership** (what he owns and could theoretically sell), not the full 13d-3 voting package.

| Ticker | Default (until SEC sync) | How it's derived |
|--------|--------------------------|------------------|
| **TSLA** | 710,172,677 | Last direct (`D`) common-stock post-transaction amount from Form 4 `0001104659-26-075213` (period 2026-06-16) |
| **SPCX** | 5,116,475,230 | Form 4 `0001628280-26-044069`: last-row-wins Class A+B tables **4,766,475,230** + vested option underlying **350,000,000** |

**SPCX aggregation (sellable ownership)** — SpaceX filings split holdings across Class A, Class B, preferred series, trusts, and derivative tables. Muskometer:

- Keeps Class A and Class B common 1:1 in separate buckets identified by normalized security class, direct/indirect ownership, and ownership nature. Option buckets also include exact strike and expiration identity.
- Applies absolute post-transaction balances by effective date. Document order resolves same-day transactions within one ordinary filing; later filings do not erase unchanged buckets. Trusted anchor holding rows without transaction dates use the anchor filing date, not its earlier report period.
- Converts leftover preferred series to Class A-equivalent (series A/B preferred × 50 per filing footnotes; IPO conversion already zeroed preferred on the June 17 filing).
- **Adds** vested option underlying shares when `securityTitle` contains `"option"` (the live row is **350,000,000** Class B, Form 4 F8 / Form 3 F4: fully vested and exercisable, strike $8.3998, expire 2031-02-11).
- **Does not** add unvested performance-based restricted Class B named only in remarks (SpaceX CEO Award **1,000,000,000** + AI CEO Award **302,072,285** ≈ **1.302B** total). Those can be voted but are not sellable until milestones and continued employment.

The 350M options are marked at the Class A last price (Class B converts 1:1). Unpaid strike (~$8.3998 × 350M ≈ **$2.94B**) is **ignored** — paper gain is `shares × Δprice` with the same path as common stock; strike is a constant and does not change the daily swing.

**Dated reconstruction** — A Class A sale changes that bucket while preserving Class B, other trusts, and vested options. Each run starts from the immutable anchors, so replay is idempotent. Historical amendments cannot replace newer balances; an amendment must uniquely identify its original bucket/date before a correction applies. Explicit zero is a valid disposal. Unknown identities, conflicting same-day filings, missing dates, malformed/nonintegral/overflowing quantities, and incomplete relevant documents remain unresolved instead of becoming zero or silently restoring baseline counts. The SPCX anchor was filed June 17 despite its February report date.

**Partial sync and bounds** — Finding a ticker is insufficient: the scan must reach and validate both anchors, within 100 Form 4/4A accessions, 10 unique archive pages, and 10,000 relevant observations. Missing coverage or ambiguous ownership omits the affected ticker. If the result lacks either ticker, AppSettings keeps both prior counts and records the attempt so auto-retry waits about 24 hours. Network failures use the same backoff. **Sync from SEC now** forces a retry. Requests are paced and cancellable; the full request budget is 211, including submission metadata and filing indexes/XML.

**Overrides** — TSLA and SPCX share counts can be edited manually in Settings; overrides persist until the next successful SEC sync updates them.

## Live prices

TSLA and SPCX quotes come from Yahoo Finance (`query1.finance.yahoo.com`) using the same API and price logic for both tickers. Quotes auto-refresh only during the **regular US session** (9:30 AM–4:00 PM ET, or early close). The Settings interval (60–120s, default **90s**) applies throughout RTH. Pre-market and post-market are treated as closed. At the end of an observed regular session, the app attempts one closing fetch and allows one bounded recovery attempt on failure. Overnight and on weekends it sleeps until the next regular open and refreshes promptly; manual refresh still works. A failed close finalizes the day from the last real regular-session observation, keeps its timestamp and stale status, and labels it as last observed rather than a newly received closing price. SEC synchronization runs independently of quote polling.

## Paper gain math

```
paperGain = shareCount × (currentPrice − previousClose)
```

Combined paper gain is the sum across TSLA and SPCX. Combined **percent** change is portfolio-weighted on prior close value — not a simple average of the two tickers.

Figures are **illustrative** — not financial advice.

## Issuer outstanding vs Form 4 ownership

Muskometer tracks **two different share numbers** for each ticker:

| Concept | What it measures | Source | Used for |
|---------|------------------|--------|----------|
| **Form 4 ownership** | Musk’s beneficial / Class A-equivalent holdings | SEC Form 4 XML (daily EDGAR walk) | Paper gain, portfolio worth, stock rows |
| **Issuer outstanding** | Company-wide shares outstanding (mcap base) | SEC companyfacts (`data.sec.gov` XBRL) with cover-derived bundled defaults | Merger market-cap parity card only |

These paths are independent: Form 4 ownership never writes issuer outstanding, and companyfacts never overwrites Form 4 share counts. Outstanding sync is best-effort on the same ~24h SEC cadence; a companyfacts miss leaves prior or default outstanding in place and does not fail Form 4.

| Ticker | Default outstanding | Derivation |
|--------|---------------------|------------|
| **TSLA** | 3,949,547,394 | `dei:EntityCommonStockSharesOutstanding`, end 2026-07-16 (10-Q / companyfacts) |
| **SPCX** | 13,571,069,199 | July 28 10-Q cover Class A 7,696,293,669 + Class B 5,485,486,276 (accession `0001628280-26-052535`) **plus** Cursor merger Class A issued 389,289,254 (8-K `0001628280-26-056945`, item (i); filed 2026-08-14). New Class A = 8,085,582,923; A+B = **13,571,069,199**. Item (ii)/(iii) RSU/option lines are not included. |

The September 10, 2026 public-data check found no usable point-in-time SPCX companyfacts outstanding total for CIK `0001181412`; weighted-average shares are rejected, so prior or cover+Cursor defaults remain. Endpoint contents can change.

Repeated whole-entity companyfacts totals are deduplicated by the selected period/filing group, retaining accession and form metadata. Equal original/amendment values count once; conflicting values remain unresolved, and an ambiguous DEI result cannot fall back to an older GAAP total.

Settings → Reset to defaults reseeds both ownership and outstanding to bundled values. Weighted-average / EPS share counts (WASO) are **rejected** for mcap — if companyfacts only exposes those, the app keeps the prior or cover default.

### Dual-class SPCX market cap

SpaceX has dual-class common stock. For market-cap parity the app uses:

```
SPCX market cap ≈ Class A Yahoo price × (Class A + Class B outstanding)
```

Class B is super-voting but economically equivalent per share for this toy. The Yahoo **Class A** last price is multiplied by the **A+B** outstanding total (not Class A alone, not fully diluted options/RSUs).

### Implied TSLA at SPCX market-cap parity

The main popover card **“If Tesla had SpaceX’s market cap”** answers: what would one TSLA share be worth if Tesla’s company market cap equaled SpaceX’s?

```
SPCX mcap     = SPCX Class A price × SPCX (A+B) outstanding
TSLA mcap     = TSLA price × TSLA outstanding
implied TSLA  = SPCX mcap / TSLA outstanding
```

The card is **illustrative market-cap parity only** — not a merger announcement, fairness opinion, deal model, or investment advice. It is hidden only when a required quote leg is missing or inputs fail basic guards; defaults-only outstanding still shows the card.

See [DISCLAIMER.md](DISCLAIMER.md).