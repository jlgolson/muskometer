# Plain-English translation

## 1. What is this document?

This is a specification for a focused visual correction to Muskometer’s local popover, the compact app window. It follows twelve completed correctness fixes and the user’s inspection of build `c151d54d21efea2681fd255012b41a8f35984130`. The deliverable is an improved local app for another visual inspection. Earlier approved specifications and reviews remain historical records. The scope covers the affected screens, necessary layout calculations, focused tests, and brief relevant documentation.

## 2. What problem is the spec trying to solve?

The main ownership card permanently displays an explanation of how common shares, vested options, and performance-based stock awards are counted. The user wants that explanation in Settings. Meanwhile, the comparison showing Tesla at SpaceX’s market value comes after records and individual stock cards, leaving it below the initially visible area even in the user’s populated 900-point-high window.

The gain chart also looks flat because its vertical scale always includes zero. Small movements around a gain of about $16 billion occupy only a few pixels in its current 36-point height. Its fill and final point provide little visual emphasis. The intended result makes the comparison immediately visible and the chart easier to read without inventing or misrepresenting movement.

## 3. What are the main architectural choices?

1. **Move the explanation into Settings → Holdings once.** Keep ownership and source information there, while preserving the main ownership total, temporary ownership-change feedback, and milestone behavior.

2. **Put the most useful figures first.** Ownership total, today’s gain and chart, and “If Tesla had SpaceX’s market cap” precede records and stock details. With the comparison enabled and complete quote data, its entire heading and implied Tesla share price must appear without scrolling at 360 points wide and available heights of 600, 700, 800, and 900 points.

3. **Use space more compactly while preserving access.** Spacing and related metric rows may change. Long source explanations should not displace useful main-page content. Type and controls remain readable, secondary content stays scrollable, footer actions remain reachable, and the comparison’s preference and calculation stay intact.

4. **Scale the chart around observed values.** Include padding and a sensible minimum range rather than forcing a distant zero into every chart. Monetary range labels make the tighter scale explicit. Show a zero reference only when zero is visible, and preserve green/red coloring when values actually cross it.

5. **Add visual depth without altering data.** Use approximately 56–64 points of plotting height, a rounded stroke, a subtle vertical gradient beneath it, and a latest-point marker. Do not invent samples, alter timestamps, create history, or add movement to constant data.

6. **Preserve shared behavior and bounded work.** The chart also appears on exported share cards, which must remain legible and contained. Continue using the existing maximum of 400 samples, with processing proportional to sample count. Respect appearance and accessibility settings without changing system preferences.

7. **Judge rendered results.** Checks must exercise actual SwiftUI screens and captures containing the app’s visual assets. Source-level layout assertions alone do not establish that useful content is visible.

## 4. What will have to actually get built / changed?

The work changes the main ownership presentation, Holdings settings, card ordering or spacing, and the shared chart’s scaling and drawing. Before implementation, add focused regression tests for the chart’s scale failure and initial comparison visibility; no test merely duplicating the relocated wording is requested.

Verification must exercise populated screens at all four specified heights, including the first visible area, scrolling, and Settings/back navigation. Rendered or accessibility evidence must show the explanation in Holdings and absent from the main page. Inspect main-page and share-card captures for narrow positive ranges, negative and mixed values, flat data, and single points, plus Holdings. Empty data must also render safely. Check a full 400-sample series for finite coordinates within bounds, and compare the main page with the user’s before screenshots.

After changes settle, run the complete XCTest suite and Release build once. Retain the existing 391 tests unless a particular presentation assertion is deliberately replaced with stronger evidence. Independent reviewers inspect both source changes and resulting images. All tests, builds, and standalone Swift checks use the shared launcher with host permissions; it closes Muskometer first and prevents parallel test hosts. Finally, close the prior app, launch exactly one newly built local app, and verify its executable location from the host.

## 5. What does the spec explicitly defer, exclude, or acknowledge as gaps?

The Deferred section says “None”; there are no deferred items requiring works-without, reasoning, tracked-as, or customer-gap fields.

Excluded actions are GitHub pushes, pull requests, releases, replacement of the installed app, and external messages. The change adds no network operations or persisted data. Validation must preserve the user’s preferences, chart history, ownership counts, records, login configuration, and notification preferences; controlled examples use isolated settings.

The stated risks are exaggerated movement from tighter scaling, a taller chart displacing important content, misleading layout-only tests, changes spilling into exported cards, and captures misrepresenting appearance when app assets are missing. The spec leaves exact padding and minimum-range values unspecified.

Summary: This work rearranges Muskometer’s local window so ownership, today’s gain, and the Tesla-versus-SpaceX comparison are visible first, while moving the ownership explanation into Holdings settings. It also makes the gain chart taller and more expressive. The central choice is to scale the chart around the values actually observed, with visible monetary context, instead of always including zero. That makes small changes readable but requires care to avoid exaggerating them. The result must work in small populated windows and exported share cards, use only real chart data, and preserve the user’s saved information. Delivery is a single newly built local app, supported by tests and inspection of actual images; publishing and replacing the installed app are outside this request.
