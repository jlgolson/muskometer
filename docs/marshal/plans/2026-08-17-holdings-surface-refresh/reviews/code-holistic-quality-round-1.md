# Code holistic quality review — round 1

**Role:** code-holistic-quality  
**Plan:** `docs/marshal/plans/2026-08-17-holdings-surface-refresh.md`  
**Spec:** `docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md`  
**Date:** 2026-08-17  
**Context:** Cold whole-diff quality of product + tests + shipping docs (organization, tests, clarity, patterns, leftover comparison, stale version strings). Not a re-score of per-task gates.

## Scope

Reviewed the live tree at HEAD against Design §§1–7 and the ten-task plan. Surfaces:

| Layer | Surfaces |
|-------|----------|
| Calculator | `SPCXOwnershipCalculator` — options in, `restrictedShares` gone |
| Seeds | `SPCXHoldings`, `TrackedPersonProfile.musk`, `IssuerSharesOutstanding` |
| Settings | `loadShareCounts` / `loadSharesOutstanding` persist-if-changed; caption-history sweep |
| Calendar | `MarketHoursService` 2026–2028 holidays + early closes |
| VM / UI | `GainsViewModel` (no comparison / `tradingDayCalendar`); `PopoverContentView` order; `MergerParityPresentation` three fields |
| Project | pbxproj comparison IDs gone, not recycled; four `0.1.5` / `26` pairs |
| Tests | calculator, remigration, 2028 calendar, outstanding, seed asserts; four comparison types deleted |
| Marketing / docs | HTML mock + PNGs, HOLDINGS / ARCHITECTURE / PRIVACY / README / CHANGELOG / current-release strings |
| Gate | `scripts/verify.sh` §6 marketing grep |

Excluded from the fix bar: marshal plan/spec/review prose, historical CHANGELOG 0.1.1–0.1.4, build artifacts under `build/`.

## What landed cleanly

Trust these without re-reading:

- **Sellable ownership is one rule.** Calculator counts option underlying 1:1 (`title.contains("option")` first), ignores remarks. June 17 live-shaped fixture (By Trust → 0, 350M option, remarks 1.302B present) returns `5_116_475_230`. Seeds match in `SPCXHoldings.defaultShareCount` and `TrackedPersonProfile.musk`.
- **Fingerprint remigration is the same persist-if-changed `String(Int64)` shape on three disjoint keys.** SPCX ownership, TSLA `699_580_882`, SPCX outstanding `13_181_779_945`. Targets are not members of the legacy sets, so a second `AppSettings` init is a no-op.
- **Outstanding stays orthogonal.** `defaultSPCX = 13_181_779_945 + 389_289_254`. Form 4 keys never write outstanding. TSLA outstanding stays `3_949_547_394`.
- **Comparison is deleted, not hidden.** Zero `ComparisonLine` / `comparisonLine` / `ComparisonCaption` / `ComparisonHistory` / `ComparisonLibrary` / `tradingDayCalendar` / `currentTSLAPrice` / `restrictedShares` in `Muskometer/` and `MuskometerTests/`. pbxproj IDs `…2B` / `2E` / `3A` / `3B` are not recycled. Popover order is ownership → combined → records → rows → parity.
- **Shipping identity is one source.** Four `MARKETING_VERSION = 0.1.5` and four `CURRENT_PROJECT_VERSION = 26`. `AppVersion.short` still reads the plist macros. Current-release docs name 0.1.5. `## [Unreleased]` is empty above `## [0.1.5] - 2026-08-17`. No tag, no `dist/`.

## Organization

No new product compile units. Outstanding remigration sits on `IssuerSharesOutstanding`. Caption-history sweep is a private `AppSettings` helper, not a kept store type. Marketing added `render-capture.html` + `render-pngs.swift` next to the existing Pages pipeline — allowed by §5, not a new app target.

Tests stay inside `MuskometerTests.swift` (repo convention). Deletion removed four test types rather than stubbing them. `TradingDayCalendar` remains a daily-records utility; only the VM debounce dependency is gone.

Ownership vs outstanding vocabulary stays separated at keys, loaders, UI consumers, and docs.

