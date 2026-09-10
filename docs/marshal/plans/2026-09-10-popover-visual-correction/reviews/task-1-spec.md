# Task 1 spec compliance review

Dispatch: `e801b958-23f4-4797-9681-fbe72ad58bd0-task-1`

Reviewed source base: `862ef0005069bd01a85aa8daafaed151d6ba3e06`  
Reviewed source head: `bfda1d2e9b31c473c205523301534ee375e9d0cb`

I read the complete approved spec, task description and implementation summary, then the actual base-to-head source diff and complete changed source/test files. I independently inspected the supplied before images and the accepted screenshots. I did not consult other reviewers or prior verdicts, rerun tests, build, launch an app, access user preferences or make git mutations.

## Independent hypotheses

Before reading the implementation, I identified these likely failure modes: the comparison could merely move earlier in source order while remaining clipped; the ownership explanation could be duplicated or removed along with functional ownership feedback; tighter chart scaling could invent movement, misrepresent timestamps or lose sign information; the taller shared chart could clip exports or lose label contrast; and claimed verification could use a different source tree, missing assets or a production test startup that touches user state.

## Compliance assessment

Missing requirements: none within Task 1. Extra work: none. Misinterpreted requirements: none.

The approved spec, `docs/marshal/specs/2026-09-10-popover-visual-correction-design.md`, **Required presentation 1–2**, is implemented at `Muskometer/Views/PopoverContentView.swift:117`, `:174` and `:217`, and `Muskometer/Views/SettingsView.swift:300`. Main content orders ownership, combined gain/chart, parity, records, then stocks. The permanent methodology is removed from ownership and rendered once beside Holdings source information; totals, transient ownership feedback and the milestone overlay remain. Parity retains its preference and data-availability conditions, title, implied price and short market-cap caption. Its long outstanding caption is omitted only at the main invocation; Holdings retains the provenance.

The actual 600/700/800/900-point main captures all show the complete comparison heading and $518.51 price before scrolling. In the smallest viewport, the clip rectangle is x=16, y=74, width=328, height=424; the title occupies approximately y=388–400 and the price y=411–429. Both are comfortably inside. The other clip heights are 524, 624 and 724 with the same top position. The 600-point detail screenshot shows readable records and both stock cards after scrolling, with footer controls still visible. Holdings and Settings captures confirm the relocated copy, source details, share fields and Back control. The existing named scrolling/footer/Settings/back test is retained and strengthened with real image text and clip geometry at `MuskometerTests/InterfaceAndCalendarTests.swift:925` and `:1188`; it does not infer visibility from source order or document height.

**Required presentation 3** and the task's domain formula are satisfied by `Muskometer/Views/GainSparklineView.swift:194`: actual extrema, a centered 1% minimum span with a $1 floor, then 8% padding. The plotting inset contains the rounded 2-point line and 6-point endpoint. The 60-point plot has monetary range labels and combined accessibility range context. Positive and negative fills use the visible domain edge, genuine crossing segments use visible zero, and fills precede reference/stroke/endpoint drawing. Zero is drawn only when the domain contains it. Timestamp-proportional positions and the existing crossing interpolation remain intact.

I inspected the observed positive, negative, mixed, flat positive/negative/zero, single, empty and 400-point chart images. They show bounded endpoints, correct sign colors, useful observed-range movement, horizontal constant data, one centered dot for one sample and no invented chart for empty input. The observed fixture values and timestamps match the supplied nine-point JSON exactly. The initial user screenshot and the accepted populated main view clearly differ in composition and chart legibility; their quote totals differ slightly, so I did not treat those totals as a same-data performance comparison. The preserved red regression supplies the controlled same-data proof of the original domain failure.

**Required presentation 4** is satisfied by the shared production renderer at `Muskometer/Views/ShareCardView.swift:86` and `Muskometer/Views/GainSparklineView.swift:4`. I inspected the observed and all eight edge-fixture share exports: labels, chart, parity, holdings and footer fit within the export. The test uses the production `ShareImageExporter.renderPNGData` path and asserts 720-pixel width. Explicit dark chart appearance keeps labels readable on the export background. Light main appearance is legible. Increased contrast and reduced transparency are passed into the same `GainSparklineContent` used by the live environment wrapper; its screenshot has stronger labels and no transparent fill. The manifest correctly reports native high-contrast normalization and makes no claim of native propagation.

