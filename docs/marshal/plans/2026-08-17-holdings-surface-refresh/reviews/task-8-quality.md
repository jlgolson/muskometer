# Task 8 Code Quality Review — Marketing screenshots and HTML mock

Reviewed the Task 8 product at HEAD `31f13621660e23df4a842625dc48485fff9fd1e8`: new `render-capture.html` popover mock, regenerated `app-capture.png` / `app-preview.png` / `og-image.png`, site + OG copy off “minute by minute, every day”, screenshot alt naming the parity card, Chrome regen documented in `docs/README.md`, and `verify.sh` section 6 failing on `Post to X` / `comparison caption`.

## Strengths

The mock is a real reconstruction of `PopoverContentView.dataView`, not a cropped live shot with the old chrome left in. Section order is ownership → combined (status + sparkline + one Copy) → records → TSLA → SPCX → parity → footer. Labels match the product: `Elon's Ownership`, `Combined today`, `Copy Image` (`ShareFormat.image.buttonTitle`), `Intraday records`, `Elon's Stake`, `Today's Loss` / `Today's Gain`, `If Tesla had SpaceX's market cap`, `SPCX … · TSLA …`. Status copy matches `MarketStatusFormatter` (`As of 4:00 PM EDT on July 2`, `Opens Mon 9:30 AM EDT`). Seeds are the new integers (`710,172,677` / `5,116,475,230`).

I looked at all three PNGs (no OCR). They show the new chrome and do not show Post to X, a comparison line, or 4:00 AM next-open. `app-preview.png` is still the menu-bar composite; `og-image.png` is the existing OG layout with the updated preview and RTH lede.

Site HTML is clean: grep of `docs/**/*.html` is empty for `Post to X`, `comparison caption`, `minute by minute`, and `4:00 AM`. `verify.sh` section 6 is the check the plan asked for — missing-file fail plus case-insensitive needles, no PNG OCR. README documents the three Chrome window sizes and the WKWebView fallback.

## Plan alignment

Planned functionality landed in the named files. Approach matches Design §5: HTML mock is the reviewable source, PNGs are the shipped artifact.

Deviations from the step sketch, all considered improvements — do not rewrite them back:

- Added `render-capture.html` as the popover source and kept `render-popover.html` as the menu-bar composite. The plan allowed either.
- Added `docs/screenshots/render-pngs.swift` and switched mock backgrounds from CSS gradients to solid fills, with the constraint documented. Confirm that was deliberate (sandbox / WKWebView). Do not drop the helper or restore gradients to match the shorter files-touched list.

`verify.sh` greps only the two strings the plan named. “4:00 AM” and “minute by minute” are already gone; do not widen the check in this task.

## File organization

New files sit next to the existing screenshot pipeline: `render-capture.html` (popover), `render-popover.html` (composite), `render-og.html` (OG), `render-pngs.swift` (optional snapshot). No product types, no pbxproj, no app compile units. The Swift helper is a standalone `swift` script under `docs/screenshots/`, not a Muskometer target — correct, `verify.sh` typecheck only walks `Muskometer/`.

## Tests

Coverage matches the behavior that matters for a marketing-docs task:

| Requirement | Where |
|-------------|--------|
| No Post to X / comparison caption in site + mock HTML | `scripts/verify.sh` §6 |
| Missing render HTML fails | same loop, `[[ ! -f ]]` |
| Chrome regen documented | `docs/README.md` |
| PNG chrome (Copy, 9:30, parity, no Post to X) | visual review of the three PNGs; no OCR |

No new XCTest, and none was required.

## Clarity and patterns

HTML structure mirrors the SwiftUI cards (padding 14/12, 12–16 gaps, 360pt width, accent combined card, compact records/rows/parity). `render-pngs.swift` disables JS, uses `loadHTMLString` with `baseURL: nil` (documented: inline `data:` URLs for composites), and times out at 15s. The KVC `drawsBackground` poke is a known WKWebView trick; acceptable in a docs helper.

## Next-request / round-trip

Static HTML + PNG + a grep. A second `verify.sh` marketing pass sees the same strings. No persisted marketing state. Regenerating the PNGs from the HTML is the only write path; README’s three Chrome commands (or the Swift helper) are idempotent over the same inputs.

## Assessment

Chrome, site copy, and the verify grep are merge-ready and match the surrounding Pages pipeline. One mock-data slip should be fixed before these PNGs go to muskometer.org: combined today was left at the old +$4.4B after SPCX shares (and therefore SPCX’s daily gain) were updated.

## Findings

