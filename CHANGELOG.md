# Changelog

All notable changes to Muskometer are documented here.

Format loosely follows [Keep a Changelog](https://keepachangelog.com/). Versioning follows [SemVer](https://semver.org/).

## [0.1.0] - 2026-07-01

First public release of Muskometer for macOS (source). A signed `.dmg` will follow on GitHub Releases.

### Added

- **Menu bar label** — combined daily paper gain with green/red coloring (e.g. `+$46.6B`)
- **Popover detail view** — per-stock price, % change, paper gain, combined total, market status
- **Auto-refresh** — configurable 60–120 second interval while US market is open
- **Copy summary** — one-click clipboard text for sharing
- **Launch at login** — optional background startup via menu bar utility pattern
- **SEC holdings sync** — TSLA and SPCX share counts from Form 4 filings (SPCX scaled ÷100)
- **Yahoo Finance integration** — live quotes for TSLA and SPCX proxy ticker
- **Market hours awareness** — 9:30 AM–4:00 PM ET with weekend/holiday handling
- **Settings** — refresh interval, menu bar display mode (dollars/percent, combined/split), manual SEC sync
- **Keyboard shortcuts** — ⌘R refresh, ⌘, settings

### Notes

- Entertainment only — not financial advice.