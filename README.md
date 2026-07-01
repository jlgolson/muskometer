# Muskometer

**What's Elon up to today?**

A lightweight native macOS menu bar app that tracks Elon Musk's daily **paper gains** on TSLA and SPCX using live Yahoo Finance quotes.

🌐 **[muskometer.org](https://muskometer.org)** · 📦 **[github.com/jlgolson/muskometer](https://github.com/jlgolson/muskometer)**

<!-- Screenshot placeholder: add docs/screenshot.png when available -->
> **Screenshot:** Menu bar label + popover preview coming soon — see [muskometer.org](https://muskometer.org) for a live mockup.

## Install

### Download latest release

1. **[GitHub Releases → Latest](https://github.com/jlgolson/muskometer/releases/latest)** — download `Muskometer-<version>.dmg`
2. Open the DMG, drag **Muskometer** to **Applications**, launch from Applications or Spotlight

Step-by-step help (Gatekeeper, menu bar, launch at login): **[docs/INSTALL.md](docs/INSTALL.md)**

> No release published yet? Use [build from source](#build-from-source) below, or watch [releases](https://github.com/jlgolson/muskometer/releases).

### Build from source

Requires macOS 14.0+ and Xcode 15+.

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

Developer setup: **[docs/DEVELOPING.md](docs/DEVELOPING.md)** · Maintainer releases: **[docs/RELEASE.md](docs/RELEASE.md)**

## Features

- **Menu bar label** — combined daily paper gain with green/red coloring (e.g. `+$46.6B`)
- **Popover** — per-stock price, % change, paper gain, combined total, market status
- **Auto-refresh** — every 60–120 seconds while the US market is open
- **Copy summary** — one-click clipboard for sharing on X
- **Launch at login** — always-on menu bar utility
- **SEC holdings sync** — TSLA/SPCX share counts from Form 4 filings

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| **⌘R** | Refresh quotes |
| **⌘,** | Open Settings |
| **Esc** | Close standalone Settings window (not the in-popover settings sheet) |

## FAQ

**Is this financial advice?**  
No. Muskometer shows illustrative *paper gains* (share count × price change) for entertainment. It is not investment advice, tax guidance, or a real-time trading tool. Not affiliated with Tesla, SpaceX, or Elon Musk.

**Why is SPCX share count divided by 100?**  
SEC Form 4 filings report SpaceX beneficial ownership in units that are **100×** the public SPCX ticker share count used with Yahoo quotes. `SPCXHoldings.swift` scales SEC values ÷100 so paper-gain math matches the proxy ticker. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

**When does the number update?**  
Quotes refresh every 60–120 seconds while the US equity market is open (9:30 AM–4:00 PM ET, weekdays, excluding holidays). Outside market hours the label uses the prior close and refreshes less often.

## Documentation

| Doc | Description |
|-----|-------------|
| [INSTALL.md](docs/INSTALL.md) | End-user install guide |
| [RELEASE.md](docs/RELEASE.md) | Signed DMG, notarization, GitHub Releases |
| [DEVELOPING.md](docs/DEVELOPING.md) | Clone, build, test, sign |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | MVVM layout and data flow |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |
| [CHANGELOG.md](CHANGELOG.md) | Release history |
| [SECURITY.md](SECURITY.md) | Security & privacy |

## Website & domain

The landing page lives in [`docs/`](docs/) and is published via **GitHub Pages**.

1. Repo **Settings → Pages → Build from branch `main` / `/docs`**
2. **Custom domain:** `muskometer.org` (the `docs/CNAME` file is already set)
3. At your registrar, point `muskometer.org` to GitHub Pages ([GitHub's DNS guide](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site))

## License

MIT — see [LICENSE](LICENSE). Copyright [Jordan Golson](https://jordangolson.com) / [@jlgolson](https://github.com/jlgolson).

## Disclaimer

SPCX tracks Space Exploration Technologies Corp. via Yahoo Finance. SEC Form 4 share counts are scaled ÷100 for public-ticker paper-gain math. Figures are illustrative entertainment — not financial advice. Not affiliated with Tesla, SpaceX, or Elon Musk.