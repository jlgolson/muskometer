# Task 2 code quality review

Dispatch: `9e8ba59c-a32e-43d0-9055-698ba03d6f76-task-2`.

Examined baseline HEAD: `38ae64739615d72d23fa8ee77ddd6aee0c5a54c5`. The reviewed change is the uncommitted immutable `build/task-2-runner-evidence/review-input.patch`, SHA-256 `57021e0c8ae163af3adf79834afaa3eb43d97bbcaf01faf34ad2f5d997815869`. All eight source/fixture hashes matched its manifest before and after review. Baseline HEAD does not represent this patch.

Classification: Swift code change with XML fixtures. File organization, tests, clarity, and patterns all apply. N/A: SQL migration reversibility and cryptographic write/verify invariants; this change introduces neither a migration nor a signature/hash/encryption protocol.

Cold hypotheses were recorded before reading the change in `build/task-2-review-quality/cold-hypotheses.md`: bucket collisions and partial totals; chronological regression; malformed/zero/overflow confusion; incomplete scans; companyfacts duplication; retry/concurrent ordering; parser/reconciliation coupling; and missing behavioral coverage.

## Strengths

The parser, immutable baseline, and dated reconciliation have distinct responsibilities and remain small enough to trace. Removing the separate regular-expression aggregation implementation avoids competing interpretations of the same XML. Bucket identity includes direct/indirect ownership, trust, strike, and expiry. Checked multiplication/addition and explicit zero handling address the previous dangerous conversions.

The fixtures retain the full verified reports, including post-transaction zero balances, dates, option terms, and footnotes. The transcription comparison checks the actual parser output against every bundled observation. Tests exercise the actual service through a transport fixture, assert totals and omission behavior, isolate sessions with fixture IDs, and preserve the existing AppSettings completeness contract. Same-filing transaction order, conflicting same-day filings, amendments, all-bucket disposal, malformed input, and the accession budget receive behavioral assertions.

## Issues

### Critical

None.

### Important

1. **Archive requests have no configured bound, including on retry — `adjudicate-retry`.** In `SECHoldingsSyncService.swift:42-53`, the loop budget is spent only when a unique Form 4 accession is removed from `pending`. An archive page with no Form 4 rows, or only already-visited accessions, spends no budget. The new archive loop therefore downloads the entire server-supplied archive list when anchors are absent, without an independent archive-page/request cap or archive deduplication. The list can grow independently of the 100-accession limit. An isolated probe using the unchanged production service and mocked transport supplied 101 empty archive pages: both the first call and a repeated call made 102 requests (initial submissions plus all 101 archives) and returned an empty result. Increasing the page count increases work without hitting any configured limit. The daily AppSettings backoff delays the next attempt, but that attempt starts the same scan again. Add a bounded metadata-page or total-request budget, preserve conservative omission on exhaustion, and cover empty/duplicate archive pages as well as successful anchor discovery in an archive. Evidence: `build/task-2-review-quality/archive-probe.log`.

2. **Decimal decoding still accepts nonintegral and out-of-range facts — `adjudicate-error`.** In `CompanyFactsOutstandingResolver.swift:60-63`, the JSON number is converted to finite-precision `Decimal` before its integrality and Int64 range are checked. Decimal can discard a sufficiently distant fractional digit; `OwnershipNumber.integer` then validates the rounded representation rather than the original number. A probe compiled against the unchanged resolver reproduced `100.00000000000000000000000000000000000000000000000001` resolving to `100`, and `9223372036854775807.0000000000000000000000000000001` resolving to `Int64.max`, although the latter is both nonintegral and greater than Int64.max. The ordinary `100.5` and immediate overflow controls correctly return nil. This violates the task's exact positive, representable-integer validation requirement. Downstream code accepts every positive resolved fact and persists it with companyfacts provenance, so there is no later validation barrier; replaying the payload repeats the acceptance. Validate the original numeric token without a lossy intermediate, or reject values whose conversion cannot be proved exact, and add a regression beyond Decimal's precision. Evidence: `build/task-2-review-quality/numeric-probe.log`.

### Minor

None.

## Tracing and validation

Every ownership synchronization starts from immutable anchors and local collections; no partially reconstructed bucket state escapes on failure, cancellation, or concurrent calls. AppSettings applies only a complete expected-symbol result, persists counts as strings, and backs off incomplete attempts for its existing daily interval. Replaying valid observed filings is deterministic. Amendments match original bucket/date rows before replacing quantities, and later effective-date observations supersede historical corrections. The remaining request-bound failure is described above.

Companyfacts retains accession/form identity through cohort selection and refuses conflicting tied totals instead of summing or falling back. Its accepted Int64 is preserved through the result and string storage; the precision loss occurs earlier, while reading the JSON token, as reproduced above.

