# Framing audit — 2026-08-17-holdings-surface-refresh-design

Role: `spec-framing-audit`
Scope: meta only (YAML frontmatter, H2 ToC, `## Deferred`, `## Risks`). Spec body, source, and other reviews were not read.

## Cold hypotheses

Given a holdings-surface refresh that changes defaults, extends a 2028 calendar, drops comparison captions, and adds a marketing surface, the change is most plausibly under-framed on:

1. Defaults remigration that over-applies to intentional custom integers, or under-applies to users still on factory defaults.
2. Orphaned comparison-history / caption persistence keys after captions are dropped.
3. Hard-coded 2028 vest / award dates drifting from 10-Q / 8-K / award-agreement language, including year-boundary and timezone misses.
4. Marketing or screenshot copy still asserting comparison deltas the live UI no longer shows.
5. An outstanding-share figure used in holdings math or marketing that is stale or undercounted.
6. Irreversible remigration: binary revert does not restore prior integers; already-remigrated users keep the new values.
7. First-launch-after-upgrade, Reset, and fresh-install paths diverging on which keys are rewritten vs left behind; remigration running twice across version skew.
8. Remaining HOLDINGS / marketing copy becoming the entire public claim set once captions are gone (SEC-adjacent wording).
9. In-session remigration racing user edits, or multi-device Key-Value / iCloud sync if any.
10. Years after 2028, or later unvested awards, treated as in-scope without being named — or silently omitted without a deferral.
11. Comparison captions having been the only non-visual explanation of a delta (a11y).
12. New marketing-surface analytics / export of holdings (privacy), or tax / 83(b) implications implied by a "holdings" claim.
13. Widget, share-sheet, store-screenshot, or leftover deep-link / share-image surfaces desyncing from the refreshed UI.
14. Operational scale cliffs if the marketing surface is a public networked page rather than in-app copy.
15. Silent dependence on an external outstanding / companyfacts feed being available and schema-stable.
16. Strike ignored so displayed value is notional, not economic; stock-split after defaults are baked into remigration fingerprints.
17. Partial remigration leaving mixed old/new default keys.
18. Compliance theater (SOC 2 / PCI / audit-trail) manufactured for a local client surface that does not have those axes.

## Check against named frames

Frontmatter is complete (`slug`, `title`, `date`, `branch`, `status: design`). The H2 ToC already names every load-bearing frame a senior reader would demand for this title: Problem / Goals / Non-goals, Current architecture, Design, Acceptance criteria, Testing strategy, Risks, Observability, Open questions, Upgrade / persisted-state contract, Rollback, Compliance & messaging, Rollout, Dependencies / external contracts, Alternatives considered, Deferred, Scale & Validation.

Named risks map onto the distinctive failure modes of the title:

- Migration overreach → hypothesis 1 (over-apply; under-apply is the inverse and lives under the upgrade-contract H2)
- Dead UserDefaults → hypothesis 2
- Calendar drift → hypotheses 3, 10
- Screenshot fidelity → hypotheses 4, 13
- Cursor outstanding undercount → hypotheses 5, 15
- Future unvested options → hypotheses 10, 16 (post-2028 / later awards)
- Strike ignored → hypothesis 16

Upgrade / persisted-state contract + Rollback cover hypotheses 6–7 and 17. Compliance & messaging covers 8 and 12. Rollout covers version skew. Dependencies / external contracts covers the outstanding / filing feed. Scale & Validation covers 14. Observability covers operational visibility of remigration and the outstanding path. Open questions + Alternatives considered make `## Deferred` as the literal `None.` credible: residual uncertainty has a home that is not silent closure and not a fake deferral.

Hypotheses without a dedicated risk bullet are not material framing holes: (9) multi-actor remigration is speculative without a sync surface in the title and can live under the upgrade-contract H2; (11) caption-as-text-alternative is an in-frame Design / Testing / Acceptance concern, not an unnamed product axis; (18) manufacturing SOC 2 / PCI / queue-depth additions would ignore that this is a client holdings-surface refresh whose compliance and scale frames are already first-class H2s.

Compliance-of-deferral: Deferred is the literal `None.`. Nothing is being treated as deferrable that has hidden coupling.

## Findings

None.

VERDICT: APPROVED

Reviewed-files: docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md

reviewed-content-sha256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

plan-graph-sha256: 01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b
