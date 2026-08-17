# Spec explainer: Holdings defaults, 2028 calendar, drop comparison captions, marketing surface

## 1. What is this document?

A **design-stage** product/engineering spec for **Muskometer** (macOS menu-bar app) on branch `jordan/holdings-surface-refresh`. Status is “design (brainstormed)”: leftover 0.1.4 scout items plus one deletion, written as one implementation cycle with acceptance criteria, an upgrade contract, and rollback notes. Implementation is not claimed done.

Scope is five leftovers under one framing — shipped 0.1.4 and the repo no longer match live filings or current UI — plus same-pass polish (README **⌘⇧C**, Settings holdings copy, PRIVACY prefs, drop unused `MergerParityPresentation.currentTSLAPrice`). The operator asked not to split the cycle for marshal-harness overhead. App version stays **0.1.4 / build 25**.

## 2. What problem is the spec trying to solve?

Bundled seeds, the NYSE table, and marketing no longer match 2026-08-17 reality, and one migrator rewrites a correct SpaceX ownership number the wrong way.

Tesla’s default is still 699,580,882; the latest Musk Form 4 last-direct row is 710,172,677. SpaceX’s default is 6,068,734,060 — June 17 Form 4 aggregate plus a 186,545 “By Trust” Class A line that a later transaction in the same filing takes to 0. Last-row-wins parse is 6,068,547,515. `SPCXHoldings.migrateStoredShareCount` currently **upgrades** that correct fingerprint *to* the too-high default, so an install that already synced June 17 correctly gets rewritten wrong on next launch.

SpaceX 8-K 2026-08-14 issued 389,289,254 new Class A as merger consideration. SPCX companyfacts is still WASO-only, so outstanding sync cannot pick this up; bundled A+B is still the July 28 10-Q cover 13,181,779,945. `MarketHoursService` stops at 2027; official NYSE 2028 is published; first miss is MLK 2028-01-17. Site PNGs still show a 0.1.2 popover (Post to X, “Opens Mon 4:00 AM EDT”, no parity card). Product after 0.1.3/0.1.4 has one Copy control, next-open 9:30, and the parity card. Site lede still says “minute by minute, every day.” Operator: remove the “today’s loss equals / today’s gain could…” block — `ComparisonCaptionView`, the ~4,500-line library, selector, history store, and VM debounce.

**Goal state:** fresh / Reset / fingerprint-migrated installs seed Form 4-accurate ownership and cover+Cursor outstanding; the SPCX upward rewrite is inverted; NYSE tables run through 2028; comparison is gone end-to-end; marketing matches the post-change popover.

## 3. What are the main architectural choices?

1. **Fingerprint remigration only.** Rewrite stored ownership or outstanding only when the integer equals a listed old default. Manual overrides, later Form 4s, and future companyfacts hits stay. Missing keys pick up new bundled defaults via existing fallbacks.

2. **Invert the SPCX ownership migrator.** New default is 6,068,547,515. Treat 6,068,734,060 as a *new* legacy fingerprint and migrate *down*. Stop treating 6,068,547,515 as legacy. Keep migrating older fingerprints (60,685,475; 842,091,670; 7,402,770) to the new default. Tesla uses the same load-path pattern: 699,580,882 → 710,172,677 only. Write the same integers in `TrackedPersonProfile.musk` holding specs *and* `SPCXHoldings.defaultShareCount`.

3. **Outstanding stays orthogonal to Form 4 ownership.** Cursor Class A issuance is a **pinned default bump**, not runtime 8-K HTML parse. New A+B is 13,571,069,199. Tesla outstanding stays 3,949,547,394. Do not add 8-K item (ii) vested-RSU or item (iii) assumed unvested RSUs/options. Daily sync stays Form 4 / 4A; the Aug 13 13G 6,418,547,515 figure includes 350M options, which stay excluded.

4. **Hardcoded NYSE 2028 from the official table**, including the published “no New Year’s 2028” rule (Saturday Jan 1, no observed close). Two early closes (2028-07-03, 2028-11-24). No invented 2027-12-31 or 2028-01-01 closes. No network holiday API.

5. **Delete comparison end-to-end**, not hide the view. No replacement caption, toggle, or empty placeholder. Popover order becomes combined card → daily records (if any) → stock rows → parity card. Leftover UserDefaults keys are swept on Reset and on settings load. After the strip, unused `GainsViewModel.tradingDayCalendar` is deleted with its constructor parameter.