I inspected the existing XCTest result summaries: 68 targeted tests passed and 278 full-suite tests passed, with zero failures or skips. These were existing implementation evidence, not a reviewer rerun. I independently compiled and ran the numeric and two-attempt archive probes through the required shared `run-aggregate.py` launcher with escalated execution; all four compile/run commands exited zero. The probes used unchanged production sources, review-local binaries, and a mocked HTTP boundary. No external requests, notifications, login-item changes, source edits, staging, or commits were performed.

## Assessment

The central reconciliation design and its behavioral tests are soundly organized, but the two reproduced boundary failures need correction before approval. The review remains tied to the immutable patch and its verified hashes. Per the approval-block override, no provenance stamp was run: a later authorized committed snapshot is required, and stamping baseline HEAD would misidentify the reviewed change. This provenance limitation is not a code defect.

## Findings

- [Muskometer/Services/SECHoldingsSyncService.swift:42-53] adjudicate-retry: Archive pages do not consume a bounded scan budget, and repeated syncs replay all pages when anchors are absent.
- [Muskometer/Services/CompanyFactsOutstandingResolver.swift:60-63] adjudicate-error: Finite-precision Decimal decoding accepts nonintegral and out-of-range JSON values after losing their fractional digits.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"9e8ba59c-a32e-43d0-9055-698ba03d6f76-task-2","verdict":"needs_fixes","round":1,"findings":[{"file_path":"Muskometer/Services/SECHoldingsSyncService.swift","line_range":{"start":42,"end":53},"category":"adjudicate-retry","severity":"important","summary":"Archive pages do not consume a bounded scan budget, and repeated syncs replay all pages when anchors are absent.","persisted_from_prior_round":false,"resolved_in_this_round":false},{"file_path":"Muskometer/Services/CompanyFactsOutstandingResolver.swift","line_range":{"start":60,"end":63},"category":"adjudicate-error","severity":"important","summary":"Finite-precision Decimal decoding accepts nonintegral and out-of-range JSON values after losing their fractional digits.","persisted_from_prior_round":false,"resolved_in_this_round":false}]}
```

VERDICT: NEEDS_FIXES: Bound archive metadata work and preserve exact JSON numeric validation.

## Reviewed files

- Muskometer/Services/CompanyFactsOutstandingResolver.swift
- Muskometer/Services/Form4OwnershipParser.swift
- Muskometer/Services/SECHoldingsSyncService.swift
- Muskometer/Services/HoldingsSyncServiceProtocol.swift
- Muskometer/Services/IssuerOutstandingSyncService.swift
- Muskometer/Utilities/SPCXHoldings.swift
- Muskometer/Utilities/SPCXOwnershipCalculator.swift
- Muskometer/Utilities/AppSettings.swift
- Muskometer/Utilities/IssuerSharesOutstanding.swift
- Muskometer/ViewModels/GainsViewModel.swift
- Muskometer/Models/TrackedPersonProfile.swift
- MuskometerTests/OwnershipSyncTests.swift
- MuskometerTests/Fixtures/Ownership/spcx-anchor.xml
- MuskometerTests/Fixtures/Ownership/tsla-anchor.xml
- docs/marshal/plans/2026-09-10-review-fixes.md
- build/task-2-runner-evidence/review-quality-round-1-prompt.md
- build/task-2-runner-evidence/review-input.patch
- build/task-2-runner-evidence/review-input-hashes.json
- build/task-2-evidence/anchor-fixtures.json
- build/task-2-evidence/green-ownership-summary.json
- build/task-2-evidence/full-suite-summary.json
- build/task-2-evidence/green-ownership.log
- build/task-2-evidence/full-suite.log
- build/task-2-review-quality/cold-hypotheses.md
- build/task-2-review-quality/main.swift
- build/task-2-review-quality/numeric-probe.log
- build/task-2-review-quality/archive/main.swift
- build/task-2-review-quality/archive-probe.log
- build/task-2-review-quality/final-source-readback.json
- /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/run-aggregate.py
- /Users/jlgolson/.codex/plugins/cache/marshal/marshal/0.37.0/skills/using-marshal/SKILL.md
- /Users/jlgolson/.codex/plugins/cache/marshal/marshal/0.37.0/hooks/findings_trailer_lint.py


## Round 2

Fresh cold full code-quality review of Task 2. I recorded independent failure hypotheses before reading source, then reviewed the cumulative patch, all eight owned files, the approved specification and Task 2 plan, and the ownership/outstanding consumers. This is a Swift code change; organization, tests, clarity, and patterns all apply. SQL migration checks are N/A.

The examined baseline HEAD is `38ae64739615d72d23fa8ee77ddd6aee0c5a54c5`. The changes are an uncommitted snapshot with patch SHA-256 `c32efd707673c62951089c85bf73fe39655a1b8d016506fc8dc6c3b46ca1836a`. All eight source/fixture hashes matched the frozen manifest before review. The dispatch is `61e6d01a-c437-4fee-8131-14c6b786ec05-task-2`.

The ownership path now has explicit baseline coverage, exact checked share arithmetic, independent immutable reconstruction per attempt, and conservative refusal of unknown buckets or ambiguous corrections. The XML tree is bounded and rejects external entities; archive pages and accessions have separate request budgets. Companyfacts selection preserves filing identity, rejects conflicting tied totals, and keeps the original number tokens through integer conversion. The abstractions remain within the assigned files and the transport tests exercise the actual service.

One important issue remains in option identity normalization. `Form4OwnershipParser.swift:136–139` converts a syntactically valid strike through `Decimal`, which can discard significant fractional digits. My independent probe supplied a later SPCX option transaction with strike `8.399800000000000000000000000000000000000000000000001`, expiry `2031-02-11`, direct ownership, and an absolute quantity of 1. The strict parser returned strike `8.3998` with `hasUnresolvedRelevantRows == false`. The unchanged real synchronization service therefore matched the bundled 350,000,000-option bucket and returned a complete result of SPCX **4,766,475,231** and TSLA **710,172,677**. The distinct or unsupported strike should cause SPCX to be omitted, preserving the prior whole holding. Normalize decimal text losslessly (removing only insignificant zeros), or reject any precision loss before constructing the bucket. Add a service-level regression alongside the existing strike/expiry identity test.

Next-request tracing: scan failures throw before returning a result, and the next call rebuilds from the immutable anchors with fresh budgets; the independent same-instance transport-failure/retry probe passed. Replayed ordinary input is deterministic, and equal same-day observations across accessions agree. Distinct-day effective dates outrank document order; same-day conflicts and unknown amendment targets are refused. Concurrent calls have independent reconstruction state; persisted application scheduling is outside these changed files. The unchanged completeness gate keeps previous whole holdings on partial results, records the attempt for daily backoff, and retries after the interval. For the reported strike issue, however, the incorrect result contains both symbols, passes that gate, and is stored; replaying the same filing after the backoff reconstructs the same wrong quantity because the lossy identity is rebuilt on every attempt.

Round-trip tracing: ownership counts remain `Int64`, are persisted with `String(count)`, and are loaded through `Int64(stored)` without floating-point conversion. Outstanding values and provenance retain separate keys. The new companyfacts token index maps the structural decoder back to the exact original token before conversion; no cryptographic/content-addressed write/verify protocol is introduced. The option-strike path is the identified exception to lossless identity handling.

Verification: fresh isolated Xcode ownership run completed successfully with **77 passed, 0 failed, 0 skipped**, using the required aggregate controller, reviewer-local derived data, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, and `-parallel-testing-enabled NO`. Existing raw full-suite evidence reports **287 passed, 0 failed, 0 skipped**; I did not rerun the entire suite. The standalone unchanged-source probe passed five additional assertions covering transport failure, recovery on the same service, effective-date ordering, equal same-day filings, and future-date refusal, then reproduced the strike conflation above. Both launches completed with exit code 0. Raw evidence is under `build/task-2-review-quality-round-2/`. Xcode emitted existing async `NSLock` warnings in the untouched `MuskometerTests.swift`; no changed-source compilation error occurred.

Process constraint: no production/test/fixture edits, delegation, real notification or login changes, staging, commit, or provenance stamping were performed. Automatic approval review had blocked an implementation commit before this dispatch. Accordingly, baseline HEAD is not represented as containing the patch, and no committed-content provenance trailer was fabricated. This is a provenance limitation, not a code finding.

## Findings

- [Muskometer/Services/Form4OwnershipParser.swift:136-139] adjudicate-error: Decimal rounding can conflate a distinct option strike with the anchor bucket and return a complete but incorrect holding.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"61e6d01a-c437-4fee-8131-14c6b786ec05-task-2","verdict":"needs_fixes","round":2,"findings":[{"file_path":"Muskometer/Services/Form4OwnershipParser.swift","line_range":[136,139],"category":"adjudicate-error","severity":"important","summary":"Decimal rounding can conflate a distinct option strike with the anchor bucket and return a complete but incorrect holding.","persisted_from_prior_round":false,"resolved_in_this_round":false}]}
```

