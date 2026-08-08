# Task 2 Spec Review — Issuer outstanding defaults, profile CIKs, AppSettings persistence

**Role:** spec-reviewer  
**Task:** 2 (Issuer outstanding defaults, profile CIKs, AppSettings persistence — design §2)  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md` §2  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 2  
**Date:** 2026-08-07  

## Scope checked

Design §2 / plan Task 2 require (for this task only):

| Requirement | Expected |
|-------------|----------|
| Bundled defaults | TSLA `3_949_547_394`; SPCX `13_181_779_945` (A+B: `7_696_293_669` + `5_485_486_276`) with as-of/accession comments |
| Issuer CIKs | TSLA `0001318605`, SPCX `0001181412` on `TrackedHoldingSpec.issuerCIKPadded` |
| Independent keys | `sharesOutstanding_SYMBOL` — not ownership `shareCount_*` |
| Reader/writer API | stored > 0 → use stored; else bundled default; else 0; set only if count > 0 |
| `resetToDefaults` | reseeds outstanding to bundled defaults (independent of ownership) |
| Form 4 isolation | outstanding **not** folded into `applyHoldingsSync` / ownership completeness |
| pbxproj | IDs `A1…50` / `A2…50` for `IssuerSharesOutstanding.swift` |
| Tests | defaults when no key; set/get independent of shareCount; reset reseeds |

Out of scope for Task 2 (deferred): companyfacts fetch/resolver, UI card, calculator.

## Findings

None.

## Compliance checklist

| Requirement | Status | Evidence |
|-------------|--------|----------|
| TSLA default `3_949_547_394` + cover comment | Pass | `IssuerSharesOutstanding.defaultTSLA`; comment cites `dei:EntityCommonStockSharesOutstanding`, end 2026-07-16 |
| SPCX default `13_181_779_945` A+B + accession | Pass | `defaultSPCX`; comment: Class A `7_696_293_669` + Class B `5_485_486_276`, accession `0001628280-26-052535` (sum = 13_181_779_945) |
| `defaultOutstanding(for:)` case-insensitive | Pass | uppercases symbol; TSLA/SPCX only |
| UserDefaults key `sharesOutstanding_SYMBOL` | Pass | `userDefaultsKey(for:)` → `"sharesOutstanding_\(uppercased)"` |
| TSLA issuer CIK `0001318605` | Pass | musk TSLA `TrackedHoldingSpec.issuerCIKPadded` |
| SPCX issuer CIK `0001181412` | Pass | musk SPCX `TrackedHoldingSpec.issuerCIKPadded` |
| CIK is issuer, not person Form 4 | Pass | Field comment; musk person CIK remains `0001494730` |
| `sharesOutstandingBySymbol` loaded in init | Pass | `loadSharesOutstanding` from registry holding specs via independent keys |
| `sharesOutstanding(for:)` fallback chain | Pass | stored > 0 → stored; else `defaultOutstanding` → else `0` |
| `setSharesOutstanding` only if `count > 0` | Pass | guard + no write for 0/−1 (test) |
| Keys independent of `shareCount_*` | Pass | different prefix; round-trip test asserts key ≠ `shareCount_TSLA` and ownership unchanged |
| `resetToDefaults` reseeds outstanding | Pass | loops musk holding specs and `setSharesOutstanding(default, for:)`; test after custom values |
| Not mixed into `applyHoldingsSync` | Pass | `applyHoldingsSync` only reads `result.sharesBySymbol`, updates `setShareCount`, ownership completeness gate — zero outstanding references |
| pbxproj IDs 50 | Pass | PBXBuildFile `A100…50`, fileRef `A200…50`, group child, Sources entry |
| Plan tests present | Pass | `IssuerSharesOutstandingTests`: bundled defaults/keys, CIKs, no-key defaults, set/get independence, non-positive ignore, reset reseed |

## VERDICT: APPROVED

## Reviewed files

- `Muskometer/Utilities/IssuerSharesOutstanding.swift` — defaults, keys, comments match plan/spec
- `Muskometer/Models/TrackedPersonProfile.swift` — optional `issuerCIKPadded`; musk TSLA/SPCX CIKs correct
- `Muskometer/Utilities/AppSettings.swift` — load/set/get outstanding API; reset reseeds; `applyHoldingsSync` ownership-only
- `Muskometer.xcodeproj/project.pbxproj` — IDs `A10000000000000000000050` / `A20000000000000000000050`
- `MuskometerTests/MuskometerTests.swift` — `IssuerSharesOutstandingTests` class
- `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md` §2
- `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 2 steps
