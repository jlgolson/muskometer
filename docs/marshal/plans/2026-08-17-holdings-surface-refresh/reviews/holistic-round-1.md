# Plan-level holistic review

Cold hypotheses before confirming the author’s framing: a spec leftover (calculator rule, TSLA remigration, Cursor outstanding, 2028 calendar, comparison cut, marketing PNGs, version tick, dead `currentTSLAPrice`) has no task; a later task consumes a type or load-path an earlier task never creates; pinned integers or fingerprints drift across tasks; Task 7 HOLDINGS omits the strike-mark sentence or an accession; comparison is hidden rather than deleted; non-goals (13G headline, strike ledger, 8-K parse, Sparkle, tag/DMG) are tasked; `## Deferred` is not the literal `None.`; Task 10 lacks in-plan WHAT/HOW/WHO or is narrower than CI `verify.sh`; remigration write/read would not be idempotent.

None of those hold.

## Assessment

The ten tasks cover Design §§1–7, Goals, Testing, Acceptance 1–12, the upgrade/persisted-state contract, Compliance messaging, and the 0.1.5 / build 26 tick. Self-review map is complete: calculator + seeds (1, 4), outstanding (3), calendar (2), comparison deletion (5), marketing (8), docs/Settings/dead field (6, 7), version/CHANGELOG (9), verify (10). Non-goals are not tasked. `docs/DEVELOPING.md` has no selector/comparison mention, so the spec §4 DEVELOPING half is vacuously satisfied without a task. Cross-task names and integers match the pinned table (`710_172_677`, `4_766_475_230` + `350_000_000` = `5_116_475_230`, `13_571_069_199`, TSLA outstanding unchanged `3_949_547_394`, marketing `0.1.5` / build `26`). Comparison is deleted end-to-end (four sources, pbxproj IDs, VM API + `tradingDayCalendar`, history-key sweep on load and Reset, four test types). Ready-set `{1, 2, 3, 5, 6}` matches the declared DAG (`1→4→7`; `3→7`; `5→7` and `5→8`; `1–8→9→10`). Shared-file concurrency (`MuskometerTests.swift`, `AppSettings.swift`, `ARCHITECTURE.md`) is already serialized by the parallelism verifier; it is not a missing product task.

Remigration is the same `String(Int64)` persist-if-changed pattern on three disjoint keys. Targets are not members of the legacy sets, so a second `AppSettings` init is a no-op. Task 10 is in-plan verification: `MUSKOMETER_SKIP_LIVE_YAHOO=1 ./scripts/verify.sh` plus the integer/string greps — the same skip-flag command CI uses. Residual suite updates (for example `Form4OwnershipParserTests.testSPCXUsesOwnershipAggregatorNotSingleRow`, which still encodes remarks-add) stay inside Task 10’s “fix only regressions introduced by this branch.” The plan is ready to execute.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

reviewed-content-sha256: 9065a765b210744d3a9b847834f3ef77e3912a3e9f03e03e86f6930e7572af19

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
