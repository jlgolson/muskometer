---
slug: 2026-08-17-holdings-surface-refresh-design
title: Holdings defaults, 2028 calendar, drop comparison captions, marketing surface
date: 2026-08-17
branch: jordan/holdings-surface-refresh
status: design
---

# Holdings defaults, 2028 calendar, drop comparison captions, marketing surface

**Date:** 2026-08-17
**Branch:** `jordan/holdings-surface-refresh`
**Status:** design (brainstormed)

One cycle. Operator asked to land every leftover from the 0.1.4 scout plus delete the comparison-caption surface, and not to split for harness overhead.

## Problem

Five independent leftovers share one “the shipped 0.1.4 product and the repo no longer match reality / intent” framing:

1. **Bundled ownership seeds are stale vs live Form 4 XML** (fetched 2026-08-17 with User-Agent `Muskometer/0.1.4 (info@muskometer.org; https://muskometer.org)`).
   - TSLA default is still `699_580_882`. Latest Musk Form 4 for TSLA (`0001104659-26-075213`, period 2026-06-16) last **direct** (`D`) `sharesOwnedFollowingTransaction` is **710,172,677**.
   - SPCX default is `6_068_734_060`, which is the June 17 Form 4 aggregate **plus** a 186,545 “By Trust” Class A line that a later transaction in the **same** filing takes to **0**. Live parse of `0001628280-26-044069` / `wk-form4_1781740812.xml` with last-row-wins is **6,068,547,515** (restricted-remark 1,302,072,285 included; 350,000,000 Class B options excluded — existing `SPCXOwnershipCalculator` rule).
   - Worse: `SPCXHoldings.migrateStoredShareCount` currently **upgrades** the correct 6,068,547,515 fingerprint *to* the too-high 6,068,734,060. Any install that already synced the June 17 Form 4 correctly gets rewritten wrong on next launch.
