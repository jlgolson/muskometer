---
main_sha_at_review: c5495b1a9417d7ff66aa6c40046e9e9e0343006d
branch_tip_sha: 651351e4fc0a4230938c0a29d042c6bb986b7f92
reviewed_at: 2026-08-08T14:30:00Z
pr_number: 3
---

# Pre-merge review — round 2

**Role:** pre-merge-reviewer  
**PR:** https://github.com/jlgolson/muskometer/pull/3  
**Plan:** `docs/marshal/plans/2026-08-07-tsla-spcx-merger-card.md`  
**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md`  
**Diff basis:** product + tests + docs vs `origin/main` (`c5495b1…` → `651351e…`); tip advanced 5 commits past round-1 tip `2bfbca9…` (copy, settings toggle, version 0.1.4 / build 25).

## Summary

Fresh whole-PR re-review after post–round-1 tip advance. Core merger-parity path is unchanged and still sound: issuer companyfacts (best-effort, WASO never read) → orthogonal `sharesOutstanding_*` settings → pure `MergerMarketCapParity` → main-popover card after stock rows. Form 4 ownership remains isolated at keys, apply path, completeness gate, failure messaging, and UI consumers. New since R1: Settings toggle `showMergerParityCard` (default on, persists, reset reseeds), tightened card copy, and coordinated **0.1.4 / build 25** release tick. Unit coverage covers calculator, resolver, outstanding settings, VM presentation/sync isolation, Loneliest copy, and the new toggle. No critical or important defects found.

## Delta since pre-merge round 1 (`2bfbca9` → `651351e`)

| Change | Assessment |
|--------|------------|
| Title → “If Tesla had SpaceX's market cap”; caption → market caps only | Spec allowed copy refinement; HOLDINGS title updated to match |
| `AppSettings.showMergerParityCard` + Settings toggle + popover gate | Default on preserves design “card shows when data allows”; hide is opt-out only |
| Toggle tests + reset-on | Persistence pattern matches `showMenuBarIcon`; suite-isolated UD tests |
| MARKETING_VERSION 0.1.4 / CURRENT_PROJECT_VERSION 25 | Consistent across app + test targets, CHANGELOG, README, INSTALL, RELEASE, SECURITY |
| CHANGELOG 0.1.4 entry | Documents card, outstanding, Loneliest, and toggle |

## Strong points

- Clear Form 4 **ownership** vs issuer **outstanding** separation (`shareCount_*` / `sharesOutstanding_*`, independent loaders, never-throw outstanding after Form 4 do/catch).
- Pure calculator and pure resolver with thorough guard/fixture tests (WASO-only nil, multi-member sum, form preference, non-finite prices).
- Defaults-only still yields presentation when both quote legs exist; hide only for missing quotes, guard failure, or explicit user toggle off.
- pbxproj registers all five new sources (`…50`–`…54`) in correct groups and Sources phase.
- Toggle uses shared `@Observable` `AppSettings` (`viewModel.settings` in popover and SettingsView) — no second settings instance.
- Holdings sync backoff tests inject empty outstanding mock so CI does not hit live companyfacts.

## Critical findings

None.

## Important findings

None.

## Minor findings / residual notes (non-blocking)

1. **`docs/PRIVACY.md`** still says public release **0.1.3** and lists only Form 4 under SEC purpose / share counts under prefs — does not name `sharesOutstanding_*`, `showMergerParityCard`, or companyfacts. Runtime privacy posture is unchanged (same hosts); docs drift only.
2. **HOLDINGS hide rule** still says the card is hidden only when a quote leg is missing or guards fail — now also when the Settings toggle is off. Product + CHANGELOG are clear; HOLDINGS one-liner slightly incomplete.
3. **Multi-row sum without member identity** (`CompanyFactsOutstandingResolver`): design dual-class rule; cannot distinguish total+class duplicates if SEC ever publishes both. SPCX currently has no mcap concepts → cover default preserved. Accept residual.
4. **MainActor parse of multi-MB companyfacts** after await on the holdings path can hitch briefly once per ~24h — same pattern as Form 4; daily cadence acceptable.
5. **`currentTSLAPrice`** remains on `MergerParityPresentation` but is unused after caption tighten — harmless leftover for contrast/future copy.
6. **Outstanding loop** does not short-circuit on task cancellation (`try? await Task.sleep`); two-CIK daily loop makes cost negligible.

## Active-tracing notes

| Invariant | Result |
|-----------|--------|
| SEC outstanding write → settings read → presentation | `setSharesOutstanding` / `sharesOutstanding(for:)` + default fallback; VM uses settings outstanding only |
| Calculator pure guards | Non-finite / ≤0 inputs and outputs → nil; happy path `spcxPrice × spcxOutstanding / tslaOutstanding` |
| Form 4 completeness gate | Outstanding never participates; isolation tests Form 4 fail + outstanding succeed, and Form 4 success + empty outstanding |
| WASO must not overwrite SPCX default | Concepts never read; WASO-only fixture → nil; empty fetch keeps defaults |
| Toggle default-on / persist / reset | Fresh suite default true; false reloads; `resetToDefaults` turns back on; popover gates on `showMergerParityCard && presentation` |
| Version surface | 0.1.4 / 25 in pbxproj (Debug/Release app + tests); AppVersion reads Info.plist macros |

## Whole-diff interaction backstop

- `applyHoldingsSync` still ownership-only; outstanding applied only in `syncIssuerOutstanding`.
- `TrackedHoldingSpec.issuerCIKPadded` only at musk TSLA/SPCX call sites; compile surface complete.
- Popover places card after stock rows, before error caption — Musk-centric content first.
- Typo: zero `Lonliest` under `Muskometer/` / `MuskometerTests/`.
- Settings UI non-goal in design was **manual outstanding edit** — show/hide toggle is additive product polish, not that non-goal.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{
  "schema_version": 1,
  "dispatch_id": null,
  "verdict": "approved",
  "round": 2,
  "role": "pre-merge-reviewer",
  "pr_number": 3,
  "main_sha_at_review": "c5495b1a9417d7ff66aa6c40046e9e9e0343006d",
  "branch_tip_sha": "651351e4fc0a4230938c0a29d042c6bb986b7f92",
  "findings": []
}
```

VERDICT: APPROVED

Diff-sha256: b104c4af7404e5c5be69b6a5151320c29f765f645f507cbc3a4aff8aaff66795
