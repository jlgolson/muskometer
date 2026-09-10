# Parallelism analysis

Dispatch-id: 5ee272ae-9b61-4b83-a804-f355199e13c6-task-0
Reviewer-role: parallelism-analyst
Review round: 1

## Parallelism analysis

The actual numbered task inventory is exactly **Task 1: Correct and visually verify the main popover and shared chart**. Its verification subtask, implementation checkboxes, three dispatch templates, and completion handoff do not introduce additional numbered tasks. The graph is V = {1}, E = {}, with one connected component of size 1 and ready set {1}. There are C(1, 2) = **0 unordered task pairs** and therefore **0 declared concurrent pairs**. No pair blocks apply. The supplied cost-benefit threshold is 0.25; a chain-length ratio requires two components and is not applicable here.

This is a coupled correction with shared presentation and validation resources. The main popover and share export both call GainSparklineView (PopoverContentView.swift:263 and ShareCardView.swift:87); chart height and domain labels directly affect the same first-viewport parity requirement. The plan assigns the chart, composition, settings relocation, export adaptation, and their assertions to one owner. Both regression classes and hosted capture helpers occupy InterfaceAndCalendarTests.swift; the existing hosted regression uses the main actor, NSWindow, and NotificationCenter.default (lines 800–879). Per-test UUID defaults isolate persisted fixtures but do not isolate these application/window resources. The bootstrap edit and ignored wrapper also govern the same compiled host used by all captures. The existing build/run-aggregate.py:39–63 holds one controller lock, checks host processes, quits the previous app, disables parallel test hosts, and waits for the launched command. Its global lifecycle constraint independently requires serialized executable validation.

No unnecessary inter-task serialization exists: there is only one task and no dependency edge to remove. Bootstrap → presentation red proof → implementation → green/captures → final verification are evidence dependencies within that task. Independent source/image review can follow the finished implementation without introducing parallel product edits or launches. Splitting this small correction would duplicate work in the shared view/test surfaces and compete for the shared launch resource. Preserve the single-task plan; there is no missed task-pair opportunity to report.

Reviewed-files: docs/marshal/plans/2026-09-10-popover-visual-correction.md, docs/marshal/specs/2026-09-10-popover-visual-correction-design.md, Muskometer/Views/GainSparklineView.swift, Muskometer/Views/PopoverContentView.swift, Muskometer/Views/ShareCardView.swift, MuskometerTests/InterfaceAndCalendarTests.swift, build/run-aggregate.py, build/test-tools/xcodebuild

## Findings

None.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"5ee272ae-9b61-4b83-a804-f355199e13c6-task-0","verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

reviewed-content-sha256: 8a5a88427beafd416fc1c38d40bef9f84efd12cf4167d92dac5820c13080fe2b

plan-graph-sha256: f10c3899ca6b0b2dffde07f086ac7df02642f933cad6463065b270c11b6e2037