The layout/drawing is pure and linear in sample count. `IntradayGainSampleStore.maxSampleCount` remains 400; services and persistence are unchanged. On a subsequent sample, the renderer derives a new domain from the supplied array without writing or generating samples. A redraw or replay of the same array produces the same geometry. Failed refreshes retain the existing supplied display state; concurrent updates and session rollover remain governed by the unchanged view model/store. This change introduces no retry, TTL or freshness state, and no new partial-write path. Settings navigation and existing copy feedback behavior are preserved by the diff.

## Verification evidence

I independently rehashed all 102 files listed in `raw/final-source-manifest.json`: every hash matches this source checkout. The source digest is `19f27e41cf450d64a0e6dfaa354413eee825b84563ff84a65fdef4ef8fb1f3db`. The approved spec hash also matches. All 34 named accepted PNGs match the corresponding raw final verification attachments byte-for-byte; viewport geometry matches the final attachments as well.

The preserved bootstrap result contains exactly one passing `PopoverLayoutRegressionTests/testUsesIsolatedApplicationEntryPoint()` execution. The isolated branch at `Muskometer/App/MuskometerApp.swift:3` has only an empty Settings scene and test marker, with no delegate adaptor or production services. I compared the normal declaration to the base and confirmed it is unchanged. The wrapper contents and SHA-256 match the manifest; its test-only flag preserves nonparallel behavior and is not applied to Release builds. The compiled-host attachment identifies the real bundle and Assets.car. Fixtures use unique test defaults, mock login/quote/SEC/outstanding dependencies and test notification sinks.

The raw red result records both intended presentation failures: distant-zero minimum below zero with only 8.677 points of movement, and absent complete parity title/price in the initial viewport. The final focused result contains 11 passing tests. The final raw XCTest tree contains 401 passed, zero failed and zero skipped cases. I compared its identifier set with the 391-case baseline tree: all baseline identifiers remain, with nine presentation additions and one conditional bootstrap addition.

I read the complete final `raw/verify.log`: typecheck, XCTest, Release build, entitlements and marketing checks pass; the live Yahoo step is explicitly skipped as instructed. Preserved launcher events show zero existing Muskometer processes before runs and disabled parallel hosts. The saved normal Release executable and asset hashes both match `normal-release.json`. The final local preview handoff is assigned to the controller after review, so this Task 1 approval does not claim that handoff has occurred.

## Findings

None.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"e801b958-23f4-4797-9681-fbe72ad58bd0-task-1","verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- `docs/marshal/specs/2026-09-10-popover-visual-correction-design.md`
- `docs/marshal/plans/2026-09-10-popover-visual-correction/reviews/.tmp-task-1-description.md`
- `docs/marshal/plans/2026-09-10-popover-visual-correction/reviews/.tmp-task-1-summary.md`
- `docs/marshal/plans/2026-09-10-popover-visual-correction/reviews/.tmp-task-1-round-1-quality-diff` and the actual base-to-head git diff
- `Muskometer/App/MuskometerApp.swift`, `Muskometer/App/AppDelegate.swift`
- `Muskometer/Views/GainSparklineView.swift`, `PopoverContentView.swift`, `SettingsView.swift`, `MergerParityCardView.swift`, `ShareCardView.swift`
- `Muskometer/Services/IntradayGainSampleStore.swift`
- `MuskometerTests/InterfaceAndCalendarTests.swift`
- `CHANGELOG.md`
- `docs/marshal/plans/2026-09-10-popover-visual-correction/reviews/task-1-validation/`: README, validation, source manifest, test identifiers, viewport geometry and normal Release manifest
- Stable evidence root `/Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/popover-visual-correction/`: raw bootstrap/red/focused/final/baseline results, full verification log, source manifest, launch events, finalization script, compiled-asset attachment, viewport geometry and normal Release artifacts
- `/Users/jlgolson/grok/muskometer/build/popover-visual-validation/`: before-popover.png, before-ownership.png and observed-chart-samples.json
- Accepted images: main top at 600/700/800/900, main-600-detail, main-900-light, main-900-requested-high-contrast, settings-600, holdings-600, chart-increased-contrast-reduced-transparency, and chart/share observed, negative, mixed, flat-positive, flat-negative, flat-zero, single, empty and 400 fixtures

reviewed-content-sha256: f092cc924bfcc7671a894fd648d195892250b0574364af8f4bf35f22b0554eb9

plan-graph-sha256: f10c3899ca6b0b2dffde07f086ac7df02642f933cad6463065b270c11b6e2037