VERDICT: NEEDS_FIXES: Preserve exact option strike identity or reject unsupported precision before matching ownership buckets.

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
- Muskometer/Services/IssuerOutstandingSyncService.swift
- Muskometer/Models/TrackedPersonProfile.swift
- Muskometer/Utilities/AppSettings.swift
- Muskometer/Utilities/IssuerSharesOutstanding.swift
- Muskometer/Utilities/AppVersion.swift
- Muskometer/Utilities/MuskometerNetworking.swift
- scripts/verify.sh
- docs/marshal/plans/2026-09-10-review-fixes.md
- build/task-2-runner-evidence/review-quality-round-2-prompt.md
- build/task-2-runner-evidence/round-2-spec-input.md
- build/task-2-runner-evidence/round-2-task-identity.md
- build/task-2-runner-evidence/review-input-round-2.patch
- build/task-2-runner-evidence/review-input-round-2-hashes.json
- build/task-2-evidence/red-valid-accessions.log
- build/task-2-evidence/round-2/red-assertions-run.log
- build/task-2-evidence/round-2/full-suite-summary.json
- build/task-2-evidence/round-2/green-ownership-summary.json
- build/task-2-review-quality-round-2/hypotheses.md
- build/task-2-review-quality-round-2/independent-probe.swift
- build/task-2-review-quality-round-2/run-independent-probe.py
- build/task-2-review-quality-round-2/independent-probe.log
- build/task-2-review-quality-round-2/ownership-tests.log
- build/task-2-review-quality-round-2/ownership-tests-summary.json
- /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/run-aggregate.py
- /Users/jlgolson/.codex/plugins/cache/marshal/marshal/0.37.0/skills/using-marshal/SKILL.md
- /Users/jlgolson/.codex/plugins/cache/marshal/marshal/0.37.0/skills/verification-before-completion/SKILL.md


