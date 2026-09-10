Task 2 cold compliance review, dispatch `de4a04f7-ea8e-4d05-89d7-7a080982474c-task-2`.

Reviewed the uncommitted implementation against the supplied approved spec and Task 2 plan. The examined baseline HEAD is `38ae64739615d72d23fa8ee77ddd6aee0c5a54c5`; the reviewed change is `build/task-2-runner-evidence/review-input.patch`, SHA-256 `57021e0c8ae163af3adf79834afaa3eb43d97bbcaf01faf34ad2f5d997815869`. All eight production/test/fixture hashes match `review-input-hashes.json`. HEAD alone does not contain this implementation.

The core ownership fixes follow the plan: immutable verified anchor observations, separate normalized ownership buckets, effective-date ordering, conservative amendment matching, explicit zero balances, checked ownership arithmetic, and unchanged `HoldingsSyncResult` / AppSettings completeness behavior. The baseline transcriptions match the supplied XML, including SPCX's February-to-June transactions, seven zero buckets, and the vested options. The existing conflicting-companyfacts expectation was corrected as authorized; the other old fixture change repairs a missing XML closing tag without changing its assertion. No unrelated production scope was found.

Two gaps remain.

1. **Important — archive fetches have no configured bound.** At `SECHoldingsSyncService.swift:42–53`, the loop's only scan allowance is `visited.count`, which advances only when processing a new Form 4 accession. Downloading an archive page with no Form 4 entries, or only previously visited entries, consumes no allowance. The archive list is accepted at arbitrary length and archive names are not deduplicated. This does not satisfy the spec's bounded SEC request requirement. An independent transport-boundary probe supplying 102 distinct valid archive names, each containing empty filing arrays, made **103 requests with zero Form 4 accessions** and returned an empty result. A second call on the same service made the total **206 requests**; increasing the supplied archive list increases that work without encountering a fixed service limit. AppSettings preserves holdings on the resulting partial sync, but the same traversal recurs after the attempt backoff expires. Add an explicit total-request or archive-page allowance, deduplicate archive names, and omit symbols without verified coverage when that allowance is exhausted. Cover pages containing no eligible filings and a repeat sync, as well as the existing accession truncation test. This is an unresolved `adjudicate-retry` finding.

2. **Minor — Decimal conversion can hide a fractional outstanding value.** At `CompanyFactsOutstandingResolver.swift:60–62`, the integer test runs after decoding through the finite precision `Decimal` representation. With the valid JSON token `100.000000000000000000000000000000000000000000000000001`, the unchanged resolver returns `100`; the token is nonintegral and should be rejected under the spec's representable-integer validation rule. The existing shorter fractional example `100.00000000000000001` correctly returns nil, so that test does not cover the precision-loss boundary. Preserve the JSON number token or otherwise establish lossless integral conversion before accepting it, and add this regression. The arithmetic guards after conversion cannot recover discarded fractional digits.

Cold failure hypotheses and their disposition are recorded in `build/task-2-review-spec/hypotheses.md`. Repeat/concurrent ownership calls reconstruct from local per-call state rather than feeding previous totals back into the anchor. Network failures and cancellation checks prevent partial holdings from being applied; AppSettings retains the existing all-symbol acceptance and daily attempt backoff. The archive traversal finding remains after that next-request analysis.

Validation: inspected the supplied red assertion evidence, the 68-passing targeted summary, and the 278-passing full-suite summary. Independently compiled unchanged production source and ran `build/task-2-review-spec/probe.swift` with only mock SEC transport, using the required shared `run-aggregate.py` launcher, escalated permission, Xcode developer directory, and reviewer-local build/cache output. The fresh probe reproduced both findings and the archive retry; exact output is in `build/task-2-review-spec/probe.log`. I did not rerun the full XCTest suite or contact live SEC services.

Provenance limitation: the dispatch explicitly reports that automatic approval review rejected the local commit. In accordance with its approval-block override, this verdict is deliberately **unstamped** until an authorized committed implementation snapshot exists. No commit, staging operation, production/test edit, or provenance stamp was performed. This limitation is not a code finding.

## Findings

