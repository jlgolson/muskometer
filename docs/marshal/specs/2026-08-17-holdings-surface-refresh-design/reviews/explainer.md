# Spec explainer: Holdings defaults, 2028 calendar, drop comparison captions, marketing surface

## 1. What is this document?

A design spec for one shipping cycle on `jordan/holdings-surface-refresh`. Status is design (brainstormed). It tells implementers how to land every leftover from the 0.1.4 scout, plus delete comparison captions, in a single PR that becomes public release **0.1.5 (build 26)**. The operator asked not to split the work for marshal-harness overhead.

It names the integers to seed, the UserDefaults fingerprints to rewrite, the comparison files to delete, the 2028 NYSE rows to add, the marketing PNGs to replace, and the docs/version strings that must move off 0.1.4. It also records non-goals, the persisted-state upgrade table, rollback, and the EDGAR/NYSE evidence for each number.

## 2. What problem is the spec trying to solve?

Five leftovers share one framing: the shipped 0.1.4 product and the repo no longer match live filings or current product intent.

Bundled Musk ownership is stale versus Form 4 XML fetched 2026-08-17. Tesla still defaults to 699.6M; the latest direct post-transaction amount is 710,172,677. SpaceX still defaults to 6.069B, which adds 1.302B unvested performance RSUs from remarks and drops 350M fully vested Class B options. The operator rule is sellable ownership: last-row-wins tables plus vested options, no unqualified performance awards — **5,116,475,230**. The current SpaceX migrator still upgrades older fingerprints *toward* the inflated 6.068B figure, so a correct sync can be undone.

SpaceX issuer outstanding still uses the July 28 10-Q cover (13.182B) and ignores the August 14 Cursor 8-K that issued 389M new Class A. Companyfacts for SpaceX is WASO-only. The NYSE holiday table stops at 2027; first 2028 miss is MLK Jan 17. Marketing screenshots are a 0.1.2 popover (Post to X, 4:00 AM next-open, no parity card) while the product now has one Copy control, 9:30 next-open, and the parity card. Site lede still says “minute by minute, every day.” Comparison captions do not earn their keep: the operator wants that block gone, including `ComparisonCaptionView`, the ~4,500-line library, selector, history store, and VM debounce. Same-cycle polish: README omits ⌘⇧C; Settings holdings copy says Form 4 only; PRIVACY prefs are incomplete; unused `MergerParityPresentation.currentTSLAPrice` remains.

## 3. What are the main architectural choices?

1. **Sellable ownership, not the 13G package.** Seed is Form 4 last-row-wins Class A+B plus vested option underlying shares. Remarks performance RSUs (1.302B) are excluded. The Aug 13 13G headline 6.42B is not the target.
2. **Do not subtract option strike.** Mark 350M options at full Class A last. Daily paper gain stays `shares × Δprice`. The ~$2.94B unpaid strike is ignored at trillion scale.
3. **Fingerprint remigration only, on `AppSettings` init.** Listed exact integers rewrite to the new seeds. Any other stored positive value is left alone. Missing keys pick up new bundled defaults. Remigration is idempotent and not automatically reversible. No migration UI.
4. **Invert the SpaceX ownership migrator.** Fingerprints including 6,068,734,060 and 6,068,547,515 move *down* to 5,116,475,230. Tesla: only 699,580,882 rewrites to 710,172,677.
5. **Pinned Cursor outstanding default, not runtime 8-K parsing.** New `defaultSPCX` is 13,571,069,199 (prior A+B plus item (i) 389M). Item (ii) 1.75M vested RSUs stay out. Stored 13,181,779,945 remigrates; Tesla outstanding stays 3,949,547,394.
6. **Hardcoded NYSE 2028 extension, no holiday API.** Keep 2026–2027. Add published 2028 holidays and two early closes (2028-07-03, 2028-11-24). New Year’s 2028 is not observed.
7. **Delete comparison end-to-end, not hide it.** Four source files and matching pbxproj IDs go away. `GainsViewModel` loses the caption API and the `tradingDayCalendar` dependency that only existed to debounce it. Leftover UserDefaults keys are swept on load and Reset.
8. **HTML mock is an accepted screenshot source.** Live AppKit capture is welcome but not a CI requirement.
9. **This cycle is the version tick.** MARKETING_VERSION 0.1.4 → 0.1.5 and CURRENT_PROJECT_VERSION 25 → 26 in all four pbxproj assignments and current-release docs. Git-tag and DMG remain a post-merge maintainer step.
10. **One cycle, one branch.** The operator refused splitting into four PRs.

