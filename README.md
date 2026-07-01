# Muskometer

![CI](https://github.com/jlgolson/muskometer/actions/workflows/ci.yml/badge.svg)

**What's Elon up to today?**

A lightweight native macOS menu bar app that tracks Elon Musk's daily **paper gains** on TSLA and SPCX using live Yahoo Finance quotes.

🌐 **[muskometer.org](https://muskometer.org)** · 📦 **[github.com/jlgolson/muskometer](https://github.com/jlgolson/muskometer)**

## Install

### Download

1. **[GitHub Releases](https://github.com/jlgolson/muskometer/releases)** — download the latest `Muskometer-0.1.0.dmg` (or the newest release asset)
2. Open the DMG, drag **Muskometer** to **Applications**
3. **First launch:** right-click **Muskometer** → **Open** → **Open** (unsigned build — macOS will trust it after that once)

Step-by-step help: **[docs/INSTALL.md](docs/INSTALL.md)**

### Build from source

Requires macOS 14.0+ and Xcode 15+.

```bash
git clone https://github.com/jlgolson/muskometer.git
cd muskometer
open Muskometer.xcodeproj
```

Select the **Muskometer** scheme, **My Mac**, press **⌘R**.

## Features

- **Menu bar label** — combined daily paper gain, percent change, split view, or **total worth** across TSLA and SPCX
- **Trend icon toggle** — optional chart icon beside the label; hide it for text only
- **Popover** — **Elon's Ownership** total, per-stock price, **Today's Gain/Loss** labels, combined total, market status
- **Auto-refresh** — every 60–120 seconds while the US market is open
- **Share** — copy an image card or text summary (configurable in Settings)
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
No. Muskometer shows illustrative *paper gains* (share count × price change) for entertainment. It is not investment advice, tax guidance, or a real-time trading tool. Not affiliated with Tesla, SpaceX, or Elon Musk. See **[docs/DISCLAIMER.md](docs/DISCLAIMER.md)**.

**Where do share counts come from?**  
**TSLA** and **SPCX** share counts come from Musk’s SEC Form 4 filings. SPCX aggregates Class A/B trust lines and filing remarks into Class A-equivalent shares (about **6 billion** by default). Live quotes from Yahoo Finance. See **[docs/HOLDINGS.md](docs/HOLDINGS.md)**.

**When does the number update?**  
Quotes refresh every 60–120 seconds while the US equity market is open (9:30 AM–4:00 PM ET, weekdays, excluding holidays). Outside market hours the label uses the prior close and refreshes less often.

**What data does the app collect?**  
Nothing leaves your Mac except HTTPS requests to Yahoo Finance and SEC EDGAR for public market data. Preferences stay in UserDefaults. See **[docs/PRIVACY.md](docs/PRIVACY.md)**.

## Documentation

| Doc | Description |
|-----|-------------|
| [INSTALL.md](docs/INSTALL.md) | Install guide |
| [HOLDINGS.md](docs/HOLDINGS.md) | Share counts, quotes, and paper-gain math |
| [DISCLAIMER.md](docs/DISCLAIMER.md) | Entertainment-only disclaimer |
| [PRIVACY.md](docs/PRIVACY.md) | Data & privacy |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | App structure and data flow |
| [DEVELOPING.md](docs/DEVELOPING.md) | Build, test, and verify locally |
| [RELEASE.md](docs/RELEASE.md) | Maintainer release process |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |
| [CHANGELOG.md](CHANGELOG.md) | Release history |
| [SECURITY.md](SECURITY.md) | Security policy |

## Contact

[info@muskometer.org](mailto:info@muskometer.org)

## License

MIT — see [LICENSE](LICENSE). Copyright [Jordan Golson](https://jordangolson.com) / [@jlgolson](https://github.com/jlgolson).

## Disclaimer

Share counts come from SEC Form 4 filings. Figures are illustrative — not financial advice. Not affiliated with Tesla, SpaceX, or Elon Musk. **[docs/DISCLAIMER.md](docs/DISCLAIMER.md)** · **[docs/HOLDINGS.md](docs/HOLDINGS.md)**