- [Muskometer/Services/SECHoldingsSyncService.swift:42-53] adjudicate-retry: Archive downloads do not consume a configured request budget, allowing an arbitrarily long traversal to repeat on every sync.
- [Muskometer/Services/CompanyFactsOutstandingResolver.swift:60-62] numeric-validation: Decimal decoding can discard fractional digits before the integer check and accept a nonintegral companyfacts total.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"de4a04f7-ea8e-4d05-89d7-7a080982474c-task-2","verdict":"needs_fixes","round":1,"findings":[{"file_path":"Muskometer/Services/SECHoldingsSyncService.swift","line_range":{"start":42,"end":53},"category":"adjudicate-retry","severity":"important","summary":"Archive downloads do not consume a configured request budget, allowing an arbitrarily long traversal to repeat on every sync.","persisted_from_prior_round":false,"resolved_in_this_round":false},{"file_path":"Muskometer/Services/CompanyFactsOutstandingResolver.swift","line_range":{"start":60,"end":62},"category":"numeric-validation","severity":"minor","summary":"Decimal decoding can discard fractional digits before the integer check and accept a nonintegral companyfacts total.","persisted_from_prior_round":false,"resolved_in_this_round":false}]}
```

VERDICT: NEEDS_FIXES: Bound archive requests and reject fractional facts before precision loss.

## Reviewed files

- Muskometer/Services/SECHoldingsSyncService.swift
- Muskometer/Services/Form4OwnershipParser.swift
- Muskometer/Services/CompanyFactsOutstandingResolver.swift
- Muskometer/Services/HoldingsSyncServiceProtocol.swift
- Muskometer/Services/IssuerOutstandingSyncService.swift
- Muskometer/Utilities/SPCXHoldings.swift
- Muskometer/Utilities/SPCXOwnershipCalculator.swift
- Muskometer/Utilities/AppSettings.swift
- Muskometer/Utilities/IssuerSharesOutstanding.swift
- Muskometer/Utilities/MuskometerNetworking.swift
- Muskometer/Utilities/AppVersion.swift
- Muskometer/Models/TrackedPersonProfile.swift
- MuskometerTests/OwnershipSyncTests.swift
- MuskometerTests/Fixtures/Ownership/spcx-anchor.xml
- MuskometerTests/Fixtures/Ownership/tsla-anchor.xml
- docs/marshal/plans/2026-09-10-review-fixes.md
- build/task-2-runner-evidence/review-spec-round-1-prompt.md
- build/task-2-runner-evidence/review-input.patch
- build/task-2-runner-evidence/review-input-hashes.json
- build/task-2-evidence/red-assertions.json
- build/task-2-evidence/red-aggregate-overflow-assertions.json
- build/task-2-evidence/green-ownership-summary.json
- build/task-2-evidence/full-suite-summary.json
- build/task-2-review-spec/hypotheses.md
- build/task-2-review-spec/probe.swift
- build/task-2-review-spec/run-probe.py
- build/task-2-review-spec/probe.log
- /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/run-aggregate.py
- /Users/jlgolson/.codex/plugins/cache/marshal/marshal/0.37.0/skills/using-marshal/SKILL.md


## Round 2

Fresh independent full Task 2 compliance review. Dispatch: `25e6370f-69fc-4070-aa9a-7ba48836803a-task-2`. No prior reviewer content, implementer summary, or author rationale was consulted. Initial hypotheses were recorded before the source, spec, and plan were read in `build/task-2-review-spec-round-2/cold-hypotheses.md`.

The reviewed input is the immutable uncommitted cumulative patch `build/task-2-runner-evidence/review-input-round-2.patch`, SHA-256 `c32efd707673c62951089c85bf73fe39655a1b8d016506fc8dc6c3b46ca1836a`. Baseline HEAD is `38ae64739615d72d23fa8ee77ddd6aee0c5a54c5`; it does not contain this implementation. All eight owned source/test/fixture files matched `review-input-round-2-hashes.json` before the review and before this append.

The implementation meets the approved Task 2 contract. Structured XML observations preserve bucket identity, row order, absolute quantities, and effective dates. The bundled anchor observations match the public XML fixtures, including zero buckets and the distinct treatment of undated anchor holdings. The verified totals remain SPCX 5,116,475,230 and TSLA 710,172,677. Updates replace only recognized dated buckets, preserve unchanged classes/trusts/options, use transaction chronology, and refuse incomplete coverage, unsupported identities, malformed quantities, and ambiguous same-day or amendment targets. Integer quantities and weighted totals use exact parsing and checked arithmetic.

Companyfacts retains accession/form identity when selecting the latest preferred period and filing group. Equal repeated entity totals contribute once; conflicting totals remain unresolved without falling through to an older GAAP value. Original numeric tokens are validated and interpreted exactly, including exponent notation and values at the Int64 boundary. The existing convenience APIs, holdings result interface, persistence keys, and completeness boundary are preserved.

Next-request tracing: every sync owns fresh pacing, visited-accession/archive sets, and reconstruction state, beginning from the immutable anchors. A network/decode failure returns no result; a coverage or reconciliation failure omits the affected symbol. AppSettings' all-expected-symbol check preserves every prior holding on incomplete results while recording the attempt. The next retry or replay rebuilds from the same baseline rather than applying a delta twice. Concurrent service invocations share no reconstruction mutations; the existing view-model guard prevents overlapping application-level holdings syncs. At the 86,400-second backoff boundary, a new scan is permitted and receives new budgets. There is no persistent filing-history cache to become stale. Cancellation is checked before requests, after transport, and throughout the scan; URLSession response caching remains disabled in the production session.

Bounds and failure paths were checked explicitly: at most 100 unique accessions, 10 unique archive-page requests, and 100 archive descriptors are traversed, with a maximum of 211 HTTP requests per sync. Empty or duplicate pages cannot create an unbounded scan. XML parsing bounds bytes, nodes, and depth and rejects DTD/entity input. Collected relevant observations are capped at 10,000. State is released after the sync.

Validation: an independent run of all nine ownership-related XCTest classes passed 77 tests with zero failures. It used the required shared controller, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, isolated reviewer DerivedData, and `-parallel-testing-enabled NO`. Evidence is `build/task-2-review-spec-round-2/ownership.log` and `ownership.xcresult`. The supplied raw regression evidence shows the expected initial failures, and the supplied round-2 full-suite result records 287 tests passed with zero failures. The full suite was inspected as existing evidence rather than represented as an independent rerun. No production, test, fixture, or project edits were made by this reviewer.

Process limitation: the supplied automatic-approval block leaves the implementation uncommitted. No staging, commit retry, or provenance stamp against baseline HEAD was attempted. This report's approval applies to the identified patch and file manifest, not to a committed implementation snapshot; that provenance limitation is not a code finding.

## Findings

None.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"25e6370f-69fc-4070-aa9a-7ba48836803a-task-2","verdict":"approved","round":2,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- Muskometer/Services/CompanyFactsOutstandingResolver.swift
- Muskometer/Services/Form4OwnershipParser.swift
- Muskometer/Services/SECHoldingsSyncService.swift
- Muskometer/Utilities/SPCXHoldings.swift
- Muskometer/Utilities/SPCXOwnershipCalculator.swift
- MuskometerTests/OwnershipSyncTests.swift
- MuskometerTests/Fixtures/Ownership/spcx-anchor.xml
- MuskometerTests/Fixtures/Ownership/tsla-anchor.xml
- Muskometer/Utilities/AppSettings.swift
- Muskometer/Services/HoldingsSyncServiceProtocol.swift
- Muskometer/Utilities/MuskometerNetworking.swift
- Muskometer/Models/TrackedPersonProfile.swift
- Muskometer/Utilities/IssuerSharesOutstanding.swift
- Muskometer/ViewModels/GainsViewModel.swift
- docs/marshal/plans/2026-09-10-review-fixes.md
- build/task-2-runner-evidence/round-2-spec-input.md
- build/task-2-runner-evidence/round-2-task-identity.md
- build/task-2-runner-evidence/review-spec-round-2-prompt.md
- build/task-2-runner-evidence/review-input-round-2.patch
- build/task-2-runner-evidence/review-input-round-2-hashes.json
- build/task-2-evidence/red-assertions.json
- build/task-2-evidence/round-2/green-ownership-summary.json
- build/task-2-evidence/round-2/full-suite-summary.json
- build/task-2-review-spec-round-2/cold-hypotheses.md
- build/task-2-review-spec-round-2/ownership.log
- /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/run-aggregate.py
- /Users/jlgolson/.codex/plugins/cache/marshal/marshal/0.37.0/skills/using-marshal/SKILL.md


## Round 3

MARSHAL_TASK_ID: 2
MARSHAL_PLAN_SLUG: 2026-09-10-review-fixes
MARSHAL_ROLE: spec-reviewer
dispatch_id: 52d30ac5-c96e-41fe-81cc-4a8c83e1cda4-task-2

This was an independent cold full review of Task 2 against the complete approved spec and Task 2 plan. Independent hypotheses were recorded in `build/task-2-review-spec-round-3/cold-hypotheses.md` before reading the patch, plan implementation steps, or source. No previous verdict contents, implementer report, memory/history, or orchestrator rationale were read.

Reviewed baseline HEAD: `38ae64739615d72d23fa8ee77ddd6aee0c5a54c5`.
Reviewed cumulative patch SHA-256: `f931a21cb85754ed6b9df48e1d4d80807a92dbbe9c7d9b20fd0948edac7a6c7e`.
All eight source/fixture file hashes matched the frozen round-3 manifest before review. Independently applying each cumulative patch hunk in memory to the baseline reproduced all eight current files exactly; evidence is `build/task-2-review-spec-round-3/patch-verification.json`.

### Requirement assessment

The dated reconstruction preserves unchanged baseline buckets and explicit zero quantities, uses absolute post-transaction balances, and distinguishes direct/indirect ownership, trust names, option strike, and expiry. The verified fixture transcription preserves SPCX 5,116,475,230 and TSLA 710,172,677. Ordinary same-day transactions use row order within their filing; independent conflicting same-day totals remain unresolved. Amendments require a uniquely identified original bucket/date row and do not replace a later effective observation. Unknown identities, undated relevant rows, unresolved numeric values, and incomplete anchor coverage omit the affected result. Integer and decimal-token handling avoid rounding or trapping at Int64 boundaries. Companyfacts retains accession/form grouping, deduplicates equal totals, and refuses tied conflicts without falling back to GAAP.

Per-sync state is rebuilt from immutable anchors. It is bounded by 100 visited accessions, 10 fetched archive pages, 100 archive descriptors, 10,000 accepted observations, and parser size/depth/node caps. Requests are paced and cancellation is checked at suspension boundaries. The production caller serializes holdings synchronization; no persistent reconstruction state is shared across requests. Existing AppSettings completeness and zero handling remain unchanged.

One error-path completeness gap remains: an empty issuer ticker is accepted as an unrelated issuer rather than an unresolved identity.

### Important issue: blank issuer ticker can roll holdings back to the anchor

`Form4OwnershipParser.observations()` at lines 106–110 distinguishes a missing ticker node from an empty ticker value. A missing node returns nil, but `<issuerTradingSymbol/>` (or whitespace) becomes `symbol == ""` and is returned as a clean unrelated document with no observations. `SECHoldingsSyncService.syncHoldings()` then skips it at line 73 without invalidating coverage. After finding the two anchors, the service returns both old anchor totals as a complete result, despite having failed to identify a newer filing.

The reviewer-only transport probe uses the unchanged production parser/service and both verified anchor XML files. Its newer SPCX sale has issuer CIK `0001181412`, a valid transaction date, a recognized existing trust bucket, and an absolute balance of 842,091,570. With ticker SPCX, the result is SPCX 5,116,475,130. Changing only the ticker element to empty or whitespace produces SPCX 5,116,475,230 with TSLA present and `complete=true`; deleting the ticker element entirely correctly produces an incomplete result. The blank-ticker replay repeats the incorrect complete anchor result. Evidence: `build/task-2-review-spec-round-3/transport-probe.swift` and `build/task-2-review-spec-round-3/transport-probe.log`.

This violates the requirement to preserve the previous whole holding when ambiguity or malformed updates prevent a reliable reconstruction. On the next request after a previously successful sale synchronization, AppSettings accepts this complete result and restores the older count, updates success provenance, and backs off for its usual interval. After that interval, the same input repeats the rollback. At minimum reject an empty normalized ticker through the unresolved parsing path, with transport-boundary regressions for empty and whitespace ticker values. Do not infer that an unidentifiable filing is unrelated.

### Verification and next-request tracing

Fresh reviewer Xcode run: 82 ownership tests passed, zero failures, exit 0, `** TEST SUCCEEDED **`. All nine ownership-related test classes were selected, with reviewer-local derived data/result bundle and `-parallel-testing-enabled NO`. Log: `build/task-2-review-spec-round-3/ownership-tests.log`; result bundle: `build/task-2-review-spec-round-3/ownership-tests.xcresult`; parsed result: `build/task-2-review-spec-round-3/verification-summary.json`. The build emitted existing async NSLock warnings in the unrelated shared tests and AppIntents metadata notices; no reviewed source diagnostic or test failure occurred.

The additional transport probe compiled and ran through the required controller with exit 0. It reproduced the blank/whitespace/replay failure above, while a missing XML response threw without returning partial holdings and a subsequent retry with complete transport returned the correct sale balance. There is no accumulated partial state to contaminate that retry. Existing fresh tests also exercised idempotent repeated inputs, malformed archive termination, cancellation, fixed archive budgets on repeated attempts, duplicate archive/accession handling, anchor discovery and truncation, valid zero disposal, historical amendments, and same-day ambiguity. AppSettings tests confirmed partial results retain both prior holdings and retry only after the daily interval; complete zero balances remain valid.

The supplied raw round-3 full-suite result reports 292/292 passed; that broader run was inspected, not rerun by this reviewer. The supplied raw red evidence shows the original partial-total, zero, chronology, deduplication, and numeric regressions failing before their corrections, and the precise-option identity regression failing in its red run. Those records supplement the fresh 82-test run rather than replacing it.

### Process and provenance constraint

The review is of the immutable uncommitted cumulative snapshot, not baseline HEAD's source content. As explicitly required by the approval-block override, no commit/staging attempt or workaround was made and the provenance stamping CLI was not run against baseline HEAD. This reviewer-authored round remains unstamped pending a legitimate committed snapshot; that provenance limitation is not a code finding. No production/test/fixture source was edited. Scratch evidence was written only in `build/task-2-review-spec-round-3`, and all test/probe compilation and launches used the required shared lifecycle controller with escalated execution. The existing review bytes were preserved by append-only persistence after checking only for the round-3 marker.

## Findings

- [Muskometer/Services/Form4OwnershipParser.swift:106-110] adjudicate-error: An empty or whitespace issuer ticker is treated as an unrelated filing, allowing a newer unresolved update to return complete anchor totals and overwrite a previously synchronized holding.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"52d30ac5-c96e-41fe-81cc-4a8c83e1cda4-task-2","verdict":"needs_fixes","round":3,"findings":[{"file_path":"Muskometer/Services/Form4OwnershipParser.swift","line_range":[106,110],"category":"adjudicate-error","severity":"important","summary":"An empty or whitespace issuer ticker is treated as an unrelated filing, allowing a newer unresolved update to return complete anchor totals and overwrite a previously synchronized holding.","persisted_from_prior_round":false,"resolved_in_this_round":false}]}
```

