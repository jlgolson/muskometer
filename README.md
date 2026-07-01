# Muskometer

**What's Elon up to today?**

A lightweight native macOS menu bar app that tracks Elon Musk's daily **paper gains** on TSLA and SPCX using live Yahoo Finance quotes.

🌐 **[muskometer.org](https://muskometer.org)** · 📦 **[github.com/jlgolson/muskometer](https://github.com/jlgolson/muskometer)**

## Install

### Download

1. **[GitHub Releases](https://github.com/jlgolson/muskometer/releases)** — download `Muskometer-0.1.1.dmg`
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

**Where do share counts come from?**  
TSLA and SPCX (SpaceX) holdings are read from Elon Musk’s SEC Form 4 filings and multiplied by live Yahoo Finance prices for paper-gain math.

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

SPCX is SpaceX’s public ticker on Yahoo Finance. Share counts come from SEC Form 4 filings. Figures are illustrative entertainment — not financial advice. Not affiliated with Tesla, SpaceX, or Elon Musk.