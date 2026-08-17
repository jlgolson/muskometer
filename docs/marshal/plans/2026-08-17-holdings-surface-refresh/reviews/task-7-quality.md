# Task 7 Code Quality Review — Product docs and Settings holdings copy

Reviewed the Task 7 product at HEAD `3d1f3b75e1253bb2be892943884526bcd229f8c2`: Settings holdings caption, README keyboard/FAQ, HOLDINGS sellable-ownership + outstanding tables, PRIVACY remaining prefs + 0.1.5, and ARCHITECTURE comparison-gone sentence.

## Strengths

The five named files all moved to the same sellable-ownership / cover+Cursor story. Numbers match the product seeds: TSLA **710,172,677**, SPCX **5,116,475,230** (`4,766,475,230` + `350,000,000`), outstanding **13,571,069,199** (`7,696,293,669` + `5,485,486,276` + `389,289,254`), TSLA outstanding unchanged **3,949,547,394**. All four accessions are named. Arithmetic is internally consistent (`8,085,582,923` A + B, `$8.3998 × 350M ≈ $2.94B`).

HOLDINGS states the calculator rule in product language: last-row-wins Class A+B, leftover preferred ×50 (already zero on the June 17 filing), option titles count, remarks 1.302B SpaceX/AI CEO Awards do **not**, options marked at the Class A last, unpaid strike ignored. Outstanding row is 10-Q cover **plus** Cursor 8-K item (i); item (ii)/(iii) stay out; WASO-only companyfacts is why the cover+Cursor default often sticks.

Settings caption is one caption next to the existing **Sync from SEC now** button. It names daily Form 4 ownership, best-effort outstanding on the same cadence, companyfacts, and the SPCX cover/Cursor fallback, then keeps the still-true “Prices refresh separately.” PRIVACY adds share format, update-notify (plus delivery mode), daily-record extremes, sparkline samples, and gain-threshold IDs. Comparison history is not listed. Release line is **0.1.5**. CHANGELOG / pbxproj / INSTALL / SECURITY version strings were left for Task 9.

## Plan alignment

Planned functionality landed in the five named files. Approach matches Design §6 / AC9: copy and numbers only; no calculator, remigration, or version-tick rewrite.

Several expansions beyond the step sketch, all considered improvements:

- README FAQ and ARCHITECTURE TSLA/SPCX bullets were rewritten off the old ~6B / remarks-included wording. The plan named only the keyboard table and a comparison-gone sentence; leaving “about **6 billion**” in the FAQ would have contradicted HOLDINGS.
- HOLDINGS keeps leftover preferred ×50, names F8/F3 strike and expire (from Design §1), splits the 1.302B awards, and records the WASO-only CIK. That is the spec’s HOLDINGS messaging, not extra product surface.
- Partial-sync copy now says **Sync from SEC now**, matching the live Settings button.
- ARCHITECTURE mentions “selector/history path” only in the past-tense removal sentence the plan asked for. No live selector remains. `docs/DEVELOPING.md` still has none.

Do not rewrite these back to the shorter sketch. README `Muskometer-0.1.4.dmg` and CHANGELOG stay Task 9. `docs/index.html` “comparison captions” stays Task 8.

## File organization

No new files or types. Caption stays in the holdings section of `SettingsView`. Docs edits stay inside existing sections (Share counts, Issuer outstanding, What stays on your Mac, Paper gain math). Keyboard table gained one row between ⌘R and ⌘,. No pbxproj, no tests, no HTML/PNG.

## Tests

None required. This is a copy/docs task. The behavior that matters is grep-level: Settings string, ⌘⇧C, pinned integers/accessions, PRIVACY pref list without comparison history, ARCHITECTURE comparison-gone, PRIVACY 0.1.5. Product integers are already locked by Tasks 1/3/4. `verify.sh` HTML greps are Task 8.

## Clarity and patterns

Names stay in the existing holdings vocabulary (sellable ownership, last-row-wins, cover+Cursor, companyfacts, WASO). Settings caption uses the same `.font(.caption)` / `.foregroundStyle(.secondary)` pattern as the other holdings notes. PRIVACY bullets are one pref per line, same list as before plus the five required adds.

A leftover “cover-derived bundled defaults” / “companyfacts / cover defaults” phrase remains in the HOLDINGS concept table and the README footer disclaimer, while the FAQ and the outstanding derivation row already say cover+Cursor. Not load-bearing — the numbered outstanding table is the source of truth.

## Next-request / round-trip

N/A. All of this is compile-time copy. The Settings string is not persisted. A later request rereads the same markdown and the same `Text(...)`.

## Assessment

Ready to merge on quality. Copy matches the surrounding docs voice, the live Settings button, and the product seeds. No new types, no leaked version tick, no comparison-history pref.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- Muskometer/Views/SettingsView.swift
- docs/HOLDINGS.md
- README.md
- docs/PRIVACY.md
- docs/ARCHITECTURE.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-7-description.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-7-summary.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-7-round-1-quality-diff
- docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md

reviewed-content-sha256: STAMP

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130

reviewed-content-sha256: 609e7786b9d2cb3826281014d56629163c738805261e37b7d000dcced41f7bc2

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