VERDICT: NEEDS_FIXES: Unresolved filing identity can produce a false complete holding and regress stored ownership.

## Reviewed files

- Muskometer/Services/CompanyFactsOutstandingResolver.swift
- Muskometer/Services/Form4OwnershipParser.swift
- Muskometer/Services/SECHoldingsSyncService.swift
- Muskometer/Utilities/SPCXHoldings.swift
- Muskometer/Utilities/SPCXOwnershipCalculator.swift
- MuskometerTests/OwnershipSyncTests.swift
- MuskometerTests/Fixtures/Ownership/spcx-anchor.xml
- MuskometerTests/Fixtures/Ownership/tsla-anchor.xml
- Muskometer/Services/HoldingsSyncServiceProtocol.swift
- Muskometer/Models/TrackedPersonProfile.swift
- Muskometer/Utilities/MuskometerNetworking.swift
- Muskometer/Utilities/AppSettings.swift
- Muskometer/Utilities/AppVersion.swift
- Muskometer/ViewModels/GainsViewModel.swift
- scripts/verify.sh
- docs/marshal/plans/2026-09-10-review-fixes.md
- build/task-2-runner-evidence/review-spec-round-3-prompt.md
- build/task-2-runner-evidence/round-3-spec-input.md
- build/task-2-runner-evidence/round-3-task-identity.md
- build/task-2-runner-evidence/review-input-round-3.patch
- build/task-2-runner-evidence/review-input-round-3-hashes.json
- build/task-2-evidence/red-assertions.json
- build/task-2-evidence/round-3/red-summary.json
- build/task-2-evidence/round-3/full-suite-summary.json
- build/task-2-evidence/round-3/green-ownership-summary.json
- build/task-2-evidence/round-3/green-targeted-summary.json
- build/task-2-review-spec-round-3/cold-hypotheses.md
- build/task-2-review-spec-round-3/snapshot-before.json
- build/task-2-review-spec-round-3/patch-verification.json
- build/task-2-review-spec-round-3/ownership-tests.log
- build/task-2-review-spec-round-3/verification-summary.json
- build/task-2-review-spec-round-3/transport-probe.swift
- build/task-2-review-spec-round-3/transport-probe-build.log
- build/task-2-review-spec-round-3/transport-probe.log
- /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/run-aggregate.py
- /Users/jlgolson/.codex/plugins/cache/marshal/marshal/0.37.0/skills/using-marshal/SKILL.md
- /Users/jlgolson/.codex/plugins/cache/marshal/marshal/0.37.0/skills/verification-before-completion/SKILL.md


