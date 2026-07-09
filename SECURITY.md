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

**When the app is codesigned with entitlements** (Xcode Debug/Release runs, and optional Developer ID / notarized builds via `scripts/release.sh`), it runs with **App Sandbox** enabled. Entitlements are limited to:

- `com.apple.security.app-sandbox`
- `com.apple.security.network.client` (outbound HTTPS only)

Defined in `Muskometer/Muskometer.entitlements`.

### Unsigned open-source DMG (current public path)

Public artifacts from `scripts/package-dmg.sh` are built with `CODE_SIGNING_ALLOWED=NO` so no Apple Developer Program membership is required. That path does **not** embed the entitlements file: the shipped `.app` is **not App Sandboxed**.

This is an intentional Gatekeeper / unsigned-distribution tradeoff, not a claim of sandbox enforcement on unsigned builds. Prefer building from source in Xcode (or a signed Developer ID release) when you want sandbox protections. See [docs/RELEASE.md](docs/RELEASE.md).

## Reporting a vulnerability

If you find a security issue, please **do not** open a public issue with exploit details.

Instead:

1. Open a [GitHub Security Advisory](https://github.com/jlgolson/muskometer/security/advisories/new), or
2. Email [info@muskometer.org](mailto:info@muskometer.org)

We'll acknowledge receipt and work on a fix. This is a solo side project — please allow reasonable time for response.

## Supported versions

| Version | Supported | Notes |
|---------|-----------|-------|
| 0.1.x   | ✅        | Current public release line (0.1.3) |
| < 0.1   | ❌        | Pre-release / not distributed |

---

© [Jordan Golson](https://jordangolson.com) · [info@muskometer.org](mailto:info@muskometer.org)