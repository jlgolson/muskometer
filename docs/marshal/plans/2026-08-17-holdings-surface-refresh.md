---
slug: 2026-08-17-holdings-surface-refresh
plan_date: 2026-08-17
spec_path: docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md
gate: review
---

# Holdings surface refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use marshal:execute-plan to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Do **not** implement outside execute-plan. Per-task gates require both `task-N-spec.md` and `task-N-quality.md` ending in `VERDICT: APPROVED` before Task N+1 (except the declared ready-set).

**Goal:** Ship 0.1.5 (build 26): sellable SPCX ownership (tables + vested options, no performance RSUs), Tesla/outstanding seed remigration, NYSE 2028 calendar, delete comparison captions, refresh marketing/docs.

**Architecture:** Keep Form 4 sync as the ownership walker. Change `SPCXOwnershipCalculator` so option titles count and remarks performance shares do not. Fingerprint remigration on `AppSettings` init only. Outstanding stays an orthogonal pinned default (10-Q cover + Cursor 8-K item (i)). Comparison is deleted, not hidden. Version tick is this cycle; git-tag/DMG are not.

**Tech Stack:** Swift / SwiftUI macOS 14+, XCTest, existing Yahoo + SEC services, static `docs/` Pages assets.

**Reference paths (read first):**

- Spec: `docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md`
- `Muskometer/Utilities/SPCXOwnershipCalculator.swift`
- `Muskometer/Utilities/SPCXHoldings.swift`
- `Muskometer/Utilities/IssuerSharesOutstanding.swift`
- `Muskometer/Utilities/AppSettings.swift`
- `Muskometer/Models/TrackedPersonProfile.swift`
- `Muskometer/Services/MarketHoursService.swift`
- `Muskometer/ViewModels/GainsViewModel.swift`
- `Muskometer/Views/PopoverContentView.swift`
- `Muskometer.xcodeproj/project.pbxproj`
- `MuskometerTests/MuskometerTests.swift`
- `scripts/verify.sh`

**Pinned integers (do not invent others):**

| Name | Value |
|------|--------|
| TSLA ownership seed | `710_172_677` |
| SPCX table last-row-wins | `4_766_475_230` |
| SPCX vested options | `350_000_000` |
| SPCX ownership seed | `5_116_475_230` |
| SPCX outstanding seed | `13_571_069_199` |
| TSLA outstanding (unchanged) | `3_949_547_394` |
| MARKETING_VERSION | `0.1.5` |
| CURRENT_PROJECT_VERSION | `26` |

Work only in this feature worktree on `jordan/holdings-surface-refresh`.

---

## Task 1: SPCX calculator — options in, remarks out

**Depends on:**

### Files touched

- Muskometer/Utilities/SPCXOwnershipCalculator.swift
- MuskometerTests/MuskometerTests.swift

### Steps

- [ ] In `SPCXOwnershipCalculatorTests.testAggregatesJune2026Form4Holdings`, expand the fixture so it matches live Form 4 `0001628280-26-044069` shape:
  - Keep existing Class A / Class B last-row holdings.
  - Add a later `nonDerivativeTransaction` for `Class A Common Stock` / `By Trust` with `sharesOwnedFollowingTransaction` `0` (after the 186545 holding).
  - Add `derivativeHolding` `Option to Buy (Class B Common Stock)` with `underlyingSecurityShares` / post-transaction `350000000`.
  - Keep remarks `does not include 1302072285 shares of restricted Class B Common Stock`.
  - Change expected total from `6_068_734_060` to `5_116_475_230`.
- [ ] Add `testOptionTitleCountsUnderlyingShares` — XML with only an option holding of `100` → total `100`.
- [ ] Add `testRemarksPerformanceSharesAreNotAdded` — Class A `1000` plus remarks `does not include 1302072285 shares` → total `1000`.
- [ ] Run the three tests; they must **fail** (calculator still zeros options and adds remarks).
- [ ] In `classAEquivalentShares`, delete `if title.contains("option") { return 0 }`. Option titles fall through: Class B in the title already matches `class b common`; if a title is only `Option to Buy (Class B Common Stock)` it contains `class b common` and must return `shares`. Confirm by reading the live title — it does contain `class b common`. If a synthetic title is `Option to Buy` with no class, still return `shares` (treat option underlying as 1:1 Class A-equivalent).
- [ ] Remove `classAEquivalent += restrictedShares(from: xml)` and delete `restrictedShares(from:)` if unused.
- [ ] Re-run the three tests; they must **pass**.
- [ ] Grep `Muskometer/` for `restrictedShares` — zero remaining.
- [ ] Commit: `Count vested SPCX options; ignore remarks performance RSUs`