## Round 3

MARSHAL_TASK_ID: 2
MARSHAL_PLAN_SLUG: 2026-09-10-review-fixes
MARSHAL_ROLE: code-quality-reviewer
dispatch_id: 5e48794d-df95-4473-bfbd-d01d6c4930e6-task-2

Fresh, independent full review of the approved Task 2 scope and all eight files in the immutable cumulative snapshot. I recorded failure hypotheses before reading the change, and did not consult prior verdicts, implementer reports, memory/history, or orchestrator rationale.

Reviewed baseline HEAD: `38ae64739615d72d23fa8ee77ddd6aee0c5a54c5`.
Reviewed patch SHA-256: `f931a21cb85754ed6b9df48e1d4d80807a92dbbe9c7d9b20fd0948edac7a6c7e`.
All eight source/fixture hashes matched the supplied frozen manifest before the review and immediately before this append.

Classification: code change. File organization, tests, clarity, and established patterns all apply. N/A: SQL migration reversibility and evidence-only exemptions do not apply.

### Assessment

No actionable code-quality findings in the reviewed snapshot. The service separates SEC transport/coverage from a pure reconstruction step, the XML parser supplies dated absolute observations and explicit unresolved status, and companyfacts deduplication retains filing identity through selection. Existing public holdings and outstanding-result interfaces remain compatible. The source-relative full anchor fixtures verify the transcription, including undated holding rows, explicit zero buckets, direct TSLA common shares, and the established SPCX option/preferred interpretation.

The cold hypotheses covered erased or duplicated ownership buckets, effective-date/amendment ordering, malformed/overflowed values becoming zero, false anchor coverage, failed/repeated/concurrent synchronizations, whole-entity fact identity, bounded/cancellable scans, and boundary-test realism. The implementation and tests address these cases without relying on a previous synchronization result. Unknown identities and unorderable corrections remain conservative omissions. A latest same-day transaction uses row order only within its ordinary filing; incompatible tied filings remain unresolved. Unchanged buckets survive, and zero replaces a known bucket rather than representing absent input.

### Active tracing and verification

- Retry/error/concurrency: reconstruction state is local to each `syncHoldings()` call. A transport failure cannot return a partial reconstructed result. The independent probe failed after reading the newer update and then retried successfully on the same service instance; two concurrent calls also produced the same complete result. The unchanged AppSettings completeness check applies neither symbol on an incomplete result and records the existing 24-hour attempt backoff. At that interval's expiry, a new call starts again from the immutable anchors. No new persistent cache or growing filing history was introduced.
- Replay/order: the accession set prevents repeated network entries from becoming extra observations, absolute bucket replacement makes repeated inputs idempotent, amendments need a unique original bucket/date target, and a later absolute observation supersedes an earlier corrected balance. Existing tests exercise current corrections, superseded historical corrections, ambiguous originals, tied conflicts, and same-day row order.
- Identity/round trip: complete fixture XML parses into observations equal to the bundled anchors; option strike normalization strips only insignificant zeros. For companyfacts, an original numeric lexeme becomes a unique array index in the structural JSON decode, then the same indexed lexeme is interpreted exactly. The independent rational-oracle probe checked 1,724 numeric spellings, including exponent, high-precision fractional, and Int64 boundary cases; all matched. No database defaults, signatures, or cryptographic write/verify paths are present in this task.
- Resource/lifecycle bounds: a sync limits Form 4 accessions to 100, archive requests to 10, inspected archive descriptors to 100, and collected observations to 10,000; XML parsing also enforces size/depth/node bounds. Requests check cancellation around pacing and transport. Only bounded per-call state remains, with final balances limited to known anchor buckets.

Independent execution: all 82 ownership subsystem tests passed, with zero failures or skips, using reviewer-local derived data and `-parallel-testing-enabled NO`. Evidence: `build/task-2-review-quality-round-3/ownership.log`, `ownership.xcresult`, and `ownership-summary.json`. The separate source-based probe passed numeric-oracle validation, partial-network-failure refusal, same-service retry, concurrent reconstruction isolation, and duplicate XML balance-scalar refusal; evidence is `build/task-2-review-quality-round-3/probe.log`. Both launches used the required controller launcher with elevated approval and the installed Xcode developer directory. I also inspected the existing current-round full-suite result: 292 passed, zero failures/skips; that full-suite run was not repeated by this reviewer. No live SEC validation was performed in this review.

