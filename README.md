# Muskometer

**What's Elon up to today?**

A lightweight native macOS menu bar app that tracks Elon Musk's daily **paper gains** on TSLA and SPCX using live Yahoo Finance quotes.

🌐 **[muskometer.org](https://muskometer.org)** · 📦 **[github.com/jlgolson/muskometer](https://github.com/jlgolson/muskometer)**

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+

## How to run

```bash
git clone https://github.com/jlgolson/muskometer.git
cd muskometer
open Muskometer.xcodeproj
```

Select the **Muskometer** scheme, **My Mac**, press **⌘R**.

Or from Terminal:

```bash
xcodebuild -scheme Muskometer -configuration Debug build
scripts/verify.sh
```

## Features

- **Menu bar label** — combined daily paper gain with green/red coloring (e.g. `+$46.6B`)
- **Popover** — per-stock price, % change, paper gain, combined total, market status
- **Auto-refresh** — every 60–120 seconds while the US market is open
- **Copy summary** — one-click clipboard for sharing on X
- **Launch at login** — always-on menu bar utility
- **SEC holdings sync** — TSLA/SPCX share counts from Form 4 filings

## Website & domain

The landing page lives in [`docs/`](docs/) and is published via **GitHub Pages**.

1. Repo **Settings → Pages → Build from branch `main` / `/docs`**
2. **Custom domain:** `muskometer.org` (the `docs/CNAME` file is already set)
3. At your registrar, point `muskometer.org` to GitHub Pages ([GitHub's DNS guide](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site))

## Disclaimer

SPCX is a proxy ticker for SpaceX exposure, not SpaceX stock itself. Figures are illustrative paper gains for entertainment — not financial advice. Not affiliated with Tesla, SpaceX, or Elon Musk.