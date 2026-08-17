# Spec correctness review — holdings surface refresh

**Spec:** `docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md`  
**Role:** spec-correctness  
**Date:** 2026-08-17

## Sources read

- Spec: `docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md`
- `Muskometer/Utilities/SPCXHoldings.swift`
- `Muskometer/Utilities/IssuerSharesOutstanding.swift`
- `Muskometer/Utilities/AppSettings.swift`
- `Muskometer/Models/TrackedPersonProfile.swift`
- `Muskometer/Utilities/SPCXOwnershipCalculator.swift`
- `Muskometer/Services/MarketHoursService.swift`
- `Muskometer/Views/PopoverContentView.swift`
- `Muskometer/ViewModels/GainsViewModel.swift`
- `Muskometer/Utilities/MergerMarketCapParity.swift`
- `Muskometer/Services/ComparisonHistoryStore.swift`
- `Muskometer/Services/Form4OwnershipParser.swift`
- `docs/HOLDINGS.md` (first 75 lines)
- `Muskometer.xcodeproj/project.pbxproj` (comparison file IDs)
- Live EDGAR + NYSE checks for the pinned integers/dates (2026-08-17)

## Summary

The design is implementable against the current architecture and the pinned numbers are product-correct. Ownership seed inversion, Cursor outstanding bump, 2028 calendar rows, comparison deletion, and marketing/docs pass are specified at plan-writer granularity (files, keys, fingerprints, pbxproj IDs, acceptance). Empirical citations match live Form 4 / 8-K / NYSE tables. `## Deferred` is honestly `None.`; `## Scale & Validation` is present with an accepted not-applicable body.

No blocking gaps for plan-writing.

## Feasibility

| Slice | Assessment |
|-------|------------|
| TSLA ownership seed | Live Form 4 `0001104659-26-075213` last **D** post-transaction amount is `710,172,677`, matching `Form4OwnershipParser` (`directBlocks.last`). Profile default is the single seed. |
| SPCX ownership seed + invert | Live `0001628280-26-044069` last-row-wins + remarks `1,302,072,285` − options = `6,068,547,515`. Current migrator upgrades that fingerprint to `6,068,734,060` in `loadShareCounts`; invert is the right fix and is specified as exact-integer cases. |
| SPCX outstanding | `7,696,293,669 + 389,289,254 + 5,485,486,276 = 13,571,069,199`. 8-K item (i) is `389,289,254`; item (ii) `1,752,426` correctly excluded. Orthogonal to Form 4; remigration only when stored equals the old cover default. |
| 2028 calendar | Official NYSE table matches the spec dates, the Saturday-New-Year’s “no observed close” footnote, and early closes `2028-07-03` / `2028-11-24` only. Additive to the existing 2026–2027 set. |
| Comparison deletion | Four compile units, four pbxproj ID pairs (`…2B/2E/3A/3B`), VM/popover/settings wiring, and the four test types all exist as named. Key sweep can live on `AppSettings` using the store’s known key shapes. |
| Marketing / docs | HTML mock + regen is an accepted substitute for a live AppKit capture. Site strings and screenshot must-not-show list are grep-able. |
| Dead field | `MergerParityPresentation.currentTSLAPrice` is unused in `MergerParityCardView`; listed test/preview call sites are accurate. |

## Architectural fit

Existing load paths already do what the design extends:

- Ownership: missing key → `TrackedPersonProfile` spec default; SPCX remigrates fingerprints under `shareCount_SPCX` on every load. TSLA remigration belongs in that same `loadShareCounts` branch, not only `migrateLegacyShareCounts`.
- Outstanding: missing key → `IssuerSharesOutstanding.defaultOutstanding`; no remigration today. Adding an exact-match rewrite of `13_181_779_945` next to `loadSharesOutstanding` (or a tiny helper on the enum) does not collide with ownership keys.
- Reset reseeds both planes from the new bundled defaults, so fingerprint logic is only for upgrade-without-Reset.
- Comparison is a leaf feature (popover caption + selector + history). Deleting it does not disturb quotes, Form 4 sync, outstanding, records, sparkline, or parity.
- Calendar is a static set + early-close map; tests already use the 2027 Good Friday / early-close style the spec wants copied.

