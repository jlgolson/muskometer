# Architecture

Muskometer is a native macOS **menu bar utility** built with SwiftUI (`MenuBarExtra`) and a thin **MVVM** layer. All network I/O is async; the view model owns refresh timing and state.

## Pattern: MVVM

| Layer | Role |
|-------|------|
| **Views** | `MenuBarLabelView`, `PopoverContentView`, `SettingsView` — render snapshot, forward user actions |
| **ViewModel** | `GainsViewModel` — refresh loop, holdings sync, formatted menu bar title |
| **Models** | `StockQuote`, `GainsSnapshot`, `PortfolioHolding`, `MenuBarDisplayMode` |
| **Services** | Yahoo quotes, SEC Form 4 sync, US market hours |
| **Utilities** | `AppSettings` (UserDefaults), formatters, `SPCXHoldings` defaults |

`GainsViewModel` is `@Observable` and `@MainActor`. Services conform to small protocols (`StockPriceServiceProtocol`, `HoldingsSyncServiceProtocol`, `MarketHoursServiceProtocol`) for test injection.

## Key files

| File | Purpose |
|------|---------|
| `App/MuskometerApp.swift` | `MenuBarExtra`, commands, settings window |
| `ViewModels/GainsViewModel.swift` | Core state machine + refresh loop |
| `Services/YahooFinanceStockPriceService.swift` | Chart API → `StockQuote` |
| `Services/SECHoldingsSyncService.swift` | EDGAR Form 4 → TSLA/SPCX share counts |
| `Services/MarketHoursService.swift` | 9:30–16:00 ET, weekends, US market holiday set |
| `Utilities/SPCXHoldings.swift` | Default SPCX share count + legacy migration |
| `Utilities/AppSettings.swift` | Holdings, refresh interval, launch at login |

## Paper gain math

```
paperGain = shareCount × (currentPrice − previousClose)
```

- **TSLA** — share count from SEC Form 4 (direct).
- **SPCX** — SpaceX’s public ticker; aggregates Class A/B trust lines plus restricted shares from SEC Form 3/4 remarks (~6B Class A-equivalent), multiplied by Yahoo price.

Combined gain is the sum across holdings. Menu bar display mode (dollars vs percent, combined vs split) is a view-layer concern over the same snapshot.

## Data flow

```mermaid
flowchart LR
    subgraph UI
        MB[MenuBarLabelView]
        POP[PopoverContentView]
        SET[SettingsView]
    end

    VM[GainsViewModel]

    subgraph Services
        YF[YahooFinanceStockPriceService]
        SEC[SECHoldingsSyncService]
        MH[MarketHoursService]
    end

    subgraph External
        Yahoo[(Yahoo Finance API)]
        EDGAR[(SEC EDGAR)]
    end

    AS[(AppSettings / UserDefaults)]

    MB --> VM
    POP --> VM
    SET --> AS
    VM --> AS

    VM --> YF
    VM --> SEC
    VM --> MH

    YF --> Yahoo
    SEC --> EDGAR

    VM --> MB
    VM --> POP
```

## Refresh loop

1. **Start** (`MenuBarLabelView.onAppear` → `viewModel.start()`). `PopoverContentView.onAppear` only toggles popover visibility for settings routing.
2. **SEC sync** if `AppSettings.needsHoldingsSync` (default: once per 24h).
3. **Fetch quotes** for all holding symbols in parallel.
4. **Build** `GainsSnapshot` with `marketIsOpen` from `MarketHoursService`.
5. **Sleep** 60–120s (user setting) when market open; ≥300s when closed.
6. Repeat until `stop()` on app terminate.

Force refresh (`⌘R`) bypasses the in-flight guard and increments a generation token to drop stale responses.

## Market holidays

`MarketHoursService` treats US equity market holidays as a **hardcoded date set** in `MarketHoursService.swift` covering **2026 and 2027** only (NYSE-style calendar: New Year's Day, MLK Day, Presidents' Day, Good Friday, Memorial Day, Juneteenth, Independence Day observed, Labor Day, Thanksgiving, Christmas).

This is intentional for v0.1.0 — no external holiday API. **Maintainers must extend the set annually** (or replace it with a maintained data source) so refresh timing and "market open" status stay correct after 2027.

## Sandbox & storage

- App Sandbox enabled; outbound network only.
- Holdings, refresh interval, display mode, launch-at-login → **UserDefaults**.
- No local database, no analytics SDK, no API keys.

## Testing strategy

`MuskometerTests` covers pure logic (formatters, SPCX scaling, market hours, Form 4 parser) and view model behavior with mock services. `scripts/verify.sh` adds integration checks against live Yahoo endpoints.

---

© [Jordan Golson](https://jordangolson.com) · [info@muskometer.org](mailto:info@muskometer.org)