# App icon source notes

Shipping assets live in `Muskometer/Assets.xcassets/AppIcon.appiconset/` as **full-bleed PNG** squares (system applies the squircle and Liquid Glass edge treatment on macOS 26).

## Icon Composer (recommended next step)

Muskometer targets **macOS 26**. For a layered Liquid Glass app icon (Default / Dark / Clear / Tinted):

1. Install [Icon Composer](https://developer.apple.com/icon-composer/) and open Apple’s macOS template from [Design Resources](https://developer.apple.com/design/resources/).
2. Author layers that match the Muskometer mark (filled shapes; avoid pre-masked white corners).
3. Export / save a `.icon` bundle.
4. In Xcode, add the `.icon` to the Muskometer target (App Icon source). Keep or replace the PNG `AppIcon.appiconset` per Apple’s coexistence guidance for your Xcode version.
5. Build on the macOS 26 SDK and verify Appearance → Default / Dark / Clear / Tinted.

Until a `.icon` ships in-repo, PNG full-bleed assets remain the supported path. Do not confuse UI `glassEffect` cards (`MuskometerGlass`) with the app icon pipeline — they are separate.

`design/app-icon-32x32.png` is a small reference thumbnail only.
