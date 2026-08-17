# Framing audit — 2026-08-17-holdings-surface-refresh-design

Role: `spec-framing-audit`
Round: 1
Scope: meta only (YAML frontmatter, H2 ToC, `## Deferred`, `## Risks`). Spec body, source, and other reviews were not read.

## Findings

- **Open questions.** Status is `design` and `## Deferred` is `None.`, but there is no `## Open questions` slot. Unresolved calls (live popover capture vs HTML mock, shipping the accepted 1.75M vested-RSU undercount in copy, treating the exact old default as remigratable) have nowhere to live except leaked Design prose or silent closure. Deferred is the wrong home for live decisions.
- **Rollback / backout.** `## Rollout` is named; rollback is not. Fingerprint remigration rewrites persisted integers and comparison-history keys are swept on upgrade. A senior reader needs an explicit backout frame: binary revert vs data revert, whether remigration is reversible or only idempotent, and what already-remigrated users keep if the new default or marketing surface is withdrawn.
- **Compliance, attribution, and marketing claims.** The title includes a marketing surface; Risks already treat 10-Q/8-K source language as a must-say and accept a stale outstanding figure. Missing a dedicated frame for how HOLDINGS and marketing copy attribute SEC sources, which claims remain once comparison captions are removed, and whether HTML mocks / screenshots may be used externally.
- **Upgrade / persisted-state contract.** Defaults change, exact-integer fingerprint remigration, and a dead-UserDefaults sweep are a user-state contract, not only a risk bullet or a ship step. `## Rollout` typically covers flags and versions; it does not name first-launch-after-upgrade behavior, Reset vs upgrade-without-Reset, or which keys are rewritten vs left behind.

VERDICT: NEEDS_FIXES: missing Open questions, Rollback, Compliance/messaging, and Upgrade/persisted-state frames

reviewed-content-sha256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

plan-graph-sha256: 01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b