### Implementer dispatch

````
MARSHAL_TASK_ID: 1
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: implementer

Implement Task 1: SPCX calculator — options in, remarks out.

Worktree: /Users/jlgolson/grok/muskometer/.worktrees/jordan/holdings-surface-refresh
Spec: docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md §1 calculator rule.

TDD: failing tests first, then calculator change. Expected seed math: 4_766_475_230 + 350_000_000 = 5_116_475_230. Do not add remarks 1_302_072_285. Do not subtract strike.

When you finish, report DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
followed by a one-paragraph summary. Do not mark yourself completed —
the orchestrator dispatches reviewers next.
````

### Spec-reviewer dispatch

```
MARSHAL_TASK_ID: 1
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: spec-reviewer

You are reviewing Task 1 for compliance with the spec.

Spec: docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md
Task: SPCX calculator — options in, remarks out.

Write your verdict to:
docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-1-spec.md

## Findings then VERDICT: APPROVED or VERDICT: NEEDS_FIXES: <reason>
Stamp with _verdict_trailer.py role spec-reviewer task-id 1 plan-slug 2026-08-17-holdings-surface-refresh round 1
```

### Code-quality-reviewer dispatch

```
MARSHAL_TASK_ID: 1
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: code-quality-reviewer

You are reviewing Task 1 for code quality.

Write your verdict to:
docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-1-quality.md

## Findings then VERDICT. Stamp trailer role code-quality-reviewer task-id 1 round 1.
```

---

## Task 2: NYSE 2028 holidays and early closes

**Depends on:**

### Files touched

- Muskometer/Services/MarketHoursService.swift
- MuskometerTests/MuskometerTests.swift
- docs/ARCHITECTURE.md

### Steps

- [ ] Add tests in `MarketHoursServiceTests` (same ET helper style as `test2027GoodFridayIsClosed`):
  - 2028-01-17 11:00 ET closed; 2028-01-18 11:00 ET open.
  - 2028-01-03 11:00 ET open (no phantom New Year’s observed close).
  - 2028-04-14 11:00 ET closed.
  - 2028-07-04 11:00 ET closed.
  - 2028-07-03 11:00 ET open; 2028-07-03 14:00 ET closed (early close 13:00).
  - 2028-11-23 11:00 ET closed; 2028-11-24 14:00 ET closed.
- [ ] Run the new tests; they must **fail**.
- [ ] Add holiday strings: `2028-01-17`, `2028-02-21`, `2028-04-14`, `2028-05-29`, `2028-06-19`, `2028-07-04`, `2028-09-04`, `2028-11-23`, `2028-12-25`. Do **not** add `2028-01-01` or `2027-12-31`.
- [ ] Add early closes: `"2028-07-03": SessionMinutes.earlyClose`, `"2028-11-24": SessionMinutes.earlyClose`.
- [ ] Update comments from “2026–2027” to “2026–2028”.
- [ ] Re-run tests; they must **pass**. Keep all 2026–2027 tests green.
- [ ] Update `docs/ARCHITECTURE.md` holiday prose to 2026–2028, add the two 2028 early-close rows, change the maintainer note to “after 2028”.
- [ ] Commit: `Extend NYSE holiday and early-close tables through 2028`

### Implementer dispatch

````
MARSHAL_TASK_ID: 2
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: implementer

Implement Task 2: NYSE 2028 holidays and early closes.

Worktree: /Users/jlgolson/grok/muskometer/.worktrees/jordan/holdings-surface-refresh
Spec §3. Official NYSE table: no New Year’s 2028 observed close. Early closes 2028-07-03 and 2028-11-24 only.

TDD: failing calendar tests first. Do not change 2026–2027 rows.

When you finish, report DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
followed by a one-paragraph summary.
````

### Spec-reviewer dispatch

