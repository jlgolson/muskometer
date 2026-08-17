Task 7 (Product docs and Settings holdings copy) matches Design §6 docs, §1–§2 HOLDINGS messaging, Compliance, and acceptance criterion 9. Reviewed Settings holdings caption, README keyboard table + FAQ, HOLDINGS numbers/accessions/strike-mark, PRIVACY remaining prefs, and ARCHITECTURE comparison/2028 tables at HEAD `3d1f3b75` as the full Task 7 product.

What landed correctly

- Settings Holdings caption is no longer Form 4-only. It states daily Form 4 ownership sync **and** best-effort issuer outstanding on the same cadence, names companyfacts, and says SPCX often stays on the cover/Cursor default (`SettingsView.swift:335`). “Prices refresh separately.” stays. Button label is already **Sync from SEC now**.
- README keyboard table adds **⌘⇧C** → copy share (image or text per Settings) and keeps ⌘R / ⌘, / Esc (`README.md:47-51`). That matches the live command: `.keyboardShortcut("c", modifiers: [.command, .shift])` in `MuskometerApp.swift:41`.
- HOLDINGS ownership table is the pinned seeds: TSLA **710,172,677** from Form 4 `0001104659-26-075213`; SPCX **5,116,475,230** = last-row-wins Class A+B **4,766,475,230** + vested option underlying **350,000,000** from Form 4 `0001628280-26-044069`. Aggregation is sellable: last-row-wins A+B, leftover preferred ×50, options in, remarks performance RSUs out. 350M options and the excluded SpaceX CEO Award **1,000,000,000** + AI CEO Award **302,072,285** (≈ **1.302B**) are named. 1.302B is not described as owned stock.
- Strike-mark sentence is present: 350M marked at the Class A last (Class B converts 1:1); unpaid strike (~$8.3998 × 350M ≈ **$2.94B**) ignored; paper gain stays `shares × Δprice`.
- Outstanding table is §2: TSLA **3,949,547,394** unchanged; SPCX **13,571,069,199** = July 28 10-Q A **7,696,293,669** + B **5,485,486,276** (`0001628280-26-052535`) **plus** Cursor 8-K item (i) **389,289,254** (`0001628280-26-056945`); new Class A **8,085,582,923**. Item (ii)/(iii) excluded. All four required accessions are named. Cursor bump is issuer outstanding only, not a Musk-stake change. WASO-only companyfacts for CIK `0001181412` is documented.
- PRIVACY “What stays on your Mac” adds share format, update-notify flag (and delivery mode), daily-record extremes, sparkline samples, and gain-threshold IDs. Outstanding stays. Comparison history is not listed. Current public release is **0.1.5**.
- ARCHITECTURE 2028 holiday prose + early-close table (Task 2) still match §3: 2026–2028, no observed New Year’s 2028 close, early closes `2028-07-03` and `2028-11-24`, maintainer note now “after 2028.” SPCX line is sellable ~5.116B, not remarks-restricted ~6B. Comparison captions are documented as removed (the “today’s loss equals / today’s gain could…” block and selector/history path). No live selector in the file/services tables. DEVELOPING has no selector mention.
- CHANGELOG / pbxproj / INSTALL / RELEASE / SECURITY / `docs/index.html` were not rewritten here. That is Task 8/9, as dispatched.

Plan wording vs implementation

The plan step for README was only the keyboard row. HEAD also rewrote the “Where do share counts come from?” FAQ to last-row-wins + vested options, **5.116 billion**, unvested awards excluded, and cover+Cursor outstanding (`README.md:58-59`). HOLDINGS’s Settings retry line now matches the live **Sync from SEC now** label. Both are considered improvements aligned with §6 / Compliance, not extra product surface. Confirm the FAQ rewrite was deliberate; do not revert it to the old ~6 billion remarks sentence.

ARCHITECTURE had no remaining live selector mention after Task 5. HEAD still added the required “captions are gone” sentence. That is the task’s fallback rule, not a leftover feature advertisement.

README download example still says `Muskometer-0.1.4.dmg`. PRIVACY is the only current-release string this task was told to tick; the rest is Task 9. Site “comparison captions” blurb is Task 8.

Next-request: these are static strings. Retry, replay, and a second launch all show the same caption and the same HOLDINGS integers. No persisted docs state and no freshness window. Binary revert restores the Form 4-only Settings sentence and the old ~6B / cover-only docs; UserDefaults seeds are unchanged by this task.

## Findings

### Suggestion

- **Leftover “beneficial” / “cover default” phrasing under the new tables.** `docs/HOLDINGS.md:47` still defines Form 4 ownership as “Musk’s beneficial / Class A-equivalent holdings.” Compliance wants “Form 4 / Class A-equivalent **sellable**” (common + vested options; not unvested CEO awards). The ownership section above already says sellable and not 13d-3; this concept-table cell is the one place a reader can still equate Form 4 with the voting package that includes the 1.302B awards. Same file `docs/HOLDINGS.md:48` and `:59` still say “cover-derived bundled defaults” / “prior or cover default,” and `README.md:92` still says “companyfacts / cover defaults,” while the outstanding table and FAQ correctly say cover+Cursor. Not a number miss (the §2 table is right). Tighten the concept row to sellable Class A-equivalent (common + vested options) and say cover+Cursor default in the two leftover cover-only sentences.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":1,"findings":[{"severity":"suggestion","id":"T7-S1","title":"Leftover beneficial / cover-default phrasing","path":"docs/HOLDINGS.md","summary":"Concept table still says beneficial holdings and cover default; ownership/outstanding tables already have sellable + cover+Cursor. Tighten to Compliance wording."}]}
```

VERDICT: APPROVED

## Reviewed files

- docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-7-description.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-7-summary.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-7-round-1-quality-diff
- Muskometer/Views/SettingsView.swift
- Muskometer/App/MuskometerApp.swift
- README.md
- docs/HOLDINGS.md
- docs/PRIVACY.md
- docs/ARCHITECTURE.md
- docs/DEVELOPING.md

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130

reviewed-content-sha256: 609e7786b9d2cb3826281014d56629163c738805261e37b7d000dcced41f7bc2

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
