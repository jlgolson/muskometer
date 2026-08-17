# Plan→Spec Translator Review

**Role:** plan-to-spec-translator  
**Plan:** `docs/marshal/plans/2026-08-17-holdings-surface-refresh.md`  
**Spec:** `docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md`  
**Date:** 2026-08-17

Method: plan read cold first (four produces sections), then the design opened and compared.

Cold hypotheses before opening the spec: a plan like this would most plausibly be wrong by (1) inventing new Swift compile units the design did not ask for, (2) dropping a leftover (calculator rule, TSLA remigration, outstanding remigration, 2028 rows, comparison sweep, marketing PNGs, version tick), (3) using different pinned integers, (4) hiding comparison instead of deleting it, (5) leaving non-goals as tasks (13G, strike ledger, 8-K HTML parse, Sparkle, git-tag/DMG), (6) verifying something narrower than `scripts/verify.sh`, or (7) Task 7 HOLDINGS steps omitting the strike-mark sentence or the four named accessions. Those are checked after Part A.

---

## Part A — What plan execution produces (cold plan only)

### 1. What new files will exist?

No required new Swift types, test files, or schema migrations. Tests stay inside `MuskometerTests/MuskometerTests.swift`. Outstanding remigration is a helper on the existing `IssuerSharesOutstanding` / `AppSettings` path, not a new compile unit.

Optional new file: `docs/screenshots/render-capture.html` if the implementer adds a capture mock instead of evolving `render-popover.html`. PNGs are the shipped artifact; HTML is the source.

The product tree loses four files: `Muskometer/Models/ComparisonLine.swift`, `Muskometer/Views/ComparisonCaptionView.swift`, `Muskometer/Services/ComparisonLineSelector.swift`, and `Muskometer/Services/ComparisonHistoryStore.swift`, plus their pbxproj `A100`/`A200` `…2B`/`2E`/`3A`/`3B` entries (IDs not recycled). `SeededComparisonRandomizer` goes with the selector file.

### 2. What existing files will be modified?

| Path | Change |
|------|--------|
| `SPCXOwnershipCalculator.swift` | Stop zeroing option titles; delete `restrictedShares(from:)` addend/helper |
| `SPCXHoldings.swift` | `defaultShareCount` → `5_116_475_230`; invert `migrateStoredShareCount` fingerprints |
| `TrackedPersonProfile.swift` | Musk TSLA seed `710_172_677`; SPCX seed `5_116_475_230` |
| `IssuerSharesOutstanding.swift` | `defaultSPCX` → `13_571_069_199`; fingerprint migrate helper |
| `AppSettings.swift` | TSLA ownership remigrate `699_580_882`; SPCX outstanding remigrate `13_181_779_945`; comparison-key sweep on init and Reset |
| `MarketHoursService.swift` | 2028 holidays + early closes `2028-07-03` / `2028-11-24`; comments 2026–2028 |
| `GainsViewModel.swift` | Strip comparison API, selector, debounce state, and `tradingDayCalendar` |
| `PopoverContentView.swift` | Remove caption view; order ownership → combined → records → rows → parity |
| `MergerMarketCapParity.swift` + `MergerParityCardView.swift` | Drop `currentTSLAPrice` |
| `SettingsView.swift` | Holdings caption mentions Form 4 **and** outstanding cadence |
| `project.pbxproj` | Delete comparison IDs; `MARKETING_VERSION` `0.1.5`; `CURRENT_PROJECT_VERSION` `26` (four pairs) |
| `MuskometerTests.swift` | Calculator/option/remarks tests; 2028 calendar; remigration; delete four comparison test types; parity asserts |
| Marketing: `docs/screenshots/{app-capture,app-preview,og-image}.png`, `render-popover.html`, `render-og.html`, `docs/index.html`, `docs/README.md` | Post-change popover mock; no Post to X / comparison / 4:00 AM; RTH lede |
| Docs: `docs/HOLDINGS.md`, `docs/ARCHITECTURE.md`, `README.md`, `docs/PRIVACY.md`, `CHANGELOG.md`, `docs/INSTALL.md`, `docs/RELEASE.md`, `SECURITY.md` | Seeds, strike-mark + four accessions, 2028 table, ⌘⇧C, prefs, 0.1.5 strings, dated CHANGELOG |
| `scripts/verify.sh` | Fail on `Post to X` / `comparison caption` in site HTML |

### 3. What new behaviors will the system have?

Fresh install, Reset, and fingerprint-matched upgrades seed **sellable** ownership: TSLA **710,172,677**; SPCX **5,116,475,230** (last-row-wins Class A+B **4,766,475,230** + vested option underlying **350,000,000**). The June 17 Form 4 calculator counts option titles 1:1 and does **not** add remarks performance RSUs (**1,302,072,285**). Stored SPCX `6_068_734_060`, `6_068_547_515`, and older fingerprints rewrite down; stored TSLA `699_580_882` rewrites up; any other positive stored count stays.

Issuer outstanding (parity card only) becomes **13,571,069,199** (10-Q A+B + Cursor 8-K item (i) **389,289,254**). Stored `13_181_779_945` remigrates; other positive outstanding stays. TSLA outstanding stays **3,949,547,394**.

NYSE tables include 2028 holidays (no observed New Year’s close) and early closes 2028-07-03 and 2028-11-24. First miss closed today — MLK 2028-01-17 — is closed.

The popover no longer shows “today’s loss equals / today’s gain could…”. Comparison library, selector, history store, VM debounce, and leftover `comparisonHistoryEntries` / `comparisonHistoryEntries_<id>` keys are gone (swept on load and Reset). No replacement caption or toggle.