```
MARSHAL_TASK_ID: 2
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: spec-reviewer

Review Task 2 vs spec §3. Verdict: docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-2-spec.md
Stamp trailer.
```

### Code-quality-reviewer dispatch

```
MARSHAL_TASK_ID: 2
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: code-quality-reviewer

Review Task 2 quality. Verdict: docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-2-quality.md
Stamp trailer.
```

---

## Task 3: Issuer outstanding Cursor bump + remigration

**Depends on:**

### Files touched

- Muskometer/Utilities/IssuerSharesOutstanding.swift
- Muskometer/Utilities/AppSettings.swift
- MuskometerTests/MuskometerTests.swift

### Steps

- [ ] Change `IssuerSharesOutstandingTests.testBundledDefaultsAndKeys` expected `defaultSPCX` to `13_571_069_199`. Run; **fail**.
- [ ] Set `IssuerSharesOutstanding.defaultSPCX = 13_181_779_945 + 389_289_254` (`13_571_069_199`). Update the comment: 10-Q cover A+B plus Cursor 8-K `0001628280-26-056945` item (i) Class A 389,289,254. Class A 8,085,582,923 + Class B 5,485,486,276. Do not add item (ii) 1,752,426.
- [ ] Add `IssuerSharesOutstanding.migrateStoredOutstanding(_ stored: Int64, symbol: String) -> Int64` (or equivalent next to the enum): if `symbol == "SPCX"` and `stored == 13_181_779_945`, return `13_571_069_199`; else return `stored`.
- [ ] In `AppSettings.loadSharesOutstanding`, after parsing a stored positive value, remigrate and persist if changed (same pattern as SPCX share-count remigration).
- [ ] Add tests: stored `13_181_779_945` rewrites to `13_571_069_199`; stored `8_888_888_888` stays; missing key returns new default.
- [ ] TSLA default remains `3_949_547_394`.
- [ ] Run `IssuerSharesOutstandingTests` + related AppSettings outstanding tests — pass.
- [ ] Commit: `Bump SPCX outstanding for Cursor Class A issuance`

### Implementer dispatch

````
MARSHAL_TASK_ID: 3
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: implementer

Implement Task 3: Issuer outstanding Cursor bump + remigration.

Worktree: /Users/jlgolson/grok/muskometer/.worktrees/jordan/holdings-surface-refresh
Spec §2. New defaultSPCX 13_571_069_199. Remigrate only stored 13_181_779_945. Orthogonal to Form 4 ownership.

When you finish, report DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
followed by a one-paragraph summary.
````

### Spec-reviewer dispatch

```
MARSHAL_TASK_ID: 3
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: spec-reviewer

Review Task 3 vs spec §2. Verdict: docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-3-spec.md
```

### Code-quality-reviewer dispatch

```
MARSHAL_TASK_ID: 3
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: code-quality-reviewer

Review Task 3 quality. Verdict: docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-3-quality.md
```

---

## Task 4: Ownership seeds and fingerprint remigration

**Depends on:** 1

### Files touched

- Muskometer/Utilities/SPCXHoldings.swift
- Muskometer/Models/TrackedPersonProfile.swift
- Muskometer/Utilities/AppSettings.swift
- MuskometerTests/MuskometerTests.swift

### Steps

- [ ] Rewrite `SPCXHoldingsTests`:
  - `defaultShareCount` / migrate targets become `5_116_475_230`.
  - Legacy fingerprints that must migrate **to** `5_116_475_230`: `60_685_475`, `842_091_670`, `7_402_770`, `6_068_547_515`, `6_068_734_060`.
  - `5_116_475_230` and `6_068_547_514` (unknown) pass through.
  - `testAppSettingsRewritesLegacyFingerprintUnderNewKey` still uses stored `6_068_547_515` and expects `SPCXHoldings.defaultShareCount`.
