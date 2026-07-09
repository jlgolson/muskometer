# Changelog

All notable changes to Muskometer are documented here.

Format loosely follows [Keep a Changelog](https://keepachangelog.com/). Versioning follows [SemVer](https://semver.org/).

## [Unreleased]

### Changed

- **RTH-only product** — auto-refresh, quotes, sparkline, and daily records run only during regular US trading hours (9:30 AM–4:00 PM ET / early close); pre-market and post-market are treated as closed (no extended-hours live trading labels or 180s floor)

## [0.1.3] - 2026-07-08

Correctness and reliability release — holdings, daily records, market hours, Settings, and refresh lifecycle.

### Fixed

- **SPCX ownership** — last Form 4 row wins (including full disposal to zero); preferred series ×50 covered by tests
- **Daily records** — quotable-only peaks/troughs; finalize after post-market (20:00 ET); persist unfinished day extremes across restarts
- **Sparkline** — clear prior-day samples on load and while always-open overnight (off-market VM sync)
- **SEC sync** — accept Form 4/A; scan up to 100 accessions; partial sync no longer overwrites counts; 24h backoff after partial/fail; complete sync can apply zero-share disposal
- **Settings** — share-count fields refresh after SEC so dismiss cannot undo a sync; empty fields restore stored counts
- **Refresh loop** — first open-session quote is immediate after off-market wait (no extra 60–180s delay)
- **Yahoo** — one symbol failure no longer drops the whole batch; prefer Yahoo `marketState` for price field selection
- **Market calendar** — Gregorian + ET defaults; early closes 2026–27; correct 2027 Good Friday (2027-03-26)
- **Launch at login** — soft-approval keeps user intent; re-sync when Settings opens / app becomes active; reset-to-defaults turns it off
- **Notifications** — request alert+sound only when enabling features; denied hint lifecycle fixed
- **Updates** — automatic mode uses GitHub notify checker (Sparkle still a stub until signed builds)
- **Share** — main-actor copy feedback; shortcut consume-on-success/debounce; global hotkey snapshots event fields
- **Currency** — en_US_POSIX formatting with consistent grouping
- **CI** — hard-fail missing sandbox entitlements on Debug product; optional live Yahoo skip in CI
- **Docs** — 0.1.3; extended-hours refresh floors; unsigned package-dmg sandbox honesty; version-scoped release notes

### Changed

- Net-worth jump below $1T → above $2T celebrates the two-trillion milestone
- `TradingDayCalendar` day keys use per-call formatters (thread-safe)

## [0.1.2] - 2026-07-03

Extended-hours release — live pre/post quotes for TSLA and SPCX on identical code paths.

### Added

- **Extended-hours quotes** — pre-market (4:00–9:30 AM ET) and post-market (4:00–8:00 PM ET) for TSLA and SPCX via the same Yahoo API path and price logic
- **`QuotePriceResolver`** — shared session-aware price selection from Yahoo chart meta

### Changed

- Auto-refresh, sparkline, intraday records, and threshold alerts run during extended hours
- UI shows Pre-market / Post-market / Market open instead of freezing at the regular close
- Docs describe TSLA and SPCX quotes identically (removed misleading “price mark” wording)

## [0.1.1] - 2026-07-02

Polish release — smarter off-hours behavior, clearer market-close labels, update notifications, and UI fixes.

### Added

- **Update checker** — optional “Notify of available updates” in Settings → General (default off); manual “Check for Updates Now” with up-to-date / available / error feedback; Sparkle-ready architecture for future one-click installs
- **Intraday sparkline** — combined gain chart in popover and share image (green above $0, red below)
- **Comparison captions** — contextual “today’s gain/loss could…” lines beneath combined total
- **Intraday records** — best/worst paper gain per session (hidden until first completed trading day)
- **Threshold notifications** — configurable gain/loss alerts during market hours
- **Post to X** — open tweet composer with pre-filled summary
- **Share image** — “As of” timestamp in local timezone on exported card
- **Trillion milestones** — celebration overlay when net worth crosses $1T / $2T

### Changed

- **Off-hours refresh** — auto-refresh only while US market is open; sleeps until next session instead of polling Yahoo overnight
- **Market closed label** — shows “As of 4:00 PM ET on July 2” (converted to your local timezone) instead of “Based on prior close”
- **Comparison caption** — gain/loss prefix updates when the day flips from red to green
- **Settings layout** — tabbed settings with auto-sized window; updates live under General
- **Daily records** — renamed from “Daily records” to “Intraday records”

### Fixed

- Sparkline color at breakeven crossings
- Comparison line stuck on “today’s loss” after flipping to a gain

### Notes

- Still unsigned `.dmg` — right-click → Open on first launch. Full auto-update requires a signed build (planned).

## [0.1.0] - 2026-07-01

First public release of Muskometer for macOS. Unsigned `.dmg` on GitHub Releases — right-click → Open on first launch.

### Added

- **Menu bar label** — combined daily paper gain with green/red coloring (e.g. `+$46.6B`)
- **Menu bar display modes** — combined or split dollars/percent, plus total worth across TSLA and SPCX
- **Trend icon toggle** — show or hide the chart icon for text-only menu bar display
- **Popover detail view** — per-stock price, % change, paper gain, combined total, market status
- **Auto-refresh** — configurable 60–120 second interval while US market is open
- **Share** — copy a branded image card to paste in Messages or anywhere
- **Launch at login** — optional background startup via menu bar utility pattern
- **SEC holdings sync** — TSLA and SPCX share counts from Form 4 filings (~6B Class A-equivalent SPCX aggregation)
- **Yahoo Finance integration** — live Nasdaq quotes for TSLA and SPCX
- **Market hours awareness** — 9:30 AM–4:00 PM ET with weekend/holiday handling
- **Settings** — refresh interval, menu bar display mode, trend icon, manual SEC sync
- **Keyboard shortcuts** — ⌘R refresh, ⌘, settings, Esc closes standalone Settings

### Changed

- **In-app disclaimer link** in Settings and popover footers
- **SEC User-Agent** uses bundle version instead of a hardcoded string

### Removed

- Undocumented Zuckerberg/META profile (Musk-only for v0.1.0 launch)

### Notes

- Entertainment only — not financial advice.