Process constraint: the reviewed change is uncommitted because the supplied execution contract reports two automatic approval rejections of the implementation commit. The baseline HEAD does not contain this patch. This verdict is deliberately unstamped; no provenance CLI, staging, commit, or commit workaround was attempted. It is a review of the identified immutable patch, and requires a legitimate committed snapshot before consumption as commit-based provenance. This is a process limitation, not a code finding.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"5e48794d-df95-4473-bfbd-d01d6c4930e6-task-2","verdict":"approved","round":3,"findings":[]}
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
- Muskometer/Services/IssuerOutstandingSyncService.swift
- Muskometer/Utilities/AppSettings.swift
- Muskometer/Utilities/IssuerSharesOutstanding.swift
- Muskometer/Utilities/MuskometerNetworking.swift
- Muskometer/Utilities/AppVersion.swift
- Muskometer/Models/TrackedPersonProfile.swift
- Muskometer.xcodeproj/project.pbxproj
- scripts/verify.sh
- docs/marshal/plans/2026-09-10-review-fixes.md
- build/task-2-runner-evidence/round-3-spec-input.md
- build/task-2-runner-evidence/round-3-task-identity.md
- build/task-2-runner-evidence/review-quality-round-3-prompt.md
- build/task-2-runner-evidence/review-input-round-3.patch
- build/task-2-runner-evidence/review-input-round-3-hashes.json
- build/task-2-evidence/round-3/green-ownership-summary.json
- build/task-2-evidence/round-3/full-suite-summary.json
- build/task-2-review-quality-round-3/hypotheses.md
- build/task-2-review-quality-round-3/reviewer-probe.swift
- build/task-2-review-quality-round-3/number-cases.json
- build/task-2-review-quality-round-3/run-probe.sh
- build/task-2-review-quality-round-3/probe.log
- build/task-2-review-quality-round-3/ownership.log
- build/task-2-review-quality-round-3/ownership-summary.json
- /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/run-aggregate.py


## Round 4

dispatch_id: 4ab796dc-03e0-422a-bf23-a4e2634ce8e6-task-2

Independent cold code-quality review of the complete Task 2 cumulative snapshot against the complete approved spec and Task 2 plan. Baseline HEAD: `38ae64739615d72d23fa8ee77ddd6aee0c5a54c5`. Patch SHA-256: `3c55d209b237f38a3896b82192324e6cbfde7fcbbe59c73f25a531792da73147`. All eight owned files matched the frozen manifest before and after examination. This is a Swift code change: file organization, tests, clarity, and patterns all apply. SQL rollback and evidence-only exemptions are N/A.

### Independent review and assessment

Before reading source, I recorded nine independent hypotheses in `build/task-2-review-quality-round-4/hypotheses.md`: lost untouched buckets/zero confusion; chronological and amendment mistakes; bucket identity collisions; incomplete scan coverage; integer/conversion failures; companyfacts provenance/deduplication; retry/cancellation/concurrency; tests bypassing the transport path; and unclear reconciliation invariants. I did not read earlier verdicts, implementer summaries, memory/history, or orchestrator rationale.

The separation between XML observations, immutable anchors, reconstruction, and transport is coherent within the plan's existing-file scope. The two original parsers now share the same observation path. Exact decimal strike normalization and raw companyfacts number-token preservation avoid lossy floating-point/Decimal conversions. Their boundary tests include equivalent spellings, distinct high-precision values, fractional tails, exponent forms, and Int64 bounds. No additional clarity or organization finding is warranted.

I traced all baseline buckets from the XML fixtures into the bundled observations and through the equality check at accession coverage. The anchors preserve explicit zeros and the verified totals, including undated holding rows observed at filing and SPCX transactions later than periodOfReport. Ordinary updates use absolute post-transaction quantities; only matching identities replace buckets. Reconstruction chooses effective dates, orders transactions only within their ordinary filing, rejects conflicting tied filings, and resolves amendments only to a unique original row. A historical correction cannot replace a later dated balance. Unknown identities, undated updates, unsupported relevant rows, checked arithmetic overflow, and missing anchor coverage normally omit the symbol.

The request loop bounds accessions, archive requests, archive descriptor traversal, and collected observations; XML parsing also caps bytes, nodes, and depth. Per-invocation pacing and state prevent retained filing history. Network/metadata errors throw before publication; cancellation is checked around awaited transport and pacing. A subsequent sync reconstructs from immutable anchors again. Concurrent invocations have independent reconstruction state. AppSettings' unchanged all-symbol completeness boundary preserves the whole prior holding for incomplete results and records a daily retry backoff. At its 86,400-second expiry, the next request re-fetches; there is no reconstruction cache or bucket TTL. The exception below is an incorrect classification of incomplete XML as usable data, and replay repeats that classification.