2. **Issuer outstanding default for SPCX ignores the Cursor close.** SpaceX 8-K `0001628280-26-056945` (filed 2026-08-14) issued **389,289,254** new Class A as merger consideration. Companyfacts for CIK `0001181412` still only exposes WASO (resolver correctly returns nil), so outstanding sync cannot pick this up. Bundled A+B cover default is still 13,181,779,945 (July 28 10-Q accession `0001628280-26-052535`).
3. **NYSE calendar stops at 2027.** `MarketHoursService` holidays + early closes are 2026–2027 only. Official NYSE 2028 table is published ([Holidays & Trading Hours](https://www.nyse.com/markets/hours-calendars), retrieved 2026-08-17). First miss: MLK **2028-01-17**.
4. **muskometer.org screenshots are a 0.1.2 popover.** `docs/screenshots/app-capture.png`, `app-preview.png`, and `og-image.png` still show **Post to X**, **“Opens Mon 4:00 AM EDT”**, and **no merger-parity card**. Product after 0.1.3/0.1.4 has a single Copy control, next-open **9:30**, and the parity card. Site lede still says “minute by minute, every day.”
5. **Comparison captions do not earn their keep.** Operator: remove the “today’s loss equals / today’s gain could…” block entirely. That is `ComparisonCaptionView` under the combined card, plus the ~4,500-line `ComparisonLibrary`, selector, history store, and VM debounce.

Related polish that belongs in the same cycle (same files / same docs pass):

- README keyboard table omits **⌘⇧C** (live in `MuskometerApp` + Settings).
- Settings Holdings copy says Form 4 only; outstanding syncs on the same cadence.
- `docs/PRIVACY.md` prefs list is incomplete.
- `MergerParityPresentation.currentTSLAPrice` is unused after caption tighten (pre-merge leftover).

## Goals

- Fresh install / Reset / fingerprint-migrated installs seed **Form 4-accurate ownership** and **cover+Cursor outstanding**.
- Reverse the SPCX migration that currently inflates the correct last-row-wins total.
- Extend the hardcoded NYSE holiday + early-close tables through **2028** from the official calendar (including the published “no New Year’s 2028” rule).
- Delete the comparison-caption feature end-to-end (UI, library, persistence, tests, pbxproj, docs, site blurb). Leftover UserDefaults keys are removed on Reset and on settings load.
- Replace marketing PNGs + site copy so the public surface matches the post-change popover (no Post to X, no comparison line, 9:30 next open, parity card present).
- Docs: HOLDINGS numbers, ARCHITECTURE 2028 table, README ⌘⇧C, Settings holdings caption, PRIVACY prefs, CHANGELOG Unreleased.
- Drop unused `currentTSLAPrice` from the parity presentation struct.

## Non-goals

- Reading Schedule 13G / 13D. Daily sync stays Form 4 / 4A only. The Aug 13 13G (`0001104659-26-095936`) 6,418,547,515 figure is the June Form 4 package **plus 350M options**; options stay excluded.
- Runtime 8-K / 10-Q HTML cover parsing. Cursor issuance is a **pinned default bump**, same pattern as today’s cover-derived SPCX outstanding.
- Adding the 1,752,426 vested-RSU Class A line from the same 8-K (withholding-uncertain) or the assumed unvested RSUs (~29.1M) / options (~44.4M). Those are not point-in-time common outstanding.
- Changing Yahoo `includePrePost`, Sparkle wiring, or `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`. Leave the app at **0.1.4 / build 25** until a separate release tick.
- Replacing the hardcoded calendar with a network holiday API.
- Multi-person UI. Comparison deletion is Musk-path only in practice (`registry` is still `[.musk]`).
- Live AppKit screenshot of a running menu-bar popover as a CI requirement. A faithful HTML reconstruction + regen of the three PNGs is an accepted implementation.

## Current architecture (relevant)

- **Ownership seeds:** `TrackedPersonProfile.musk.holdingSpecs[].defaultShareCount` + `SPCXHoldings.defaultShareCount`. `AppSettings.shareCount(for:)` uses stored `shareCount_<SYM>` else the spec default. `SPCXHoldings.migrateStoredShareCount` remigrates fingerprints already under the new key.
- **Outstanding seeds:** `IssuerSharesOutstanding.defaultTSLA` / `defaultSPCX`. `sharesOutstanding(for:)` uses stored `sharesOutstanding_<SYM>` else bundled default. No fingerprint remigration today. Companyfacts path (`IssuerOutstandingSyncService` + `CompanyFactsOutstandingResolver`) rejects WASO; SPCX companyfacts is WASO-only as of 2026-08-17.
- **Calendar:** `MarketHoursService` holiday `Set<String>` + `earlyCloses` map; tests in `MarketHoursServiceTests` (Good Friday 2027, early close, next-open 9:30).
- **Comparison:** `ComparisonLine.swift` (library + `ComparisonLine` + polarity helpers), `ComparisonLineSelector` (owns `SeededComparisonRandomizer`), `ComparisonHistoryStore` (`comparisonHistoryEntries` / `comparisonHistoryEntries_<personID>`), `ComparisonCaptionView`, `GainsViewModel.comparisonLine` + `lastComparisonStateByPerson` + `updateComparisonLineIfNeeded`. Wired in `PopoverContentView` after the combined card. Share card does **not** render captions. pbxproj IDs `A200…2B/2E/3A/3B`. Comparison tests live **inside** `MuskometerTests/MuskometerTests.swift` (`ComparisonLibraryTests`, `ComparisonHistoryStoreTests`, `ComparisonLineSelectorTests`, `GainsViewModelComparisonDebounceTests`), not separate files.
- **Marketing:** `docs/screenshots/{app-capture,app-preview,og-image}.png`, `render-popover.html` (composites capture under a fake menu bar), `render-og.html`, `docs/index.html`.

## Design

### 1. Ownership defaults + fingerprint migration

| Symbol | New default | Source (empirical, 2026-08-17 EDGAR fetch) |
|--------|-------------|--------------------------------------------|
| **TSLA** | `710_172_677` | Form 4 `0001104659-26-075213`, last direct common-stock post-transaction amount |
| **SPCX** | `6_068_547_515` | Form 4 `0001628280-26-044069`: last-row-wins per `(title, nature)` + remarks restricted 1,302,072,285; options title excluded |

Write the same integer in **both** `TrackedPersonProfile.musk` holding specs **and** `SPCXHoldings.defaultShareCount` (TSLA has no parallel enum; the spec default is the single seed).

**SPCX `migrateStoredShareCount` inversion:**

- `defaultShareCount` becomes `6_068_547_515`.
- Treat `6_068_734_060` as a **new** legacy fingerprint (the 186,545-too-high default / previous migration target) → migrate **down** to `6_068_547_515`.
- **Stop** treating `6_068_547_515` as legacy. That value must pass through unchanged (it is now correct).
- Keep migrating the older fingerprints (`60_685_475`, `842_091_670`, `7_402_770`) to the **new** default.

**TSLA fingerprint remigration** (same load-path pattern as SPCX, not only the one-shot `migrateLegacyShareCounts` that runs when `shareCount_TSLA` is missing):

- If stored `shareCount_TSLA` equals `699_580_882` (old bundled default), rewrite to `710_172_677`.
- Leave any other stored TSLA count (manual override or a later Form 4) untouched.

`shareCount(for:)` with no stored key automatically picks up the new spec defaults. Reset-to-defaults reseeds both.

**Parser / fixture:** `SPCXOwnershipCalculatorTests.testAggregatesJune2026Form4Holdings` must include the later `By Trust` Class A transaction to **0** (as in the live XML) and expect `6_068_547_515`. Do not keep a fixture that omits the disposal and asserts the old 6,068,734,060.

### 2. Issuer outstanding (parity card only — not Musk ownership)

Issuer outstanding remains orthogonal to Form 4 ownership. This change only affects `MergerMarketCapParity` inputs.

| Piece | Value |
|-------|--------|
| Prior Class A (10-Q cover 2026-07-28) | 7,696,293,669 |
| Prior Class B | 5,485,486,276 |
| Cursor merger Class A issued (8-K 2026-08-14, item (i)) | 389,289,254 |
| **New Class A** | **8,085,582,923** |
| **New A+B (`defaultSPCX`)** | **13,571,069,199** |

Citation: 8-K accession `0001628280-26-056945`, `spcx-20260814.htm`. Do **not** add item (ii) 1,752,426 (withholding) or item (iii) assumed unvested RSUs/options.

TSLA `defaultTSLA` stays `3_949_547_394` (`dei:EntityCommonStockSharesOutstanding` end 2026-07-16, still the latest companyfacts row as of 2026-08-17).

**Fingerprint remigration for outstanding:** if stored `sharesOutstanding_SPCX` equals `13_181_779_945`, rewrite to `13_571_069_199`. Any other stored positive outstanding (future companyfacts hit, or a test override) is left alone. Missing key → new bundled default via `sharesOutstanding(for:)`.

HOLDINGS.md table + derivation sentence must match these integers and name both accessions.

### 3. NYSE calendar through 2028

Source: [NYSE Holidays & Trading Hours](https://www.nyse.com/markets/hours-calendars) (retrieved 2026-08-17). Add to the existing holiday set (keep 2026–2027 rows):

| Holiday | 2028 date |
|---------|-----------|
| New Year’s Day | **not observed** (Saturday Jan 1; NYSE footnote: no observed close) |
| Martin Luther King, Jr. Day | 2028-01-17 |
| Washington's Birthday | 2028-02-21 |
| Good Friday | 2028-04-14 |
| Memorial Day | 2028-05-29 |
| Juneteenth | 2028-06-19 |
| Independence Day | 2028-07-04 (full close) |
| Labor Day | 2028-09-04 |
| Thanksgiving | 2028-11-23 |
| Christmas | 2028-12-25 |

Early closes (13:00 ET), add:

| Date | Reason |
|------|--------|
| 2028-07-03 | Day before Independence Day (NYSE footnote **) |
| 2028-11-24 | Day after Thanksgiving (NYSE footnote ***) |

No 2028 Christmas Eve early close on the published table. Do **not** invent 2027-12-31 or 2028-01-01 closes.

Tests (same style as `test2027GoodFridayIsClosed` / early-close cases):

- 2028-01-17 11:00 ET closed; 2028-01-18 11:00 ET open.
- 2028-01-03 11:00 ET open (proves no phantom New Year’s observed close).
- 2028-04-14 closed; 2028-07-04 closed; 2028-07-03 14:00 ET closed (after early close); 2028-07-03 11:00 ET open (still RTH until 13:00).
- 2028-11-24 14:00 ET closed; 2028-11-23 closed.

ARCHITECTURE.md holiday prose + early-close table: “2026–2028”, add the two 2028 early-close rows, keep the annual-extension note (now “after 2028”).

### 4. Delete comparison captions

Remove the feature completely. After this cycle the popover goes combined card → daily records (if any) → stock rows → parity card. No replacement caption. No settings toggle. No empty placeholder view.

**Delete source (and matching pbxproj fileRef / build-file / group entries):**

- `Muskometer/Models/ComparisonLine.swift`
- `Muskometer/Views/ComparisonCaptionView.swift`
- `Muskometer/Services/ComparisonLineSelector.swift`
- `Muskometer/Services/ComparisonHistoryStore.swift`

**Strip from survivors:**

- `PopoverContentView`: the `ComparisonCaptionView` line.
- `GainsViewModel`: `comparisonLine`, `comparisonLineSelector`, `lastComparisonStateByPerson`, `updateComparisonLineIfNeeded`, constructor parameter, calls in `processSnapshotSideEffects` / `reloadPersistedDisplayState` / `reloadPersonScopedDisplayState`. After that strip, `tradingDayCalendar` is only used to debounce captions — **delete the stored property and constructor parameter** so the type does not keep a dead dependency.
- `AppSettings.resetPersistedState`: drop the `ComparisonHistoryStore.resetPersistedState` call. In its place, **delete leftover keys** `comparisonHistoryEntries` and `comparisonHistoryEntries_musk` (and, if a non-musk personID is ever selected, `comparisonHistoryEntries_<id>`) so Reset and a one-shot load-time sweep do not leave dead prefs. A tiny private helper on `AppSettings` is enough; do not keep the store type just for key names.

**Delete tests:** `ComparisonLibraryTests`, `ComparisonHistoryStoreTests`, `ComparisonLineSelectorTests`, `GainsViewModelComparisonDebounceTests`, and any helper types they uniquely own (`SeededComparisonRandomizer` if unused elsewhere).

**Docs / site:** remove “comparison captions” from `docs/index.html` features blurb and any DEVELOPING/ARCHITECTURE mention of the selector. CHANGELOG **Unreleased** records the removal. Historical 0.1.1/0.1.2 CHANGELOG entries stay as history.

Share image path is already caption-free; no ShareCard change required beyond not growing a caption.

### 5. Marketing screenshots + site copy

Replace all three PNGs so they cannot be mistaken for the old popover:

| File | Must show | Must not show |
|------|-----------|---------------|
| `docs/screenshots/app-capture.png` | Current popover chrome: ownership, combined, sparkline, **single Copy** control, records, TSLA/SPCX rows, **parity card**, 9:30-style next-open if a next-open line is shown | “Post to X”; comparison caption; “4:00 AM” next-open |
| `docs/screenshots/app-preview.png` | Menu-bar + capture composite (existing `render-popover.html` pattern) | same |
| `docs/screenshots/og-image.png` | Existing OG layout with updated preview | same |

`render-og.html` / `docs/index.html` lede: drop or soften “minute by minute, every day” to language that matches RTH-only refresh (e.g. glanceable menu-bar worth / paper gain during the regular US session). Update `index.html` screenshot `alt` to mention the parity card and not Post to X.

Implementation: a checked-in HTML mock of the popover (evolve `render-popover.html` or add `render-capture.html`) that is the source of `app-capture.png` is acceptable and preferred for reviewability. If Chrome/headless is available in the implementer environment, document the regen command in `docs/README.md` (the Pages folder readme). PNGs are the shipped artifact; HTML is the source.

### 6. Docs + dead field

- **README** keyboard table: add **⌘⇧C** → copy share (image or text per Settings). Keep ⌘R / ⌘, / Esc.
- **Settings Holdings** caption: one sentence that Form 4 ownership syncs daily **and** issuer outstanding is best-effort on the same cadence (companyfacts; SPCX often stays on the cover/Cursor default).
- **PRIVACY.md** “What stays on your Mac”: add share format, update-notify flag, daily-record extremes, sparkline samples, gain-threshold IDs. Do **not** list comparison history after deletion. Outstanding stays listed. Do not bump the “current public release is 0.1.4” line.
- **CHANGELOG Unreleased:** ownership seed + migration invert, SPCX outstanding Cursor bump, 2028 calendar, comparison removal, screenshot/docs pass, unused `currentTSLAPrice` drop.
- **`MergerParityPresentation`:** remove `currentTSLAPrice`. Update calculator, preview, and tests that assert passthrough (`MuskometerTests` ~1172, ~1287, ~1504; `MergerParityCardView` preview).

### 7. pbxproj

Remove the four comparison `PBXBuildFile` / `PBXFileReference` / group children / Sources-phase lines (`A100/A200 …2B, 2E, 3A, 3B`). Do not recycle those IDs. No new compile units are required unless the HTML mock or a tiny `IssuerSharesOutstanding` migrate helper is added as Swift (prefer keeping outstanding migrate next to `IssuerSharesOutstanding` or `AppSettings.loadSharesOutstanding` — no new file required).

## Acceptance criteria

1. New `UserDefaults` suite (no stored keys) → TSLA 710,172,677 and SPCX 6,068,547,515 ownership; SPCX outstanding 13,571,069,199; TSLA outstanding unchanged 3,949,547,394.
2. Stored SPCX ownership `6_068_734_060` or `6_068_547_515` → after `AppSettings` init, **6,068,547,515** (no upward rewrite).
3. Stored TSLA ownership `699_580_882` → 710,172,677; stored `710_172_677` or any other value stays.
4. Stored SPCX outstanding `13_181_779_945` → 13,571,069,199; any other positive stored outstanding stays.
5. Calculator on a fixture that mirrors live June 17 SPCX Form 4 (including By Trust → 0) returns 6,068,547,515.
6. 2028 holiday/early-close tests above pass; 2026–2027 existing tests stay green.
7. App target does not compile `ComparisonLine` / `ComparisonCaptionView` / `ComparisonLineSelector` / `ComparisonHistoryStore`. Popover has no comparison view. `GainsViewModel` has no `comparisonLine` API.
8. `docs/screenshots/app-capture.png` (and the two derivatives) visually match the post-change popover rules in §5. `docs/index.html` and `render-og.html` do not say “minute by minute, every day” or advertise comparison captions. No “Post to X” string in `docs/` HTML.
9. README lists ⌘⇧C. PRIVACY lists the remaining prefs. HOLDINGS and ARCHITECTURE numbers/tables match §2–§3.
10. `MergerParityPresentation` has no `currentTSLAPrice`. `MUSKOMETER_SKIP_LIVE_YAHOO=1 ./scripts/verify.sh` passes.

## Testing strategy

TDD against existing suites:

- Extend `SPCXHoldingsTests` / `AppSettings` share-count tests for the inverted fingerprints and the new Tesla fingerprint.
- Extend outstanding settings tests for the Cursor default + old-default remigration.
- Replace the June 2026 SPCX calculator fixture with last-row-wins-accurate XML (include the zeroing transaction).
- Add 2028 rows next to the 2026/2027 `MarketHoursServiceTests`.
- Delete comparison test types; if any VM test constructed a `ComparisonLineSelector`, drop that dependency.
- Update parity presentation assertions.
- Docs/HTML: grep-level checks can live in `scripts/verify.sh` **or** as comments in the Pages readme plus implementer verification — prefer a small `verify.sh` section that fails if `docs/index.html` or `docs/screenshots/render-*.html` contain `Post to X` or `comparison caption`. Do not try to OCR the PNGs in CI.

## Risks

- **Migration overreach.** Fingerprint remigration must only rewrite the listed exact integers. A user who typed 699,580,882 as a deliberate override (vanishingly unlikely; it *is* the old default) would be updated — accepted, same policy as prior SPCX fingerprint migrations.
- **Cursor outstanding undercount.** Omitting the 1.75M vested-RSU shares and any later ATM/issuance means the parity card is slightly stale until the next 10-Q cover or a companyfacts point-in-time concept appears. Accepted: better than inventing withholding-adjusted shares. HOLDINGS must say the default is 10-Q cover **plus the 8-K Class A issuance in item (i)**.
- **Screenshot fidelity.** An HTML mock can drift from SwiftUI. Mitigation: mock is reviewed against `PopoverContentView` structure (section order, no comparison, parity after rows, one Copy button). Live capture is welcome if the implementer can produce one; not required.
- **Calendar drift.** Hardcoded 2028 still needs a 2029 pass. Unchanged policy; ARCHITECTURE keeps the maintainer note.
- **Dead UserDefaults.** Comparison history keys left behind on upgrade-without-Reset. Mitigation: load-time + Reset sweep of the two known key shapes.

## Observability

None beyond existing debug logging. No new user-facing error paths.

## Open questions

None remaining. Live popover capture vs HTML mock (HTML mock accepted), the 1.75M vested-RSU undercount (excluded), and remigrating the exact old bundled defaults (yes, fingerprint-only) are decided in Design, Non-goals, and Risks.

## Upgrade / persisted-state contract

`AppSettings` init is the upgrade hook. No migration UI, no version gate.

| Situation | Ownership | Outstanding | Comparison history |
|-----------|-----------|-------------|--------------------|
| Fresh install / no keys | New spec defaults | New bundled defaults (`sharesOutstanding(for:)` fallback) | No keys written |
| Upgrade; stored equals an old fingerprint listed in §1–§2 | Rewrite to the new integer | SPCX `13_181_779_945` → `13_571_069_199` only | Keys `comparisonHistoryEntries` and `comparisonHistoryEntries_<personID>` deleted on load and on Reset |
| Upgrade; stored is any other positive value (manual override, later Form 4, future companyfacts) | Leave stored | Leave stored | Same sweep |
| Reset to defaults | Reseed both ownership defaults | Reseed both outstanding defaults | Sweep leftover keys |

Remigration is **idempotent** (running twice is a no-op once the stored value is the new integer). It is **not automatically reversible**.

## Rollback

- **Binary revert** (ship previous build): the old binary’s migrator may rewrite SPCX `6_068_547_515` *up* to `6_068_734_060` again (today’s bug). Tesla `710_172_677` and outstanding `13_571_069_199` are unknown to the old binary and are left stored (old `shareCount(for:)` / `sharesOutstanding(for:)` return stored values when present). Comparison UI returns; history keys stay empty until new captions are selected.
- **Data revert** is not provided. Users who want old seeds after a binary revert can Reset (old binary reseeds old defaults) or edit Settings share counts.
- **Git revert** of this branch restores source, tests, and marketing PNGs. UserDefaults on installed Macs are unchanged by git.

## Compliance & messaging

- Ownership copy stays “Form 4 / Class A-equivalent”; outstanding copy stays “issuer shares for the parity card only.” HOLDINGS must name accessions for the TSLA Form 4, SPCX Form 4, July 28 10-Q cover, and the Cursor 8-K item (i) Class A issuance.
- Do not describe the Cursor bump as a change in Musk’s stake.
- Entertainment disclaimer (`docs/DISCLAIMER.md`) is unchanged. Screenshots and HTML mocks are illustrative product UI, not live quotes; they may be used on muskometer.org and OG cards.
- After comparison deletion, site features must not advertise comparison captions. No new legal surface.

## Rollout

Ship on the feature branch; CHANGELOG under **Unreleased**. No settings flag, no phased rollout. Comparison disappearance is immediate on upgrade. Ownership/outstanding fingerprint migrations and the comparison-key sweep run on next `AppSettings` init (app launch). See **Upgrade / persisted-state contract** and **Rollback**.

## Dependencies / external contracts

| Contract | Evidence |
|----------|----------|
| Musk TSLA Form 4 last D row 710,172,677 | Empirical GET `https://www.sec.gov/Archives/edgar/data/1318605/000110465926075213/tm2618092-2_4seq1.xml` (2026-08-17) |
| Musk SPCX Form 4 last-row-wins 6,068,547,515 | Empirical GET `…/000162828026044069/wk-form4_1781740812.xml`; remarks + option row inspected |
| Aug 13 13G 6,418,547,515 includes 350M options | Empirical GET `…/000110465926095936/primary_doc.xml` — **out of scope** for the seed |
| Cursor 389,289,254 Class A | Empirical GET `…/000162828026056945/spcx-20260814.htm` |
| TSLA outstanding 3,949,547,394 still latest | Empirical GET `https://data.sec.gov/api/xbrl/companyfacts/CIK0001318605.json` |
| SPCX companyfacts WASO-only | Empirical GET `…/CIK0001181412.json` — no `dei:EntityCommonStockSharesOutstanding` |
| NYSE 2028 holidays + early closes | [nyse.com/markets/hours-calendars](https://www.nyse.com/markets/hours-calendars) retrieved 2026-08-17 |

SEC fetches used User-Agent `Muskometer/0.1.4 (info@muskometer.org; https://muskometer.org)` per EDGAR fair-access policy already used by the app.

## Alternatives considered

1. **Parse 13G and include 350M options** — rejected. Operator confirmed outstanding ≠ holdings; the 6.42B headline is options + the same Form 4 package. Options stay excluded.
2. **Leave defaults; rely on daily Form 4 sync** — rejected for SPCX because the current migrator *undoes* a correct sync, and for Tesla because Reset / first-run still show 699.6M until a successful sync.
3. **Runtime 8-K HTML parse for outstanding** — rejected (non-goal; WASO-only companyfacts already forced cover defaults). Pin the Cursor integer.
4. **Keep comparison library, hide the view** — rejected. Operator asked to toss it; a 4,500-line unused library is the wrong leftover.
5. **Split into four PRs** — rejected. Operator explicitly wants one cycle to amortize marshal harness overhead.

## Deferred

None.

## Scale & Validation

Not applicable: local UserDefaults seeds, a static holiday table, UI deletion, and static marketing assets. No data-volume or multi-tenant dimension.