## Round 4

Independent cold full Task 2 specification review. Dispatch: `80f9ca0d-c611-43a5-9430-e21066cd0ef1-task-2`. The approved complete specification and Task 2 identity were read first; independent failure hypotheses were recorded in `build/task-2-review-spec-round-4/hypotheses.md` before inspecting the implementation, plan details, tests, or test evidence. No earlier verdict contents, implementer summaries, or orchestration rationale were consulted.

Reviewed baseline HEAD: `38ae64739615d72d23fa8ee77ddd6aee0c5a54c5`. Cumulative patch SHA-256: `3c55d209b237f38a3896b82192324e6cbfde7fcbbe59c73f25a531792da73147`. All eight current source/fixture hashes matched the frozen manifest before review. Independently reconstructing every patch output from the baseline also produced the exact manifest hashes; the result is recorded in `build/task-2-review-spec-round-4/patch-integrity.json`.

The implementation meets the approved ownership and outstanding-facts requirements. The explicit anchor transcription preserves SPCX's 13 buckets, seven zero balances, unchanged trusts and options, the 5,116,475,230 SPCX total, and the 710,172,677 TSLA direct-common total. Transactions use effective dates; trusted undated anchor holdings use the anchor observation date. Normalized security/ownership/nature and exact strike/expiry identity prevent unrelated grants or unknown trusts from replacing existing buckets. Partial dated changes replace their own known bucket, zero remains a valid quantity, same-filing transaction order resolves same-day rows, and conflicting unorderable totals are omitted. Amendments require a uniquely identifiable original bucket/date and cannot replace later observations. Missing coverage, unsupported or undated changes, malformed XML/numbers, unknown identities, and overflow all preserve an incomplete result rather than inventing a complete total.

