Task 8 (Marketing screenshots and HTML mock) matches Design §5, Compliance’s marketing-copy rule, and acceptance criterion 8. Reviewed the new `render-capture.html` mock against `PopoverContentView` section order, the three shipped PNGs as visual artifacts (no OCR), `docs/index.html` + `render-og.html` ledes, screenshot alt, and the `verify.sh` marketing grep at HEAD `31f13621` as the full Task 8 product.

What landed correctly

- `docs/screenshots/render-capture.html` is a reviewable HTML reconstruction of the post-change popover. Section order matches `PopoverContentView.dataView`: ownership → combined (status + sparkline + **one** Copy control) → intraday records → TSLA row → SPCX row → parity card → footer. No comparison-caption block under combined. Share counts are the new seeds (`710,172,677` / `5,116,475,230`). Next-open is `Opens Mon 9:30 AM EDT`. Default button title is `Copy Image`, which is `ShareFormat.image.buttonTitle`.
- Site HTML (`docs/index.html` and `docs/screenshots/render-*.html`) has zero `Post to X`, `comparison caption`, `4:00 AM`, and `minute by minute` strings. The only “4:00” on the mock is close-of-session `As of 4:00 PM EDT on July 2`, which is RTH close, not the old pre-market next-open.
- `docs/index.html` + `render-og.html` ledes dropped “minute by minute, every day” for glanceable menu-bar worth / paper gain during the regular US session. Features blurb is now “Combined gain chart and best/worst session records” — no comparison advertising. Screenshot `alt` names the parity card and the single Copy control, not Post to X. `og:description` matches. Disclaimer / legal surface is unchanged.
- Shipped PNGs were replaced and visually match §5’s must-show / must-not-show table: `app-capture.png` is the popover mock; `app-preview.png` is the existing menu-bar composite of that capture; `og-image.png` is the existing OG layout with the updated preview and RTH lede. None show Post to X, a comparison line, or 4:00 AM next-open. All three show the parity card, one Copy control, and 9:30 next-open.
- `docs/README.md` documents the Chrome headless regen (`360×920` capture → `920×1154` preview → `1200×630` OG) and states PNGs are the shipped artifact, HTML is the reviewable source, and `verify.sh` does not OCR.
- `scripts/verify.sh` section 6 fails (exit 1) if `docs/index.html` or `docs/screenshots/render-*.html` contain `Post to X` or `comparison caption` (case-insensitive), including a missing-file fail. No PNG OCR.

Plan wording vs implementation

The plan said rebuild `render-popover.html` **or** add `render-capture.html`. HEAD added `render-capture.html` as the popover source and kept `render-popover.html` as the menu-bar composite. That is the intended split, not a shortcut.

HEAD also added `docs/screenshots/render-pngs.swift` (WKWebView snapshot fallback) and switched mock backgrounds from CSS gradients to solid fills. README documents both as sandbox / WKWebView constraints. That is a considered improvement over Chrome-only regen; confirm it was deliberate. Do not drop the helper or restore gradients just to match the shorter files-touched list.

`verify.sh` greps only the two strings the plan named. “4:00 AM” and “minute by minute, every day” are absent from site HTML but are not additional grep needles. That matches Testing strategy; do not widen the check in this task.

Next-request: these are static HTML + PNG artifacts plus a grep. Retry, replay, and a second `verify.sh` marketing pass all see the same strings and the same three files. No persisted marketing state and no freshness window. Binary revert would restore the 0.1.2 popover PNGs and the old lede; GitHub Pages only updates on the next `main` deploy.

No missing §5 product requirements, no extra product work, no leftover Post to X / comparison / 4:00 AM / “minute by minute” in site HTML.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-8-description.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-8-summary.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-8-round-1-quality-diff
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
- Muskometer/Models/ShareFormat.swift

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130

reviewed-content-sha256: STAMP

## Round 2

Re-reviewed Task 8 at HEAD `49d9a40c` against Design §5, AC8, and the round-2 rework that combined must be +$0.2B matching the two rows. Combined today is `+$0.2B` / `+0.02%` in `render-capture.html`, the menu-bar composite (`render-popover.html`), and all three shipped PNGs (visual check, no OCR). TSLA `-$22.6B` + SPCX `+$22.8B` = `+$0.2B`. Percent is `0.2 / 1110 ≈ 0.018%` → `+0.02%`.

§5 chrome is unchanged and still correct: ownership → combined (sparkline + one Copy) → records → TSLA → SPCX → parity → footer; 9:30 next-open; no Post to X / comparison caption / 4:00 AM. Site HTML still has zero forbidden strings. `docs/index.html` lede is one RTH sentence (no doubled “worth”). `app-capture.jpg` is gone. `+$4.4B` remains only as Intraday records Best on Jul 2 — not a §5 requirement; the quality note treated matching that figure as optional.

No missing §5 product requirements, no extra product work.

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
