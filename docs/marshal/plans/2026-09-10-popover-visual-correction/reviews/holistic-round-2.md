## Round 2

The plan covers the visual correction as a coupled change: moving methodology into Holdings, placing complete parity ahead of secondary cards, and increasing chart depth without altering samples or timestamp spacing. The proposed domain rules address the observed positive-series flattening and retain honest flat, single, empty, negative and crossing cases. First-viewport assertions use the actual scroll viewport and complete title/price, while retained scrolling, footer and Settings/back checks protect the surrounding interaction. Real asset-backed captures, explicit appearance checks and the production ShareImageExporter.renderPNGData path cover the shared chart's integration beyond its pure layout tests.

The validation sequence is coherent with the actual app and launcher source. The compile-time isolated branch excludes the production delegate and service initialization; the existing wrapper applies its flag only to test commands, and the required bootstrap assertion precedes presentation runs. Isolated defaults and injected fixture services keep captures away from user history, login settings and network actions. The final suite and Release build remain owned by implementation after edits converge, followed by independent image/source acceptance and a separately built normal local preview. This static pre-implementation review found no coverage, dependency or integration gap; no tests, builds or apps were run.

Reviewed-files: docs/marshal/plans/2026-09-10-popover-visual-correction.md, docs/marshal/specs/2026-09-10-popover-visual-correction-design.md, Muskometer/Views/GainSparklineView.swift, Muskometer/Views/PopoverContentView.swift, Muskometer/Views/SettingsView.swift, Muskometer/Views/MergerParityCardView.swift, Muskometer/Views/ShareCardView.swift, MuskometerTests/InterfaceAndCalendarTests.swift, Muskometer/App/MuskometerApp.swift, Muskometer/App/AppDelegate.swift, Muskometer/Utilities/ShareImageExporter.swift, Muskometer/Services/IntradayGainSampleStore.swift, Muskometer/ViewModels/GainsViewModel.swift, Muskometer.xcodeproj/project.pbxproj, build/test-tools/xcodebuild, build/run-aggregate.py, scripts/verify.sh

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"3f8f04d1-7e7d-46da-8944-5af5f6bfe953-task-0","verdict":"approved","round":2,"findings":[]}
```

VERDICT: APPROVED

reviewed-content-sha256: 328e9ad85ce8acba06d583ff49f88031d0888c62aeb164c8a5a9ce8a59b0092d

plan-graph-sha256: f10c3899ca6b0b2dffde07f086ac7df02642f933cad6463065b270c11b6e2037
