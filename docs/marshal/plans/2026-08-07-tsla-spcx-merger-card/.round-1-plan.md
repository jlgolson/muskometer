---
slug: 2026-08-07-tsla-spcx-merger-card
plan_date: 2026-08-07
spec_path: docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md
gate: review
---

# TSLA–SPCX merger parity card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use marshal:execute-plan to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Do **not** implement outside execute-plan. Per-task gates require both `task-N-spec.md` and `task-N-quality.md` ending in `VERDICT: APPROVED` before Task N+1.

**Goal:** Add a main-popover card showing implied TSLA $/share if TSLA company market cap matched SPCX (Class A Yahoo price × Class A+B outstanding ÷ TSLA outstanding), source outstanding from SEC companyfacts with cover-derived defaults, and fix the Loneliest easter-egg typo. Fix any related bugs found during implementation within scope.

**Architecture:** Keep Musk Form 4 ownership sync unchanged. Add an orthogonal issuer-outstanding path (bundled defaults + best-effort companyfacts on the same ~24h SEC cadence). Pure calculator builds a presentation model from live snapshot quotes + outstanding. UI card after stock rows. No Yahoo marketCap; reject WASO for mcap.

**Tech Stack:** Swift / SwiftUI macOS 14+, XCTest, SEC `data.sec.gov` companyfacts, existing Yahoo chart quotes.

**Reference paths (read first):**

- Spec: `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md`
- `Muskometer/Services/NetWorthMilestoneTracker.swift`
- `Muskometer/Services/SECHoldingsSyncService.swift` (User-Agent pattern)
- `Muskometer/Utilities/AppSettings.swift`
- `Muskometer/Models/TrackedPersonProfile.swift`
- `Muskometer/ViewModels/GainsViewModel.swift`
- `Muskometer/Views/PopoverContentView.swift`
- `Muskometer/Views/StockRowView.swift` (card visual language)
- `Muskometer.xcodeproj/project.pbxproj` (register every new `.swift` file)
- `MuskometerTests/MuskometerTests.swift`

**Xcode project IDs for new files (use these exact hex IDs; next free after `…46`):**

| Role | Build file ID | File ref ID | Path |
|------|---------------|-------------|------|
| IssuerSharesOutstanding | `A10000000000000000000050` | `A20000000000000000000050` | `Muskometer/Utilities/IssuerSharesOutstanding.swift` |
| MergerMarketCapParity | `A10000000000000000000051` | `A20000000000000000000051` | `Muskometer/Utilities/MergerMarketCapParity.swift` |
| CompanyFactsOutstandingResolver | `A10000000000000000000052` | `A20000000000000000000052` | `Muskometer/Services/CompanyFactsOutstandingResolver.swift` |
| IssuerOutstandingSyncService | `A10000000000000000000053` | `A20000000000000000000053` | `Muskometer/Services/IssuerOutstandingSyncService.swift` |
| MergerParityCardView | `A10000000000000000000054` | `A20000000000000000000054` | `Muskometer/Views/MergerParityCardView.swift` |

For each new file: add `PBXBuildFile`, `PBXFileReference`, group child under Utilities/Services/Views as appropriate, and entry in `A60000000000000000000002 /* Sources */`.

---

## Task 1: Fix Loneliest typo

**Depends on:**

### Files touched

- Muskometer/Services/NetWorthMilestoneTracker.swift
- MuskometerTests/MuskometerTests.swift

### Steps

- [ ] Change `NetWorthMilestoneTracker.belowTrillionMessage` from `"One Trillion Is the Lonliest Number"` to `"One Trillion Is the Loneliest Number"`.
- [ ] In `MuskometerTests.swift`, rename `testSadMessageUsesLonliestNumberCopy` → `testSadMessageUsesLoneliestNumberCopy`.
- [ ] Update its assertion to `"One Trillion Is the Loneliest Number"` and also `XCTAssertEqual(message, NetWorthMilestoneTracker.belowTrillionMessage)`.
- [ ] Grep the repo for `Lonliest` under `Muskometer/` and `MuskometerTests/` — zero remaining product/test string literals (comments in historical plan/spec reviews may keep the misspelling).
- [ ] Run: `xcodebuild test -scheme Muskometer -destination 'platform=macOS' -only-testing:MuskometerTests/NetWorthMilestoneTrackerTests` (or full tests if filter fails). Confirm the renamed test passes.
- [ ] Commit: `Fix Loneliest spelling in trillion easter-egg message`

