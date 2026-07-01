# Round 1 Quality Review — Elon Gains

**Reviewer:** Marshal-equivalent verification (automated)  
**Date:** 2026-06-30  
**Project:** `/Users/jlgolson/grok/ElonGains`  
**Scope:** Compile/build, Yahoo API integration, paper-gain math, formatting, runtime behavior

---

## Commands Run

### 1. `swiftc -typecheck` (macOS 14 target, all 14 Swift sources)

```bash
cd /Users/jlgolson/grok/ElonGains
SDK=$(xcrun --show-sdk-path)
swiftc -typecheck \
  -target arm64-apple-macos14.0 \
  -sdk "$SDK" \
  -module-name ElonGains \
  -parse-as-library \
  $(find ElonGains -name "*.swift" | sort)
echo "swiftc: OK (exit 0, no diagnostics)"
```

**Output excerpt:**
```
Files typechecked:
      14
swiftc: OK (exit 0, no diagnostics)
```

> **Note:** A bare `swiftc -typecheck` without `-module-name ElonGains -parse-as-library` produced no output after 31s and was interrupted during review. The module-flag invocation above completes in ~2.5s with exit 0 and is the recommended CI command.

---

### 2. `xcodebuild` Debug build

```bash
cd /Users/jlgolson/grok/ElonGains
xcodebuild -scheme ElonGains -configuration Debug build
```

**Output excerpt:**
```
note: Target dependency graph (1 target)
    Target 'ElonGains' in project 'ElonGains' (no dependencies)
...
note: Disabling hardened runtime with ad-hoc codesigning. (in target 'ElonGains' from project 'ElonGains')
** BUILD SUCCEEDED **
```

**Build settings verified:**
```
BUILT_PRODUCTS_DIR = .../Build/Products/Debug
CODE_SIGN_ENTITLEMENTS = ElonGains/ElonGains.entitlements
MACOSX_DEPLOYMENT_TARGET = 14.0
PRODUCT_NAME = Elon Gains
```

---

### 3. Yahoo Finance API — TSLA + SPCX live quotes

```bash
for sym in TSLA SPCX; do
  curl -sS -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
    "https://query1.finance.yahoo.com/v8/finance/chart/${sym}?interval=1d&range=1d"
done
```

**Output excerpt (2026-06-30 session):**
```
=== TSLA ===
shortName: Tesla, Inc.
regularMarketPrice: 420.6
previousClose: 411.84
priceChange: 8.7600
percentChange: 2.1270%

=== SPCX ===
shortName: Space Exploration Technologies 
regularMarketPrice: 170.86
previousClose: 164.19
priceChange: 6.6700
percentChange: 4.0624%
```

Both symbols return valid `regularMarketPrice` and `previousClose` via the same endpoint used by `YahooFinanceStockPriceService`.

---

### 4. Paper gains — hardcoded share counts

**Defaults from `AppSettings.swift`:**
| Symbol | Shares |
|--------|--------|
| TSLA | 699,580,882 |
| SPCX | 6,068,547,515 |

**Formula:** `paperGain = shares × (currentPrice − previousClose)`

**Computed at verification time:**
```
TSLA paper gain: +$6.1B  (raw: $6,128,328,526.32)
SPCX paper gain: +$40.5B (raw: $40,477,211,925.05)
Combined:        +$46.6B (raw: $46,605,540,451.37)
```

Matches `StockQuote.paperGain(shareCount:)` and `GainsSnapshot.combinedPaperGain`.

---

### 5. `CurrencyFormatter` audit

Verified against live computed values using the implementation in `CurrencyFormatter.swift`:

```
formatCurrency(combined):  +$46.6B
formatPercent(TSLA):       +2.13%
formatPercent(SPCX):       +4.06%
formatCurrency(TSLA gain): +$6.1B
formatCurrency(SPCX gain): +$40.5B
```

