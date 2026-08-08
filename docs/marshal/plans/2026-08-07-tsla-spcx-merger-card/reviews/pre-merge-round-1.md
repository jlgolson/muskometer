---
main_sha_at_review: c5495b1a9417d7ff66aa6c40046e9e9e0343006d
branch_tip_sha: 2bfbca96d531a3e5d34243c7cc1c6e792472b3b1
reviewed_at: 2026-08-08T12:00:00Z
pr_number: 3
---

# Pre-merge review — round 1

**Role:** pre-merge-reviewer  
**PR:** https://github.com/jlgolson/muskometer/pull/3  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md`  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md`  
**Diff basis:** product + tests + docs vs `origin/main` (`c5495b1…` → `2bfbca9…`); ~5.3k additions (mostly marshal docs), well under overflow bar.

## Summary

Fresh-eyes whole-PR review of the TSLA–SPCX merger market-cap parity card and Loneliest typo fix. End-to-end data path matches the design: issuer companyfacts (best-effort, WASO never read) → orthogonal `sharesOutstanding_*` settings → pure calculator → main-popover card after stock rows. Form 4 ownership sync stays independent at keys, APIs, completeness gate, failure messaging, and UI consumers. Live SEC companyfacts spot-check: TSLA `EntityCommonStockSharesOutstanding` resolves to the bundled 3_949_547_394 (single latest preferred-form row); SPCX lacks point-in-time Entity/Common outstanding concepts, so resolver correctly stays nil and cover A+B default is preserved. Unit coverage locks the design testing matrix and Form 4 isolation. No critical or important defects found.

## Strong points

- Clear separation of Form 4 **ownership** vs issuer **outstanding** at every layer (`shareCount_*` / `sharesOutstanding_*`, independent loaders, never-throw outstanding fetch after Form 4 do/catch).
- Pure calculator and pure resolver with thorough guard/fixture tests (WASO-only nil, multi-member sum, form preference, non-finite prices).
- Defaults-only still shows the card; hide only when a quote leg is missing or guards fail.
- pbxproj registers all five new sources (`…50`–`…54`) in the correct groups and Sources phase.
- HOLDINGS documents dual-class A+B convention, formula, and illustrative-only posture without weakening disclaimer.

## Critical findings

None.

## Important findings

None.

## Minor findings / residual notes (non-blocking)

1. **Multi-row sum without member identity** (`CompanyFactsOutstandingResolver`): summing all same `(end, filed)` rows is the design dual-class rule, but cannot distinguish total+class duplicates if SEC ever publishes both. Live TSLA payload is single-row at the latest instant; SPCX currently has no mcap concepts so stays on cover default. Accept residual; optional future harden with segment frames or “if multi-row vals equal, take one.”
2. **MainActor parse of multi-MB companyfacts** after await on the holdings path can hitch briefly once per ~24h — same architectural pattern as Form 4 sync; daily cadence keeps cost acceptable.
3. **Outstanding loop** does not short-circuit on task cancellation (`try? await Task.sleep`); two-CIK daily loop makes cost negligible.
4. **Footer** still says “Holdings: SEC EDGAR” only; outstanding also uses companyfacts — documentation is in HOLDINGS; not required by design UI copy.

## Active-tracing notes

| Invariant | Result |
|-----------|--------|
| SEC outstanding write → settings read → presentation | `setSharesOutstanding` / `sharesOutstanding(for:)` round-trip + default fallback tested; VM presentation uses settings outstanding only |
| Calculator pure guards | Non-finite / ≤0 inputs and outputs → nil; happy path `spcxPrice × spcxOutstanding / tslaOutstanding` |
| Form 4 completeness gate | Outstanding never participates; isolation tests for Form 4 fail + outstanding succeed, and Form 4 success + empty outstanding |
| WASO must not overwrite SPCX default | Concepts never read; WASO-only fixture → nil; empty fetch keeps defaults |

## Whole-diff interaction backstop

- `applyHoldingsSync` still ownership-only; outstanding applied only in `syncIssuerOutstanding`.
- Existing holdings-sync backoff tests inject empty outstanding mock so CI does not hit live companyfacts.
- `TrackedHoldingSpec.issuerCIKPadded` only at musk TSLA/SPCX call sites; compile surface complete.
- Popover places card after stock rows, before error caption — Musk-centric content first.
- Typo: zero `Lonliest` under `Muskometer/` / `MuskometerTests/`.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{
  "schema_version": 1,
  "dispatch_id": null,
  "verdict": "approved",
  "round": 1,
  "role": "pre-merge-reviewer",
  "pr_number": 3,
  "main_sha_at_review": "c5495b1a9417d7ff66aa6c40046e9e9e0343006d",
  "branch_tip_sha": "2bfbca96d531a3e5d34243c7cc1c6e792472b3b1",
  "findings": []
}
```

VERDICT: APPROVED

Diff-sha256: 361ef0676b2916bc81501ba33395822e499530e2d3fa40650b2b2b3dc3025a8b
