# Privacy

Muskometer is designed to be a **local, read-only** menu bar utility. It does not run analytics, ads, or account systems.

## What stays on your Mac

Preferences are stored in **UserDefaults** under the app bundle ID (`org.muskometer.app`):

- TSLA and SPCX share counts (including SEC-synced defaults)
- Menu bar display mode and trend icon preference
- Auto-refresh interval
- Launch-at-login setting
- Last SEC holdings sync timestamp

No database, no cloud sync, no third-party SDKs.

## What leaves your Mac

The app makes **outbound HTTPS** requests only:

| Destination | Purpose |
|-------------|---------|
| Yahoo Finance (`query1.finance.yahoo.com`) | Live TSLA and SPCX quotes |
| SEC EDGAR (`data.sec.gov`, `www.sec.gov`) | Public Form 4 filings for reported holdings |

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

If this policy changes materially, it will be updated in this repository. The current public release is **0.1.3**.

## Contact

Privacy questions: [info@muskometer.org](mailto:info@muskometer.org)

---

© [Jordan Golson](https://jordangolson.com) · [info@muskometer.org](mailto:info@muskometer.org) · MIT License