Companyfacts retains accession and form through the preferred-period/filing selection, returns an identical whole-entity total once, and refuses conflicting tied totals without falling through to older GAAP data. Exact original-number token validation preserves representable integral values and rejects fractions, overflow, booleans, strings, forged objects, and invalid numeric syntax. Existing migration defaults and separate outstanding/ownership/provenance interfaces remain intact.

Next-request tracing covered success, failure, cancellation, replay, concurrent calls, and daily retry expiry. Every synchronization owns fresh coverage sets, observations, reconstruction events, and request pacing; no partial reconstruction survives into a later invocation. Requests check cancellation before and after transport, and scan loops check it between entries. Request work is bounded by 100 accessions and ten archive fetches; duplicate archive names are not fetched repeatedly, and each retry receives the same fixed budget. The result boundary still uses AppSettings' all-expected-symbol check, so an omitted symbol preserves the previous whole holding and successful provenance while recording the attempt. At the 86,400-second backoff boundary, the next permitted attempt reconstructs from the immutable anchors again. Concurrent service calls share no mutable reconstruction state. The service introduces no persistent filing history or freshness cache.

Independent verification: the full macOS suite completed with **296 tests passed, zero failures, zero skips**, including all 86 ownership subsystem tests. The run used the required shared `run-aggregate.py` launcher, explicit reviewer-local derived data and result bundle, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, `MUSKOMETER_SKIP_LIVE_YAHOO=1`, and `-parallel-testing-enabled NO`. Evidence: `build/task-2-review-spec-round-4/full-suite.log` and `build/task-2-review-spec-round-4/full-suite.xcresult`. Existing round-4 raw red/green result summaries were also inspected after hypotheses were recorded: the expected malformed-ticker regressions failed before the production fix and the ownership/full suites passed afterward. This review makes no live-endpoint availability claim.

