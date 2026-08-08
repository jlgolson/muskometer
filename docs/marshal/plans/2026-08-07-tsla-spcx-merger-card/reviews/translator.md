# Plan→Spec Translator Review

**Role:** plan-to-spec-translator  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md`  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md`  
**Date:** 2026-08-07  
**Revision:** Re-read after Task 4 form-preference unit test made **Required** (was previously optionalized).

Method: plan read cold first (four produces sections), then design opened and compared.

---

## Part A — What plan execution produces (cold plan only)

### 1. New files

| Path | Introduced in | Role |
|------|---------------|------|
| `Muskometer/Utilities/IssuerSharesOutstanding.swift` | Task 2 | Bundled TSLA/SPCX issuer outstanding defaults + UserDefaults key helper |
| `Muskometer/Utilities/MergerMarketCapParity.swift` | Task 3 | Pure calculator + `MergerParityPresentation` model |
| `Muskometer/Services/CompanyFactsOutstandingResolver.swift` | Task 4 | Pure SEC companyfacts JSON → outstanding Int64 (WASO rejected) |
| `Muskometer/Services/IssuerOutstandingSyncService.swift` | Task 5 | Best-effort companyfacts fetch per issuer CIK |
| `Muskometer/Views/MergerParityCardView.swift` | Task 6 | Main-popover parity card UI |

Each new `.swift` file is registered in `Muskometer.xcodeproj/project.pbxproj` with plan-specified build/file ref IDs (`…50`–`…54`).

### 2. Modified files

| Path | Tasks | Change summary |
|------|-------|----------------|
| `Muskometer/Services/NetWorthMilestoneTracker.swift` | 1 | `belowTrillionMessage`: Lonliest → Loneliest |
| `MuskometerTests/MuskometerTests.swift` | 1–5 | Typo test rename/assert; outstanding settings tests; calculator tests; resolver fixture tests (incl. required form-preference); optional VM smoke |
| `Muskometer/Models/TrackedPersonProfile.swift` | 2 | `TrackedHoldingSpec.issuerCIKPadded`; Musk TSLA/SPCX CIKs |
| `Muskometer/Utilities/AppSettings.swift` | 2 | `sharesOutstandingBySymbol`, get/set, `resetToDefaults` reseeds outstanding (isolated from Form 4 ownership) |
| `Muskometer.xcodeproj/project.pbxproj` | 2–6 | PBX entries for five new sources |
| `Muskometer/ViewModels/GainsViewModel.swift` | 5 | Orthogonal companyfacts sync in SEC path; `mergerParityPresentation` |
| `Muskometer/Views/PopoverContentView.swift` | 6 | Card after stock-row `ForEach` when presentation non-nil |
| `docs/HOLDINGS.md` | 7 | Issuer outstanding vs Form 4; dual-class SPCX; formula; illustrative note |

### 3. New behaviors

1. **Typo fix:** Product easter-egg string and tests use `One Trillion Is the Loneliest Number`; product/test tree has no remaining `Lonliest` literals.
2. **Issuer outstanding defaults:** Bundled TSLA `3_949_547_394`, SPCX `13_181_779_945` (A+B cover-derived); cold start / offline / failed resolve use these.
3. **Persistence:** Independent `sharesOutstanding_SYMBOL` keys; get falls back to defaults then `0`; set only when `count > 0`; reset reseeds to bundled defaults without touching Form 4 ownership completeness.
4. **Issuer CIKs on holdings:** TSLA `0001318605`, SPCX `0001181412` on `TrackedHoldingSpec` for companyfacts sync.
5. **Parity calculator:** `impliedTSLAPrice = (spcxPrice × spcxOutstanding) / tslaOutstanding`; also exposes both market caps and current TSLA price; nil on non-finite / ≤0 inputs.
6. **Companyfacts resolve:** Concept priority EntityCommonStockSharesOutstanding → CommonStockSharesOutstanding (`shares` only); preferred forms; latest `(end, filed)`; multi-member sum; **WASO → nil** (never store wrong outstanding).
7. **Orthogonal sync:** After Form 4 attempt path (including on Form 4 throw), best-effort companyfacts fetch with same SEC User-Agent and inter-request delay; failures silent w.r.t. Form 4 messages; successes overwrite outstanding only.
8. **Presentation:** `GainsViewModel.mergerParityPresentation` from live TSLA/SPCX snapshot quotes + settings outstanding (defaults-only still computable).
9. **UI:** Always-on card after stock rows when presentation non-nil; title “If TSLA matched SPCX’s market cap”; primary implied price; caption with mcaps / current TSLA; StockRow-like chrome; no settings toggle.
10. **Docs + verify:** HOLDINGS documents model; `./scripts/verify.sh` (or typecheck + xcodebuild test) green against acceptance criteria 1–7.