### Implementer dispatch

````
MARSHAL_TASK_ID: 1
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: implementer

Implement Task 1: Fix Loneliest typo.

Worktree root: the feature worktree already checked out on jordan/tsla-spcx-merger-card.
Spec: docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md §1 Typo fix.

Do exactly the Steps under Task 1. Do not implement merger card code.

When you finish, report DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
followed by a one-paragraph summary. Do not mark yourself completed —
the orchestrator dispatches reviewers next.
````

### Spec-reviewer dispatch

````
MARSHAL_TASK_ID: 1
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: spec-reviewer

You are reviewing Task 1 for compliance with the spec.

Spec: docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md
Task: Fix Loneliest typo only.

Verify product constant and tests use Loneliest; no other scope creep.

Write your verdict to:
docs/marshal/plans/2026-08-07-tsla-spcx-merger-card/reviews/task-1-spec.md

## Findings then VERDICT: APPROVED or VERDICT: NEEDS_FIXES: <reason>
## Reviewed files
````

### Code-quality-reviewer dispatch

````
MARSHAL_TASK_ID: 1
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: code-quality-reviewer

You are reviewing Task 1 for code quality (naming, test accuracy, no drive-by edits).

Write your verdict to:
docs/marshal/plans/2026-08-07-tsla-spcx-merger-card/reviews/task-1-quality.md

## Findings then VERDICT: APPROVED or VERDICT: NEEDS_FIXES: <reason>
## Reviewed files
````

---

## Task 2: Issuer outstanding defaults, profile CIKs, AppSettings persistence

**Depends on:** 1

### Files touched

- Muskometer/Utilities/IssuerSharesOutstanding.swift
- Muskometer/Models/TrackedPersonProfile.swift
- Muskometer/Utilities/AppSettings.swift
- Muskometer.xcodeproj/project.pbxproj
- MuskometerTests/MuskometerTests.swift

### Steps

- [ ] Create `Muskometer/Utilities/IssuerSharesOutstanding.swift`:

```swift
import Foundation

/// Bundled point-in-time issuer shares outstanding for market-cap parity
/// (company totals — not Musk Form 4 ownership).
enum IssuerSharesOutstanding {
    /// dei:EntityCommonStockSharesOutstanding, end 2026-07-16 (TSLA 10-Q / companyfacts).
    static let defaultTSLA: Int64 = 3_949_547_394

    /// 10-Q cover as of 2026-07-28: Class A 7_696_293_669 + Class B 5_485_486_276
    /// (accession 0001628280-26-052535).
    static let defaultSPCX: Int64 = 13_181_779_945

    static func defaultOutstanding(for symbol: String) -> Int64? {
        switch symbol.uppercased() {
        case "TSLA": return defaultTSLA
        case "SPCX": return defaultSPCX
        default: return nil
        }
    }

    static func userDefaultsKey(for symbol: String) -> String {
        "sharesOutstanding_\(symbol.uppercased())"
    }
}
```

- [ ] Extend `TrackedHoldingSpec` with `let issuerCIKPadded: String?` (or non-optional `String` empty unused — prefer optional). Set musk holdings: TSLA `0001318605`, SPCX `0001181412`. Update any other `TrackedHoldingSpec(...)` call sites if compile breaks.
- [ ] In `AppSettings`:
  - In-memory `sharesOutstandingBySymbol: [String: Int64]` loaded in `init` via keys `sharesOutstanding_SYMBOL` (string Int64 like share counts).
  - `func sharesOutstanding(for symbol: String) -> Int64` — stored value if > 0, else `IssuerSharesOutstanding.defaultOutstanding(for:)` else `0`.
  - `func setSharesOutstanding(_ count: Int64, for symbol: String)` — only persist if `count > 0`; key independent of `shareCount_`.
  - `resetToDefaults()`: for each musk holding symbol with a default outstanding, `setSharesOutstanding(default, for:)` (reseed even if a prior SEC value was stored).
  - Do **not** mix outstanding into `applyHoldingsSync` / ownership completeness.