## 4. What will have to actually get built / changed?

Write 710,172,677 (TSLA) and 5,116,475,230 (SPCX) into `TrackedPersonProfile.musk` holding specs and `SPCXHoldings.defaultShareCount`. Change the SpaceX calculator to count option underlying shares and stop adding remarks restricted shares. Invert `migrateStoredShareCount`, add a Tesla load-path remigration, and remigrate outstanding 13,181,779,945 → 13,571,069,199. Replace the June 2026 calculator fixture with live-shaped XML (By Trust → 0, 350M option row, remarks 1.302B present) expecting 5,116,475,230.

Add 2028 holidays and early closes to `MarketHoursService` and tests (MLK closed, Jan 3 open, Good Friday, July 4, July 3 early close, Thanksgiving and day-after).

Remove `ComparisonLine.swift`, `ComparisonCaptionView.swift`, `ComparisonLineSelector.swift`, `ComparisonHistoryStore.swift`, their pbxproj entries (do not recycle IDs), and the four test types inside `MuskometerTests.swift`. Strip wiring from `PopoverContentView` and `GainsViewModel`. Sweep `comparisonHistoryEntries` keys on load and Reset via a small `AppSettings` helper.

Replace `app-capture.png`, `app-preview.png`, and `og-image.png` so they show one Copy control, 9:30 next-open, and the parity card, and do not show Post to X, comparison captions, or 4:00 AM. Soften the site lede off “minute by minute, every day.” Add ⌘⇧C to README; fix Settings holdings caption; complete PRIVACY prefs; promote CHANGELOG Unreleased to `## [0.1.5] - 2026-08-17`; rewrite HOLDINGS and ARCHITECTURE; tick version strings. Drop `currentTSLAPrice` from `MergerParityPresentation`.

`MUSKOMETER_SKIP_LIVE_YAHOO=1 ./scripts/verify.sh` must pass. Prefer a verify.sh grep that fails if docs HTML still contains “Post to X” or “comparison caption.”

## 5. What does the spec explicitly defer, exclude, or acknowledge as gaps?

**Deferred:** None.

**Excluded (non-goals):** Schedule 13G/13D parsing; targeting the 13G 6.42B headline; subtracting option strike; runtime 8-K/10-Q HTML cover parsing; adding Cursor item (ii) 1.75M or assumed unvested RSUs/options to outstanding; changing Yahoo `includePrePost` or wiring Sparkle; cutting a GitHub Release/DMG in this PR; replacing the hardcoded calendar with a network API; multi-person UI; requiring a live AppKit screenshot in CI.

**Acknowledged gaps / accepted risks:** Fingerprint remigration will also rewrite a user who typed an old default on purpose. Cursor outstanding undercounts by ~1.75M vested RSUs and any later issuance until the next 10-Q. An HTML mock can drift from SwiftUI. Hardcoded 2028 still needs a 2029 pass. Counting every option title would include a later unvested grant; this cycle accepts that the only June 17 option row is F8 fully vested. Strike is ignored. Comparison history keys left on upgrade-without-Reset are swept at load. Binary rollback can re-inflate older SpaceX fingerprints via the old migrator; stored new integers are left as-is. Data revert is not provided.

---

Summary: This spec is one 0.1.5 cycle that reseeds Tesla and SpaceX ownership and SpaceX outstanding from live 2026-08-17 EDGAR, extends the hardcoded NYSE calendar through 2028, deletes comparison captions end-to-end, and replaces marketing PNGs and current-release docs so the public surface matches the post-change popover.

The load-bearing decision is the sellable-ownership rule plus fingerprint-only remigration: Form 4 last-row-wins tables plus 350M vested options (5,116,475,230), no 1.302B remarks performance RSUs, no 13G headline, no strike subtraction; listed old defaults rewrite on `AppSettings` init, every other stored value stays. Outstanding is a pinned Cursor 8-K bump (13,571,069,199), not a new parser.

The binding constraint is one PR that *is* the release: MARKETING_VERSION 0.1.5 / build 26, no feature flag, comparison gone on upgrade, no git-tag or DMG in this cycle.

reviewed-content-sha256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

plan-graph-sha256: 01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b
