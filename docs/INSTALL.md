# Installing Muskometer

## Install now

There is no pre-built download yet. Build and run locally with Xcode:

1. Clone the repo: `git clone https://github.com/jlgolson/muskometer.git`
2. Open `Muskometer.xcodeproj` in Xcode 15+
3. Scheme **Muskometer**, destination **My Mac**, press **⌘R**

The app appears in your menu bar (no Dock icon).

**Requirements:** macOS 14.0 (Sonoma) or later, internet access (Yahoo Finance + SEC EDGAR).

## Install from a release (when available)

A signed `.dmg` will be published on [GitHub Releases](https://github.com/jlgolson/muskometer/releases). When it’s there:

1. Download **`Muskometer-<version>.dmg`**
2. Open the DMG and drag **Muskometer** into **Applications**
3. Eject the disk image

## First launch (Gatekeeper)

Because Muskometer is distributed outside the Mac App Store, macOS may ask you to confirm the first open:

1. Open **Applications** and double-click **Muskometer**.
2. If you see *"Muskometer can't be opened because it is from an unidentified developer"*, go to **System Settings → Privacy & Security** and click **Open Anyway** (or right-click the app → **Open** → **Open**).

**Official GitHub releases** are **Developer ID signed and notarized** — Gatekeeper should allow a normal double-click. If macOS still prompts, use **Open Anyway** in Privacy & Security or right-click → **Open**.

## Find it in the menu bar

Muskometer is a **menu bar app** — there is no Dock icon.

Look for the gain label in the **top-right** of your screen (e.g. `+$46.6B`). Click it to open the popover with per-stock details, refresh, and settings.

If you don't see it, other menu bar items may be hiding it — click the **◀** overflow chevron on the right side of the menu bar.

## Launch at login

1. Click the Muskometer menu bar label.
2. Open **Settings** (or press **⌘,**).
3. Enable **Launch at login**.

Muskometer will start quietly in the background whenever you log in.

## Uninstall

1. Quit Muskometer (popover → **Quit**, or **⌘Q** if the app is frontmost).
2. Drag **Muskometer** from Applications to the Trash.

Preferences are stored in `~/Library/Preferences/` under the app bundle ID (`org.muskometer.app`).

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| Stale or `—` label | Click **Refresh** or wait for the next auto-refresh |
| SEC sync message | Holdings update daily from Form 4 — partial syncs retry automatically |
| Wrong number after hours | Expected — outside 9:30 AM–4:00 PM ET the label reflects prior close |

Questions or bugs? [Open an issue on GitHub](https://github.com/jlgolson/muskometer/issues) or email [info@muskometer.org](mailto:info@muskometer.org).

---

© [Jordan Golson](https://jordangolson.com) · [info@muskometer.org](mailto:info@muskometer.org) · MIT License