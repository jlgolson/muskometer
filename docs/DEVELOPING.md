# Developing Muskometer

Thanks for poking around the code. This is a small SwiftUI menu bar app — easy to build and test locally.

## Prerequisites

- macOS 14.0+
- **Xcode 15+** (includes Swift 5.9+)
- Command Line Tools (`xcode-select --install` if needed)

## Clone & open

```bash
git clone https://github.com/jlgolson/muskometer.git
cd muskometer
open Muskometer.xcodeproj
```

In Xcode:

1. Scheme: **Muskometer**
2. Destination: **My Mac**
3. Run: **⌘R**

The app appears in your menu bar immediately. No Dock icon — that's intentional (`NSApplication.shared.setActivationPolicy(.accessory)`).

## Verify script

Before opening a PR, run the full check suite:

```bash
scripts/verify.sh
```

This runs:

1. **Swift typecheck** — all `Muskometer/**/*.swift` files
2. **Unit tests** — `xcodebuild test` on macOS
3. **Release build** — sanity compile
4. **Entitlements check** — **fails** if the built `.app` is missing sandbox or `network.client`
5. **Live Yahoo API** — end-to-end quote + paper-gain math (local default)

### Skipping live Yahoo (CI)

Live Yahoo is on by default for local `scripts/verify.sh` so you catch integration regressions. GitHub Actions sets `MUSKOMETER_SKIP_LIVE_YAHOO=1` so CI is not flaky when Yahoo is down or rate-limits.

To skip locally:

```bash
MUSKOMETER_SKIP_LIVE_YAHOO=1 scripts/verify.sh
```

## Tests

Run tests from Xcode (**⌘U**) or Terminal:

```bash
xcodebuild test \
  -scheme Muskometer \
  -configuration Debug \
  -destination 'platform=macOS'
```

Tests live in `MuskometerTests/` — formatters, quote math, market hours, SEC parser, SPCX scaling, and view model behavior.

## Project layout

```
muskometer/
├── Muskometer/
│   ├── App/              # MuskometerApp, AppDelegate, notifications
│   ├── ViewModels/       # GainsViewModel (@Observable)
│   ├── Views/            # Menu bar label, popover, settings
│   ├── Models/           # StockQuote, GainsSnapshot, holdings
│   ├── Services/         # Yahoo Finance, SEC sync, market hours
│   ├── Utilities/        # Formatters, AppSettings, SPCXHoldings
│   └── Resources/        # Assets, Info.plist, entitlements
├── MuskometerTests/
├── scripts/
│   ├── verify.sh         # CI-style checks
│   ├── package-dmg.sh    # Unsigned DMG + zip (primary release path)
│   └── release.sh        # Signed DMG + notarization (optional)
├── Config/               # Optional local signing overrides (gitignored)
└── docs/                 # GitHub Pages site + documentation
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for how the pieces connect.

## Code signing

`DEVELOPMENT_TEAM` is empty in `Muskometer.xcodeproj` so the repo builds **unsigned** for anyone out of the box. That is intentional — do not commit your Team ID to `project.pbxproj`.

### Local Debug signing (optional)

1. Open the project in Xcode.
2. Select the **Muskometer** target → **Signing & Capabilities**.
3. Set your **Team** (Personal Team is fine for local dev).
4. Bundle ID: `org.muskometer.app` (change if it conflicts with your account).

### Recommended: local xcconfig (no pbxproj edits)

```bash
cp Config/Release.xcconfig.example Config/Release.xcconfig
# Edit DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

`Config/Release.xcconfig` is gitignored. `scripts/release.sh` reads it when `APPLE_TEAM_ID` is unset.

### Distribution (maintainers)

Public releases use the **unsigned** `./scripts/package-dmg.sh` path (no Apple Developer account). Signed, notarized builds via `release.sh` are optional — see **[RELEASE.md](RELEASE.md)**.

```bash
./scripts/package-dmg.sh
```

## Entitlements

`Muskometer/Muskometer.entitlements`:

- `com.apple.security.app-sandbox` — enabled
- `com.apple.security.network.client` — Yahoo + SEC only

No keychain, no file access beyond UserDefaults.

## Useful commands

```bash
# Debug build only
xcodebuild -scheme Muskometer -configuration Debug build

# Release build
xcodebuild -scheme Muskometer -configuration Release build

# Typecheck without Xcode GUI
SDK=$(xcrun --show-sdk-path)
swiftc -typecheck -target arm64-apple-macos14.0 -sdk "$SDK" \
  -module-name Muskometer -parse-as-library \
  $(find Muskometer -name "*.swift" | sort)
```

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md). Short version: fork, branch, run `scripts/verify.sh`, open a PR.

---

© [Jordan Golson](https://jordangolson.com) · [info@muskometer.org](mailto:info@muskometer.org)