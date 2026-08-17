# Framing audit — 2026-08-17-holdings-surface-refresh-design

Role: `spec-framing-audit`
Scope: meta only (YAML frontmatter, H2 ToC, `## Deferred`, `## Risks`). Spec body, source, and other reviews were not read.

## Cold hypotheses

Given a holdings-surface refresh that changes defaults, extends a 2028 calendar, drops comparison captions, and adds a marketing surface, the change is most plausibly under-framed on:

1. Defaults remigration that over-applies to intentional custom integers, or under-applies to users still on factory defaults.
2. Orphaned comparison-history / caption persistence keys after captions are dropped.
3. Hard-coded 2028 vest / award dates drifting from 10-Q / 8-K / award-agreement language.
4. Marketing or screenshot copy still asserting comparison deltas the live UI no longer shows.
5. An outstanding-share figure used in holdings math or marketing that is stale or undercounted.
6. Irreversible remigration: binary revert does not restore prior integers; already-remigrated users keep the new values.
7. First-launch-after-upgrade, Reset, and fresh-install paths diverging on which keys are rewritten vs left behind.
8. Remaining HOLDINGS / marketing copy becoming the entire public claim set once captions are gone (SEC-adjacent wording).
9. Year-boundary / timezone calendar misses around vest dates.
10. Multi-device or in-session races if remigration and user edits (or synced defaults) interleave.
11. Years after 2028 treated as in-scope without being named, or silently omitted without a deferral.
12. Comparison captions having been the only non-visual explanation of a delta (a11y).
13. New marketing-surface analytics / export of holdings (privacy).
14. Widget, share-sheet, or store-screenshot surfaces desyncing from the refreshed UI.
15. Operational scale cliffs if the marketing surface is a public networked page rather than in-app copy.
16. Silent dependence on an external outstanding / companyfacts feed being available and schema-stable.

## Check against named frames

The H2 ToC already names every load-bearing frame a senior reader would demand for this title: Problem / Goals / Non-goals, Current architecture, Design, Acceptance criteria, Testing strategy, Risks, Observability, Open questions, Upgrade / persisted-state contract, Rollback, Compliance & messaging, Rollout, Dependencies / external contracts, Alternatives considered, Deferred, Scale & Validation.

Named risks map onto the distinctive failure modes of the title:

- Migration overreach (exact-integer remigration) → hypotheses 1
- Dead UserDefaults → hypothesis 2
- Calendar drift → hypotheses 3, 9
- Screenshot fidelity → hypotheses 4, 14
- Cursor outstanding undercount → hypotheses 5, 16

Upgrade / persisted-state contract + Rollback cover hypotheses 6–7. Compliance & messaging covers 8 (and 13 at the claim/privacy boundary). Rollout covers version skew. Dependencies / external contracts covers the outstanding / filing feed. Scale & Validation covers 15. Open questions + Alternatives considered make `## Deferred` as the literal `None.` credible: residual uncertainty has a home that is not silent closure and not a fake deferral.

Hypotheses 10–12 are the only ones without a dedicated risk bullet. They are not material framing holes: (10) multi-device remigration is speculative without a sync surface in the title and can live under the upgrade-contract H2 if it exists; (11) post-2028 calendar rows are a future-year chore already bounded by the "2028 calendar" title and by calendar-drift; (12) caption-as-text-alternative is an in-frame Design / Testing / Acceptance concern, not an unnamed product axis. Manufacturing SOC 2 / GDPR / queue-depth additions would ignore that this is a client holdings-surface refresh whose compliance and scale frames are already first-class H2s.

Compliance-of-deferral: Deferred is the literal `None.`. Nothing is being treated as deferrable that has hidden coupling.

## Findings

None.

VERDICT: APPROVED

reviewed-content-sha256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

plan-graph-sha256: 01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b
