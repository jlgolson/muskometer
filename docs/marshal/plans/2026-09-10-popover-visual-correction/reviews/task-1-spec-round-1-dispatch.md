MARSHAL_TASK_ID: 1
MARSHAL_PLAN_SLUG: 2026-09-10-popover-visual-correction
MARSHAL_ROLE: spec-reviewer
dispatch_id: e801b958-23f4-4797-9681-fbe72ad58bd0-task-1

> Do not use any memory tools (`memory_search`, `memory_get`, or
> equivalent). Your work must be entirely self-contained: rely only on
> the spec, plan, diff, and source provided in this prompt. Reading
> orchestrator or prior-session memory would compromise the
> independence this review depends on.

Your first tool call is the concrete first action of this task (read the spec, plan, or files named in this brief). No oath, no skill-map recitation, no greeting, and no memory lookup before that first tool call.

## Delivery contract

Your final response is the delivery mechanism. It is the Agent-tool / `spawn_subagent` / dispatcher return value and reaches the caller automatically. The return value is the delivery mechanism.

The dispatcher/orchestrator persists that text to the canonical path named in this prompt. Do not write that file yourself (except where a template already requires a reviewer to write the verdict file — that existing contract stays).

Do not call `SendMessage` or `ListAgents`. Do not contact `main`, `general-purpose`, the orchestrator, a sibling, or any other agent by name or id.

`No agent named '…' is reachable` is expected. It is not a delivery failure.

On that error: do not retry, do not re-verify work, do not re-transmit the report. Emit the status/verdict once and stop.

Effort: high (prose-level guidance for the reviewer subagent; the dispatch mechanism is unchanged)

You are reviewing Task 1 for compliance with the spec.

## Inputs (read these files — they are NOT inlined)

Spec: /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/docs/marshal/specs/2026-09-10-popover-visual-correction-design.md
Task description: /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/.marshal-cache/agent-wt/9e1e8f3b-d8bb-4765-b4a3-bfbe324963bc-task-1/docs/marshal/plans/2026-09-10-popover-visual-correction/reviews/.tmp-task-1-description.md
Implementation summary: /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/.marshal-cache/agent-wt/9e1e8f3b-d8bb-4765-b4a3-bfbe324963bc-task-1/docs/marshal/plans/2026-09-10-popover-visual-correction/reviews/.tmp-task-1-summary.md

Read all three now, in full, before you assess anything. They are passed
by path, not inlined: a spec body inlined into this prompt would exceed
Grok Build's 128 KiB toolInput cap and the dispatch would be denied
before you ever ran (ART-963 §4.6). Your verdict must cite the spec; a
verdict that cannot is evidence you skipped the read.

## Your job

Verify code against the spec directly. The implementer's DONE summary is a
starting point, not a substitute for reading the diff.

Read the actual implementation code and check:

**Missing requirements:** did the implementer skip anything the task
description or acceptance criteria required? Did they claim something works
without actually building it?

**Extra or unrequested work:** did they add features, flags, or abstractions
that weren't in the spec? Over-engineering counts as a spec-compliance issue
because the plan picked scope for a reason.

**Misunderstood requirements:** did they interpret a requirement differently
than the spec intended? Did they solve a similar-but-wrong problem?

Read the diff (git log / git diff against the pre-task commit) rather than
only reading the files. Things the implementer deleted, moved, or silently
reformatted show up in the diff but not in a file read.

## Write your verdict

Write your review to:

$MARSHAL_REVIEWS_ROOT_ABS/task-1-spec.md

The file body should list what's missing, what's extra, and what's
misinterpreted, with file:line references. The file must end with a line
starting with one of:

VERDICT: APPROVED
VERDICT: NEEDS_FIXES: <one-line reason>

A trailing `: <rationale>` on `VERDICT: APPROVED` is accepted; the preferred form remains bare `APPROVED` with the rationale in a paragraph above.

If you re-review after the implementer fixes issues, append a new review
section and a new VERDICT line — the hook reads only the last VERDICT line,
so leaving earlier NEEDS_FIXES history in the file is fine and is useful
as an audit trail.

End your verdict with a `## Findings` section listing every issue you raised, one bullet per finding, in the format `- [<file-or-ref>:<section>] <category>: <one-line summary>`. The `<category>` must be a short noun phrase (1–3 words, hyphen-separated, lowercase) — for example `coverage-gap`, `type-mismatch`, `placeholder`, `scope-creep`, `missing-test`. Do NOT put the specific subject in the category. If your verdict is APPROVED with zero issues, the section body is the literal `None.`.