- [ ] Add Tesla remigration tests: stored `699_580_882` under `shareCount_TSLA` rewrites to `710_172_677`; stored `710_172_677` stays; stored `123456` stays. Empty suite (no keys) → `shareCount(for: "TSLA")` is `710_172_677`.
- [ ] Run; **fail**.
- [ ] Set `SPCXHoldings.defaultShareCount = 5_116_475_230`. Comment: June 17 Form 4 tables + vested 350M options; no remarks performance RSUs.
- [ ] Update `migrateStoredShareCount` switch: all listed legacy integers return `defaultShareCount`. Do **not** treat `5_116_475_230` as legacy.
- [ ] Set `TrackedPersonProfile.musk` TSLA `defaultShareCount` to `710_172_677` and SPCX to `5_116_475_230`.
- [ ] In `AppSettings.loadShareCounts`, remigrate TSLA when stored equals `699_580_882` (same persist-if-changed pattern as SPCX).
- [ ] Update every test that asserts the old TSLA default `699_580_882` as a **seed** (AppSettings reset / no-key cases) to `710_172_677`. Do **not** change `CurrencyFormatter` / paper-gain math tests that use `699_580_882` as an arbitrary share count.
- [ ] Run `SPCXHoldingsTests` and AppSettings share-count tests — pass.
- [ ] Commit: `Reseed TSLA/SPCX ownership; invert SPCX fingerprint migration`

### Implementer dispatch

````
MARSHAL_TASK_ID: 4
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: implementer

Implement Task 4: Ownership seeds and fingerprint remigration.

Worktree: /Users/jlgolson/grok/muskometer/.worktrees/jordan/holdings-surface-refresh
Spec §1. TSLA 710_172_677. SPCX 5_116_475_230. Migrate 6_068_734_060 and 6_068_547_515 down. Leave non-fingerprint stored counts.

When you finish, report DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
followed by a one-paragraph summary.
````

### Spec-reviewer dispatch

```
MARSHAL_TASK_ID: 4
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: spec-reviewer

Review Task 4 vs spec §1 seeds/migration. Verdict: docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-4-spec.md
```

### Code-quality-reviewer dispatch

```
MARSHAL_TASK_ID: 4
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: code-quality-reviewer

Review Task 4 quality. Verdict: docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-4-quality.md
```

---

## Task 5: Delete comparison captions

**Depends on:**

### Files touched

- Muskometer/Models/ComparisonLine.swift
- Muskometer/Views/ComparisonCaptionView.swift
- Muskometer/Services/ComparisonLineSelector.swift
- Muskometer/Services/ComparisonHistoryStore.swift
- Muskometer/Views/PopoverContentView.swift
- Muskometer/ViewModels/GainsViewModel.swift
- Muskometer/Utilities/AppSettings.swift
- Muskometer.xcodeproj/project.pbxproj
- MuskometerTests/MuskometerTests.swift

### Steps

- [ ] Delete the four source files listed above.
- [ ] Remove pbxproj `PBXBuildFile` / `PBXFileReference` / group / Sources entries for IDs `A100/A200 …2B, 2E, 3A, 3B`. Do not recycle those IDs.
- [ ] `PopoverContentView`: remove `ComparisonCaptionView(line: viewModel.comparisonLine)`. Order becomes ownership → combined → daily records → stock rows → parity.
- [ ] `GainsViewModel`: remove `comparisonLine`, `comparisonLineSelector`, `lastComparisonStateByPerson`, `updateComparisonLineIfNeeded`, constructor parameter, and all call sites. Remove `tradingDayCalendar` stored property and constructor parameter (only used to debounce captions).
- [ ] `AppSettings.resetPersistedState`: remove `ComparisonHistoryStore.resetPersistedState`. Add a private helper that deletes `comparisonHistoryEntries` and `comparisonHistoryEntries_<personID>` (at least `musk`). Call it from `resetPersistedState` and from `init` after other migrations (load-time sweep).
- [ ] Delete test types: `ComparisonLibraryTests`, `ComparisonHistoryStoreTests`, `ComparisonLineSelectorTests`, `GainsViewModelComparisonDebounceTests`, and `SeededComparisonRandomizer` if it lived on the selector file.
- [ ] Grep `Muskometer/` and `MuskometerTests/` for `ComparisonLine`, `comparisonLine`, `ComparisonCaption`, `ComparisonHistory`, `ComparisonLibrary`, `tradingDayCalendar` — zero remaining product/test references (docs/CHANGELOG history may keep the words).
- [ ] `swiftc -typecheck` via `MUSKOMETER_SKIP_LIVE_YAHOO=1` is not required yet; run `xcodebuild test` filtered to a remaining VM test plus typecheck if needed. Full verify is Task 10.
- [ ] Commit: `Remove comparison captions and unused calendar debounce`

