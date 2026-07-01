# Manual smoke checklist — Muskometer

Run after `scripts/verify.sh` passes. Takes ~5 minutes.

## Launch & menu bar

- [ ] App launches with **no Dock icon** (only menu bar item)
- [ ] Menu bar shows chart icon + gain label (e.g. `+$46.6B` or `…` while loading)
- [ ] Label turns **green** when combined gain is positive, **red** when negative
- [ ] Label updates within ~10s of launch (network fetch completes)

## Popover

- [ ] Click menu bar item → popover opens (not a dropdown menu)
- [ ] **Combined today** card shows total paper gain
- [ ] **TSLA** row: price, % change, paper gain
- [ ] **SPCX** row: price, % change, paper gain
- [ ] **Market open/closed** indicator matches current ET time
- [ ] **Updated** timestamp shows recent time
- [ ] **Refresh** button re-fetches (timestamp updates)
- [ ] Popover looks correct in **light and dark mode** (toggle System Settings → Appearance)

## Settings

- [ ] Popover **Settings…** or **⌘,** opens settings window
- [ ] Refresh slider (60–120s) saves and persists after relaunch
- [ ] Invalid share count shows red error and reverts
- [ ] Valid share count changes update popover math after refresh
- [ ] **Reset to defaults** restores 699,580,882 / 6,068,547,515 and 90s interval

## Edge cases

- [ ] Turn off Wi-Fi → error state with **Try Again** (not a crash)
- [ ] Turn Wi-Fi back on → **Try Again** recovers
- [ ] Quit app (Activity Monitor or `killall "Muskometer"`) → no orphan processes

## Optional

- [ ] Leave running 2+ minutes during market hours → label auto-updates without clicking
- [ ] Compare TSLA % in popover to Yahoo Finance web (should be within rounding)