The verdict file (or, in a multi-round file, each `## Round N` section body) MUST contain exactly one `## Findings` section. The body of that section contains canonical bullets only (or the literal `None.`) — never prose, never sub-headings (`### 1.`, `### 2.`, etc), never numbered narrative. Do NOT write `## Findings` as a parent heading for prose sub-sections and then a separate canonical-bullets `## Findings` later; the lint anchors on the first occurrence and rejects the prose body.

Do not write `## Round N` as a level-2 heading anywhere in your prose except as a round delimiter. Quoted references to prior round headings must be inside backticks (e.g., `` `## Round 2` ``) or as blockquotes (`> ## Round 2`). The convergence parser splits on level-2 `## Round M` headings; an unquoted prose reference would be misinterpreted as a real round delimiter. Round-1 verdict files do NOT emit a `## Round 1` marker — round 1 is implicit per `convergence_check.py:_split_rounds`.

The file's final line is `VERDICT: APPROVED` or `VERDICT: NEEDS_FIXES: <reason>`. Do not start any line with `VERDICT:` anywhere in your prose except the final line of your verdict (or, if appending a `## Round M` section to a multi-round file, the final line of that section). Quoted references to prior verdicts must be indented (start with `>` blockquote) or written inline (e.g., "`VERDICT: APPROVED`" with backticks).

    After you finish writing your verdict file, stamp its content-provenance
    trailer so the marshal gate will trust it at consumption. Run this once,
    exactly (it resolves the plugin-bundled script, falling back to the repo
    copy):

        python3 "$([ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && printf %s "${CLAUDE_PLUGIN_ROOT}/scripts/_verdict_trailer.py" || printf %s scripts/_verdict_trailer.py)" stamp --verdict-path <your-verdict-file> --role <your-MARSHAL_ROLE> --task-id <your-MARSHAL_TASK_ID-or-0> --plan-slug <your-MARSHAL_PLAN_SLUG> --round <this-round-number>

    Do NOT hand-write or hand-compute the trailer — the CLI computes the correct
    content hash for your verdict class. If it exits non-zero, say so in your
    report; never fabricate a trailer line.

## Cold review — generate your own hypotheses first

You have NOT been given the author's design rationale or a pre-enumerated risk list, and you must not seek one. Before reading the change, enumerate your OWN failure hypotheses: given this artifact and your objective, how would a change like this most plausibly be wrong? Write them down. THEN read the change and check it against each hypothesis. A reviewer who only confirms the author's framing reproduces the author's blind spots — the point of a cold pass is to bring failure hypotheses the author did not.

> Do not use any memory tools (`memory_search`, `memory_get`, or equivalent). Rely only on the artifact, source, and instructions in this prompt.

## Next-request tracing

For any state-mutating change, trace the NEXT request: after this path runs OR fails, what does the next request (retry / replay / concurrent) see, and what happens at TTL / freshness-window expiry? A change that is correct for a single clean request can still be wrong for the retry after a partial failure, the replay of a captured request, the concurrent request racing it, or the request that arrives one tick after a freshness window closes. Walk each explicitly.

## Adjudicate-class findings (blocking)

Any finding in the retry / error / race / next-request-wrong-outcome class MUST be tagged with a category in the `adjudicate-*` namespace (e.g. `adjudicate-retry`, `adjudicate-race`, `adjudicate-next-request`, `adjudicate-error`). An `adjudicate-*` finding is unresolved at raise time and is NEVER compatible with `VERDICT: APPROVED`: a round raising any unresolved `adjudicate-*` finding REQUIRES `VERDICT: NEEDS_FIXES`. Do not downgrade such a finding to a non-blocking note. The finding is cleared only by a matching resolution line `ADJUDICATED: <category> — (fixed: <commit> | accepted: <rationale>)`, never by reviewer judgment within the raising round.

<!-- WORKED_EXAMPLE_START -->

## Canonical verdict shape (worked example)

Your verdict output must follow this exact shape. The dispatcher writes the body verbatim, then prepends `## Round N` for round-N appends and appends a cache-stats footer. Do NOT emit `# Round N` (h1) or `## Round N` (h2) yourself.

````
[Your prose review goes here — Strengths, Issues by severity (Critical /
Important / Minor), Assessment, etc.]

