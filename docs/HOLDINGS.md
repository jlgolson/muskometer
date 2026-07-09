# Holdings and quotes

Muskometer tracks Musk's paper gains on **TSLA** and **SPCX** using SEC-reported share counts and live Yahoo Finance quotes.

## Share counts

Share counts come from Elon Musk's **SEC Form 4** filings. The app checks EDGAR once per day and walks recent Form 4 accessions until it finds counts for both tickers.

| Ticker | Default (until SEC sync) | How it's derived |
|--------|--------------------------|------------------|
| **TSLA** | 699,580,882 | Direct beneficial-ownership row from Form 4 XML |
| **SPCX** | 6,068,734,060 | Aggregated Class A-equivalent ownership from Form 4 XML |

**SPCX aggregation** — SpaceX filings split holdings across Class A, Class B, preferred series, and trusts. Muskometer sums the latest per-trust rows, converts preferred series to Class A-equivalent (series A/B preferred × 50 per filing footnotes), and adds restricted Class B cited in filing remarks.

**Partial sync** — If only one ticker is found in the filings checked, the app keeps prior counts and records the attempt so auto-retry waits ~24h (not every quote refresh). Network failures use the same backoff. You can also tap **Sync holdings from SEC** in Settings to force a retry immediately.

**Overrides** — TSLA and SPCX share counts can be edited manually in Settings; overrides persist until the next successful SEC sync updates them.

## Live prices

TSLA and SPCX quotes come from Yahoo Finance (`query1.finance.yahoo.com`) using the same API and price logic for both tickers. Quotes auto-refresh only during the **regular US session** (9:30 AM–4:00 PM ET, or early close). The Settings interval (60–120s, default **90s**) applies throughout RTH. Pre-market and post-market are treated as closed. Overnight and on weekends the app sleeps until the next regular open (minimum 60s) and refreshes immediately when the session starts; the label shows the last regular close until then (manual refresh still works).

## Paper gain math

```
paperGain = shareCount × (currentPrice − previousClose)
```

Combined paper gain is the sum across TSLA and SPCX. Combined **percent** change is portfolio-weighted on prior close value — not a simple average of the two tickers.

Figures are **illustrative** — not financial advice.

See [DISCLAIMER.md](DISCLAIMER.md).