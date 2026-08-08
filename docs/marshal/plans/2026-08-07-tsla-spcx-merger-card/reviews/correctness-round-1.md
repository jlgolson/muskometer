# Plan correctness review — round 1

**Role:** plan-correctness  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md`  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md`  
**Date:** 2026-08-07

## Scope checked

File paths, type consistency, placeholders, TDD/test structure, task ordering, spec coverage, test/verify commands, imports/module placement, dependency graph, deferral discipline, verification task (WHAT/HOW/WHO), pbxproj IDs, and alignment with current sources named in the marshal brief.

## Systematic checklist

### File paths

| Plan path | Status |
|-----------|--------|
| `Muskometer/Services/NetWorthMilestoneTracker.swift` | Exists; `belowTrillionMessage` is misspelled as planned |
| `Muskometer/Utilities/AppSettings.swift` | Exists; shareCount / resetToDefaults patterns match Task 2 approach |
| `Muskometer/Models/TrackedPersonProfile.swift` | Exists; only two `TrackedHoldingSpec(...)` sites (musk TSLA/SPCX) |
| `Muskometer/ViewModels/GainsViewModel.swift` | Exists; `syncHoldingsFromSEC` + `snapshot` match Task 5 hooks |
| `Muskometer/Views/PopoverContentView.swift` | Exists; `dataView` ends ForEach stock rows then error caption — Task 6 insert site correct |
| `Muskometer/Services/SECHoldingsSyncService.swift` | User-Agent matches plan string pattern |
| `Muskometer/Views/StockRowView.swift` | Card chrome reference exists |
| `Muskometer.xcodeproj/project.pbxproj` | Highest product source IDs `…46` (ShareCountTextInput); plan `…50`–`…54` free and unique |
| `MuskometerTests/MuskometerTests.swift` | `NetWorthMilestoneTrackerTests` + `testSadMessageUsesLonliestNumberCopy` present |
| `docs/HOLDINGS.md` | Exists; Task 7 section target correct |
| New files under Utilities/Services/Views | Consistent with existing layout |

### Type consistency

- `MergerParityPresentation` fields match spec §4 (`impliedTSLAPrice`, mcaps, `currentTSLAPrice`).
- Calculator signature uses `Double` prices + `Int64` outstanding; formula matches Goals (`spcxPrice × spcxOutstanding / tslaOutstanding`).
- Happy-path unit case (100/50, 2/4 → implied 100) is arithmetically correct.
- `TrackedHoldingSpec.issuerCIKPadded: String?` is a clean orthogonal field; does not overload `defaultShareCount` (ownership).
- Outstanding UserDefaults keys `sharesOutstanding_SYMBOL` are distinct from `shareCount_SYMBOL`.
- `HoldingGain.quote.currentPrice` is the correct quote input for presentation wiring.
- Bundled defaults match spec exactly: TSLA `3_949_547_394`, SPCX `13_181_779_945` (A+B).

### Placeholders

- No TBD/TODO/FIXME in task steps (self-review claim verified).
- Calculator body is intentionally sketched with comments; rules are complete enough for implementers.
- Resolver rules enumerated from spec §2 (concept priority, multi-member sum, WASO reject, form preference, latest end/filed).

### Task ordering & dependency graph

```
1 → 2 → (3 ∥ 4) → 5 → 6 → 7
```

- T1 isolated typo (no merger deps) — correct first ship slice.
- T2 foundations (defaults, CIKs, AppSettings) before pure calc/resolver consumers — correct.
- T3 ∥ T4 both pure and only need T2 transitive for product integration; both feed T5 — correct.
- T5 wires sync + VM after pure pieces exist — correct.
- T6 UI after presentation API — correct.
- T7 docs + full verify last — correct.
- Tasks 1–7 sequential IDs; Depends lines consistent with self-review.

### Spec coverage map

| Spec | Plan |
|------|------|
| §1 Typo | T1 |
| §2 Defaults, CIKs, keys, reset, fetch orthogonality, WASO reject, multi-member | T2, T4, T5 |
| §3 Calculator | T3 |
| §4 VM presentation | T5 |
| §5 UI after stock rows | T6 |
| §6 HOLDINGS | T7 |
| Error table / Form 4 independence | T5 (never-throw fetch; silent outstanding; Form 4 message semantics preserved) |
| Acceptance 1–7 | T1–T7 + T7 WHAT |
| Non-goals (reverse, HTML 10-Q, settings edit, Yahoo mcap) | Deferred None; not in task bodies |

### Tests

- T1: rename + string + constant equality; class filter `MuskometerTests/NetWorthMilestoneTrackerTests` is real (`@MainActor final class NetWorthMilestoneTrackerTests`).
- T2: defaults / key independence / reset reseed.
- T3: happy path, non-positive, non-finite, order-of-magnitude smoke.
- T4: TSLA-style accept, dual-member sum, WASO-only nil, form preference (optional depth documented).
- T5: optional presentation smoke; pure layers already unit-tested; no mandatory live SEC CI test (matches spec).
- T7: full suite via verify.

Strict red-green TDD not mandated by spec; plan’s implement-then-unit-test structure is adequate.

### Verification (WHAT / HOW / WHO)

- **WHAT:** Acceptance criteria 1–7 called out explicitly.
- **HOW:** Real in-plan commands:

  ```bash
  export MUSKOMETER_SKIP_LIVE_YAHOO=1
  ./scripts/verify.sh
  ```

  with `swiftc -typecheck` + `xcodebuild test` fallback. `scripts/verify.sh` and `MUSKOMETER_SKIP_LIVE_YAHOO` exist in-repo and match CI docs.
- **WHO:** Task 7 implementer runs verification in-plan.

### Imports / module / pbxproj

- New types stay in app module; tests use `@testable import Muskometer` — no new targets.
- pbxproj: each new file gets PBXBuildFile + PBXFileReference + group child + `A60000000000000000000002 /* Sources */` entry — stated in plan header.
- IDs `50`–`54` after current max `46`; no collisions.

### Source alignment (spot checks)

- `syncHoldingsFromSEC` is the right hook for orthogonal companyfacts best-effort; Form 4 `applyHoldingsSync` remains ownership-only.
- User-Agent string matches `SECHoldingsSyncService` (`Muskometer/\(AppVersion.short) (info@muskometer.org; https://muskometer.org)`).
- `resetToDefaults()` today reseeds ownership only — Task 2 correctly extends reseeding for outstanding without folding into `applyHoldingsSync`.
- Popover placement after stock rows, before error caption — matches `dataView` structure.
- Typo product + test name/assertion match current misspelling.

### Deferral discipline

- Plan `## Deferred`: None.
- Reverse parity, HTML cover parse, manual outstanding UI, Yahoo mcap remain non-goals — not smuggled into tasks.

## Non-blocking notes (do not block execute)

- T3/T4 listed Depends on 2 though pure types do not need AppSettings; ordering is conservative and fine.
- Nested Observation for outstanding-only updates without a snapshot refresh is an edge case; start/loop paths already refresh after sync cadence.
- Resolver sketch omits explicit `import Foundation`; implementer-standard.

## Findings

None.

## Findings (machine-readable)

```json
{
  "schema_version": 1,
  "round": 1,
  "role": "plan-correctness",
  "plan_slug": "2026-08-07-tsla-spcx-merger-card",
  "verdict": "APPROVED",
  "findings": []
}
```

VERDICT: APPROVED