## Findings

- [path/to/file.py:section] category-kebab: one-line summary
- [path/to/other.py:section] category-kebab: one-line summary

VERDICT: APPROVED

## Reviewed files

- path/to/file.py
- path/to/other.py
````

If the verdict is APPROVED with zero issues, the Findings body is the literal text `None.` (one line, no bullet prefix):

````
## Findings

None.

VERDICT: APPROVED

## Reviewed files

- path/to/file.py
````

Notes:
- `## Findings` precedes `VERDICT:`; `## Reviewed files` follows `VERDICT:`.
- `None.` is bare — never `- None.` with a bullet.
- The `VERDICT:` line is the FINAL line of the verdict body content; the `## Reviewed files` heading goes AFTER `VERDICT:` (it is not part of the verdict body, and the h2 heading ensures both the convergence helper and the sticky-pass parser agree on section boundaries).

<!-- WORKED_EXAMPLE_END -->

## Findings (machine-readable)

After the `## Findings` section and BEFORE the final `VERDICT:` line, add a section exactly titled `## Findings (machine-readable)`. Its body is one line `<!-- MARSHAL_FINDINGS_JSON v1 -->` followed immediately by a fenced ```json block containing `{"schema_version":1,"dispatch_id":"<this dispatch's id or null>","verdict":"approved|needs_fixes","round":<int>,"findings":[{"file_path":..,"line_range":..,"category":..,"severity":"critical|important|minor","summary":..,"persisted_from_prior_round":<bool>,"resolved_in_this_round":<bool>}]}`. Emit `findings: []` for a clean pass. This block is in its own section so the canonical `## Findings` lint is unaffected.


## Task-specific execution contract

Your source checkout and cwd for all commands is /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/.marshal-cache/agent-wt/9e1e8f3b-d8bb-4765-b4a3-bfbe324963bc-task-1. Your only writes are your canonical verdict above, owned solely by you. No git mutations. Read the exact installed canonical round-1 template incorporated above; write the complete verdict yourself and stamp it with your actual dispatch_id in Findings JSON. Use absolute plugin script path /Users/jlgolson/.codex/plugins/cache/marshal/marshal/0.37.0/scripts/_verdict_trailer.py and run from the source checkout. Environment: MARSHAL_REVIEWS_ROOT_ABS=/Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/.marshal-cache/agent-wt/9e1e8f3b-d8bb-4765-b4a3-bfbe324963bc-task-1/docs/marshal/plans/2026-09-10-popover-visual-correction/reviews, MARSHAL_AUTONOMOUS=1, MARSHAL_LINEAR_ENABLED=0, MARSHAL_LINEAR_PHASE_MIRROR=0, MARSHAL_TELEMETRY_ENABLED=0. Do not inspect prior task verdicts or orchestrator history. Enumerate your hypotheses before reading the implementation.

Read actual diff at /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/.marshal-cache/agent-wt/9e1e8f3b-d8bb-4765-b4a3-bfbe324963bc-task-1/docs/marshal/plans/2026-09-10-popover-visual-correction/reviews/.tmp-task-1-round-1-quality-diff and complete source/test files. Read source-bound evidence /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/popover-visual-correction/validation/validation.json, /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/popover-visual-correction/raw/final-source-manifest.json, raw/verify.log, raw/verify-summary.json, raw/verify-tests.json, and validation/test-identifiers.json. Use view_image on before images at /Users/jlgolson/grok/muskometer/build/popover-visual-validation/before-popover.png and before-ownership.png plus real accepted PNGs in /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/popover-visual-correction/accepted: all main heights (600/700/800/900), Holdings, positive chart and share, edge fixtures, light main and accessibility renderer. Read geometry in validation/initial-viewport-geometry.json. Check source hashes. Do not launch an app, build, test, or repeat unchanged verification. All necessary raw evidence is preserved outside deleted implementer checkout in the stable evidence root. The normal Release artifact is /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/popover-visual-correction/normal-release/Muskometer.app.

Accessibility evidence describes native high-contrast normalization rather than claiming native propagation: validate explicit increased-contrast/reduced-transparency inputs into the SAME renderer used by live production environment. Do not change system preferences, use CUA, or access user defaults. No network telemetry, external messages, publication, preview or replacement installation. This is an independent review; report actual findings, do not assume approval. Return only verdict status, actual dispatch_id and canonical verdict path.
