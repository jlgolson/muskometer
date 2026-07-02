# Holdings and quotes

Muskometer tracks Musk's paper gains on **TSLA** and **SPCX** using SEC-reported share counts and live Yahoo Finance quotes.

## Share counts

Share counts come from Elon Musk's **SEC Form 4** filings. The app checks EDGAR once per day and walks recent Form 4 accessions until it finds counts for both tickers.

| Ticker | Default (until SEC sync) | How it's derived |
|--------|--------------------------|------------------|
| **TSLA** | 699,580,882 | Direct beneficial-ownership row from Form 4 XML |
| **SPCX** | 6,068,734,060 | Aggregated Class A-equivalent ownership from Form 4 XML |

**SPCX aggregation** — SpaceX filings split holdings across Class A, Class B, preferred series, and trusts. Muskometer sums the latest per-trust rows, converts preferred series to Class A-equivalent (series A/B preferred × 50 per filing footnotes), and adds restricted Class B cited in filing remarks.

**Partial sync** — If only one ticker is found in the filings checked, the app keeps prior counts and retries on the next daily sync. You can also tap **Sync holdings from SEC** in Settings.

**Overrides** — TSLA and SPCX share counts can be edited manually in Settings; overrides persist until the next successful SEC sync updates them.

## Live prices

TSLA and SPCX quotes come from Yahoo Finance (`query1.finance.yahoo.com`). Quotes refresh every 60–120 seconds (default **90s**) while the US equity market is open. Outside market hours the app does not auto-refresh; the label keeps the last fetched prior-close values until the next session (manual refresh still works).

## Paper gain math

```
paperGain = shareCount × (currentPrice − previousClose)
```

Combined paper gain is the sum across TSLA and SPCX. Combined **percent** change is portfolio-weighted on prior close value — not a simple average of the two tickers.

Figures are **illustrative** — not financial advice.

See [DISCLAIMER.md](DISCLAIMER.md).