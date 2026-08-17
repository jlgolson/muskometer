# Round-trip deep-dive — holdings fingerprint remigration

Round 1. Adversarial trace of the persisted share-count / outstanding integers this
plan remigrates. There is no hash chain, HMAC envelope, or content-addressed blob.
The persisted payload *is* the decimal string. Spec and plan read in full; write and
read paths traced in the live worktree (`AppSettings`, `SPCXHoldings`,
`IssuerSharesOutstanding`, Settings / Form 4 / companyfacts callers).

## What is persisted

Three UserDefaults string keys, all written as `String(Int64)` and read as
`defaults.string(forKey:)` then `Int64(stored)`:

| Surface | Key | Legacy fingerprint(s) | Planned stored value |
|---------|-----|------------------------|----------------------|
| SPCX ownership | `shareCount_SPCX` | `60_685_475`, `842_091_670`, `7_402_770`, `6_068_547_515`, `6_068_734_060` | `5_116_475_230` |
| TSLA ownership | `shareCount_TSLA` | `699_580_882` | `710_172_677` |
| SPCX outstanding | `sharesOutstanding_SPCX` | `13_181_779_945` | `13_571_069_199` |

Prefixes do not collide (`shareCount_*` vs `sharesOutstanding_*`). TSLA outstanding
is not remigrated.

## Write path (production)

Every persist site for these keys goes through `String(count)` — Swift's locale-free
ASCII decimal of `Int64` (no grouping separators, no sign for positives).

`AppSettings.setShareCount` (`Muskometer/Utilities/AppSettings.swift`):

```swift
func setShareCount(_ count: Int64, for symbol: String) {
    shareCountsBySymbol[symbol] = count
    defaults.set(String(count), forKey: Self.shareCountKey(for: symbol))
}
```

`shareCountKey` is `"shareCount_\(symbol)"`. Callers that reach this writer:

- Settings apply (`SettingsView.applyShareCounts`): `ShareCountTextInput.resolve`
  strips commas, parses `Int64`, then `setShareCount`. The field is then rewritten
  to `String(count)`, so a typed `5,116,475,230` never lands in UserDefaults.
- Form 4 complete sync (`applyHoldingsSync`) → `setShareCount(shares, for:)`.
- `resetToDefaults` → `setShareCount(spec.defaultShareCount, for: spec.symbol)`.

`AppSettings.setSharesOutstanding`:

```swift
func setSharesOutstanding(_ count: Int64, for symbol: String) {
    guard count > 0 else { return }
    let normalized = symbol.uppercased()
    sharesOutstandingBySymbol[normalized] = count
    defaults.set(String(count), forKey: IssuerSharesOutstanding.userDefaultsKey(for: normalized))
}
```

Key is `"sharesOutstanding_\(symbol.uppercased())"`. Callers: `resetToDefaults` and
`GainsViewModel.syncIssuerOutstanding` (positive companyfacts hits only).

One-shot key copy (`migrateLegacyShareCounts`) also writes `String(value)` /
`String(migrated)` under the new `shareCount_*` keys. It never stores `NSNumber`.

Planned remigration writes reuse the existing persist-if-changed line already live
for SPCX in `loadShareCounts`:

```swift
let migrated = SPCXHoldings.migrateStoredShareCount(value)
if migrated != value {
    defaults.set(String(migrated), forKey: key)
}
counts[spec.symbol] = migrated
```

Task 3 copies that pattern into `loadSharesOutstanding` after a stored positive
parse. Task 4 adds a TSLA branch: stored `== 699_580_882` → persist
`String(710_172_677)`. Same encoder as `setShareCount` / `setSharesOutstanding`.

UserDefaults stores that `String` as an `NSString` in the suite plist. There is no
SQL schema, no `DEFAULT`, no generated column, no trigger. The bytes on disk are
the decimal characters the writer passed in.

## Read / remigrate path (production)

`AppSettings.init` runs `migrateLegacyShareCounts` then:

```swift
self.shareCountsBySymbol = Self.loadShareCounts(defaults: defaults)
self.sharesOutstandingBySymbol = Self.loadSharesOutstanding(defaults: defaults)
```

`loadShareCounts` (today, SPCX only; plan adds the TSLA equality rewrite in the
same loop):

