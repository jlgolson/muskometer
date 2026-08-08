# Task 6 Spec Review — MergerParityCardView on main popover

**Role:** spec-reviewer  
**Task:** 6 (MergerParityCardView + popover placement; design §5 UI, Acceptance 2, Compliance & messaging)  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md` §5, Error handling (hide rules), Compliance & messaging, Acceptance 2  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 6  
**Date:** 2026-08-08  

## Scope checked

Design §5 / plan Task 6 require (for this task only):

| Requirement | Expected |
|-------------|----------|
| View | `MergerParityCardView` taking `MergerParityPresentation` (+ optional `animateValues`) |
| Placement | Main popover `dataView`, **after** `ForEach(snapshot.holdings)` stock rows, before optional error caption |
| Hide when nil | `if let presentation = viewModel.mergerParityPresentation { … }` — no settings toggle |
| Always-on when non-nil | Show for defaults-only outstanding when presentation computes (Task 5 wiring) |
| Title copy | “If TSLA matched SPCX’s market cap” (illustrative parity framing; ASCII apostrophe OK per plan) |
| Primary | Implied TSLA via `CurrencyFormatter.formatPrice`, large rounded bold monospaced |
| Caption | SPCX + TSLA market caps via `formatMarketValue` and/or current TSLA price for contrast |
| Chrome | Same card family as `StockRowView` (padding / corner radius / controlBackground opacity) |
| Non-goals | No reverse-direction toggle, no settings gear, no navigation |
| pbxproj | IDs `A1…54` / `A2…54` |
| Docs | `HOLDINGS.md` deferred to Task 7 |

## Findings

None.

## Compliance checklist

| Requirement | Status | Evidence |
|-------------|--------|----------|
| `MergerParityCardView` exists | Pass | `Muskometer/Views/MergerParityCardView.swift` |
| Takes `MergerParityPresentation` | Pass | `let presentation: MergerParityPresentation` |
| Optional `animateValues` | Pass | `var animateValues = false`; popover passes `true` |
| Placement after stock rows | Pass | In `dataView`: `ForEach(snapshot.holdings)` → then `if let presentation` → then error caption |
| Before error caption | Pass | Error `Text` is the final conditional after the parity card |
| Hide when presentation nil | Pass | `if let presentation = viewModel.mergerParityPresentation` only |
| No settings toggle | Pass | No `AppSettings` / toggle / gear for card visibility |
| Title framing (illustrative parity) | Pass | `"If TSLA matched SPCX's market cap"` — matches §5 / Compliance (no pending-deal language) |
| Primary implied price | Pass | `CurrencyFormatter.formatPrice(presentation.impliedTSLAPrice)` with `.title2` rounded bold + `.monospacedDigit()` |
| Caption mcaps + current price | Pass | `"SPCX \(spcx) · TSLA now \(tsla) (\(price)/sh)"` via `formatMarketValue` ×2 + `formatPrice(currentTSLAPrice)` |
| Uses presentation fields only | Pass | `impliedTSLAPrice`, `spcxMarketCap`, `tslaMarketCap`, `currentTSLAPrice` |
| Stock-row chrome family | Pass | `.padding(12)`; `RoundedRectangle(cornerRadius: 10, style: .continuous)` + `controlBackgroundColor` opacity `0.55` (same as `StockRowView`) |
| Animation pattern when enabled | Pass | `.contentTransition(.numericText())` + `.animation(.smooth(duration: 0.25), value: impliedTSLAPrice)` gated by `animateValues` |
| No reverse / nav / settings on card | Pass | Presentational `VStack` only |
| pbxproj IDs 54 | Pass | Build file `A100…54`, fileRef `A200…54`, Views group child, Sources entry |
| Musk-centric content first | Pass | Ownership + combined + comparison + daily records + stock rows all precede parity card |

## Non-blocking notes

- Title uses ASCII `SPCX's` rather than the curly apostrophe in the design prose; plan Task 6 explicitly allows matching existing popover ASCII copy style.
- Caption omits an explicit “illustrative only” disclaimer line; design §5 treats title framing + existing app disclaimer as sufficient for v1 (HOLDINGS note is Task 7).
- Show/hide correctness for defaults-only and missing quote legs is owned by Task 5 `mergerParityPresentation`; Task 6 correctly binds only to the optional presentation.

## VERDICT: APPROVED

## Reviewed files

- `Muskometer/Views/MergerParityCardView.swift` — title, primary price, caption, chrome, optional animation
- `Muskometer/Views/PopoverContentView.swift` — `dataView` placement after stock rows; nil-gated; no toggle
- `Muskometer.xcodeproj/project.pbxproj` — IDs `A10000000000000000000054` / `A20000000000000000000054`
- `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md` §5 UI, hide rules, Compliance & messaging, Acceptance 2
- `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 6 steps
