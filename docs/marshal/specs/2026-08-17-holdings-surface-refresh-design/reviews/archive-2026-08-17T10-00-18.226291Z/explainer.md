# Spec translation: Holdings defaults, 2028 calendar, drop comparison captions, marketing surface

## 1. What is this document?

A design spec for one cycle on `jordan/holdings-surface-refresh`. Status is design (brainstormed). The operator asked to land every leftover from the 0.1.4 scout, delete comparison captions, and keep the work in one cycle to avoid harness overhead.

It is a build contract: integers to seed, fingerprints to remigrate, files to delete, marketing assets to replace, docs to update, and the version tick from 0.1.4 / build 25 to 0.1.5 / build 26.

## 2. What problem is the spec trying to solve?

Five leftovers share one framing: the shipped 0.1.4 product and the repo no longer match live filings, the published NYSE calendar, or operator intent.

Ownership seeds are stale vs Form 4 XML fetched 2026-08-17. TSLA still defaults to 699,580,882; latest last-direct amount is 710,172,677. SPCX still defaults to 6,068,734,060 (June 17 aggregate plus a 186,545 “By Trust” line later taken to 0 in the same filing). Last-row-wins is 6,068,547,515. Worse, `migrateStoredShareCount` upgrades that correct fingerprint *to* the too-high default, so a correctly synced install is rewritten wrong on next launch.

SPCX outstanding ignores the Cursor 8-K’s 389,289,254 new Class A. Companyfacts is WASO-only, so sync cannot pick this up. Bundled A+B is still 13,181,779,945. The NYSE table stops at 2027; first miss is MLK 2028-01-17. Marketing screenshots still show Post to X, 4:00 AM next-open, and no parity card. Operator wants comparison captions gone — library, view, store, and debounce. Same-cycle polish: ⌘⇧C, Settings/PRIVACY copy, unused `currentTSLAPrice`.

## 3. What are the main architectural choices?

1. **One cycle is the 0.1.5 update.** Four PRs rejected. Release/DMG stay a maintainer step after merge.
2. **Form 4 last-row-wins remains the ownership source of truth.** Daily sync stays Form 4 / 4A only. Options stay excluded.
3. **Fingerprint remigration on `AppSettings` init.** Only exact listed integers rewrite. SPCX inverts: 6,068,547,515 is no longer legacy; 6,068,734,060 migrates *down*. TSLA rewrites only stored 699,580,882. Idempotent, not automatically reversible.
4. **Issuer outstanding stays orthogonal to Musk ownership.** Cursor bump is a pinned default (10-Q cover + 8-K item (i) Class A only). Remigrate only stored 13,181,779,945 → 13,571,069,199. TSLA outstanding stays 3,949,547,394.
5. **Hardcoded NYSE table through 2028**, including the published “no New Year’s 2028” rule. No network holiday API.
6. **Delete comparison end-to-end**, not hide it. No replacement caption or toggle. Sweep leftover UserDefaults keys on load and Reset. Drop `GainsViewModel.tradingDayCalendar` after debounce is gone.
7. **Marketing PNGs are the shipped artifact; a checked-in HTML mock is the accepted source.**

## 4. What will have to actually get built / changed?

New ownership defaults and inverted SPCX migrator; TSLA fingerprint remigration; last-row-wins calculator fixture including By Trust → 0. New `defaultSPCX` 13,571,069,199 and outstanding remigration next to existing types. 2028 holidays plus early closes 2028-07-03 and 2028-11-24, with matching tests.

Delete four comparison sources and pbxproj IDs `A200…2B/2E/3A/3B`. Strip `PopoverContentView`, `GainsViewModel`, and Reset. Delete four test types. Sweep comparison history keys.

Replace the three marketing PNGs from an HTML mock. Soften site/OG lede; no “Post to X” or comparison advertising in `docs/` HTML.

Docs: README ⌘⇧C, Settings Holdings caption, PRIVACY prefs, CHANGELOG 0.1.5 dated 2026-08-17, HOLDINGS/ARCHITECTURE numbers, INSTALL/RELEASE/SECURITY current-release strings. Drop `currentTSLAPrice`. Tick all four `MARKETING_VERSION` and four `CURRENT_PROJECT_VERSION` lines. Do not git-tag or attach `dist/` artifacts.

## 5. What does the spec explicitly defer, exclude, or acknowledge as gaps?

Deferred is None.

Excluded: 13G/13D; runtime 8-K/10-Q HTML parse; the 1,752,426 vested-RSU line and assumed unvested RSUs/options; Yahoo `includePrePost` and Sparkle; cutting a GitHub Release / DMG; a network holiday API; multi-person UI; live AppKit screenshot as a CI requirement.

Acknowledged: remigrating exact old defaults would also rewrite a user who typed those integers (accepted). Omitting 1.75M vested RSUs leaves the parity card slightly stale. HTML mock can drift from SwiftUI. 2028 still needs a 2029 pass. Binary revert of the old build may rewrite SPCX *up* again; new Tesla and outstanding integers stay stored. Data revert is not provided. Open questions: none remaining.

Summary: This spec proposes one 0.1.5 (build 26) cycle that reseeds Form 4-accurate ownership and cover-plus-Cursor outstanding, inverts the SPCX migrator that currently inflates a correct last-row-wins total, extends the NYSE calendar through 2028, deletes comparison captions, and replaces marketing PNGs and site copy so the public surface matches the post-change popover.

The load-bearing decision is fingerprint remigration on `AppSettings` init: only the listed exact old integers rewrite, the SPCX direction inverts so 6,068,547,515 is no longer treated as legacy, issuer outstanding stays orthogonal to Musk ownership, and comparison is deleted rather than hidden.

The most important constraint is that remigration is idempotent and not automatically reversible, and a binary revert can reintroduce the upward SPCX rewrite. Options stay excluded, the 1.75M vested-RSU line stays out, and this PR must not cut the GitHub Release.

reviewed-content-sha256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

plan-graph-sha256: 01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b
