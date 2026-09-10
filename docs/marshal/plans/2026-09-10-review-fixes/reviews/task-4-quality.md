# Task 4 code-quality review

Reviewed implementation `38ae64739615d72d23fa8ee77ddd6aee0c5a54c5..e89dcce91420ec5fbcb7c7414a27339eab418999` in the assigned Task 4 worktree. The source/test working tree matches the implementation head. This is a Swift code change; file organization, tests, clarity, and surrounding patterns all apply.

## Independent failure hypotheses

Before reading the diff, I enumerated these failure cases: reopening/restarting might register a pending service twice; failed login changes might lose the preference or trigger another service call through the property observer; approval might be followed by unregister; constraining the popover might clip content or footer actions; Settings navigation might reintroduce sizing feedback or alter existing actions; and changing December 31 might produce the wrong close or next opening. I checked these against the implementation, surrounding callers, regression tests, and saved evidence.

## Strengths

- The login adapter exposes all relevant service states while preserving Boolean-only protocol conformers through a default implementation. Status mapping agrees with the installed SDK header. Reconciliation has explicit matched/pending/unavailable paths, and failure adoption retains an existing pending registration without recursive service calls.
- The layout change stays within the existing view responsibilities. The main panel retains its 360-point width and places expanding content inside one vertical scrolling region. Settings keeps its existing initializer usage through defaulted arguments, its routes and actions, and a fixed outer layout with scrolling tabs. Removing the measurement feedback from these views makes their bounds easier to reason about.
- Tests assert persisted preference, visible state, errors, and service state across reopening, restart, approval, disable, and failure. Their call-count assertions establish the required absence of duplicate registration/unregistration rather than substituting for behavioral assertions. Existing Boolean-only success, failure, mismatch, recovery, and reset tests remain present.
- The layout regression instantiates the actual populated SwiftUI view, checks hosting dimensions at 600/700/800/900 points, scrolls to the final document edge, checks the footer control frames, and sends public mouse events to Back. The calendar regression checks regular trading, the 16:00 close, and January 3, 2028 at 09:30 Eastern as the next opening. Other holiday and early-close assertions remain intact.

## Next-request and error tracing

Pending enable followed by repeated reconciliation or restart keeps desired=true without registering again. A later enabled status clears the pending message without unregistering. Successful disable reaches notRegistered, so subsequent disable/reconciliation is a no-op. A failed pending disable adopts the still-registered status and persists true; the next passive reconciliation displays pending approval, and another explicit disable can retry. A registration error adopts the service status and exposes the error; a later explicit enable can retry. An unavailable service causes no service mutation and is re-read on the next reconciliation. UI and application callers use synchronous reconciliation; this change adds no asynchronous suspension inside that sequence, and the existing observer guard prevents adoption from recursively applying the preference.

Returning from Settings and reopening the popover preserve the existing route and view-state behavior; quote/loading/error content remains inside the same scrolling region, with footer actions outside it. At the December 31 close, the unchanged calendar loop skips the weekend and returns the January 3 regular opening. There is no new TTL or freshness cache in this task.

## Verification and limits

I inspected the recorded red failures, final targeted summary/log, full-suite log, rendered-height log, and the 600-point main/Settings bitmap attachments. The final saved runs report 44 targeted tests and 255 full-suite tests, both with zero failures on macOS 26.4.1 arm64. The red evidence records eight failing regressions before the fixes, including the 1,002-point host height and missing scrolling container. A fresh read-only `git diff --check` for the reviewed commit range passed, and the source/test tree has no differences from the specified implementation head.

No app, test host, or probe was launched during this review. The saved geometric/navigation assertions support the height and reachability claims. Bitmap captures visibly omit some composited glass and native control labels, so they are supplemental geometry evidence rather than a complete live-screen visual or accessibility audit. The frame-based control lookup is specific to the tested SwiftUI/macOS layout. Real login registration and external approval are represented by mocks in the regression evidence.

## Issues

Critical: none. Important: none. Minor: none.

## Assessment

The implementation is scoped, readable, and consistent with the existing interfaces. The regression coverage and recorded actual-view checks are appropriate to the changes. No actionable code-quality regression was found.

## Reviewed files

- Muskometer/Utilities/LaunchAtLoginManager.swift
- Muskometer/Utilities/AppSettings.swift (login property, initialization, reconciliation, and reset callers)
- Muskometer/Views/PopoverContentView.swift
- Muskometer/Views/SettingsView.swift
- Muskometer/Views/SettingsContentHeightKey.swift (former measurement definitions)
- Muskometer/App/MuskometerApp.swift (view and login-service callers)
- Muskometer/Services/MarketHoursService.swift
- MuskometerTests/InterfaceAndCalendarTests.swift
- docs/marshal/specs/2026-09-10-review-fixes-design.md (Task 4 scope)
- docs/marshal/plans/2026-09-10-review-fixes/reviews/.tmp-task-4-description.md
- docs/marshal/plans/2026-09-10-review-fixes/reviews/.tmp-task-4-summary.md
- docs/marshal/plans/2026-09-10-review-fixes/reviews/.tmp-task-4-round-1-quality-diff
- build/task-4-evidence/red-summary.json
- build/task-4-evidence/red-layout.json
- build/task-4-evidence/targeted-final-summary.json
- build/task-4-evidence/targeted-final.log
- build/task-4-evidence/full-final.log
- build/task-4-evidence/rendered-heights.txt
- build/task-4-evidence/test-pause-status.json
- build/task-4-evidence/targeted-final-snapshots/main-600-scrolled.png
- build/task-4-evidence/targeted-final-snapshots/settings-600.png
- /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/ServiceManagement.framework/Headers/SMAppService.h (status and registration documentation)

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"6ab1b0f6-c973-477f-9572-3da28bf7609f-task-4","verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

reviewed-content-sha256: 6a7d92eaf4dc538eae57c8995ce2e1f39151a680b604b81aa7ffb592ea952d2e

plan-graph-sha256: c5582aec64ba1273dc1ddb9487db6d546ccf6879bd93cdd16eda9a28cf89a760
