# Changelog

All notable changes to Muskometer are documented here.

Format loosely follows [Keep a Changelog](https://keepachangelog.com/). Versioning follows [SemVer](https://semver.org/).

## [Unreleased]

Initial public release — source and docs are on GitHub; the first signed DMG is pending.

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
- **Unit tests** — formatters, quote math, SEC parser, SPCX scaling, view model
- **Landing site** — [muskometer.org](https://muskometer.org) via GitHub Pages
- **Release tooling** — `scripts/release.sh` for Developer ID signed DMG + notarization ([docs/RELEASE.md](docs/RELEASE.md))

### Notes

- **Distribution:** Until the first [GitHub Release](https://github.com/jlgolson/muskometer/releases) ships, install via [build from source](README.md#build-from-source).
- Entertainment only — not financial advice.