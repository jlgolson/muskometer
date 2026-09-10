# Popover visual correction validation

The change restores the complete comparison heading and $518.51 implied price above secondary content at 600, 700, 800 and 900 points. Ownership methodology appears once in the actual Holdings tab and is absent from main-view OCR. Main records, both stock cards, footer controls and Settings/back remain reachable through real scrolling and clicks.

`validation.json` binds final results and stable raw evidence paths to `source-manifest.json`. `test-identifiers.json` proves preservation of the 391 baseline cases. `initial-viewport-geometry.json` records the recognized complete title and exact price against the actual NSScrollView clip bounds before scrolling, using top-left image coordinates. `normal-release.json` identifies the normal Release app produced by the sole final verification run, copied to the controller for the later preview handoff. No preview was launched by this implementer.

## Visual observations

- Compared the original supplied images and a same-data red-run image against the corrected main600 and main900 images. The observed nine samples retain their actual timestamp spacing; the $2.7B range now spans about 45 of the 60 plotting points, with a clear endpoint and a modest area gradient. Labels disclose the approximately +$13.2B to +$16.3B displayed domain. The current +$15.9B total matches the latest sample.
- The full comparison fits initially at each required height. Secondary cards remain readable, with scrolling on small screens. The 600-point detail image reaches both stock cards, and footer controls stay outside the scroll area.
- Holdings shows the methodology once above the existing SEC, issuer provenance, share fields and reset control; only the tab and Back were clicked. No SEC sync, reset, notifications or real defaults were used.
- The shared image uses the production ShareImageExporter path at 720 pixels wide, with the same chart and explicit dark range-label environment. Positive, negative and mixed exports retain their corresponding totals, parity and holdings, with no clipping.
- Negative charts shade upward toward their visible domain edge. Genuine crossings retain green/red segmentation and visible zero; flat positive/negative/zero remain horizontal. Single input draws a centered dot, empty history draws no invented chart, and the labelled 400-point fixture preserves ordered monotonic movement.
- Light and dark main images are legible. The increased-contrast/reduced-transparency renderer fixture has stronger labels and no transparent fill, with its real line and endpoint intact.

## Capture fidelity and accessibility adaptation

The initial cacheDisplay raster lost macOS Liquid Glass compositor layers and made primary labels black. Those early images are retained as harness diagnostics, not accepted visual evidence. Final main/Settings/chart images use ScreenCaptureKit currentProcess shareable content filtered to the test's own borderless NSWindow, preserving real composited glass and compiled Assets.car. No desktop or other app was captured, and no TCC permission/system preference was changed. Share images use the unchanged production exporter.

The public NSHostingView/NSWindow high-contrast appearance request normalized to Dark Aqua on this macOS 26.4.1 host; SwiftUI's get-only contrast stayed standard. Initial assertions exposed that limitation rather than proving propagation. The final evidence records requested and observed appearances honestly. A narrow shared rendering component accepts explicit color-scheme/contrast/reduced-transparency inputs; production GainSparklineView always supplies its live environment, and tests supply accessible inputs to that same renderer. This uses no private environment keys, swizzling or global preferences. The requested-appearance main screenshot is not claimed as proof of system contrast propagation.

## Isolation and preserved behavior

The flagged test app has only an empty Settings scene and positive test marker. It cannot register AppDelegate or start settings, login, network, update, notification or menu-bar services. The original normal app declaration is byte-for-byte preserved under #else. The existing controller xcodebuild wrapper adds the flag only to test actions, retaining its nonparallel controls and unchanged aggregate launch lock. Exactly one bootstrap test executed and passed before presentation red. Focused/full suites include its positive assertion and actual compiled asset proof.

All fixture settings use unique MuskometerTests-visual suites, MockLaunchAtLoginManager, controlled quotes, explicit mock SEC/outstanding factories, failing test notification sinks, fixed Eastern dates and a controlled store. The observed JSON is read-only; synthetic cases are labelled and never written into user history. The full verification skips only the optional live Yahoo network step, as instructed. Historical twelve-fix plans and review artifacts were preserved.
