# Task 6 Spec Review — MergerParityCardView on main popover

**Role:** spec-reviewer  
**Task:** 6 (MergerParityCardView + popover placement; design §5 UI, Acceptance 2, Compliance & messaging)  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md` §5, Error handling (hide rules), Compliance & messaging, Acceptance 2, Rollout  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 6  
**Date:** 2026-08-08  

## Scope checked

Design §5 / plan Task 6 require (for this task only):

| Requirement | Expected |
|-------------|----------|
| View | `MergerParityCardView` taking `MergerParityPresentation` (+ optional `animateValues`) |
| Placement | In `PopoverContentView.dataView`, **after** `ForEach(snapshot.holdings)` stock rows, before error caption |
| Hide rule | Show only when `viewModel.mergerParityPresentation` is non-nil (`if let`) |
| Title framing | Illustrative parity: “If TSLA matched SPCX’s market cap” (ASCII `SPCX's` allowed to match popover style) |
| Primary value | `CurrencyFormatter.formatPrice(impliedTSLAPrice)` — large rounded bold monospaced |
| Caption | SPCX + TSLA mcaps via `formatMarketValue` + current TSLA price (e.g. `SPCX $X · TSLA now $Y ($Z/sh)`) |
| Chrome | Same padding / cornerRadius / background opacity family as `StockRowView` |
| Always-on | No settings toggle / kill switch / reverse-direction control |
| pbxproj | Fixed IDs `A1…54` / `A2…54` for `MergerParityCardView.swift` |

Out of scope for Task 6 (owned by other tasks): calculator/presentation nil rules (Task 5), HOLDINGS.md (Task 7), reverse-direction, settings outstanding editor.

## Findings

No blocking or non-blocking spec gaps for Task 6.

### Checklist

| Requirement | Status | Evidence |
|-------------|--------|----------|
| `MergerParityCardView` exists | Pass | `Muskometer/Views/MergerParityCardView.swift` |
| Takes `MergerParityPresentation` | Pass | `let presentation: MergerParityPresentation` |
| Optional `animateValues` | Pass | `var animateValues = false`; numericText animation on implied price when true |
| Placement after stock rows | Pass | `dataView`: `ForEach(snapshot.holdings)` → then `if let presentation = viewModel.mergerParityPresentation { MergerParityCardView(...) }` → then optional error caption |
| Hide when presentation nil | Pass | Conditional `if let`; no card without presentation |
| Title framing (illustrative) | Pass | `"If TSLA matched SPCX's market cap"` — parity framing, no pending-deal / merger-announcement language (Compliance) |
| Primary uses `formatPrice` | Pass | `CurrencyFormatter.formatPrice(presentation.impliedTSLAPrice)` with `.system(.title2, design: .rounded, weight: .bold)` + `.monospacedDigit()` |
| Caption uses `formatMarketValue` + current price | Pass | `formatMarketValue` for SPCX/TSLA mcaps; `formatPrice` for current TSLA; string `SPCX … · TSLA now … (…/sh)` |
| Card chrome matches stock rows | Pass | `.padding(12)`; `RoundedRectangle(cornerRadius: 10, style: .continuous)` fill `controlBackgroundColor` opacity `0.55` — same as `StockRowView` |
| Always-on; no settings toggle | Pass | UI gates only on non-nil presentation; no merger/parity toggle in SettingsView or card; no reverse-direction control |
| pbxproj IDs `…54` | Pass | `A10000000000000000000054` (PBXBuildFile) + `A20000000000000000000054` (PBXFileReference); in Views group and Sources build phase |
| Wire passes `animateValues: true` | Pass | Matches plan snippet and stock-row pattern |

### Notes (non-blocking)

- Title uses ASCII apostrophe in `SPCX's`; plan Task 6 explicitly allows ASCII to match existing popover copy style.
- Caption does not add a separate “illustrative only” disclaimer line; design §5 + Compliance treat title framing + existing app disclaimer as sufficient for v1 (HOLDINGS note is Task 7).
- Show/hide for missing quotes or non-positive outstanding is owned by Task 5 `mergerParityPresentation`; Task 6 correctly binds only to the optional presentation (design Rollout: hide via missing quotes/bad inputs, not a toggle).

## Spec coverage (Task 6 slice)

| Design / plan item | Covered by Task 6? |
|--------------------|--------------------|
| §5 card after stock rows | Yes |
| §5 title + primary + secondary caption | Yes |
| §5 native card chrome | Yes |
| §5 no navigation / settings gear / reverse toggle | Yes |
| Compliance: illustrative parity copy | Yes |
| Acceptance 2 (card after stock rows when presentation available) | Yes (UI half; data half is Task 5) |
| Rollout always-on | Yes |

VERDICT: APPROVED

## Reviewed files

- `Muskometer/Views/MergerParityCardView.swift` — title, primary price, caption, chrome, optional animation
- `Muskometer/Views/PopoverContentView.swift` — `dataView` placement after stock rows; nil hide
- `Muskometer/Views/StockRowView.swift` — chrome / animateValues reference
- `Muskometer/Views/SettingsView.swift` — no merger-parity settings toggle
- `Muskometer.xcodeproj/project.pbxproj` — IDs `…54` fileRef + build file
- `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md` §5 UI, Compliance & messaging, Acceptance 2, Rollout
- `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 6 steps

VERDICT: APPROVED