- [ ] Register new file in `project.pbxproj` (IDs above).
- [ ] Tests (new test class or section in `MuskometerTests.swift`):
  - Defaults returned when no key set.
  - set/get round-trip independent of `shareCount`.
  - `resetToDefaults` reseeds outstanding to bundled defaults after a custom value.
- [ ] Commit: `Add issuer outstanding defaults and AppSettings persistence`

### Implementer dispatch

````
MARSHAL_TASK_ID: 2
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: implementer

Implement Task 2: Issuer outstanding defaults, profile CIKs, AppSettings persistence.

Spec: docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md §2 (defaults, keys, reset, independence from Form 4).

Follow Task 2 Steps exactly. Register pbxproj IDs from the plan header table.
Do not add UI or companyfacts network code yet.

When you finish, report DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
followed by a one-paragraph summary. Do not mark yourself completed —
the orchestrator dispatches reviewers next.
````

### Spec-reviewer dispatch

````
MARSHAL_TASK_ID: 2
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: spec-reviewer

Review Task 2 against spec §2 defaults (TSLA 3_949_547_394, SPCX 13_181_779_945 A+B), issuer CIKs, separate UserDefaults keys, reset reseeds, no Form 4 gate coupling.

Write verdict to docs/marshal/plans/2026-08-07-tsla-spcx-merger-card/reviews/task-2-spec.md
## Findings then VERDICT line; ## Reviewed files
````

### Code-quality-reviewer dispatch

````
MARSHAL_TASK_ID: 2
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: code-quality-reviewer

Review Task 2 for naming, key isolation, pbxproj correctness, tests.

Write verdict to docs/marshal/plans/2026-08-07-tsla-spcx-merger-card/reviews/task-2-quality.md
## Findings then VERDICT line; ## Reviewed files
````

---

## Task 3: MergerMarketCapParity pure calculator

**Depends on:** 2

### Files touched

- Muskometer/Utilities/MergerMarketCapParity.swift
- Muskometer.xcodeproj/project.pbxproj
- MuskometerTests/MuskometerTests.swift

### Steps

- [ ] Create:

```swift
import Foundation

struct MergerParityPresentation: Equatable, Sendable {
    let impliedTSLAPrice: Double
    let tslaMarketCap: Double
    let spcxMarketCap: Double
    let currentTSLAPrice: Double
}

enum MergerMarketCapParity {
    /// SPCX mcap uses Class A Yahoo price × total A+B outstanding.
    static func presentation(
        tslaPrice: Double,
        spcxPrice: Double,
        tslaOutstanding: Int64,
        spcxOutstanding: Int64
    ) -> MergerParityPresentation? {
        // Guards: finite, > 0 for all inputs; finite implied > 0
        // tslaMarketCap = tslaPrice * Double(tslaOutstanding)
        // spcxMarketCap = spcxPrice * Double(spcxOutstanding)
        // impliedTSLAPrice = spcxMarketCap / Double(tslaOutstanding)
    }
}
```

- [ ] Register pbxproj.
- [ ] Unit tests:
  - Happy path: prices 100/50, outstanding 2/4 → spcx mcap 200, implied TSLA 100.
  - Zero/negative outstanding or price → nil.
  - Non-finite → nil.
  - Smoke with real-ish orders of magnitude (TSLA ~3.95e9, SPCX ~13.18e9).
- [ ] Commit: `Add MergerMarketCapParity calculator`

### Implementer dispatch

````
MARSHAL_TASK_ID: 3
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: implementer

Implement Task 3: MergerMarketCapParity pure calculator.

Spec: Goals formula + §3 calculator. Class A price × A+B outstanding for SPCX mcap.

When you finish, report DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
followed by a one-paragraph summary. Do not mark yourself completed —
the orchestrator dispatches reviewers next.
````

### Spec-reviewer dispatch

````
MARSHAL_TASK_ID: 3
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: spec-reviewer

Review Task 3 formula and guards against spec Goals/§3.

Write verdict to docs/marshal/plans/2026-08-07-tsla-spcx-merger-card/reviews/task-3-spec.md
````

### Code-quality-reviewer dispatch

````
MARSHAL_TASK_ID: 3
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: code-quality-reviewer

Review Task 3 purity, edge cases, tests.

