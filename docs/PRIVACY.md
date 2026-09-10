# Privacy

Muskometer is designed to be a **local, read-only** menu bar utility. It does not run analytics, ads, or account systems.

## What stays on your Mac

Preferences are stored in **UserDefaults** under the app bundle ID (`org.muskometer.app`):

- TSLA and SPCX share counts (including SEC-synced ownership defaults)
- Issuer shares outstanding for market-cap parity (company totals, separate from ownership)
- Menu bar display mode, trend icon preference, and market-cap parity card toggle
- Share format (copy image card vs text summary)
- Update-notify flag for available GitHub releases
- Auto-refresh interval
- Launch-at-login setting
- Last SEC holdings sync timestamp
- Daily-record extremes (best/worst session paper gains and related day keys)
- Intraday sparkline samples (combined paper-gain series for the latest RTH session)
- Gain-threshold notification IDs and per-threshold state

No database, no cloud sync, no third-party SDKs.

## What leaves your Mac

The app makes **outbound HTTPS** requests only:

| Destination | Purpose |
|-------------|---------|
| Yahoo Finance (`query1.finance.yahoo.com`) | Live TSLA and SPCX quotes |
| SEC EDGAR (`data.sec.gov`, `www.sec.gov`) | Public Form 4 filings (ownership) and companyfacts (issuer outstanding) |
| GitHub Releases API (`api.github.com`) | Optional update checks when notify-of-updates is enabled |

These services receive standard request metadata (IP address, TLS handshake, etc.) as any HTTPS client would. Muskometer does **not** send your name, email, Apple ID, or other personal identifiers.

## What we do not collect

- No analytics or crash-reporting SDKs
- No API keys or secrets in the binary
- No access to Keychain, Contacts, Photos, or arbitrary files
- No inbound network listeners

## App Sandbox

When codesigned with entitlements (Xcode builds and optional Developer ID releases), Muskometer runs with **App Sandbox** enabled; entitlements are limited to sandboxing and outbound network client access. Public unsigned DMGs from `package-dmg.sh` do **not** embed those entitlements. See [SECURITY.md](../SECURITY.md) for the full policy.

## Children

Muskometer is not directed at children and does not knowingly collect personal information from anyone.

## Changes

If this policy changes materially, it will be updated in this repository. The current public release is **0.1.5**.

## Contact

Privacy questions: [info@muskometer.org](mailto:info@muskometer.org)

---

© [Jordan Golson](https://jordangolson.com) · [info@muskometer.org](mailto:info@muskometer.org) · MIT License