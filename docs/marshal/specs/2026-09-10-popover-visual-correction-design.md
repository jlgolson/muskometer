---
slug: 2026-09-10-popover-visual-correction-design
date: 2026-09-10
local_only: true
---

# Correct the local popover preview

## Intent and authorization

The user reviewed the actual build at `c151d54d21efea2681fd255012b41a8f35984130` and explicitly requested that the vested-options explanation move into Settings, the Tesla/SpaceX market-cap comparison become visible on the main page again, and the flat sparkline gain useful shape and visual depth. This is a scoped follow-up to the twelve completed correctness fixes. Deliver an improved local app for another visual inspection. No GitHub push, PR, release, installation replacement, or external messages are authorized. Existing approved specification and review history remain historical artifacts.

## Observed causes

`PopoverContentView` places the ownership-methodology text prominently inside its ownership card. Its scrollable content places parity after daily records and both stock cards, so the user's populated 900-point view clips parity below the fold. Previous layout coverage checks scrolling and footer reachability, but not initial parity visibility. `SparklineLayout` forces zero into its vertical domain: fluctuations around approximately +$16B collapse into a few pixels in a 36-point chart. Its uniform fill lacks a visible gradient or endpoint emphasis.

## Required presentation

1. Remove the permanent common-stock/vested-options/performance-RSU explanation from the main ownership card. Present that methodology once under **Settings → Holdings**, alongside ownership/source information. Keep ownership totals, temporary ownership-change feedback, and milestone behavior intact.
2. Prioritize the main-page ownership total, today's gain/chart, and **If Tesla had SpaceX's market cap** comparison before historical records and individual stock detail. With parity enabled and complete quote data, its complete heading and implied TSLA price must be visible without scrolling in a populated 360-point-wide popover at 600, 700, 800, and 900-point available heights. Keep source/outstanding detail available in Holdings; avoid repeating long provenance on the main page when it prevents useful content fitting. Compact spacing or related metric rows as needed, while preserving readable type, controls, records, stocks, and the existing parity preference/calculation. Keep scrollable secondary content and reachable footer actions.
3. Give the chart approximately 56–64 points of plotting height, a legible rounded stroke, a subtle vertical area gradient, and a clear latest-point marker. Scale to the actual observed range with padding and a sensible minimum range; do not force a distant zero into an entirely positive or negative series. Show concise monetary range context so the tighter scale is honest. Draw the zero reference only when zero lies in the visible range, and retain correct green/red coloring across genuine crossings. Never invent market samples or intraday history, distort timestamps, or add oscillations to constant data. Empty, one-point, flat, mixed-sign, negative-only, and tightly varying large-value series must render safely and honestly. Continue bounding input through the existing 400-sample store.
4. `GainSparklineView` is shared with the exported share card. Preserve legibility and bounded layout there as well. Respect appearance/accessibility settings without changing the user's system preferences. Limit changes to these UI surfaces, their necessary pure layout helpers, focused tests, and concise relevant documentation.

## Verification and delivery

Use the screenshots supplied by the user as the before reference. Write focused regressions for the actual chart-domain failure and initial parity visibility before implementing the behavior changes. Do not write a text-mirroring test just for relocating copy. Exercise actual hosted SwiftUI content with all cards populated, at 600/700/800/900 points, checking the first visible area as well as scrolling and Settings/back. Verify the methodology is in Holdings and absent from the main view through rendered/accessibility evidence.

Render and inspect asset-backed main-page and share-card captures with representative positive narrow-range data, negative/mixed/flat/single-point data, plus Settings → Holdings. Compare the main page against the user's screenshot before claiming visual success. A source-tree layout assertion alone is insufficient. Run the complete XCTest suite and Release build once after executable changes converge; retain all 391 existing cases unless a specific presentation assertion is intentionally superseded with stronger evidence. Independent reviewers must inspect the changed source and the actual after images. Then quit the prior app, launch exactly one newly built local app, and verify its executable path at host level.

All tests, app builds, and standalone Swift probes use the existing shared `build/run-aggregate.py` launcher with host permissions: it quits existing Muskometer before launching and disables parallel test hosts. Never run a second app version concurrently. Do not clear or overwrite the user's preferences, chart history, ownership counts, records, login configuration, or notification preferences for visual validation; use isolated defaults for controlled fixtures.

## Risks

Auto-scaling can exaggerate tiny movement without range labels or sensible padding. Increasing chart height can again displace the comparison or controls. A fixed-height assertion can pass while useful content is clipped. Shared chart changes can affect exported images. Standalone captures without the asset catalog can misrepresent the actual appearance. Address these with the explicit domain cases, first-viewport assertions, asset-backed image inspection, and local app handoff above.

## Deferred

None.

## Scale & Validation

The change introduces no new network work or persisted data. Chart layout/drawing remains linear in the existing maximum of 400 samples; verify a full-capacity series and finite bounded coordinates. Rendering checks cover small supported screen heights, realistic dense content, appearance, Settings, and the shared export surface.
