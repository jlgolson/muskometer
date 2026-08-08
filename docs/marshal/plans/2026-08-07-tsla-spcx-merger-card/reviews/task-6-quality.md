# Task 6 Code Quality Review — MergerParityCardView on main popover

**Role:** code-quality-reviewer  
**Task:** 6 (MergerParityCardView SwiftUI + PopoverContentView wiring)  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 6  
**Date:** 2026-08-08  

## Scope reviewed

Quality axes: SwiftUI consistency with existing cards (`StockRowView`, `DailyRecordsCardView`, ownership/combined cards), formatter usage, animation pattern, pbxproj, scope hygiene (no calculator/sync reimplementation, no docs).

## Findings

None blocking.

### SwiftUI structure & chrome

| Check | Status |
|-------|--------|
| Card layout | Pass — `VStack(alignment: .leading, spacing: 8)` mirrors stock-row vertical rhythm |
| Padding | Pass — `12`, same as `StockRowView` / `DailyRecordsCardView` |
| Corner radius | Pass — `10` continuous, matches stock/daily records (ownership/combined use `12` as primary hero cards) |
| Background | Pass — `Color(nsColor: .controlBackgroundColor).opacity(0.55)` identical to stock rows |
| Full-width frame | Pass — `.frame(maxWidth: .infinity, alignment: .leading)` matches `DailyRecordsCardView` so the card spans the popover content width after full-width stock rows |
| Hierarchy | Pass — caption title (secondary) → large primary value → caption2 secondary context |

Visual language sits correctly in the “secondary card” family (stock rows / daily records), not the accent ownership/combined heroes.

### Typography & formatters

| Item | Assessment |
|------|------------|
| Title | `.caption` + `.secondary` — same pattern as ownership “Elon’s Ownership” / “Combined today” labels |
| Primary price | `.system(.title2, design: .rounded, weight: .bold)` + `.monospacedDigit()` — large, monospaced, plan-aligned |
| Caption | `.caption2` + `.secondary` — consistent with market-status / footer secondary density |
| Formatters | `formatPrice` for $/sh; `formatMarketValue` for mcaps — correct compact vs price split |
| Caption string | `"SPCX $X · TSLA now $Y ($Z/sh)"` is scannable; middle-dot separator matches app density without wrapping sprawl |

No ad-hoc `NumberFormatter` or string interpolation of raw doubles.

### Animation consistency

| Check | Status |
|-------|--------|
| Optional `animateValues` default `false` | Pass — same default as `StockRowView` / `DailyRecordsCardView` |
| Gated `@ViewBuilder` helper | Pass — `priceText(_:)` mirrors stock-row `priceText` / `gainText` pattern |
| Transition | Pass — `.contentTransition(.numericText())` |
| Timing | Pass — `.animation(.smooth(duration: 0.25), value: presentation.impliedTSLAPrice)` |
| Popover call site | Pass — `animateValues: true` with live rows |

Only the primary implied price animates; caption (derived mcaps/current price) is static text rebuild — appropriate for secondary density.

### Popover integration

| Check | Status |
|-------|--------|
| Placement after `ForEach` stock rows | Pass |
| Before residual error caption | Pass |
| Conditional `if let` only | Pass — no empty placeholder / shimmer when nil |
| Spacing in parent `VStack` | Pass — inherits `dataView` spacing `12` like sibling cards |
| No extra state on popover | Pass — presentation is a VM computed property; view is pure inputs |
| Settings / reverse / navigation | Absent — good |

### Preview & API surface

| Item | Assessment |
|------|------------|
| DEBUG preview | Pass — `#if DEBUG` `PreviewProvider` with realistic orders of magnitude; width `328` matches daily-records previews |
| API | Minimal: `presentation` + `animateValues` — no ViewModel dependency in the card itself |
| Doc comment | Brief intent string; points at main-popover role |

### pbxproj

| Check | Status |
|-------|--------|
| Build file ID `A10000000000000000000054` | Pass — plan table exact |
| File ref ID `A20000000000000000000054` | Pass |
| Views group child | Pass |
| Sources entry | Pass |
| No extra accidental IDs | Pass |

### Drive-by / scope

| Check | Status |
|-------|--------|
| No calculator / resolver / sync changes | Pass — view-only + popover wire |
| No `HOLDINGS.md` (Task 7) | Pass |
| No settings UI for outstanding | Pass |
| Reuses Task 5 `mergerParityPresentation` | Pass — no duplicate presentation math in the view |

## Quality checklist

| Axis | Result |
|------|--------|
| SwiftUI consistency | Matches stock-row/daily-records chrome, type scale, monospaced digits, secondary captions |
| Animation | Same numericText + smooth 0.25s optional pattern as other cards |
| Formatters | Correct `formatPrice` / `formatMarketValue` split |
| Integration | After stock rows, nil-hide, no toggle/state bloat |
| Scope | View + wire + pbxproj only; IDs correct |

## Non-blocking notes

- `StockRowView` omits `.frame(maxWidth: .infinity)` (content-driven width inside the same parent); `MergerParityCardView` includes it like `DailyRecordsCardView`. Both read as full-width in the popover; no visual inconsistency to fix.
- Caption rebuilds on every body pass from presentation fields — fine for a small struct; no need for memoization.

## VERDICT: APPROVED

## Reviewed files

- `Muskometer/Views/MergerParityCardView.swift` — card layout, formatters, animation helper, preview
- `Muskometer/Views/PopoverContentView.swift` — `dataView` placement and nil gate
- `Muskometer/Views/StockRowView.swift` — chrome / animation reference
- `Muskometer/Views/DailyRecordsCardView.swift` — full-width secondary-card reference
- `Muskometer.xcodeproj/project.pbxproj` — IDs `…54`, Views group + Sources
