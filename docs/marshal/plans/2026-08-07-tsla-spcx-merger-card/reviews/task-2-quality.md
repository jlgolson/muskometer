# Task 2 Code Quality Review — Issuer outstanding defaults, profile CIKs, AppSettings persistence

**Role:** code-quality-reviewer  
**Task:** 2 (Defaults, CIKs, AppSettings keys, reset, pbxproj, tests)  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 2  
**Date:** 2026-08-07  

## Scope reviewed

Quality axes: naming, key isolation, pbxproj correctness, tests. Task introduces bundled issuer outstanding constants, `TrackedHoldingSpec.issuerCIKPadded`, AppSettings get/set/load/reset for outstanding, project registration, and unit coverage — no UI or companyfacts network.

## Findings

None blocking.

### Naming

| Item | Assessment |
|------|------------|
| `IssuerSharesOutstanding` | Clear domain enum; parallel to ownership-side utilities (`SPCXHoldings`) without colliding with Form 4 language. |
| `defaultTSLA` / `defaultSPCX` | Explicit symbol constants; comments carry as-of / accession provenance. |
| `defaultOutstanding(for:)` / `userDefaultsKey(for:)` | Lookup + key helper colocated with defaults; case-normalized via `uppercased()`. |
| `sharesOutstandingBySymbol` | Mirrors `shareCountsBySymbol` naming symmetry (ownership vs issuer totals). |
| `sharesOutstanding(for:)` / `setSharesOutstanding(_:for:)` | Parallel to `shareCount` / `setShareCount`; verb/noun pair is unambiguous. |
| `issuerCIKPadded` | Distinct from person `secCIKPadded` / `secCIKNumeric`; comment states companyfacts use. |
| `IssuerSharesOutstandingTests` | Focused test class name matches product type. |

No overloaded “shares” API that mixes ownership and outstanding without a distinct name.

### Key isolation

| Check | Status |
|-------|--------|
| Outstanding keys `sharesOutstanding_SYMBOL` via `IssuerSharesOutstanding.userDefaultsKey` | Pass |
| Ownership keys remain `shareCount_SYMBOL` via `shareCountKey` | Pass |
| `loadSharesOutstanding` separate from `loadShareCounts` | Pass |
| `setSharesOutstanding` only writes outstanding keys; `count > 0` gate | Pass |
| `sharesOutstanding(for:)` does not read ownership store / defaults | Pass |
| `applyHoldingsSync` only `setShareCount` — no outstanding side effects | Pass |
| `resetToDefaults` reseeds outstanding via defaults helper; ownership reseeds separately | Pass |
| Test asserts key string inequality + dual round-trip (ownership + outstanding) | Pass |

In-memory map and UserDefaults both use uppercased symbol keys for outstanding, reducing accidental split-brain vs mixed-case callers. Ownership path still uses raw symbol (existing convention); not a Task 2 regression.

### pbxproj

| Check | Status |
|-------|--------|
| Build file ID `A10000000000000000000050` | Pass — plan table exact |
| File ref ID `A20000000000000000000050` | Pass — plan table exact |
| `PBXFileReference` path `IssuerSharesOutstanding.swift` | Pass |
| Utilities group child | Pass |
| `A60000000000000000000002 /* Sources */` entry | Pass |
| No accidental registration of Task 3–6 files (`…51`–`…54`) | Pass |

All four required project touch points present; IDs do not collide with `…46` (last pre-task free slot).

### Tests

| Plan requirement | Coverage | Notes |
|------------------|----------|-------|
| Defaults when no key set | `testDefaultsReturnedWhenNoKeySet` | TSLA/SPCX defaults; unknown → 0 |
| set/get independent of shareCount | `testSetGetRoundTripIndependentOfShareCount` | Dual set, dual assert, raw UserDefaults keys, reload via second `AppSettings` |
| `resetToDefaults` reseeds after custom | `testResetToDefaultsReseedsOutstanding` | Custom outstanding + ownership; reset restores both defaults |
| Extra (good) | `testBundledDefaultsAndKeys` | Constants, case-insensitive lookup, key format |
| Extra (good) | `testMuskHoldingsHaveIssuerCIKs` | TSLA/SPCX padded CIKs |
| Extra (good) | `testSetSharesOutstandingIgnoresNonPositive` | 0 / −1 do not persist; getters fall back to defaults |

Suite isolation uses ephemeral `UserDefaults(suiteName:)` + `removePersistentDomain` — matches existing AppSettings test hygiene.

### Drive-by / scope

| Check | Status |
|-------|--------|
| No `MergerMarketCapParity` / resolver / sync service / card UI | Pass |
| `applyHoldingsSync` completeness gate unchanged | Pass |
| `TrackedHoldingSpec` only gains optional `issuerCIKPadded`; only musk call sites | Pass |
| Product file set matches plan Files touched | Pass |

## Quality checklist

| Axis | Result |
|------|--------|
| Naming | Clear ownership vs issuer vocabulary; API symmetry with shareCount |
| Key isolation | Separate keys, loaders, setters, reset paths; Form 4 gate untouched |
| pbxproj | Plan IDs `…50`; Utilities + Sources complete |
| Tests | Required three scenarios covered; isolation/reload/CIK/non-positive extras solid |

## VERDICT: APPROVED

## Reviewed files

- `Muskometer/Utilities/IssuerSharesOutstanding.swift` — defaults, lookup, key helper
- `Muskometer/Models/TrackedPersonProfile.swift` — `issuerCIKPadded` + musk TSLA/SPCX CIKs
- `Muskometer/Utilities/AppSettings.swift` — in-memory map, get/set, load, reset reseed; no Form 4 coupling
- `Muskometer.xcodeproj/project.pbxproj` — PBXBuildFile / FileReference / Utilities group / Sources
- `MuskometerTests/MuskometerTests.swift` — `IssuerSharesOutstandingTests`

VERDICT: APPROVED