Public PNGs and site copy match the post-change chrome: one Copy control, 9:30 next-open, parity card, no Post to X, no comparison line, no “minute by minute, every day.” Shipping identity is **0.1.5 / build 26**. `MergerParityPresentation` no longer carries `currentTSLAPrice`. README lists ⌘⇧C. Settings/PRIVACY/HOLDINGS/ARCHITECTURE match the new numbers and remaining prefs. HOLDINGS states 350M options marked at the Class A last (Class B 1:1), ~$2.94B unpaid strike ignored, and names accessions `0001104659-26-075213`, `0001628280-26-044069`, `0001628280-26-052535`, `0001628280-26-056945`.

### 4. What is the plan explicitly NOT doing?

Not tasked / non-goals: Schedule 13G/13D (do not seed **6,418,547,515**); subtracting option strike (~$2.94B); runtime 8-K/10-Q HTML parse; adding 8-K item (ii) 1,752,426 or assumed unvested RSUs/options; Yahoo `includePrePost` or Sparkle wiring; git-tag, `dist/`, or cutting a GitHub Release/DMG; network holiday API; multi-person UI; live AppKit screenshot as a CI requirement (HTML mock accepted); OCR of PNGs; splitting the cycle; leaving marketing version at 0.1.4. Deferred is the literal none. `## Deferred` in the plan is empty.

---

## Part B — Spec comparison (after reading design)

### Map: description items → spec sections

| Description item | Spec section |
|------------------|--------------|
| Calculator: options count, remarks out, delete `restrictedShares`, fixture `5_116_475_230` | Design §1 calculator rule + parser/fixture; Testing; AC5 |
| TSLA/SPCX seeds + inverted SPCX fingerprints + TSLA `699_580_882` remigrate | Design §1 seeds/migration; Goals; Upgrade contract; AC1–3 |
| Cursor outstanding `13_571_069_199` + remigrate `13_181_779_945` | Design §2; Goals; Upgrade contract; AC1, AC4 |
| 2028 holidays/early closes + ARCHITECTURE table | Design §3; AC6 |
| Delete four comparison sources, VM/calendar, tests, pbxproj IDs, key sweep | Design §4 + §7; Goals; Upgrade contract; AC7 |
| Marketing PNGs, HTML mock, site lede, verify.sh grep | Design §5; Testing; AC8 |
| Settings holdings caption, README ⌘⇧C, PRIVACY prefs, HOLDINGS aggregation/outstanding/strike-mark/four accessions | Design §1 last para; §2 HOLDINGS table; §6; Compliance; AC9 |
| Drop `currentTSLAPrice` | Design §6 dead field; AC10 |
| Version 0.1.5 / build 26, current-release strings, CHANGELOG 0.1.5 | Design §6 version tick; Goals; Rollout; AC11 |
| `verify.sh` production path | Acceptance AC12; Testing; Scale & Validation |
| Non-goals (13G, strike, 8-K parse, Sparkle, tag/DMG, holiday API, multi-person, live screenshot CI) | Non-goals; Alternatives; Rollout |

Task graph vs design: T1 calculator → T4 seeds; T3 outstanding; T2 calendar; T5 comparison; T6 dead field; T7 docs after 3/4/5; T8 marketing after 5; T1–8 → T9 version/CHANGELOG → T10 verify. Ready-set 1, 2, 3, 5, 6 matches independent leftovers.

Hypothesis check: (1) no required new Swift files — matches §7. (2) every leftover has a task. (3) pinned integers match the spec table. (4) deletion not hide. (5) non-goals not tasked. (6) Task 10 is the same `MUSKOMETER_SKIP_LIVE_YAHOO=1 ./scripts/verify.sh` as CI. (7) Task 7 HOLDINGS now states the Class A last / ignored-strike sentence and names all four accessions.

### Spec sections with no plan item

Process / non-deliverable sections that correctly have no implementer task: Problem framing, Current architecture, Risks (accepted), Observability (“none”), Open questions (“none remaining”), Rollback, Alternatives considered, Dependencies/external contracts (evidence only), Deferred (none), Scale & Validation (N/A except Task 10).

`AppVersion.short` / SEC User-Agent already read `MARKETING_VERSION` via Info.plist; spec §6’s “do not hardcode a second source” is a non-change and is correctly un-tasked. Design §4 “any DEVELOPING/ARCHITECTURE mention of the selector”: Task 7 covers ARCHITECTURE; `docs/DEVELOPING.md` currently has no selector/comparison mention, so the DEVELOPING half is vacuously satisfied.

No functional / docs requirement inside tasked sections is left off a task checklist.

### Plan items with no spec backing

None that add product surface. Task 8’s required `verify.sh` grep is the spec Testing “prefer”. Task 9 authoring CHANGELOG from `git log`/`git diff` is process around spec §6’s dated 0.1.5 section. Task 10 integer greps harden AC11–12. Optional `render-capture.html` is allowed by §5. Tracker `ART-1162` is not a product change.

No task implements a non-goal.

---

## Part C — Verdict summary

The ten tasks are a faithful decomposition of Design §§1–7, Goals, Testing, Acceptance 1–12, Upgrade contract, Compliance messaging, and the version/rollout tick. New-file set is empty except an optional HTML mock. Comparison is deleted. Integers match. Non-goals stay out. Task 7 HOLDINGS steps now carry the §1 strike-mark sentence and the Compliance four-accession naming.

## Findings

None.

VERDICT: APPROVED

Reviewed-files: docs/marshal/plans/2026-08-17-holdings-surface-refresh.md, docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md, docs/HOLDINGS.md, docs/DEVELOPING.md, docs/ARCHITECTURE.md, Muskometer/Utilities/AppVersion.swift

reviewed-content-sha256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
