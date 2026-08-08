# Task 7 Code Quality Review — HOLDINGS.md + verification evidence

**Role:** code-quality-reviewer  
**Task:** 7 (HOLDINGS.md clarity + verify actually run; residual compile hygiene)  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md` Task 7  
**Date:** 2026-08-08  
**Commit reviewed:** `38c2fa3512e90373412fc2a9fb20fa6d208c964c` — *Document issuer outstanding for merger parity; verify build and tests*

## Scope reviewed

Quality axes: docs clarity (design §6 / acceptance 7), scope discipline (docs + verify only; in-scope bugfixes only if verify failed), no accidental product breakage in the Task 7 commit, residual compile/test hygiene from on-disk verify artifacts.

## Findings

None blocking.

### Commit scope discipline

| Check | Status |
|-------|--------|
| Commit message matches plan | Pass — exact plan string |
| Files changed | Pass — **only** `docs/HOLDINGS.md` (+40 / −0) |
| No Swift / pbxproj / UI / tests in this commit | Pass |
| No drive-by marketing site / DISCLAIMER edits | Pass |
| No accidental product breakage | Pass — pure documentation append; product tree unchanged at this commit |

Task 7’s plan allows fixing in-scope bugs discovered during verify. Zero product files in the commit implies verify was green without residual compile/test patches — consistent with clean derived-data evidence below.

### Docs clarity (`docs/HOLDINGS.md`)

New section **“Issuer outstanding vs Form 4 ownership”** (appended after paper-gain math; keeps prior Form 4 / quotes sections intact).

| Required content (plan Task 7 / design §6) | Present? | Notes |
|-------------------------------------------|----------|-------|
| Issuer outstanding vs Form 4 **ownership** | Yes | Concept table: measures / source / used-for |
| Dual-class SPCX mcap ≈ Class A price × (A+B) | Yes | Dedicated subsection + fenced formula |
| Formula: implied TSLA = SPCX mcap / TSLA outstanding | Yes | Three-line fenced breakdown |
| Card is illustrative only | Yes | Explicit “not a merger announcement…” sentence |
| Independence of Form 4 vs companyfacts | Yes | “never writes / never overwrites”; miss does not fail Form 4 |
| Defaults + accession / concept provenance | Yes | Matches bundled constants |
| WASO reject for mcap | Yes | Explicit; keeps prior/cover default |
| Reset reseeds both | Yes | Settings → Reset sentence |
| Defaults-only still shows card | Yes | Hide only on missing quote leg / guard fail |
| Link to DISCLAIMER | Yes | Existing trailer retained |

**Structure / voice:** Matches pre-existing HOLDINGS style (tables for counts, fenced formulas for math, bold key terms, short operational paragraphs). Hierarchy is scannable: dual-number model → defaults → dual-class → implied formula → illustrative guardrails. Not marketing-site tone; technical note density is appropriate.

**Cross-check vs product constants** (`IssuerSharesOutstanding.swift`):

| Doc value | Code |
|-----------|------|
| TSLA 3,949,547,394 | `defaultTSLA = 3_949_547_394` |
| SPCX 13,181,779,945 | `defaultSPCX = 13_181_779_945` |
| A 7,696,293,669 + B 5,485,486,276 | Comments match sum |
| end 2026-07-16 / cover 2026-07-28 / accession | Comments match |

No drift between HOLDINGS numbers and bundled defaults.

**Card title string:** Docs use curly apostrophe in “SPCX’s”; UI title is ASCII `SPCX's` (`MergerParityCardView`). Cosmetic prose vs product-string difference; not a clarity or correctness issue for this docs task.

### Verification evidence (actually run)

| Evidence | Assessment |
|----------|------------|
| On-disk derived data `build/verify-derived-87263/` | Matches `scripts/verify.sh` naming `build/verify-derived-$$` |
| Test log | `Logs/Test/Test-Muskometer-2026.08.08_00-02-30--0400.xcresult` |
| LogStoreManifest primaryObservable | `totalNumberOfErrors: 0`, `totalNumberOfTestFailures: 0` |
| Analyzer issues | 0 |
| Warnings | 3 (non-failing; status `W`) |
| Products | `Muskometer.app` + test modules present under Debug |

Residual compile hygiene: no evidence of failed typecheck/test requiring product patches in Task 7. Commit stayed docs-only.

## Quality checklist

| Axis | Result |
|------|--------|
| Doc structure | Clear section hierarchy; table + formulas; matches existing HOLDINGS voice |
| Completeness vs §6 / acceptance 7 | All required bullets covered plus useful extras (independence, WASO, reset, hide rules) |
| Numbers vs code | Exact match to `IssuerSharesOutstanding` defaults and comments |
| Scope discipline | Docs-only commit; plan message exact; no product tree touch |
| Product breakage | None possible from this commit’s diff |
| Verify actually run | Strong: PID-named derived data + 0 failures/errors in Test LogStore |

## Non-blocking notes

- GitHub patch for `38c2fa3` reports missing trailing newline at EOF on `HOLDINGS.md`. Harmless; optional one-byte tidy later.
- UI title apostrophe is ASCII; docs prose uses curly in “Musk’s” / “SPCX’s” — fine for markdown narrative.
- Task 7 plan’s primary file list is `docs/HOLDINGS.md` only; verify is a gate, not a second product deliverable — evidence satisfies the gate without scope creep.

VERDICT: APPROVED

## Reviewed files

- `docs/HOLDINGS.md` — structure, dual-number model, dual-class, formula, illustrative copy, defaults/WASO/reset
- Commit `38c2fa3512e90373412fc2a9fb20fa6d208c964c` (via API/diff) — scope: docs-only +40/−0
- `Muskometer/Utilities/IssuerSharesOutstanding.swift` — default / provenance cross-check
- `Muskometer/Views/MergerParityCardView.swift` — card title string cross-check (cosmetic)
- `scripts/verify.sh` — derived-data naming convention
- `build/verify-derived-87263/Logs/Test/LogStoreManifest.plist` — 0 errors / 0 test failures


VERDICT: APPROVED