### 4. Explicitly not doing

From plan self-review / Deferred / task boundaries:

- Reverse direction (SPCX priced at TSLA mcap).
- Parsing 10-Q HTML cover pages.
- Settings UI to edit outstanding shares manually.
- Yahoo `marketCap` / `quoteSummary`.
- Folding outstanding into Form 4 `applyHoldingsSync` / ownership completeness gate.
- Legal merger, exchange ratio, dilution, preferred, control premium, fully diluted counts.
- Multi-person profile generalization beyond Musk TSLA/SPCX data hooks.
- Optional nice-to-haves not tasked: concept/filed metadata captions, last-sync timestamp UI, analytics.
- No deferred backlog items (Deferred: None).

---

## Part B — Spec comparison (after reading design)

### Map: plan produces → design sections

| Spec section / requirement | Plan coverage | Task(s) |
|----------------------------|---------------|---------|
| Problem / Goals: implied TSLA under SPCX mcap parity (Class A price × A+B) | Formula + presentation + card | T3, T5, T6 |
| Goals: issuer outstanding from SEC point-in-time; not Yahoo / Form 4 / WASO | Defaults + resolver + sync | T2, T4, T5 |
| Goals: main popover card, resilient defaults-only show | Card after rows; presentation via settings defaults | T5, T6 |
| Goals: Loneliest typo | Product + tests + grep | T1 |
| Non-goals (reverse, Yahoo mcap, Form 4 proxy, settings edit, multi-person, HTML 10-Q, legal merger) | Explicitly out of scope / Deferred None notes non-goals | All |
| §1 Typo fix | Exact string + test rename | T1 |
| §2 Definition TSLA single / SPCX A+B; reject WASO | Defaults A+B; resolver rejects WASO | T2, T4 |
| §2 Issuer CIKs on TrackedHoldingSpec | `issuerCIKPadded` TSLA/SPCX | T2 |
| §2 Bundled defaults + accession comments | Exact constants + comments in `IssuerSharesOutstanding` | T2 |
| §2 Fetch on ~24h SEC path, orthogonal to Form 4 | `IssuerOutstandingSyncService` from `syncHoldingsFromSEC` | T5 |
| §2 Concept priority, multi-member sum, form preference, latest end/filed, shares unit | Resolver rules + **required** form-preference unit test | T4 |
| §2 Independent UserDefaults keys; reset reseeds | AppSettings API + tests | T2 |
| §2 Sync completeness / error table (companyfacts fail keeps prior; Form 4 unaffected) | Best-effort; silent outstanding failures | T5 |
| §3 Pure calculator + guards | `MergerMarketCapParity` + unit tests | T3 |
| §4 VM wiring; hide only on missing quotes / guards; show defaults-only | `mergerParityPresentation` | T5 |
| §5 UI after stock rows; copy framing; native card chrome; no reverse/settings | `MergerParityCardView` + PopoverContentView | T6 |
| §6 HOLDINGS | Section on outstanding vs ownership, dual-class, formula, illustrative | T7 |
| Testing matrix (resolver single, multi-member, WASO, latest+(form preference), calculator, typo, settings) | T1–T4 unit tests; T4 form-preference **Required**; T7 verify | T1–T4, T7 |
| Acceptance criteria 1–7 | T7 verification checklist + prior tasks | T7 |
| Compliance: illustrative parity wording | Card title + HOLDINGS | T6, T7 |
| Rollout: always-on, no kill switch | Card when presentation non-nil | T6 |
| Observability: optional timestamp / debug log not required | Not implemented (correct omission) | — |
| Optional metadata captions not required | Not implemented (correct omission) | — |

### Missing coverage (spec → plan gaps)