Write verdict to docs/marshal/plans/2026-08-07-tsla-spcx-merger-card/reviews/task-3-quality.md
````

---

## Task 4: CompanyFactsOutstandingResolver (pure, WASO rejected)

**Depends on:** 2

### Files touched

- Muskometer/Services/CompanyFactsOutstandingResolver.swift
- Muskometer.xcodeproj/project.pbxproj
- MuskometerTests/MuskometerTests.swift

### Steps

- [ ] Create pure resolver:

```swift
enum CompanyFactsOutstandingResolver {
    /// Parse SEC companyfacts JSON Data → positive Int64 outstanding or nil.
    static func resolveSharesOutstanding(from companyFactsJSON: Data) -> Int64?
}
```

**Rules (spec §2):**

1. Concept priority only: `facts.dei.EntityCommonStockSharesOutstanding` then `facts.us-gaap.CommonStockSharesOutstanding` (units key `shares` only).
2. **Do not** read `WeightedAverageNumberOfSharesOutstandingBasic` / Diluted — if only those exist, return nil.
3. Each row needs `end` (string), positive `val`, optional `filed`, optional `form`.
4. Prefer rows whose `form` is in `{10-Q,10-K,10-Q/A,10-K/A}` when any preferred-form rows exist; else all rows with `end`.
5. Among pool: max `end`, then max `filed`; **sum** all members with that (end, filed) pair (dual-class multi-member).
6. Invalid JSON / missing facts → nil.

- [ ] Unit tests with minimal JSON fixtures (as `Data` from UTF-8 strings):
  - TSLA-style single EntityCommonStockSharesOutstanding → that value.
  - Two members same end/filed values 100 and 200 → 300.
  - WASO-only us-gaap concepts → nil.
  - Prefer 10-Q over older non-preferred when both present (if easy; else document).
- [ ] Register pbxproj.
- [ ] Commit: `Add CompanyFactsOutstandingResolver for mcap share counts`

### Implementer dispatch

````
MARSHAL_TASK_ID: 4
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: implementer

Implement Task 4: CompanyFactsOutstandingResolver (pure, WASO rejected).

Spec §2 Fetch resolve rules. No network in this task.

When you finish, report DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
followed by a one-paragraph summary. Do not mark yourself completed —
the orchestrator dispatches reviewers next.
````

### Spec-reviewer dispatch

````
MARSHAL_TASK_ID: 4
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: spec-reviewer

Review Task 4 against spec §2 concept priority, multi-member sum, WASO reject, latest selection.

Write verdict to docs/marshal/plans/2026-08-07-tsla-spcx-merger-card/reviews/task-4-spec.md
````

### Code-quality-reviewer dispatch

````
MARSHAL_TASK_ID: 4
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: code-quality-reviewer

Review Task 4 parser robustness and fixture tests.

Write verdict to docs/marshal/plans/2026-08-07-tsla-spcx-merger-card/reviews/task-4-quality.md
````

---

## Task 5: Issuer outstanding sync + GainsViewModel presentation

**Depends on:** 3, 4

### Files touched

- Muskometer/Services/IssuerOutstandingSyncService.swift
- Muskometer/ViewModels/GainsViewModel.swift
- Muskometer.xcodeproj/project.pbxproj
- MuskometerTests/MuskometerTests.swift

### Steps

- [ ] Create `IssuerOutstandingSyncService`:
  - `init(session: URLSession = .shared)`
  - User-Agent: same pattern as `SECHoldingsSyncService` (`Muskometer/\(AppVersion.short) (info@muskometer.org; https://muskometer.org)`).
  - `func fetchOutstanding(for specs: [TrackedHoldingSpec]) async -> [String: Int64]`
  - For each spec with non-empty `issuerCIKPadded`: GET `https://data.sec.gov/api/xbrl/companyfacts/CIK{padded10}.json`, parse with resolver, on success include symbol→shares; on any failure skip symbol (never throw out of `fetchOutstanding`).
  - Small delay between requests (~120ms) like Form 4 crawl.
- [ ] Wire in `GainsViewModel.syncHoldingsFromSEC`:
  - After Form 4 `applyHoldingsSync` path (success or partial or even in `catch` after recording attempt is fine — prefer **always try outstanding best-effort when Form 4 attempt runs**, including after partial/complete Form 4; on Form 4 throw still attempt outstanding so companyfacts can update independently).
  - For each positive result: `settings.setSharesOutstanding(shares, for: symbol)`.
  - Outstanding failure must not change `holdingsSyncMessage` error semantics for Form 4 (silent best-effort).