- [docs/screenshots/render-capture.html:combined] mock-math: combined today was +$4.4B / +0.40% after SPCX shares were updated; TSLA -$22.6B + SPCX +$22.8B = +$0.2B
- [docs/index.html:lede] leftover-phrasing: visible lede splices the new RTH phrase into the old worth sentence
- [docs/screenshots/app-capture.jpg] stale-asset: 0.1.2 live capture still in docs/screenshots/

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{
  "schema_version": 1,
  "dispatch_id": null,
  "verdict": "needs_fixes",
  "round": 1,
  "findings": [
    {
      "id": "mock-combined-gain-inconsistent",
      "severity": "major",
      "category": "correctness",
      "refs": [
        "docs/screenshots/render-capture.html:297",
        "docs/screenshots/render-capture.html:361",
        "docs/screenshots/render-capture.html:382",
        "docs/screenshots/app-capture.png"
      ],
      "summary": "Combined today is still +$4.4B / +0.40% after SPCX shares were updated; TSLA -$22.6B + SPCX +$22.8B = +$0.2B. Ownership/stake arithmetic is consistent; the hero combined figure was not recomputed.",
      "fix_hint": "Either set combined to +$0.2B / +0.02%, or raise SPCX's daily gain to ~+$27.0B so the rows still sum to +$4.4B. Regen app-capture.png, app-preview.png, and og-image.png."
    },
    {
      "id": "index-lede-splice",
      "severity": "minor",
      "category": "clarity",
      "refs": ["docs/index.html:24"],
      "summary": "Visible lede splices the new RTH phrase into the old “See what … are worth” sentence; “worth” repeats and the em-dash does not parse. Meta/OG copy is already clean.",
      "fix_hint": "Replace the lede with one RTH sentence (the og:description line is fine) plus the existing “Green days…” closer."
    },
    {
      "id": "stale-app-capture-jpg",
      "severity": "minor",
      "category": "missing",
      "refs": ["docs/screenshots/app-capture.jpg"],
      "summary": "A 0.1.2 live capture (Post to X, 4:00 AM next-open, comparison caption) still sits in docs/screenshots/. Not linked; would be publicly served if tracked.",
      "fix_hint": "Delete the jpg if tracked; do not add it if untracked. Same for generate-sparkline.py unless it is kept as the SVG source."
    }
  ]
}
```

VERDICT: NEEDS_FIXES

## Reviewed files

- docs/screenshots/render-capture.html
- docs/screenshots/render-popover.html
- docs/screenshots/render-og.html
- docs/screenshots/render-pngs.swift
- docs/screenshots/app-capture.png
- docs/screenshots/app-preview.png
- docs/screenshots/og-image.png
- docs/index.html
- docs/README.md
- scripts/verify.sh
- Muskometer/Views/PopoverContentView.swift
- Muskometer/Views/MergerParityCardView.swift
- Muskometer/Views/StockRowView.swift
- Muskometer/Views/DailyRecordsCardView.swift
- Muskometer/Views/GainSparklineView.swift
- Muskometer/Models/ShareFormat.swift
- Muskometer/Utilities/MarketStatusFormatter.swift
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-8-description.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-8-summary.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-8-round-1-quality-diff
- docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md

reviewed-content-sha256: STAMP

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130

reviewed-content-sha256: 308a9630c7d859af27c718494f7cbc75de9ddb36e90634718c99ab3f1ff73921

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130

## Round 2

Re-reviewed the Task 8 rework at HEAD `49d9a40c57cc7ad5cb7424eeaa7626644b20d26b`. Combined today is `+$0.2B` / `+0.02%` in `render-capture.html`, the menu-bar composite (`render-popover.html`), and all three shipped PNGs (visual check, no OCR). TSLA `-$22.6B` + SPCX `+$22.8B` = `+$0.2B`. Percent is `$0.2B / $1.11T ≈ 0.018%` → `+0.02%`. Ownership/stake arithmetic is unchanged and still consistent (`$279.4B + $828.9B = $1.11T`).

All three round-1 findings are closed:

- Combined hero matches the two rows; PNGs were regenerated from the updated HTML.
- Visible `docs/index.html` lede is one RTH sentence (no doubled “worth”). Meta/OG copy was already clean.
- `docs/screenshots/app-capture.jpg` is gone from `docs/screenshots/`.

`+$4.4B` remains only as Intraday records Best on Jul 2. That is session-extreme mock data, not the combined hero; round 1 treated matching that figure as optional. `generate-sparkline.py` is still the SVG source and was correctly kept.

No new quality issues. Organization, naming, and the HTML → PNG pipeline are unchanged from round 1.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":2,"findings":[]}
```

VERDICT: APPROVED

reviewed-content-sha256: 308a9630c7d859af27c718494f7cbc75de9ddb36e90634718c99ab3f1ff73921

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