## Product-correctness checks

| Claim | Verdict |
|-------|---------|
| New suite seeds TSLA `710,172,677` / SPCX `6,068,547,515` / SPCX outstanding `13,571,069,199` | Matches live filings + parser rules; TSLA outstanding stays `3,949,547,394`. |
| Stored SPCX `6_068_734_060` migrates down; `6_068_547_515` passes through | Inverts the current `legacyPartialAggregateDefault` bug. Older fingerprints still retarget the new default. |
| Stored TSLA `699_580_882` remigrates; any other stored TSLA count stays | Same exact-integer policy as SPCX; load-path, not one-shot legacy copy. |
| Stored SPCX outstanding old cover default remigrates; any other positive stays | Correct; companyfacts is WASO-only so it will not overwrite. |
| Calculator fixture must include By Trust → 0 | Live XML has `186545` then later `0` for the same `(title, nature)`. Current fixture omits the disposal and asserts the inflated total. |
| 2028 holidays / early closes | Matches [NYSE Holidays & Trading Hours](https://www.nyse.com/markets/hours-calendars); do not invent `2027-12-31` / `2028-01-01`. |
| Popover order after deletion | combined → records → stock rows → parity. Matches `PopoverContentView.dataView` minus the caption line. |
| Version stays `0.1.4` / build 25 | Explicit non-goal. |

## Strengths

1. **Load-bearing integers are sourced and arithmetic-checked**, with accessions, User-Agent, and last-row-wins / last-D rules that match the parsers already in tree.
2. **Migration invert is specified as fingerprint surgery**, not a blanket rewrite — the current upward remigration is the actual shipped bug.
3. **Outstanding stays a different plane** from Form 4 ownership; Cursor is a pinned default bump, not a new 8-K HTML parser.
4. **Comparison deletion is end-to-end** (UI, library, persistence, tests, pbxproj, site, dead prefs) rather than “hide the view.”
5. **Non-goals and alternatives close the tempting wrong paths** (13G + 350M options, runtime cover parse, vested RSUs, holiday API, splitting the cycle).
6. **Acceptance + TDD map is plan-ready**; screenshot CI is correctly limited to string greps, not OCR.

## Architectural risks (accepted)

| Risk | Why acceptable |
|------|----------------|
| Fingerprint remigration of a deliberate old-default override | Same policy as prior SPCX migrations; vanishingly unlikely. |
| Cursor outstanding omits 1.75M vested RSUs / later ATM | HOLDINGS must say 10-Q cover + 8-K item (i); better than inventing withholding. |
| HTML mock can drift from SwiftUI | Review against popover section order; live capture welcome, not required. |
| Hardcoded calendar still needs a 2029 pass | Unchanged policy; ARCHITECTURE note moves to “after 2028.” |
| Comparison history keys on upgrade-without-Reset | Load-time + Reset sweep of the two known key shapes. |

## Missing considerations / unanswered questions

None that would change the implementation. Plan-writer reminders only (not spec defects):

- Comparison test types live **inside** `MuskometerTests/MuskometerTests.swift`, not separate files. `SeededComparisonRandomizer` lives on `ComparisonLineSelector.swift` and goes away with that file.
- After stripping comparison, `GainsViewModel.tradingDayCalendar` is unused (it exists only to debounce captions). Drop the stored property/parameter so the type does not keep a dead dependency.

## Deferral form and scale

- **`## Deferred`:** `None.` — Appropriate. 13G/options, 8-K HTML parse, extra RSU/option share lines, version tick, holiday API, multi-person UI, and live AppKit screenshot CI are non-goals or accepted leftovers, not silent deferrals.
- **`## Scale & Validation`:** Present. Body correctly treats this as local UserDefaults seeds, a static holiday table, UI deletion, and static marketing assets — no data-volume or multi-tenant dimension.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{
  "schema_version": 1,
  "dispatch_id": null,
  "verdict": "approved",
  "round": 1,
  "findings": []
}
```

VERDICT: APPROVED

reviewed-content-sha256: bc7923a6a2563c2f0dbe909b39b80bff57e35adeb03da050a62193c734794741