Process limitation, not a code finding: the reviewed changes are an uncommitted immutable snapshot. The execution contract records that automatic approval review rejected the implementation commit. Baseline HEAD does not contain these changes, so this verdict intentionally has no content-provenance stamp; the stamp CLI was not run. No source/test/fixture edits, staging, commits, delegation, real notification/login changes, or external messages were performed. Only this reviewer-authored round and reviewer-local scratch evidence were written.

## Findings

None.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"80f9ca0d-c611-43a5-9430-e21066cd0ef1-task-2","verdict":"approved","round":4,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- Muskometer/Services/CompanyFactsOutstandingResolver.swift
- Muskometer/Services/Form4OwnershipParser.swift
- Muskometer/Services/SECHoldingsSyncService.swift
- Muskometer/Utilities/SPCXHoldings.swift
- Muskometer/Utilities/SPCXOwnershipCalculator.swift
- MuskometerTests/Fixtures/Ownership/spcx-anchor.xml
- MuskometerTests/Fixtures/Ownership/tsla-anchor.xml
- MuskometerTests/OwnershipSyncTests.swift
- Muskometer/Utilities/AppSettings.swift
- Muskometer/Services/IssuerOutstandingSyncService.swift
- Muskometer/Utilities/IssuerSharesOutstanding.swift
- docs/marshal/plans/2026-09-10-review-fixes.md
- build/task-2-runner-evidence/round-4-spec-input.md
- build/task-2-runner-evidence/round-4-task-identity.md
- build/task-2-runner-evidence/review-spec-round-4-prompt.md
- build/task-2-runner-evidence/review-input-round-4.patch
- build/task-2-runner-evidence/review-input-round-4-hashes.json
- build/task-2-evidence/round-4/red-summary.json
- build/task-2-evidence/round-4/green-ownership-summary.json
- build/task-2-evidence/round-4/full-suite-summary.json
- build/task-2-review-spec-round-4/full-suite.log
- build/task-2-review-spec-round-4/hypotheses.md
- build/task-2-review-spec-round-4/patch-integrity.json
- scripts/verify.sh
- /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/run-aggregate.py