### Implementer dispatch

````
MARSHAL_TASK_ID: 5
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: implementer

Implement Task 5: Delete comparison captions.

Worktree: /Users/jlgolson/grok/muskometer/.worktrees/jordan/holdings-surface-refresh
Spec §4. Delete end-to-end. No replacement caption. Sweep leftover UserDefaults keys on load and Reset.

When you finish, report DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
followed by a one-paragraph summary.
````

### Spec-reviewer dispatch

```
MARSHAL_TASK_ID: 5
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: spec-reviewer

Review Task 5 vs spec §4. Verdict: docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-5-spec.md
```

### Code-quality-reviewer dispatch

```
MARSHAL_TASK_ID: 5
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: code-quality-reviewer

Review Task 5 quality. Verdict: docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-5-quality.md
```

---

## Task 6: Drop unused currentTSLAPrice

**Depends on:**

### Files touched

- Muskometer/Utilities/MergerMarketCapParity.swift
- Muskometer/Views/MergerParityCardView.swift
- MuskometerTests/MuskometerTests.swift

### Steps

- [ ] Remove `currentTSLAPrice` from `MergerParityPresentation` and from `presentation(...)` construction.
- [ ] Remove preview argument in `MergerParityCardView`.
- [ ] Remove assertions at the three test sites that currently `XCTAssertEqual(presentation.currentTSLAPrice, ...)`.
- [ ] Grep `currentTSLAPrice` — zero remaining.
- [ ] Run merger parity tests — pass.
- [ ] Commit: `Remove unused currentTSLAPrice from parity presentation`

### Implementer dispatch

````
MARSHAL_TASK_ID: 6
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: implementer

Implement Task 6: Drop unused currentTSLAPrice.

Worktree: /Users/jlgolson/grok/muskometer/.worktrees/jordan/holdings-surface-refresh
Spec §6 dead field.

When you finish, report DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
followed by a one-paragraph summary.
````

### Spec-reviewer dispatch

```
MARSHAL_TASK_ID: 6
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: spec-reviewer

Review Task 6. Verdict: docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-6-spec.md
```

### Code-quality-reviewer dispatch

```
MARSHAL_TASK_ID: 6
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: code-quality-reviewer

Review Task 6 quality. Verdict: docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-6-quality.md
```

---

## Task 7: Product docs and Settings holdings copy

**Depends on:** 3, 4, 5

### Files touched

- Muskometer/Views/SettingsView.swift
- docs/HOLDINGS.md
- README.md
- docs/PRIVACY.md
- docs/ARCHITECTURE.md

### Steps

- [ ] Settings Holdings caption (the Form 4-only sentence): say Form 4 ownership syncs daily **and** issuer outstanding is best-effort on the same cadence (companyfacts; SPCX often stays on the cover/Cursor default).
- [ ] README keyboard table: add **⌘⇧C** → copy share (image or text per Settings). Keep ⌘R / ⌘, / Esc.
- [ ] HOLDINGS.md: TSLA default 710,172,677; SPCX default 5,116,475,230; aggregation = last-row-wins Class A+B **plus vested option underlying shares**; **do not** add remarks performance RSUs. Name 350M options and excluded 1.302B SpaceX/AI CEO Awards. Outstanding table: SPCX 13,571,069,199 = cover A+B + Cursor 8-K item (i) 389,289,254 (accession `0001628280-26-056945`).
- [ ] PRIVACY.md: add share format, update-notify flag, daily-record extremes, sparkline samples, gain-threshold IDs. Do not list comparison history. “Current public release” becomes **0.1.5** (version strings in Task 9 may already say this — if Task 9 has not run, set 0.1.5 here).
- [ ] ARCHITECTURE.md: already updated for 2028 in Task 2; add a sentence that comparison captions are gone if any mention remains. Remove selector mentions.
- [ ] Commit: `Docs and Settings copy for sellable ownership and outstanding`

### Implementer dispatch

````
MARSHAL_TASK_ID: 7
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: implementer

Implement Task 7: Product docs and Settings holdings copy.

