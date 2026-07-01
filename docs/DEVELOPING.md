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
4. **Entitlements check** — sandbox + network client on the built `.app`
5. **Live Yahoo API** — end-to-end quote + paper-gain math

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
│   └── release.sh        # Signed DMG + notarization (maintainers)
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

Signed, notarized DMG releases use **Developer ID Application** + `xcrun notarytool`. See **[RELEASE.md](RELEASE.md)** for one-time Apple portal setup, env vars, and GitHub Releases.

```bash
export APPLE_TEAM_ID=YOUR_TEAM_ID
export NOTARY_PROFILE=muskometer-notary   # after notarytool store-credentials
./scripts/release.sh
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