## Round 5

Independent cold full Task 2 spec review. Dispatch: `979a0da5-215f-4de9-9561-6629b9ac042b-task-2`. I recorded eight independent failure hypotheses before inspecting the patch or implementation, then reviewed all eight owned files and the application boundaries against the approved ownership and companyfacts requirements. No earlier reviewer verdict, implementer diagnosis, or orchestrator rationale was used.

The reviewed input is the cumulative uncommitted patch with SHA-256 `67fd323bf6279ca8db7d031506d4435a83ff61ed2aec27385397f22bfee4bbb4`, based on HEAD `38ae64739615d72d23fa8ee77ddd6aee0c5a54c5`. All eight current file hashes match the frozen manifest and the exact-source green evidence manifest. I also reconstructed every patch postimage in memory against the baseline and verified byte equality with the corresponding current file.

The implementation satisfies the reviewed Task 2 requirements. The immutable anchor observations agree with both supplied XML fixtures, including SPCX's February report date, later effective transactions, retained zero buckets, trust identities, and option terms. Reconciliation preserves unchanged buckets, selects balances by effective date, limits document-order tie breaking to ordinary filing transactions, and refuses unresolved identities/dates/corrections or conflicting current balances. Numeric conversion and preferred-share multiplication use checked exact arithmetic. The convenience parser preserves the verified default interpretation. Companyfacts retains accession/form identity during selection, counts equal whole-entity facts once, rejects conflicting tied facts, and blocks a fallback from ambiguous DEI data to an older GAAP total.

Next-request tracing: each ownership attempt starts from the immutable anchor with fresh accession, archive, observation, and invalid-symbol state. A successful partial filing cannot erase an unreported bucket. Missing XML, unknown relevant rows, malformed values, rowless ownership tables, missing anchor coverage, and exhausted scan budgets cannot yield a complete holding for the affected symbol. AppSettings records the attempt but preserves the previous whole holding and successful provenance on incomplete results; retry after its 86,400-second backoff repeats reconstruction without feeding the prior result into it. Cancellation is checked around pacing and network suspension, and transport failures return no partially committed holding. Concurrent invocations do not share mutable reconstruction state. Historical corrections cannot overwrite a later effective balance. The scan has explicit limits of 100 accessions, 10 fetched archive pages, 100 archive descriptors, and 10,000 collected observations; parser size, depth, and node limits additionally bound XML processing. No per-filing history persists after a sync.

I independently inspected the current round-5 raw logs, result summaries, commands, and exit records: targeted 8/8, ownership 93/93, and full suite 303/303 passed with zero skipped tests and exit 0. Raw test-case counts agree with the summaries. The round-5 red run has five failing tests and three passing controls, exit 65; its recorded production hash and source audit establish that only tests changed for that red run. The raw failures demonstrate loss of previously synchronized holdings on rowless-table replay, and the current targeted run demonstrates the corrected behavior. I also inspected the original raw red evidence for partial holdings, amendments, exact integers, duplicate companyfacts, and aggregate overflow. The green logs contain no source errors; their warnings concern destination selection and AppIntents metadata extraction.

Independent execution: through the required shared launcher, with the required Xcode developer directory and reviewer-local compiler cache, I compiled the unchanged parser, companyfacts resolver, anchor, and outstanding-fact source files into a focused probe. It passed 254 numeric cases checked against an independently calculated rational-number oracle, 12 permutations testing latest-period selection and equal/conflicting original/amendment facts, and both exact anchor observation comparisons. Compile output was empty and execution exited 0. This was a focused probe; I did not independently rerun the supplied ownership or full suite. The raw probe and evidence audit are under `build/task-2-review-spec-round-5/`.