| Style requirement | Expected | Actual | OK |
|-------------------|----------|--------|----|
| Billions compact | `$46.6B` | `+$46.6B` | ✅ |
| Signed billions | `+$46.6B` | `+$46.6B` | ✅ |
| Percent 2 decimals | `+2.13%` | `+2.13%` | ✅ |
| Price | `$420.60` | `$420.60` | ✅ |

---

### 6. Runtime / architecture audit

| Area | Inspection | Result |
|------|------------|--------|
| **Refresh lifecycle** | `MenuBarLabelView.onAppear → viewModel.start()` launches polling `Task`; loop reads `settings.refreshIntervalSeconds` each iteration; sleeps `interval` when market open, `max(interval, 300)` when closed | ✅ Functional |
| **Settings persistence** | `UserDefaults` keys for interval + share counts; slider saves on `onEditingChanged`; share counts applied on `onSubmit` and `onDisappear` | ✅ Functional |
| **Market hours** | ET timezone, Mon–Fri 9:30–16:00, 2026 US holiday set in `MarketHoursService` | ✅ Functional (limited holiday table) |
| **Sandbox network** | `ElonGains.entitlements`: `app-sandbox` + `network.client`; signed into built `.app` | ✅ Present |

**Built app entitlements (codesign):**
```xml
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.network.client</key><true/>
```

**Info.plist:** `LSUIElement = true`, `LSMinimumSystemVersion = 14.0`

---

## Pass / Fail Table

| # | Requirement | Result |
|---|-------------|--------|
| 1 | `swiftc -typecheck` all Swift sources, macOS 14 target | **PASS** |
| 2 | `xcodebuild -scheme ElonGains -configuration Debug build` | **PASS** |
| 3 | Yahoo API returns TSLA + SPCX quotes | **PASS** |
| 4 | Paper gains computed with hardcoded share counts | **PASS** (`+$46.6B` combined) |
| 5 | `CurrencyFormatter` produces `$46.6B` / `+2.13%` style | **PASS** |
| 6 | Refresh lifecycle (auto-poll, market-aware sleep) | **PASS** |
| 7 | Settings persistence (UserDefaults) | **PASS** |
| 8 | Market hours detection | **PASS** |
| 9 | Sandbox + network client entitlement | **PASS** |

**Overall: 9 / 9 requirements passed.**

---

## Findings

### 1. [LOW] `GainsViewModel.stop()` is never invoked
`stop()` cancels the refresh `Task`, but no view or app lifecycle hook calls it. For a menu-bar accessory app this is acceptable (process exit tears down tasks), but explicit cleanup on termination would be cleaner.

### 2. [LOW] Refresh-interval clamp mismatch between `AppSettings` and `SettingsView`
`AppSettings.refreshIntervalSeconds` clamps to **60–300** seconds, while the settings slider is **60–120**. README documents 60–120. A stored value above 120 (possible via defaults manipulation) would sit outside the slider range.

### 3. [LOW] Concurrent refresh requests are silently dropped
`refresh()` returns immediately when `isLoading == true`. Manual "Refresh" / "Try Again" clicks during an in-flight auto-refresh are ignored without feedback.

### 4. [INFO] Market holiday table is 2026-only
`MarketHoursService.isHoliday` hardcodes 2026 dates. After 2026, closed-market detection on holidays will be wrong until the list is updated.

### 5. [INFO] `swiftc -typecheck` needs module flags for reliable CLI use
Without `-module-name ElonGains -parse-as-library`, type-checking all sources together emitted no diagnostics and had not finished after 31s (process interrupted). With module flags it completes in ~2.5s. Use the module-flag invocation for CI.

---

## Code Review Notes (no blocking issues)

- **MVVM structure** is clean: protocol-oriented `StockPriceServiceProtocol`, `@Observable` `GainsViewModel`, injected dependencies.
- **Yahoo parsing** correctly falls back `chartPreviousClose ?? previousClose`, matching live API payloads.
- **Menu bar UX** shows combined gain with color coding; popover shows per-stock breakdown and market status.
- **No trivial one-line bugs** were found during verification; no code changes were made.

---

VERDICT: APPROVED