- [ ] Add computed property on `GainsViewModel`:

```swift
var mergerParityPresentation: MergerParityPresentation? {
    guard let snapshot else { return nil }
    guard let tsla = snapshot.holdings.first(where: { $0.symbol == "TSLA" }),
          let spcx = snapshot.holdings.first(where: { $0.symbol == "SPCX" }) else {
        return nil
    }
    return MergerMarketCapParity.presentation(
        tslaPrice: tsla.quote.currentPrice,
        spcxPrice: spcx.quote.currentPrice,
        tslaOutstanding: settings.sharesOutstanding(for: "TSLA"),
        spcxOutstanding: settings.sharesOutstanding(for: "SPCX")
    )
}
```

- [ ] Optional inject: factory or default `IssuerOutstandingSyncService()` for tests (keep simple if hard — pure calculator already tested; smoke-test presentation with real AppSettings + synthetic snapshot if VM allows).
- [ ] Register pbxproj.
- [ ] Commit: `Sync issuer outstanding from companyfacts; expose merger parity presentation`

### Implementer dispatch

````
MARSHAL_TASK_ID: 5
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: implementer

Implement Task 5: Issuer outstanding sync + GainsViewModel presentation.

Spec §2 sync orthogonality, §4 wiring, Error handling table.
Form 4 must not fail solely because companyfacts fails.

When you finish, report DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
followed by a one-paragraph summary. Do not mark yourself completed —
the orchestrator dispatches reviewers next.
````

### Spec-reviewer dispatch

````
MARSHAL_TASK_ID: 5
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: spec-reviewer

Review Task 5: orthogonal sync, presentation keys TSLA/SPCX, defaults-only still computable via sharesOutstanding defaults.

Write verdict to docs/marshal/plans/2026-08-07-tsla-spcx-merger-card/reviews/task-5-spec.md
````

### Code-quality-reviewer dispatch

````
MARSHAL_TASK_ID: 5
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: code-quality-reviewer

Review Task 5 concurrency/MainActor, error isolation, User-Agent, injectability.

Write verdict to docs/marshal/plans/2026-08-07-tsla-spcx-merger-card/reviews/task-5-quality.md
````

---

## Task 6: MergerParityCardView on main popover

**Depends on:** 5

### Files touched

- Muskometer/Views/MergerParityCardView.swift
- Muskometer/Views/PopoverContentView.swift
- Muskometer.xcodeproj/project.pbxproj

### Steps

- [ ] Create `MergerParityCardView` taking `MergerParityPresentation` (and optional `animateValues` like stock rows).
  - Title: `If TSLA matched SPCX’s market cap` (use typographic apostrophe consistent with app, or ASCII `SPCX's` — match existing copy style in popover).
  - Primary: `CurrencyFormatter.formatPrice(impliedTSLAPrice)` large rounded bold monospaced.
  - Caption: SPCX and TSLA market caps via `formatMarketValue` plus current TSLA price for contrast, e.g. `SPCX $X · TSLA now $Y ($Z/sh)`.
  - Card chrome: match `StockRowView` padding/cornerRadius/background opacity.
- [ ] In `PopoverContentView.dataView`, **after** the `ForEach(snapshot.holdings)` stock rows (and before the error caption if any):

```swift
if let presentation = viewModel.mergerParityPresentation {
    MergerParityCardView(presentation: presentation, animateValues: true)
}
```

- [ ] Register pbxproj.
- [ ] Typecheck or build to ensure view compiles.
- [ ] Commit: `Show merger market-cap parity card on main popover`

### Implementer dispatch

````
MARSHAL_TASK_ID: 6
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: implementer

Implement Task 6: MergerParityCardView on main popover.

Spec §5 UI. Always-on when presentation non-nil; no settings toggle.

When you finish, report DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
followed by a one-paragraph summary. Do not mark yourself completed —
the orchestrator dispatches reviewers next.
````

### Spec-reviewer dispatch

````
MARSHAL_TASK_ID: 6
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: spec-reviewer