| Spec item | Severity | Notes |
|-----------|----------|-------|
| Design **Testing**: “Unit: latest selection by `(end, filed)` **and form preference**” | **None (closed)** | Prior review flagged T4 optionalizing this fixture. Plan T4 now marks form-preference as **Required** with assertion that preferred 10-Q/10-K form rows win over non-preferred when both present (even with competing later `filed` / `end` per resolver rules). Aligns with design Testing section. |
| Design **Rollout**: changelog / release notes when shipping | **Negligible** | Process/release concern; not a code task. Correct to omit from implementer tasks. |
| Design **Observability** optional last-successful-sync timestamp | **None** | Explicitly not required for v1 UI. |

No material functional requirement from Goals, Design §§1–6, Error handling, Testing, Acceptance criteria, Non-goals, or Dependencies is left without a task that implements it.

### Scope creep (plan → beyond / against spec)

| Plan item | Verdict |
|-----------|---------|
| Five new named files + fixed pbxproj hex IDs | Implementation detail within design sketch — **not creep** |
| ~120ms delay between companyfacts requests | Matches Form 4 crawl pattern; consistent with SEC politeness — **not creep** |
| Attempt outstanding even after Form 4 throw | Strengthens orthogonality required by error table — **not creep** |
| Grep zero remaining `Lonliest` in product/test | Hardens §1 / AC1 — **not creep** |
| `verify.sh` / full typecheck+test gate in T7 | Directly supports AC + Testing — **not creep** |
| Required form-preference fixture (preferred form wins over competing non-preferred) | Matches design Testing + §2 selection rules — **not creep** |
| Reverse / HTML 10-Q / settings edit / Yahoo mcap | Explicitly excluded — **no creep** |
| Live SEC integration test | Spec forbids mandatory CI live test; plan unit-only — **aligned** |

No task expands into non-goals or invents product surface beyond the design.

### Formula / data contract fidelity

| Contract | Spec | Plan | Match |
|----------|------|------|-------|
| SPCX mcap | Class A Yahoo × (A+B) | `spcxPrice * Double(spcxOutstanding)` with default A+B total | Yes |
| Implied TSLA | SPCX mcap / TSLA outstanding | Same | Yes |
| TSLA default | `3_949_547_394` | Same | Yes |
| SPCX default | `13_181_779_945` (A `7_696_293_669` + B `5_485_486_276`) | Same + accession comment | Yes |
| CIKs | TSLA `0001318605`, SPCX `0001181412` | Same on holding specs | Yes |
| Endpoint | `data.sec.gov/.../companyfacts/CIK{padded}.json` | Same | Yes |
| User-Agent | Existing EDGAR pattern | Mirror `SECHoldingsSyncService` | Yes |
| WASO | Reject / keep default | Resolver nil; set only on positive resolve | Yes |
| Card placement | After stock rows | After `ForEach(snapshot.holdings)` | Yes |
| Hide condition | Missing quote leg / calculator nil | Presentation optional + `if let` | Yes |

### Task graph vs design

```
T1 typo ──► T2 defaults/CIKs/settings ──┬──► T3 calculator ──┐
                                        └──► T4 resolver  ──┴──► T5 sync+VM ──► T6 UI ──► T7 docs+verify
```

Parallel T3∥T4 after T2 matches independent pure utilities before wiring. Self-review table in plan maps every design section to a task. Placeholder scan clean; Deferred empty matches design Deferred.

### Delta from prior translator review

| Prior finding | Status after re-read |
|---------------|----------------------|
| T4 form-preference unit test optionalized (“if easy; else document”) vs design Testing requiring latest+(form preference) coverage | **Closed.** T4 step now: “**Required:** Prefer 10-Q/10-K form rows over older non-preferred forms when both present…” |

---

## Part C — Verdict summary

Plan is a faithful, task-decomposed translation of the design. Implementation files, behaviors, full Testing-section unit coverage (including form preference), acceptance verification, and non-goals line up with Goals through Acceptance criteria. Prior soft gap on form-preference test optionality is resolved. No scope creep into non-goals. Negligible process-only items (changelog at release) correctly omitted from code tasks.

**Recommendation for implementers:** None beyond following task steps as written; implement the required T4 form-preference fixture so design Testing stays green without ambiguity.

---

COVERAGE: FULL_MATCH
