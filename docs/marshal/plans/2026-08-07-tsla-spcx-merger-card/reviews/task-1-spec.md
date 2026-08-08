# Task 1 Spec Review — Fix Loneliest typo

**Role:** spec-reviewer  
**Task:** 1 (Typo fix only — design §1)  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md` §1  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 1  
**Date:** 2026-08-07  
**Implementer claim:** Fixed Loneliest typo; test renamed; commit `2968bb5`

## Scope checked

Design §1 requires only:

| Location | Change |
|----------|--------|
| `NetWorthMilestoneTracker.belowTrillionMessage` | `"Lonliest"` → `"Loneliest"` |
| Matching unit test assertion | same string |

No behavior change beyond spelling. AC1: product + tests use exactly `One Trillion Is the Loneliest Number`. Plan also requires test rename, dual assert (literal + constant), and zero `Lonliest` under `Muskometer/` + `MuskometerTests/`.

## Findings

None.

## Compliance checklist

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Product string `One Trillion Is the Loneliest Number` | Pass | `NetWorthMilestoneTracker.belowTrillionMessage` = `"One Trillion Is the Loneliest Number"` |
| Test assertion matches corrected spelling | Pass | `XCTAssertEqual(message, "One Trillion Is the Loneliest Number")` |
| Test also equals constant | Pass | `XCTAssertEqual(message, NetWorthMilestoneTracker.belowTrillionMessage)` |
| Test renamed (`Lonliest` → `Loneliest` in name) | Pass | `testSadMessageUsesLoneliestNumberCopy` |
| Zero `Lonliest` in `Muskometer/` | Pass | grep: no matches |
| Zero `Lonliest` in `MuskometerTests/` | Pass | grep: no matches |
| No scope creep beyond spelling | Pass | Only the message constant and the Loneliest test/asserts changed for this task; tracker behavior otherwise untouched |

## VERDICT: APPROVED

## Reviewed files

- `Muskometer/Services/NetWorthMilestoneTracker.swift` — `belowTrillionMessage` correctly spelled
- `MuskometerTests/MuskometerTests.swift` — `testSadMessageUsesLoneliestNumberCopy` (rename + dual asserts)
- `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md` §1 / AC1
- `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 1 steps
