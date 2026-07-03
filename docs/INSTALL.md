# Installing Muskometer

## Download

1. Go to **[GitHub Releases](https://github.com/jlgolson/muskometer/releases)**.
2. Download the latest **`Muskometer-0.1.1.dmg`** (or the newest `Muskometer-<version>.dmg` on the releases page).
3. Open the DMG and drag **Muskometer** into **Applications**.
4. Eject the disk image.

**Requirements:** macOS 14.0 (Sonoma) or later, internet access (Yahoo Finance + SEC EDGAR).

## First launch (Gatekeeper)

Muskometer releases are **unsigned** (no $99 Apple Developer account). macOS will block a normal double-click the first time.

**Do this once:**

1. Open **Applications**.
2. **Right-click** (or Control-click) **Muskometer** → **Open**.
3. Click **Open** in the dialog.

After that, you can launch it normally from Applications or Spotlight.

If you prefer **System Settings → Privacy & Security → Open Anyway**, that works too.

## Find it in the menu bar

Muskometer is a **menu bar app** — there is no Dock icon.

Look for the gain label in the **top-right** of your screen (e.g. `+$46.6B`). Click it to open the popover with per-stock details, refresh, and settings.

If you don't see it, other menu bar items may be hiding it — click the **◀** overflow chevron on the right side of the menu bar.

## Launch at login

1. Click the Muskometer menu bar label.
2. Open **Settings** (or press **⌘,**).
3. Enable **Launch at login**.

Muskometer will start quietly in the background whenever you log in.

## Build from source

If you prefer to compile yourself (or there’s no release for your Mac yet):

1. Clone: `git clone https://github.com/jlgolson/muskometer.git`
2. Open `Muskometer.xcodeproj` in Xcode 15+
3. Scheme **Muskometer**, destination **My Mac**, press **⌘R**

## Uninstall

1. Quit Muskometer (popover → **Quit**, or **⌘Q** if the app is frontmost).
2. Drag **Muskometer** from Applications to the Trash.

Preferences are stored in `~/Library/Preferences/` under the app bundle ID (`org.muskometer.app`).

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| App won't open | Right-click → **Open** (see First launch above) |
| Stale or `—` label | Click **Refresh** or wait for the next auto-refresh |
| SEC sync message | Holdings update daily from Form 4 — partial syncs retry automatically |
| Wrong number overnight | Expected — outside extended hours the label reflects the last regular close |

Questions or bugs? [Open an issue on GitHub](https://github.com/jlgolson/muskometer/issues) or email [info@muskometer.org](mailto:info@muskometer.org).

---

© [Jordan Golson](https://jordangolson.com) · [info@muskometer.org](mailto:info@muskometer.org) · MIT License