```swift
if let stored = defaults.string(forKey: key), let value = Int64(stored) {
    if spec.symbol == "SPCX" {
        let migrated = SPCXHoldings.migrateStoredShareCount(value)
        if migrated != value {
            defaults.set(String(migrated), forKey: key)
        }
        counts[spec.symbol] = migrated
    } else {
        counts[spec.symbol] = value
    }
}
```

`loadSharesOutstanding` today parses `string` → `Int64` and keeps `value > 0`.
The plan remigrates after that parse and persists only when the integer changes.

`SPCXHoldings.migrateStoredShareCount` is an exact-integer `switch`. The plan
points every listed legacy case at `defaultShareCount` (`5_116_475_230`) and
explicitly does **not** treat `5_116_475_230` as legacy. Unknown values
(including `6_068_547_514`) return `stored` unchanged.

`shareCount(for:)` / `sharesOutstanding(for:)` then return the in-memory map, or
the spec / bundled default when the key is absent. A missing key is not written
on load.

`Int64(String(n)) == n` for every `Int64` n. The writer never emits a string
`Int64.init` rejects. Existing coverage already asserts the persist form:

```swift
XCTAssertEqual(defaults.string(forKey: "shareCount_SPCX"), String(SPCXHoldings.defaultShareCount))
```

## Divergence (absence)

A break would require the remigrated bytes on disk to parse as a *different*
integer than the writer intended, or for that integer to match another legacy
fingerprint so a second load remigrates again.

Checked:

1. **Encoder/decoder inverse.** `String(Int64)` ↔ `Int64(String)` is bijective on
   this domain. No `NumberFormatter`, no locale, no thousands separators, no
   floating point. The largest planned integer (`13_571_069_199`) is far below
   `Int64.max`.
2. **Target ∉ legacy set.** `{5_116_475_230, 710_172_677, 13_571_069_199}` is
   disjoint from `{60_685_475, 842_091_670, 7_402_770, 6_068_547_515,
   6_068_734_060, 699_580_882, 13_181_779_945}`. After the first rewrite, the
   stored decimal is not a remigration trigger.
3. **Idempotent second load.** Stored `"5116475230"` → parse `5_116_475_230` →
   default / passthrough arm → `migrated == value` → no write. Same for TSLA
   `== 699_580_882` (exact equality only) and outstanding `== 13_181_779_945`.
   Spec contract: remigration running twice is a no-op once the new integer is
   stored.
4. **Legacy-key copy then remigrate.** `migrateLegacyShareCounts` copies
   `tslaShareCount` / `spcxShareCount` onto the new keys when those new keys are
   missing. TSLA is copied as-is; SPCX is passed through `migrateStoredShareCount`.
   The subsequent `loadShareCounts` in the same `init` remigrates TSLA
   `699_580_882` and any SPCX fingerprint still present. After persist, the next
   launch sees only the new decimal. Same-init double-apply is still a no-op on
   the second function because the first persist already wrote the target.
5. **Non-fingerprints stay.** Manual overrides, later Form 4 syncs, and future
   companyfacts hits are exact-integer misses and are left stored. Plan tests
   name this (`6_068_547_514`, `123456`, `8_888_888_888`).
6. **No reconstructed canonical body.** There is nothing to hash or re-sign.
   Writer persists the remigrated decimal string; reader parses that same string.
   UserDefaults does not mutate the `NSString` after `set`.

Rollback of the *old* binary may rewrite stored `6_068_547_515` *up* to
`6_068_734_060` again (spec Rollback). That is a previous-build policy, not a
new-writer / new-reader byte mismatch.

## Tripwire (D1 / SQLite DEFAULTs)

Does not apply. Persistence is `UserDefaults` string keys, not D1/SQLite. There
is no DDL `DEFAULT`, generated column, or stub that could echo an insert payload
while hiding engine-populated columns. Plan tests construct a real
`UserDefaults(suiteName:)` suite, write `String(fingerprint)`, construct
`AppSettings(defaults:)`, and assert both `shareCount(for:)` / `sharesOutstanding(for:)`
and the stored string. That is a real-suite read-back of the same bytes the writer
set — the DEFAULT-masking stub class does not exist here.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"chain_safe","round":1,"findings":[]}
```

VERDICT: CHAIN-SAFE

reviewed-content-sha256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
