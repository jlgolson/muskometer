# Muskometer

**What's Elon up to today?**

A lightweight native macOS menu bar app that tracks Elon Musk's daily **paper gains** on TSLA and SPCX using live Yahoo Finance quotes.

🌐 **[muskometer.org](https://muskometer.org)** · 📦 **[github.com/jlgolson/muskometer](https://github.com/jlgolson/muskometer)**

## Install

Requires macOS 14.0+ and Xcode 15+.

```bash
git clone https://github.com/jlgolson/muskometer.git
cd muskometer
open Muskometer.xcodeproj
```

Select the **Muskometer** scheme, **My Mac**, press **⌘R**. The app appears in your menu bar.

Step-by-step help: **[docs/INSTALL.md](docs/INSTALL.md)**

A signed `.dmg` for drag-to-Applications install will be posted on [GitHub Releases](https://github.com/jlgolson/muskometer/releases) when it’s ready.

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
SEC Form 4 filings report SpaceX beneficial ownership in units that are **100×** the public SPCX ticker share count used with Yahoo quotes. The app scales SEC values ÷100 so paper-gain math matches the proxy ticker.

**When does the number update?**  
Quotes refresh every 60–120 seconds while the US equity market is open (9:30 AM–4:00 PM ET, weekdays, excluding holidays). Outside market hours the label uses the prior close and refreshes less often.

## Documentation

| Doc | Description |
|-----|-------------|
| [INSTALL.md](docs/INSTALL.md) | Install guide |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |
| [CHANGELOG.md](CHANGELOG.md) | Release history |
| [SECURITY.md](SECURITY.md) | Security & privacy |

## Contact

[info@muskometer.org](mailto:info@muskometer.org)

## License

MIT — see [LICENSE](LICENSE). Copyright [Jordan Golson](https://jordangolson.com) / [@jlgolson](https://github.com/jlgolson).

## Disclaimer

SPCX tracks Space Exploration Technologies Corp. via Yahoo Finance. SEC Form 4 share counts are scaled ÷100 for public-ticker paper-gain math. Figures are illustrative entertainment — not financial advice. Not affiliated with Tesla, SpaceX, or Elon Musk.