## Patterns

Remigration, seed comments, and persist-if-changed writes match the pre-existing SPCX load-path. Calculator title matching stays `contains` on a lowercased security title. The option-first `return shares` branch is a considered improvement over the plan’s fall-through sketch: it is what makes `testOptionTitleCountsUnderlyingShares` (`Option to Buy`, no class) return 100. Do not flatten it back.

`defaultSPCX` stays the sum expression rather than a second `13_571_069_199` literal. Tests pin the sum. Do not flatten it.

TSLA remigration writes `spec.defaultShareCount` instead of repeating `710_172_677`. Same single-source style as the SPCX / outstanding helpers.

## Tests

Coverage maps onto the behavior that matters:

| Area | Coverage |
|------|----------|
| Live-shaped June 17 fixture → `5_116_475_230` | `testAggregatesJune2026Form4Holdings` |
| Option-only / remarks-not-added | `testOptionTitleCountsUnderlyingShares`, `testRemarksPerformanceSharesAreNotAdded` |
| Parser aggregator no longer adds remarks | `testSPCXUsesOwnershipAggregatorNotSingleRow` |
| Five SPCX fingerprints + unknown pass-through | `SPCXHoldingsTests` |
| TSLA `699_580_882` rewrite / current / custom / empty | same |
| Outstanding fingerprint + custom + missing key | `IssuerSharesOutstandingTests` |
| 2028 MLK, no phantom New Year’s, GF, Jul 4, Jul 3 early, Thanksgiving + Friday | `MarketHoursServiceTests` |
| Empty suite / reset seeds | `testDefaultShareCounts`, reset outstanding case |
| No `currentTSLAPrice` | DTO is three fields; remaining parity asserts pin implied + mcaps |
| No Post to X / comparison caption in site + mock HTML | `verify.sh` §6 |

`699_580_882` that remains in `CurrencyFormatter`, paper-gain math, Form 4 XML, `ShareCountTextInput`, and `ShareImageExporter` is fixture input, not a seed. Plan asked to leave those.

No sweep test for `comparisonHistoryEntries` keys. The helper is `removeObject` on known strings; load and Reset both call it. Not required by the plan. Acceptable gap.

## Leftover comparison / stale versions

Product and test greps for comparison types, `tradingDayCalendar`, `currentTSLAPrice`, and `restrictedShares` are empty. Site + `docs/screenshots/render-*.html` have no `Post to X`, `comparison caption`, `minute by minute`, or `4:00 AM`. `app-capture.jpg` is gone.

Current-release strings moved together: README / INSTALL DMG examples, RELEASE “current: v0.1.5”, PRIVACY, SECURITY. Historical `## [0.1.4]` and marshal/spec mentions of 0.1.4 stay as history. `docs/README.md` “post-0.1.4 popover” is chrome description, not a shipping identity.

## Accepted leftovers (not findings)

1. `scripts/verify.sh` §5 optional live-Yahoo `SHARES` dict still prints `699_580_882` / `6_068_734_060`. The required skip-flag path (CI and Task 10) never runs it. Prior reviews left this as a considered no-op.
2. Unused `PortfolioHolding.defaults` still hardcodes TSLA `699_580_882` while SPCX reads `SPCXHoldings.defaultShareCount`. Zero call sites; not a seed or remigration path. Task 4 correctly left it.
3. Extra `render-capture.html` + `render-pngs.swift` are the §5-allowed mock pipeline.

## Quality checklist (whole PR)

| Axis | Result |
|------|--------|
| Organization | Changes in existing types; four comparison files deleted; no orphan pbxproj IDs |
| Tests | Seeds, remigration, calculator rule, 2028 calendar, outstanding, marketing grep |
| Clarity | Sellable-ownership comments; named legacy fingerprints; HOLDINGS strike-mark + four accessions |
| Patterns | Persist-if-changed remigration; orthogonal outstanding; option-first calculator branch |
| Comparison leftover | None in product/tests; history keys swept on load and Reset |
| Version leftover | No current-release 0.1.4 / build 25; AppVersion still reads plist macros |
| Critical bugs | None found |

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

Diff-sha256: 