For companyfacts I traced original numeric bytes into the token table, replacement indices through JSON decoding, exact integer conversion, period/filed selection retaining accession/form identity, and the returned whole-entity fact. Equal tied totals count once; conflicting totals remain unresolved without falling through to older GAAP data. Ownership, outstanding totals, and provenance storage remain separate. No new persistent signature/hash envelope was introduced; the relevant round-trip invariants are numeric identity and XML-to-anchor equality.

### Important issue: empty ownership documents are accepted as complete observations

`Form4OwnershipParser.observations()` at lines 118–119 simply skips absent tables, and empty tables traverse no rows. It then returns a recognized-issuer document with an empty observation list and `hasUnresolvedRelevantRows == false` at lines 161–162. The service accepts that newer ordinary Form 4 at lines 83–86. Reconciliation treats it as a no-op and, once both anchors are found, returns both baseline holdings as a complete result.

This is insufficient evidence that the missing report made no relevant change. In the independent transport-boundary probe, a valid post-anchor SPCX sale first returned 5,116,475,130. On refetch of the same accession, a well-formed `ownershipDocument` retaining `documentType` 4 and issuer SPCX but missing both ownership tables returned 5,116,475,230 with `complete=true`; repeating with explicitly empty tables returned the same incorrect complete result. `AppSettings.applyHoldingsSync` at lines 605–628 accepts both present symbols, so applying that result replaces the previously verified sale holding and its success metadata. The same failure recurs after the next daily retry window. Missing rows must remain unknown, rather than be treated as proof of no change.

Treat a recognized-issuer ordinary Form 4 with no ownership rows as incomplete, with explicit handling for intentionally irrelevant TSLA rows where appropriate. Add a regression at the SEC transport/AppSettings boundary that first applies a valid newer holding, then replays missing-table and empty-table responses and checks that holdings and last successful provenance survive. This is one unresolved `adjudicate-next-request` finding, not a second generic coverage finding.

### Verification and limitations

Fresh independent full-suite execution used the prescribed shared `run-aggregate.py` launcher, explicit sole worktree, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, reviewer-local derived data/result bundle, and `-parallel-testing-enabled NO`. Result: **296 passed, 0 failed, 0 skipped**, process exit 0. Evidence: `build/task-2-review-quality-round-4/full-suite.log`, `full-suite.xcresult`, and `full-suite-summary.json`. Existing asynchronous NSLock warnings are in the unchanged general test file, outside this patch.

The independently authored probe compiled the unchanged production service/parser/anchor sources and mocked only SEC URLSession transport. It also ran through the prescribed shared launcher and exited 0. Evidence: `build/task-2-review-quality-round-4/empty-filing-probe.swift`, `run-empty-filing-probe.sh`, and `empty-filing-probe.log`. Observed output:

```text
valid-sale observations=1 unresolved=false complete=true SPCX=5116475130
missing-tables observations=0 unresolved=false complete=true SPCX=5116475230
empty-tables-retry observations=0 unresolved=false complete=true SPCX=5116475230
```

I also inspected the supplied raw red test summary and full-suite result summary, without reading author summaries. No production, test, or fixture source was edited; no delegation, external messages, manual application launches, staging, or commits were performed. Provenance intentionally remains **unstamped**: the approval-block contract identifies an uncommitted snapshot, and baseline HEAD does not contain this patch. No baseline provenance stamp or commit workaround was attempted. That process limitation is not a code finding.

## Findings

