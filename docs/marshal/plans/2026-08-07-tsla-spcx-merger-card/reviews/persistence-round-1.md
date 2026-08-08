# Persistence objective review — round 1

**Role:** objective-reviewer (persistence)  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md`  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md`  
**Date:** 2026-08-08  
**Diff basis:** product sources vs `origin/main` (cold re-read of live tree; focus AppSettings keys, companyfacts store path, reset, hash chains)

## Scope

Persistence surfaces introduced or touched for issuer shares outstanding:

| Surface | Path |
|---------|------|
| Key helper + defaults | `Muskometer/Utilities/IssuerSharesOutstanding.swift` |
| Load / get / set / reset | `Muskometer/Utilities/AppSettings.swift` |
| Parse | `Muskometer/Services/CompanyFactsOutstandingResolver.swift` |
| Fetch + map | `Muskometer/Services/IssuerOutstandingSyncService.swift` |
| Apply + presentation read | `Muskometer/ViewModels/GainsViewModel.swift` |
| Pure consumer (no I/O) | `Muskometer/Utilities/MergerMarketCapParity.swift` |
| Tests | `IssuerSharesOutstandingTests`, `GainsViewModelIssuerOutstandingSyncTests`, presentation tests |

Out of scope for fix bar: UI chrome, resolver concept policy (covered elsewhere), marshal docs only.

## Checklist results

### 1. UserDefaults keys: `sharesOutstanding_*` vs `shareCount_*`

| Concern | Result |
|---------|--------|
| Outstanding key form | `IssuerSharesOutstanding.userDefaultsKey` → `"sharesOutstanding_\(symbol.uppercased())"` |
| Ownership key form | `AppSettings.shareCountKey` → `"shareCount_\(symbol)"` (unchanged) |
| Collision | Prefixes differ; unit test asserts key ≠ `shareCount_TSLA` |
| Independent maps | `sharesOutstandingBySymbol` vs `shareCountsBySymbol` |
| Independent APIs | `sharesOutstanding` / `setSharesOutstanding` vs `shareCount` / `setShareCount` |
| `applyHoldingsSync` | Ownership only (`setShareCount`); never writes outstanding |
| Outstanding sync apply | `syncIssuerOutstanding` only calls `setSharesOutstanding` |

**Pass.** No cross-writes. Symbol casing for outstanding is normalized to uppercase on key, in-memory dict, and fetch results (`spec.symbol.uppercased()`).

### 2. companyfacts parse → store → presentation read path

```
companyfacts JSON Data
  → CompanyFactsOutstandingResolver.resolveSharesOutstanding → Int64?  (nil if unresolved / WASO-only / bad payload)
  → IssuerOutstandingSyncService.fetchOutstanding → [String: Int64]     (omit failures; shares > 0 only)
  → GainsViewModel.syncIssuerOutstanding
  → AppSettings.setSharesOutstanding (guard count > 0)
       in-memory sharesOutstandingBySymbol[normalized] = count
       UserDefaults string: String(count) under sharesOutstanding_SYMBOL
  → AppSettings.sharesOutstanding(for:)
       stored > 0 else IssuerSharesOutstanding.defaultOutstanding else 0
  → GainsViewModel.mergerParityPresentation
       settings.sharesOutstanding("TSLA"/"SPCX") + snapshot quote prices
  → MergerMarketCapParity.presentation (pure; no defaults/UserDefaults)
```

| Step invariant | Result |
|----------------|--------|
| Non-positive never persisted | `setSharesOutstanding` returns early for `count <= 0`; load requires `value > 0` |
| Unresolved fetch does not clear prior | Empty map → no `setSharesOutstanding` calls; defaults or prior SEC value remain |
| String Int64 storage (not Double) | Matches ownership pattern; preserves values above 2^53 (e.g. SPCX ~13.18B) |
| Process restart | `loadSharesOutstanding` in `init` rebuilds in-memory map from UD strings |
| Defaults-only presentation | Unset keys → bundled defaults → card still computable when quotes present |
| Form 4 failure still stores outstanding | `syncIssuerOutstanding` runs after Form 4 `do/catch`; isolation test covers it |

**Pass.** Linear path; no intermediate reformatting beyond `String`/`Int64` for UD (same as ownership).

### 3. `resetToDefaults` reseeds outstanding

```swift
for spec in selectedProfile.holdingSpecs {
    setShareCount(spec.defaultShareCount, for: spec.symbol)
    if let defaultOutstanding = IssuerSharesOutstanding.defaultOutstanding(for: spec.symbol) {
        setSharesOutstanding(defaultOutstanding, for: spec.symbol)
    }
}
```

| Check | Result |
|-------|--------|
| Custom SEC-like outstanding overwritten | Yes — reseeds TSLA `3_949_547_394`, SPCX `13_181_779_945` |
| Ownership reseeds independently | Yes — same loop; tested alongside outstanding |
| Stale SEC value cleared | Yes — by writing bundled constants (spec: reseed, not remove-key-only) |
| Test coverage | `testResetToDefaultsReseedsOutstanding` |

**Pass.** Matches design error table and AC5.

### 4. Round-trip hash chains

| Path | Hash / fingerprint chain? |
|------|---------------------------|
| Outstanding parse → store → load | **None** — direct `Int64` ↔ `String` |
| Outstanding presentation | **None** — live settings + quotes |
| Pre-existing ownership SPCX fingerprint migrate | Unrelated (`shareCount_SPCX` only); outstanding does not adopt or depend on it |

**Pass.** No unnecessary hash round-trips on the new persistence surface.

## Test evidence (persistence-relevant)

- Defaults when no key: `testDefaultsReturnedWhenNoKeySet`
- UD round-trip + key independence + ownership isolation: `testSetGetRoundTripIndependentOfShareCount`
- Non-positive ignored: `testSetSharesOutstandingIgnoresNonPositive`
- Reset reseeds: `testResetToDefaultsReseedsOutstanding`
- Presentation defaults-only: `testPresentationUsesDefaultOutstandingWhenUnset`
- Sync write after Form 4 fail: `testOutstandingAppliedAfterForm4FailureWithoutChangingMessage`
- Empty outstanding keeps defaults after Form 4 success: `testOutstandingEmptyResultDoesNotChangeDefaultsOrForm4SuccessMessage`

## Non-blocking notes (do not block)

1. **`testResetToDefaultsReseedsOutstanding` asserts getters only** — does not re-read UD strings after reset. Product path always writes via `setSharesOutstanding`, and separate round-trip test covers UD; residual test gap only.
2. **`docs/PRIVACY.md`** still lists share counts / last Form 4 sync and does not name issuer outstanding keys — documentation drift, not a runtime persistence defect.
3. **Optional last-outstanding-sync timestamp** (design “v1-light optional”) is not stored — correct omission; no incomplete half-feature.

## Findings

None.

VERDICT: APPROVED
