# Task 6 Code Quality Review — MergerParityCardView on main popover

**Role:** code-quality-reviewer  
**Task:** 6 (MergerParityCardView + PopoverContentView wiring + pbxproj)  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 6  
**Date:** 2026-08-08  

## Scope reviewed

Quality axes: SwiftUI consistency with `StockRowView` / existing cards, pure view (no calc / no VM / no I/O), placement & hide-when-nil, `animateValues` parity, pbxproj registration, no scope creep. Cold review of implementation files only.

## Findings

None blocking.

### Pure view

| Check | Status |
|-------|--------|
| Inputs are presentation-only | Pass — `let presentation: MergerParityPresentation`; optional `animateValues` |
| No calculator / outstanding / quote fetch | Pass — no `MergerMarketCapParity`, `IssuerSharesOutstanding`, network, or settings |
| No `GainsViewModel` / `@Bindable` / `@State` | Pass — formatting-only surface |
| Caption is display glue | Pass — string interpolation over precomputed caps + prices via `CurrencyFormatter` |
| Side effects | Pass — none; body is pure layout |

VM remains the sole owner of “when to show” (`mergerParityPresentation` from Task 5). The view never decides nil vs non-nil from raw quotes.

### SwiftUI consistency with StockRowView / card family

| Axis | StockRowView / family | MergerParityCardView | Assessment |
|------|----------------------|----------------------|------------|
| Outer stack | `VStack(alignment: .leading, spacing: 8)` | same | Match |
| Padding | `12` | `12` | Match |
| Corner radius | `10`, `.continuous` | `10`, `.continuous` | Match |
| Background fill | `Color(nsColor: .controlBackgroundColor).opacity(0.55)` | identical | Match |
| Full-width frame | DailyRecords / ownership use `maxWidth: .infinity` | `.frame(maxWidth: .infinity, alignment: .leading)` | Aligns with full-width cards (StockRow relies on parent stack) |
| Primary number | rounded + `monospacedDigit()` | `.title2` rounded bold + `monospacedDigit()` | Same font family; larger hero is appropriate |
| Formatters | `CurrencyFormatter.formatPrice` / `formatMarketValue` | same for implied price, caps, current price | Match |
| `animateValues` | `priceText` + `.numericText()` + `.smooth(0.25)` on source value | same pattern on `impliedTSLAPrice` | Match |
| Default `animateValues` | `false` | `false` | Match |
| Popover wiring | `animateValues: true` on rows | `animateValues: true` on card | Match |

Title uses `.caption` + `.secondary` (same secondary-label weight as ownership / “Combined today”). Caption uses `.caption2` + `.secondary` (same tier as market-status / footer microcopy). No gain/loss color semantics on this illustrative metric — correct; parity is not a signed P&L.

### Copy & chrome vs plan / design §5

| Requirement | Implementation | Assessment |
|-------------|----------------|------------|
| Title framing (illustrative, not deal language) | `"If TSLA matched SPCX's market cap"` | Pass — matches design intent; plan allows ASCII apostrophe |
| Primary = `formatPrice(impliedTSLAPrice)` large rounded bold | `.title2` bold rounded monospaced | Pass |
| Caption = SPCX/TSLA market caps + current TSLA $/sh | `"SPCX \(spcx) · TSLA now \(tsla) (\(price)/sh)"` | Pass — middle-dot separator, compact formatters |
| Card chrome match StockRow | padding/radius/opacity identical | Pass |
| Always-on when presentation non-nil; no settings toggle | only `if let presentation = viewModel.mergerParityPresentation` | Pass |

DEBUG `#if DEBUG` preview with sample presentation is fine and does not ship production surface.

### PopoverContentView placement

```swift
ForEach(snapshot.holdings) { holding in
    StockRowView(...)
}

if let presentation = viewModel.mergerParityPresentation {
    MergerParityCardView(presentation: presentation, animateValues: true)
}

if let error = viewModel.errorMessage { ... }
```

| Check | Status |
|-------|--------|
| After stock rows | Pass |
| Before soft error caption | Pass |
| Hide when nil | Pass — `if let` only |
| No extra flags / settings | Pass |
| Imports / other panels | Pass — only `dataView` touched; loading/error/ownership/combined unchanged |

### pbxproj

| Check | Status |
|-------|--------|
| Build file ID `A10000000000000000000054` | Pass — plan ID table exact |
| File ref ID `A20000000000000000000054` | Pass |
| Views group child | Pass — alongside `StockRowView` / `GainSparklineView` |
| `Sources` build phase entry | Pass |
| Path `Muskometer/Views/MergerParityCardView.swift` | Pass |

### Scope creep

| Check | Status |
|-------|--------|
| Files in task scope | Pass — view + popover + pbxproj only (for this UI task) |
| No settings UI / AppSettings keys | Pass |
| No reimplementation of calculator or sync | Pass |
| No ShareCard / menu bar / sparkline changes | Pass |
| No drive-by refactors in PopoverContentView | Pass — single conditional insert in `dataView` |

### Non-blocking notes

1. **Apostrophe:** UI string uses ASCII `SPCX's`; doc comment uses typographic `SPCX’s`. Plan explicitly allows either; no consistency issue with product UI (profiles use ASCII possessives like `Elon's`).
2. **Caption animation:** only the primary price uses `numericText`; the multi-field caption string updates without per-token animation. Acceptable — StockRow animates discrete scalar fields, not composite captions.
3. **No dedicated view unit tests:** consistent with other pure SwiftUI cards (`StockRowView`, `DailyRecordsCardView`); presentation nil/non-nil covered at VM layer in Task 5.

## Quality checklist

| Axis | Result |
|------|--------|
| Pure view | Presentation + formatters only; no calc/I/O/settings |
| StockRow chrome parity | padding 12, radius 10 continuous, controlBackground 0.55 |
| Typography / formatters | Rounded monospaced price; caption2 secondary; CurrencyFormatter |
| animateValues | Same helper pattern; popover enables true |
| Placement | After holdings ForEach, before error; hide when nil |
| pbxproj | IDs `…54`, Views group + Sources |
| Scope | No toggle, no unrelated refactors |

VERDICT: APPROVED

## Reviewed files

- `Muskometer/Views/MergerParityCardView.swift` — pure card; StockRow chrome; `animateValues`; caption; DEBUG preview
- `Muskometer/Views/PopoverContentView.swift` — `dataView` placement after stock rows; `if let` hide-when-nil
- `Muskometer/Views/StockRowView.swift` — comparison baseline for padding/radius/fill/`animateValues`
- `Muskometer.xcodeproj/project.pbxproj` — IDs `A100…54` / `A200…54`, Views group + Sources


VERDICT: APPROVED
