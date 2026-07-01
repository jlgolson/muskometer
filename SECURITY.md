# Security Policy

Muskometer is a read-only menu bar utility. It does not handle payments, accounts, or personal financial data.

## What the app does

- Fetches **public** stock quotes from Yahoo Finance (`query1.finance.yahoo.com`)
- Fetches **public** SEC EDGAR Form 4 filings for Elon Musk's reported holdings
- Stores preferences locally in **UserDefaults** (share counts, refresh interval, display mode, launch-at-login)

## What the app does *not* do

- No analytics or tracking SDKs
- No API keys or secrets in the binary
- No inbound network listeners
- No access to Keychain, Contacts, Photos, or arbitrary files

## Sandbox

The app runs with **App Sandbox** enabled. Entitlements are limited to:

- `com.apple.security.app-sandbox`
- `com.apple.security.network.client` (outbound HTTPS only)

## Reporting a vulnerability

If you find a security issue, please **do not** open a public issue with exploit details.

Instead:

1. Open a [GitHub Security Advisory](https://github.com/jlgolson/muskometer/security/advisories/new), or
2. Email [info@muskometer.org](mailto:info@muskometer.org)

We'll acknowledge receipt and work on a fix. This is a solo side project — please allow reasonable time for response.

## Supported versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | ✅        |

---

© [Jordan Golson](https://jordangolson.com) · [info@muskometer.org](mailto:info@muskometer.org)