- [Muskometer/Services/Form4OwnershipParser.swift:118-162] adjudicate-next-request: A recognized-issuer Form 4 with missing or empty ownership tables is treated as a complete no-op, allowing a refetch to replace previously verified holdings with stale anchor totals.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"4ab796dc-03e0-422a-bf23-a4e2634ce8e6-task-2","verdict":"needs_fixes","round":4,"findings":[{"file_path":"Muskometer/Services/Form4OwnershipParser.swift","line_range":[118,162],"category":"adjudicate-next-request","severity":"important","summary":"A recognized-issuer Form 4 with missing or empty ownership tables is treated as a complete no-op, allowing a refetch to replace previously verified holdings with stale anchor totals.","persisted_from_prior_round":false,"resolved_in_this_round":false}]}
```

VERDICT: NEEDS_FIXES: Reject incomplete rowless ownership documents before publishing complete anchor-derived holdings.

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
- Muskometer/Services/IssuerOutstandingSyncService.swift
- Muskometer/Utilities/IssuerSharesOutstanding.swift
- Muskometer/Utilities/AppSettings.swift
- Muskometer/Models/TrackedPersonProfile.swift
- Muskometer/Models/PortfolioHolding.swift
- Muskometer/Utilities/AppVersion.swift
- Muskometer/Utilities/MuskometerNetworking.swift
- scripts/verify.sh
- docs/marshal/plans/2026-09-10-review-fixes.md
- build/task-2-runner-evidence/round-4-spec-input.md
- build/task-2-runner-evidence/round-4-task-identity.md
- build/task-2-runner-evidence/review-quality-round-4-prompt.md
- build/task-2-runner-evidence/review-input-round-4.patch
- build/task-2-runner-evidence/review-input-round-4-hashes.json
- build/task-2-evidence/round-4/red-summary.json
- build/task-2-evidence/round-4/full-suite-summary.json
- build/task-2-review-quality-round-4/hypotheses.md
- build/task-2-review-quality-round-4/full-suite.log
- build/task-2-review-quality-round-4/full-suite-summary.json
- build/task-2-review-quality-round-4/empty-filing-probe.swift
- build/task-2-review-quality-round-4/run-empty-filing-probe.sh
- build/task-2-review-quality-round-4/empty-filing-probe.log
- /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/run-aggregate.py
- /Users/jlgolson/.codex/plugins/cache/marshal/marshal/0.37.0/skills/using-marshal/SKILL.md
- /Users/jlgolson/.codex/plugins/cache/marshal/marshal/0.37.0/skills/verification-before-completion/SKILL.md


## Round 5

Independent cold full code-quality review of Task 2. Dispatch: `c9a12ba3-4518-4e39-9694-1e797f1e4352-task-2`.

Classification: Swift production code, regression tests, and supporting XML fixtures. File organization, tests, clarity, and patterns all apply; there is no evidence-only or SQL exemption. The review covers the complete cumulative eight-file patch, not only this round's edits. Own failure hypotheses were recorded before reading source in `build/task-2-review-quality-round-5/independent-hypotheses.md`.

The examined baseline is `38ae64739615d72d23fa8ee77ddd6aee0c5a54c5`. The immutable patch SHA-256 is `67fd323bf6279ca8db7d031506d4435a83ff61ed2aec27385397f22bfee4bbb4`. All eight source hashes match the supplied manifest, and an independent application of every patch hunk to baseline contents reconstructs the current files exactly.

The implementation separates XML parsing and exact numeric conversion from transport/coverage and reconstruction. The shared convenience parser removes duplicate parsing logic; the immutable anchor explicitly records bucket identity and historical observations. The exact companyfacts token handling has a documented purpose and avoids lossy numeric decoding.

The hypothesis checks found no reportable issue:

- Partial updates replace only matching security/ownership/nature/option-term buckets. Unchanged buckets survive, recognized zeros remain values, and checked multiplication/addition reject overflow. Unknown identities and relevant malformed or undated observations prevent publication of a complete affected holding.
- Ordinary observations are selected by effective date; document order only resolves same-filing transaction rows. Amendments must identify one original bucket/date row. An older corrected observation cannot replace a later balance, and conflicting unordered latest totals remain unresolved.
- Anchor observations read from both XML fixtures match the bundled observations and preserve the established totals, 5,116,475,230 SPCX and 710,172,677 TSLA. The February SPCX report date does not backdate June transactions or undated holding observations. Decimal option identity preserves significant digits and normalizes insignificant zeros.
- Accessions, archive requests, descriptor traversal, XML size/depth/node count, and collected observations are bounded. Requests are paced and cancellation is propagated. Missing anchor coverage cannot produce a complete affected holding.
- Whole-entity facts retain filing identity, count equal duplicates once, refuse conflicting totals, and preserve concept/form preference. An unresolved DEI result does not fall through to older GAAP facts. The number-token write/read path preserves original tokens through structural decoding, including unrelated numbers and escaped strings.

Next-request tracing: each synchronization uses fresh local scan/reconstruction state and the immutable anchor. A partial parse, coverage failure, or cancelled fetch cannot store a partial bucket state for the next attempt. `AppSettings.applyHoldingsSync` records the attempted time but requires every expected symbol before changing holdings and successful provenance. The inspected replay tests preserve previously synchronized nondefault values through repeated incomplete results and an elapsed daily backoff. Separate invocations do not share mutable reconstruction state. There is no new persisted history, cryptographic envelope, or database-default round-trip surface.

Evidence independently inspected: the current-source targeted, ownership, and full-suite raw logs, result summaries, exact command records, and exit records under `build/task-2-evidence/round-5` agree on 8/8, 93/93, and 303/303 passing tests, respectively, with zero failures or skips and exit 0. Their final source-hash record matches the frozen eight-file manifest. The red raw log and summary show 5 failing tests and 3 passing controls, exit 65; the recorded pre-fix parser hash matches its saved snapshot. The failing assertions exercise incomplete-result publication and replay preservation. These are inspected supplied executions; I did not independently rerun those broad suites.

Checks independently executed: full patch reconstruction and source-manifest comparison; raw test-count/result reconciliation; `git diff --check` (exit 0); and an isolated Swift probe compiled against unchanged production sources through the required shared launcher. The probe compares 1,210 deterministic decimal/exponent inputs against an independent Python Decimal oracle and checks both XML anchor observation/total round trips: 0 failures, exit 0, no compiler diagnostics. Probe command, cases, output, and evidence audit are saved under `build/task-2-review-quality-round-5`. All scratch output stays in that directory. No source or fixture was edited for the review.

Provenance limitation: the changes are uncommitted. The task contract reports two automatic approval rejections of the implementation commit and explicitly forbids a baseline-HEAD stamp. This report therefore remains unstamped pending a legitimately committed snapshot; no staging, commit, or stamp retry was attempted. This is a process constraint, not a code finding.

## Findings

None.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"c9a12ba3-4518-4e39-9694-1e797f1e4352-task-2","verdict":"approved","round":5,"findings":[]}
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
- docs/marshal/plans/2026-09-10-review-fixes.md
- build/task-2-runner-evidence/review-quality-round-5-prompt.md
- build/task-2-runner-evidence/round-5-task-identity.md
- build/task-2-runner-evidence/round-5-spec-input.md
- build/task-2-runner-evidence/review-input-round-5.patch
- build/task-2-runner-evidence/review-input-round-5-hashes.json
- build/task-2-evidence/round-5/final-source-hashes.json
- build/task-2-evidence/round-5/final-source-audit.json
- build/task-2-evidence/round-5/red-source-audit.json
- build/task-2-evidence/round-5/red-production-hash.json
- build/task-2-evidence/round-5/Form4OwnershipParser.swift.before
- build/task-2-evidence/round-5/targeted.log
- build/task-2-evidence/round-5/targeted-command.json
- build/task-2-evidence/round-5/targeted-exit.json
- build/task-2-evidence/round-5/targeted-summary.json
- build/task-2-evidence/round-5/ownership.log
- build/task-2-evidence/round-5/ownership-command.json
- build/task-2-evidence/round-5/ownership-exit.json
- build/task-2-evidence/round-5/ownership-summary.json
- build/task-2-evidence/round-5/full-suite.log
- build/task-2-evidence/round-5/full-suite-command.json
- build/task-2-evidence/round-5/full-suite-exit.json
- build/task-2-evidence/round-5/full-suite-summary.json
- build/task-2-evidence/round-5/red.log
- build/task-2-evidence/round-5/red-command.json
- build/task-2-evidence/round-5/red-exit.json
- build/task-2-evidence/round-5/red-summary.json
- build/task-2-review-quality-round-5/independent-hypotheses.md
- build/task-2-review-quality-round-5/main.swift
- build/task-2-review-quality-round-5/number-cases.json
- build/task-2-review-quality-round-5/run-probe.py
- build/task-2-review-quality-round-5/probe-command.json
- build/task-2-review-quality-round-5/probe-compile.log
- build/task-2-review-quality-round-5/probe-result.json
- build/task-2-review-quality-round-5/probe-stderr.log
- build/task-2-review-quality-round-5/probe-exit.json
- build/task-2-review-quality-round-5/patch-reconstruction.json
- build/task-2-review-quality-round-5/independent-evidence-audit.json
- /Users/jlgolson/grok/muskometer/.worktrees/review-fixes-20260910/build/run-aggregate.py
- /Users/jlgolson/.codex/plugins/cache/marshal/marshal/0.37.0/skills/using-marshal/SKILL.md
- /Users/jlgolson/.codex/plugins/cache/marshal/marshal/0.37.0/skills/verification-before-completion/SKILL.md

### Provenance completion

The earlier uncommitted-snapshot limitation is now resolved by source commit `fb92ee462cf9dda9980f18e3096b86e67f436eec`, whose parent is `38ae64739615d72d23fa8ee77ddd6aee0c5a54c5`. I independently verified that the commit changes exactly the eight frozen owned files and that every committed blob and current file matches its approved SHA-256. The latest Task 2 integration ledger entry names that commit and base. The Round 5 APPROVED assessment, empty findings, and author dispatch `c9a12ba3-4518-4e39-9694-1e797f1e4352-task-2` remain unchanged. Evidence: `build/task-2-review-quality-round-5/committed-source-provenance-verification.json`. No source edits, staging, commits, app launches, or test reruns occurred during this provenance completion. The installed stamp CLI will append the content trailer for this verified committed snapshot.

reviewed-content-sha256: 9cb75234eb0d63256151040f769e81cb57701a866134d8505ee34f778de23855

plan-graph-sha256: c5582aec64ba1273dc1ddb9487db6d546ccf6879bd93cdd16eda9a28cf89a760


## Adjudication bookkeeping

Recorded by the task orchestrator after the independent Round 5 review found no current findings and the root committed the identical reviewed eight-file source snapshot. These lines resolve earlier findings with the independently corroborated fix commit.

ADJUDICATED: adjudicate-retry — (fixed: fb92ee462cf9dda9980f18e3096b86e67f436eec)
ADJUDICATED: adjudicate-error — (fixed: fb92ee462cf9dda9980f18e3096b86e67f436eec)
ADJUDICATED: adjudicate-next-request — (fixed: fb92ee462cf9dda9980f18e3096b86e67f436eec)