6. **`AppSettings` init is the upgrade hook.** No migration UI, no version gate. Remigration is idempotent and not automatically reversible. Marketing PNGs come from a checked-in HTML mock (live AppKit capture welcome, not a CI requirement). Stay at 0.1.4 / build 25.

## 4. What will have to actually get built / changed?

Ownership defaults become Tesla 710,172,677 and SpaceX 6,068,547,515. The SpaceX migrator inverts (6,068,734,060 down; 6,068,547,515 passes through; older fingerprints remap). Tesla rewrites stored 699,580,882 only. `defaultSPCX` becomes 13,571,069,199 with remigration of stored 13,181,779,945 only. The June 2026 SpaceX Form 4 fixture must include the By Trust → 0 row and expect 6,068,547,515.

`MarketHoursService` adds 2028 holidays and two early closes, plus tests. Comparison is deleted as four source files and pbxproj IDs `A100`/`A200` …`2B`/`2E`/`3A`/`3B`, stripped from the VM, popover, and reset path, with four test types removed and `tradingDayCalendar` dropped from `GainsViewModel`. An `AppSettings` helper deletes leftover `comparisonHistoryEntries` / `comparisonHistoryEntries_<id>` on load and Reset. `currentTSLAPrice` leaves `MergerParityPresentation` and its calculator, preview, and tests.

Marketing replaces the three PNGs from an HTML mock, softens “minute by minute, every day”, and drops “Post to X” from `docs/` HTML. Docs: HOLDINGS numbers and accessions, ARCHITECTURE 2026–2028, README ⌘⇧C, Settings holdings caption, PRIVACY remaining prefs, CHANGELOG Unreleased. Gate is `MUSKOMETER_SKIP_LIVE_YAHOO=1 ./scripts/verify.sh`, preferably with a grep that docs HTML does not contain “Post to X” or “comparison caption”. Do not OCR PNGs.

## 5. What does the spec explicitly defer, exclude, or acknowledge as gaps?

**Deferred:** None.

**Non-goals:** Schedule 13G/13D (sync stays Form 4/4A); runtime 8-K/10-Q HTML cover parsing; adding 1,752,426 vested-RSU Class A or assumed unvested RSUs (~29.1M) / options (~44.4M); changing Yahoo `includePrePost`, Sparkle, or `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`; a network holiday API; multi-person UI (`registry` is still `[.musk]`); live AppKit screenshot as a CI requirement.

**Risk-acceptances:** remigration rewrites a user who typed the exact old default as an override (same policy as prior SpaceX migrations); Cursor outstanding undercount until the next 10-Q cover or a companyfacts point-in-time concept (HOLDINGS must say the default is 10-Q cover plus 8-K item (i)); HTML mock can drift from SwiftUI (review against `PopoverContentView`); hardcoded 2028 still needs a 2029 pass; comparison history keys left behind on upgrade-without-Reset (load-time + Reset sweep); binary revert reintroduces the old SpaceX upward rewrite, while Tesla 710,172,677 and outstanding 13,571,069,199 stay stored. Data revert is not provided.

**Messaging:** do not describe the Cursor bump as a change in Musk’s stake; ownership copy stays “Form 4 / Class A-equivalent”; outstanding copy stays “issuer shares for the parity card only”; entertainment disclaimer unchanged; no new legal surface.

## Summary

This spec is one cycle to bring Muskometer’s bundled ownership and outstanding numbers, NYSE calendar, marketing screenshots, and popover surface in line with live 2026-08-17 filings and the post-0.1.4 UI — and to delete comparison captions completely. Fresh and Reset installs get Tesla 710,172,677 and SpaceX 6,068,547,515 ownership plus SpaceX outstanding 13,571,069,199 (July 28 10-Q cover plus Cursor 8-K Class A issuance). Stored values are rewritten only when they match those old bundled fingerprints; the SpaceX migrator that currently inflates a correct last-row-wins total is inverted so that number is no longer treated as legacy.

The load-bearing decision is fingerprint-only remigration plus a pinned Cursor outstanding bump, with comparison deleted rather than hidden, all without a version gate or a 0.1.5 tick. The main limitation the spec accepts is that issuer outstanding will stay slightly under the 8-K’s full share picture (no vested-RSU / unvested RSU / options lines, no runtime 8-K parse) until a later cover or companyfacts concept appears, and that a binary revert would turn the old SpaceX upward migrator back on.