Worktree: /Users/jlgolson/grok/muskometer/.worktrees/jordan/holdings-surface-refresh
Spec §6 docs + HOLDINGS messaging. Do not write CHANGELOG or pbxproj version here (Task 9).

When you finish, report DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
followed by a one-paragraph summary.
````

### Spec-reviewer dispatch

```
MARSHAL_TASK_ID: 7
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: spec-reviewer

Review Task 7 vs spec HOLDINGS/Settings/PRIVACY/README. Verdict: docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-7-spec.md
```

### Code-quality-reviewer dispatch

```
MARSHAL_TASK_ID: 7
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: code-quality-reviewer

Review Task 7 quality. Verdict: docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-7-quality.md
```

---

## Task 8: Marketing screenshots and HTML mock

**Depends on:** 5

### Files touched

- docs/screenshots/app-capture.png
- docs/screenshots/app-preview.png
- docs/screenshots/og-image.png
- docs/screenshots/render-popover.html
- docs/screenshots/render-og.html
- docs/index.html
- docs/README.md
- scripts/verify.sh

### Steps

- [ ] Rebuild `render-popover.html` (or add `render-capture.html`) as a faithful mock of the post-change popover: ownership, combined, sparkline, **single Copy** control, records, TSLA/SPCX rows, **parity card**, 9:30-style next-open if shown. Must **not** include Post to X, comparison caption, or 4:00 AM.
- [ ] Generate/replace `app-capture.png`, then composite `app-preview.png` and `og-image.png`. If Chrome headless is available, document the command in `docs/README.md`. PNGs are the shipped artifact.
- [ ] `docs/index.html` + `render-og.html`: drop “minute by minute, every day”; feature blurb must not advertise comparison captions; screenshot alt mentions parity card, not Post to X.
- [ ] Add a `verify.sh` section that **fails** if `docs/index.html` or `docs/screenshots/render-*.html` contain `Post to X` or `comparison caption` (case-insensitive).
- [ ] Commit: `Refresh marketing screenshots and site copy for 0.1.5 popover`

### Implementer dispatch

````
MARSHAL_TASK_ID: 8
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: implementer

Implement Task 8: Marketing screenshots and HTML mock.

Worktree: /Users/jlgolson/grok/muskometer/.worktrees/jordan/holdings-surface-refresh
Spec §5. HTML mock is accepted. No OCR. verify.sh grep is required.

When you finish, report DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
followed by a one-paragraph summary.
````

### Spec-reviewer dispatch

```
MARSHAL_TASK_ID: 8
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: spec-reviewer

Review Task 8 vs spec §5. Verdict: docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-8-spec.md
```

### Code-quality-reviewer dispatch

```
MARSHAL_TASK_ID: 8
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: code-quality-reviewer

Review Task 8 quality. Verdict: docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-8-quality.md
```

---

## Task 9: Version 0.1.5 / build 26 and CHANGELOG from the branch diff

**Depends on:** 1, 2, 3, 4, 5, 6, 7, 8

### Files touched

- Muskometer.xcodeproj/project.pbxproj
- CHANGELOG.md
- README.md
- docs/INSTALL.md
- docs/RELEASE.md
- docs/PRIVACY.md
- SECURITY.md

### Steps

- [ ] Set all four `MARKETING_VERSION` to `0.1.5` and all four `CURRENT_PROJECT_VERSION` to `26` in `project.pbxproj` (app + test, Debug + Release).
- [ ] Update current-release strings: README DMG example, INSTALL DMG name, RELEASE “current: v0.1.5” and shipping-version examples, PRIVACY “current public release”, SECURITY “Current public release line (0.1.5)”.
- [ ] Author CHANGELOG from the **actual branch diff**, not from this plan’s prose:
  - `git log origin/main..HEAD`
  - `git diff origin/main..HEAD --stat`
  - Promote `## [Unreleased]` bullets into `## [0.1.5] - 2026-08-17` covering what actually landed (ownership seeds, calculator rule, outstanding bump, 2028 calendar, comparison removal, screenshots/docs, version tick). Leave `## [Unreleased]` empty above it.
- [ ] Do **not** git-tag, do **not** add `dist/` artifacts.
- [ ] Commit: `Release 0.1.5 (build 26)`

### Implementer dispatch

````
MARSHAL_TASK_ID: 9
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: implementer

