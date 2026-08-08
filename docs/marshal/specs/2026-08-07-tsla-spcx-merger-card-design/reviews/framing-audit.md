# Spec framing audit

**Spec:** `docs/marshal/specs/2026-08-07-tsla-spcx-merger-card-design.md`  
**Role:** spec-framing-audit  
**Date:** 2026-08-07  
**Scope:** Meta only (YAML frontmatter, H2 ToC, Deferred, Risks). Body not read; no re-litigation of in-body design.

## Meta inventory

| Meta item | Present? | Notes |
|-----------|----------|--------|
| YAML (slug, title, date, branch, status) | Yes | `status: design` |
| Problem / Goals / Non-goals | Yes | Standard triad |
| Current architecture | Yes | Scoped “relevant” |
| Design / Data flow | Yes | Core design spine |
| Error handling | Yes | Named |
| Testing | Yes | Named |
| Implementation sketch (files) | Yes | Named |
| Scale & Validation | Yes | Named |
| Deferred | Yes | Content: **None** |
| Risks | **No** | Explicitly absent |

## Findings

### F1. Missing **Risks** section (blocking framing gap)

The ToC never names Risks, and the meta extract confirms there is no risks section. For a card that presents **issuer market-cap parity** (TSLA public + SPCX private/illiquid) sourced from **SEC companyfacts + quotes + settings**, a senior engineer expects an explicit risk surface, even if short. Typical risk themes this kind of feature almost always needs *named* (not designed here):

- **Wrong-number risk:** mis-stated outstanding, dual-class resolution, or price × shares producing a misleading “merger mcap” that users treat as fact.
- **External dependency risk:** SEC companyfacts schema/availability; quote path for SPCX (or lack thereof); stale bundled defaults presented as live.
- **Product/comms risk:** “merger” framing and parity UI implying a corporate event or valuation claim; interaction with app disclaimer posture.
- **Settings / persistence risk:** new outstanding keys vs ownership keys; reset/default/load paths diverging silently.
- **Easter-egg typo fix risk:** low severity but high visibility if tests/copy drift or intentional jokes regress elsewhere.

**Framing addition:** Add an H2 **Risks** (or **Risks & mitigations**) section. Can be a short table: risk → likelihood/impact → mitigation / residual. Does not need new design depth—only that the document *owns* the risk list.

### F2. No **Acceptance criteria / Definition of done** named

Goals and Testing exist, but meta never names product-level acceptance or a DoD. A senior engineer expects something that answers: *when is the card correct enough to ship?* (visibility rules, default-vs-live outstanding, typo assertion, non-regression of ownership sync). Testing covers verification method; acceptance criteria name the bar.

**Framing addition:** Add **Acceptance criteria** (or fold a short DoD under Goals / Testing) so success is product-checkable, not only unit-test-checkable.

### F3. No **Observability / operability** named

Error handling is present; Scale & Validation is present; nothing names how operators or the author know the outstanding path is healthy in the wild (e.g. companyfacts parse miss → cover default forever, silent stale mcap). For a menu-bar app this can be light (debug logs, optional status in UI, last-sync metadata)—but it should be *framed*.

**Framing addition:** Add a brief **Observability** (or **Operability**) subsection: what is logged, whether last successful outstanding sync is retained/surfaced, and how “using default outstanding” is distinguishable from “live SEC outstanding.”

### F4. No **Rollout / kill switch / release framing**

Implementation sketch and status=design exist; nothing names ship strategy: always-on vs setting, docs/release-note touch, or a way to hide the card if the parity number is wrong in production. For a valuation-adjacent UI, a named kill path or settings gate is a common senior-eng expectation even if the answer is “always on.”

**Framing addition:** Add **Rollout** (or **Release & feature control**): visibility control (if any), docs/changelog ownership, and whether the card can be disabled without a rebuild.

### F5. No **Compliance / disclaimer / user-facing framing**

Title and design imply a **TSLA↔SPCX merger market-cap** presentation. Meta never names legal/disclaimer/copy constraints relative to existing app disclaimer docs. Even a one-liner—“card is informational parity only; no new legal surface” or “must not imply deal certainty”—belongs in framing.

**Framing addition:** Add **Compliance & messaging** (or a Non-goals / Risks bullet that explicitly names disclaimer boundary and user-facing copy constraints for “merger” language).

### F6. No **Alternatives considered** or **Open questions**

Design is present; meta does not name rejected approaches or unresolved product questions. With Deferred = **None**, either everything is decided (fine) or open product/tech choices are hidden. Senior readers expect at least one of: **Alternatives considered**, **Open questions**, or a non-empty **Deferred** when dual-class / private-company data is involved.

**Framing addition:** Add **Alternatives considered** (short) and/or **Open questions**, or populate **Deferred** if any decision is intentionally postponed (e.g. multi-person generalization, live SPCX quote quality, dual-class resolver v2). “None” is only credible if Alternatives/Open questions absorb residual uncertainty.

### F7. No **Dependencies / external contracts** named as a section

Data flow implies SEC + quotes + settings, but meta never elevates **external contracts** (companyfacts concepts, CIK map ownership, quote symbol assumptions) as a first-class framing concern. That usually sits beside Current architecture.

**Framing addition:** Add **Dependencies** (or **External contracts**): endpoints/concepts/symbols the design assumes, and who owns CIK/symbol maps when they change.

## Non-findings (adequately framed at meta)

- Problem / Goals / Non-goals triad is present.
- Architecture → Design → Data flow → Error handling → Testing → Implementation sketch is a complete engineering spine.
- Scale & Validation is named (often omitted in thin specs).
- Deferred is present as a section (content emptiness is F6, not a missing H2).

## Proposed framing additions (summary checklist)

| Priority | Add section / heading | Why |
|----------|----------------------|-----|
| P0 | **Risks** (or Risks & mitigations) | Absent entirely; required for mcap + SEC + “merger” UI |
| P1 | **Acceptance criteria / DoD** | Bridge Goals ↔ Testing |
| P1 | **Compliance & messaging** | Merger/mcap language vs disclaimer posture |
| P2 | **Observability** | Distinguish default vs live outstanding in operation |
| P2 | **Rollout / feature control** | Ship/kill/docs ownership |
| P2 | **Dependencies / external contracts** | SEC + quote + CIK assumptions |
| P3 | **Alternatives considered** and/or **Open questions** | Credibility of Deferred: None |

These are **framing** additions only—name the concerns in the document outline. No requirement to redesign the body.

## Verdict

**VERDICT: NEEDS_FIXES**

Blocking framing gap: **Risks** must be named. Strongly recommended framing gaps: acceptance criteria, compliance/messaging, observability, rollout, external dependencies, and either alternatives/open questions or a non-empty Deferred where uncertainty remains.