Process limitation: the source snapshot is uncommitted because the dispatch records automatic approval rejection of the local implementation commit. This review intentionally remains unstamped; the baseline HEAD does not contain the reviewed implementation and cannot establish its content provenance. No staging/commit retry or provenance-stamp workaround was attempted. This is a provenance limitation, not a code finding. No live SEC endpoint availability or current live balance claim follows from the deterministic fixture review.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"979a0da5-215f-4de9-9561-6629b9ac042b-task-2","verdict":"approved","round":5,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- Muskometer/Services/CompanyFactsOutstandingResolver.swift
- Muskometer/Services/Form4OwnershipParser.swift
- Muskometer/Services/SECHoldingsSyncService.swift
- Muskometer/Utilities/SPCXHoldings.swift
- Muskometer/Utilities/SPCXOwnershipCalculator.swift
- MuskometerTests/Fixtures/Ownership/spcx-anchor.xml
- MuskometerTests/Fixtures/Ownership/tsla-anchor.xml
- MuskometerTests/OwnershipSyncTests.swift
- Muskometer/Services/HoldingsSyncServiceProtocol.swift
- Muskometer/Models/TrackedPersonProfile.swift
- Muskometer/Utilities/IssuerSharesOutstanding.swift
- Muskometer/Utilities/MuskometerNetworking.swift
- Muskometer/Utilities/AppVersion.swift
- Muskometer/Utilities/AppSettings.swift
- Muskometer/Services/IssuerOutstandingSyncService.swift
- docs/marshal/plans/2026-09-10-review-fixes.md
- build/task-2-runner-evidence/review-spec-round-5-prompt.md
- build/task-2-runner-evidence/round-5-spec-input.md
- build/task-2-runner-evidence/round-5-task-identity.md
- build/task-2-runner-evidence/review-input-round-5.patch
- build/task-2-runner-evidence/review-input-round-5-hashes.json
- build/task-2-evidence/red.log
- build/task-2-evidence/red-valid-accessions.log
- build/task-2-evidence/red-aggregate-overflow.log
- build/task-2-evidence/round-5/red.log
- build/task-2-evidence/round-5/red-summary.json
- build/task-2-evidence/round-5/red-command.json
- build/task-2-evidence/round-5/red-exit.json
- build/task-2-evidence/round-5/red-production-hash.json
- build/task-2-evidence/round-5/red-source-audit.json
- build/task-2-evidence/round-5/targeted.log
- build/task-2-evidence/round-5/targeted-summary.json
- build/task-2-evidence/round-5/targeted-command.json
- build/task-2-evidence/round-5/targeted-exit.json
- build/task-2-evidence/round-5/ownership.log
- build/task-2-evidence/round-5/ownership-summary.json
- build/task-2-evidence/round-5/ownership-command.json
- build/task-2-evidence/round-5/ownership-exit.json
- build/task-2-evidence/round-5/full-suite.log
- build/task-2-evidence/round-5/full-suite-summary.json
- build/task-2-evidence/round-5/full-suite-command.json
- build/task-2-evidence/round-5/full-suite-exit.json
- build/task-2-evidence/round-5/final-source-hashes.json
- build/task-2-evidence/round-5/final-source-audit.json
- build/task-2-evidence/round-5/run-suite.py
- build/task-2-review-spec-round-5/hypotheses.md
- build/task-2-review-spec-round-5/number-cases.json
- build/task-2-review-spec-round-5/Probe.swift
- build/task-2-review-spec-round-5/run-probe.py
- build/task-2-review-spec-round-5/probe-build.log
- build/task-2-review-spec-round-5/probe-result.json
- build/task-2-review-spec-round-5/probe-exit.json
- build/task-2-review-spec-round-5/evidence-audit.json
- build/task-2-review-spec-round-5/frozen-source-verification.json
- /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/run-aggregate.py
- /Users/jlgolson/.codex/plugins/cache/marshal/marshal/0.37.0/skills/using-marshal/SKILL.md
- /Users/jlgolson/.codex/plugins/cache/marshal/marshal/0.37.0/skills/verification-before-completion/SKILL.md

Provenance completion for the same Round 5 review: I independently verified that committed snapshot `fb92ee462cf9dda9980f18e3096b86e67f436eec`, its parent `38ae64739615d72d23fa8ee77ddd6aee0c5a54c5`, and the latest Task 2 integration ledger record agree. All eight committed blobs and all eight current files exactly match the frozen review manifest. The earlier uncommitted-source limitation is therefore resolved without changing the assessment, zero findings, or author dispatch `979a0da5-215f-4de9-9561-6629b9ac042b-task-2`. The installed provenance CLI is now being invoked for this existing review; no new review round, test run, or source change was performed. Independent hash readback: `build/task-2-review-spec-round-5/committed-source-verification.json`.

reviewed-content-sha256: 9cb75234eb0d63256151040f769e81cb57701a866134d8505ee34f778de23855

plan-graph-sha256: c5582aec64ba1273dc1ddb9487db6d546ccf6879bd93cdd16eda9a28cf89a760


## Adjudication bookkeeping

Recorded by the task orchestrator after the independent Round 5 review found no current findings and the root committed the identical reviewed eight-file source snapshot. These lines resolve earlier findings with the independently corroborated fix commit.

ADJUDICATED: adjudicate-retry — (fixed: fb92ee462cf9dda9980f18e3096b86e67f436eec)
ADJUDICATED: adjudicate-error — (fixed: fb92ee462cf9dda9980f18e3096b86e67f436eec)