Review Task 6 placement after stock rows, copy framing (illustrative parity), hide when nil.

Write verdict to docs/marshal/plans/2026-08-07-tsla-spcx-merger-card/reviews/task-6-spec.md
````

### Code-quality-reviewer dispatch

````
MARSHAL_TASK_ID: 6
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: code-quality-reviewer

Review Task 6 SwiftUI consistency with existing cards.

Write verdict to docs/marshal/plans/2026-08-07-tsla-spcx-merger-card/reviews/task-6-quality.md
````

---

## Task 7: HOLDINGS.md + full verification

**Depends on:** 6

### Files touched

- docs/HOLDINGS.md

### Steps

- [ ] Add a section to `docs/HOLDINGS.md` covering:
  - Issuer shares outstanding (companyfacts + cover defaults) vs Form 4 **ownership**
  - Dual-class SPCX: mcap ≈ Class A price × (A+B)
  - Formula: implied TSLA = SPCX mcap / TSLA outstanding
  - Card is illustrative only
- [ ] **Verification (required):**
  - **WHAT:** Spec acceptance criteria 1–7: Loneliest string; card wiring; formula; Form 4 independence; reset reseeds outstanding; unit tests for resolver/calculator/typo/settings; HOLDINGS updated.
  - **HOW:** From worktree root run:

```bash
export MUSKOMETER_SKIP_LIVE_YAHOO=1
./scripts/verify.sh
```

    If live Yahoo skip is insufficient, at minimum:

```bash
SDK=$(xcrun --show-sdk-path)
swiftc -typecheck -target arm64-apple-macos14.0 -sdk "$SDK" -module-name Muskometer -parse-as-library $(find Muskometer -name "*.swift" | sort)
xcodebuild test -scheme Muskometer -configuration Debug -destination 'platform=macOS' -derivedDataPath build/verify-merger-card
```

    Expect typecheck PASS and unit tests PASS (0 failures). Capture any failure and fix before DONE.
  - **WHO:** This task (implementer runs verification in-plan).
- [ ] Fix any bugs found during verification that block acceptance (within feature scope).
- [ ] Commit: `Document issuer outstanding for merger parity; verify build and tests`

### Implementer dispatch

````
MARSHAL_TASK_ID: 7
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: implementer

Implement Task 7: HOLDINGS.md + full verification.

Run the HOW commands from the task body; do not claim success without green output.
Fix in-scope bugs discovered during verification.

When you finish, report DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
followed by a one-paragraph summary including test result summary. Do not mark yourself completed —
the orchestrator dispatches reviewers next.
````

### Spec-reviewer dispatch

````
MARSHAL_TASK_ID: 7
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: spec-reviewer

Review Task 7 docs against spec §6 and that verification evidence supports acceptance criteria.

Write verdict to docs/marshal/plans/2026-08-07-tsla-spcx-merger-card/reviews/task-7-spec.md
````

### Code-quality-reviewer dispatch

````
MARSHAL_TASK_ID: 7
MARSHAL_PLAN_SLUG: 2026-08-07-tsla-spcx-merger-card
MARSHAL_ROLE: code-quality-reviewer

Review Task 7 doc clarity and that verify was actually run (look for residual compile issues in tree).

Write verdict to docs/marshal/plans/2026-08-07-tsla-spcx-merger-card/reviews/task-7-quality.md
````

---

## Deferred

None.

## Tracker

Unanchored (no `tracker_intake`). Mirror to Linear only if `MARSHAL_LINEAR_ENABLED=1`.

---

## Self-review (orchestrator)

| Spec section | Task |
|--------------|------|
| §1 Typo | T1 |
| §2 Outstanding defaults, CIKs, keys, reset, WASO reject | T2, T4 |
| §3 Calculator | T3 |
| §4 VM presentation | T5 |
| §5 UI card after stock rows | T6 |
| §6 HOLDINGS | T7 |
| Sync orthogonality / error table | T5 |
| Acceptance criteria / verify | T7 |
| Reverse direction / HTML 10-Q / settings edit | Deferred None (out of scope in non-goals) |

Placeholder scan: no TBD/TODO in steps. Task IDs 1–7 sequential. Depends graph: 1→2→(3∥4)→5→6→7. pbxproj IDs unique.