Implement Task 9: Version 0.1.5 / build 26 and CHANGELOG from the branch diff.

Worktree: /Users/jlgolson/grok/muskometer/.worktrees/jordan/holdings-surface-refresh
Spec version tick. Author CHANGELOG bullets from `git log origin/main..HEAD` and `git diff origin/main..HEAD` — do not paraphrase the plan.

When you finish, report DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
followed by a one-paragraph summary.
````

### Spec-reviewer dispatch

```
MARSHAL_TASK_ID: 9
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: spec-reviewer

Review Task 9 vs spec version/CHANGELOG. Verdict: docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-9-spec.md
```

### Code-quality-reviewer dispatch

```
MARSHAL_TASK_ID: 9
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: code-quality-reviewer

Review Task 9 quality. Verdict: docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-9-quality.md
```

---

## Task 10: Verify production path

**Depends on:** 9

### Files touched

- scripts/verify.sh

### Steps

**WHAT:** The 0.1.5 product path typechecks, unit-tests, release-builds, keeps sandbox entitlements, rejects stale marketing strings, and uses the pinned sellable-ownership / outstanding / version integers.

**HOW:** From the feature worktree run:

```
MUSKOMETER_SKIP_LIVE_YAHOO=1 ./scripts/verify.sh
```

Confirm exit 0 and the script’s “All automated checks passed” line. Also confirm (grep or `plutil`/pbxproj read):

- `MARKETING_VERSION = 0.1.5` and `CURRENT_PROJECT_VERSION = 26` (four each)
- `SPCXHoldings.defaultShareCount` is `5_116_475_230`
- `IssuerSharesOutstanding.defaultSPCX` is `13_571_069_199`
- `docs/index.html` and `docs/screenshots/render-*.html` do not contain `Post to X` or `comparison caption`

**WHO:** This task. The implementer runs the command in-plan and pastes the tail of the output in the DONE summary.

- [ ] Run the command above. On failure, fix only regressions introduced by this branch and re-run. Do not skip live-Yahoo skip flag.
- [ ] Commit only if a verify.sh tweak is still needed; otherwise report DONE with the output tail (no empty commit).

### Implementer dispatch

````
MARSHAL_TASK_ID: 10
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: implementer

Implement Task 10: Verify production path.

Worktree: /Users/jlgolson/grok/muskometer/.worktrees/jordan/holdings-surface-refresh
Run MUSKOMETER_SKIP_LIVE_YAHOO=1 ./scripts/verify.sh and the integer/string greps in the task Steps. This is in-plan verification, not post-merge.

When you finish, report DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
followed by a one-paragraph summary including the verify.sh tail.
````

### Spec-reviewer dispatch

```
MARSHAL_TASK_ID: 10
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: spec-reviewer

Review Task 10 verification evidence vs spec acceptance. Verdict: docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-10-spec.md
```

### Code-quality-reviewer dispatch

```
MARSHAL_TASK_ID: 10
MARSHAL_PLAN_SLUG: 2026-08-17-holdings-surface-refresh
MARSHAL_ROLE: code-quality-reviewer

Review Task 10 quality. Verdict: docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/task-10-quality.md
```

---

## Deferred

None.

## Tracker

Resolves: ART-1162

## Self-review

| Spec section | Task |
|--------------|------|
| §1 calculator + seeds + migration | 1, 4 |
| §2 outstanding + remigration | 3 |
| §3 2028 calendar | 2 |
| §4 comparison deletion | 5 |
| §5 marketing PNGs / site | 8 |
| §6 docs, Settings, PRIVACY, README, dead field | 6, 7 |
| Version 0.1.5 / build 26 / CHANGELOG | 9 |
| Acceptance / verify.sh | 10 |
| Non-goals (13G, strike, 8-K parse, Sparkle, tag/DMG) | not tasked |

Placeholder scan: no TBD/TODO in steps. Task IDs 1–10 sequential. Depends: 1→4→7; 3→7; 5→7 and 5→8; 1–8→9→10. Ready-set: 1, 2, 3, 5, 6.

## Scale & Validation

Not applicable: local UserDefaults seeds, static holiday table, UI deletion, static marketing assets. Verification is Task 10 `scripts/verify.sh`.
