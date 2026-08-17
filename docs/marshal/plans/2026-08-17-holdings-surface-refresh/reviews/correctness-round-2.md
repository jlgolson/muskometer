# Plan-correctness review

Cold hypotheses before confirming the author’s framing: Task 7 HOLDINGS steps omit the strike-mark sentence or one of the four named accessions; `## Deferred` is not the literal `None.`; Task 10 lacks WHAT/HOW/WHO, is narrower than CI `verify.sh`, or is a maybe-no-op product task; dep graph has a dangling edge, cycle, or ready-set that ignores a real `Depends on:`; pinned integers drift from the spec or the current worktree seeds; calculator steps still zero options or keep remarks; remigration still inflates SPCX or rewrites non-fingerprints; 2028 calendar invents a New Year’s close; comparison deletion leaves `tradingDayCalendar` / pbxproj IDs / history keys; placeholders or missing TDD on functional tasks.

None of those hold as blockers.

## Strengths

Pinned table still matches the spec and the worktree: TSLA seed `710_172_677`, SPCX table last-row-wins `4_766_475_230` + vested options `350_000_000` = `5_116_475_230`, outstanding `13_181_779_945 + 389_289_254 = 13_571_069_199`, TSLA outstanding unchanged `3_949_547_394`, `MARKETING_VERSION` `0.1.5` / `CURRENT_PROJECT_VERSION` `26`. Current sources still hold the old values (`SPCXHoldings.defaultShareCount` / musk SPCX `6_068_734_060`, musk TSLA `699_580_882`, `IssuerSharesOutstanding.defaultSPCX` `13_181_779_945`, four pbxproj version pairs at `0.1.4` / `25`).

Task 7 HOLDINGS step is complete against spec §1 / §2 / Compliance: last-row-wins plus vested option underlying; do not add remarks performance RSUs; name 350M options and excluded 1.302B awards; **strike-mark sentence** (350M marked at Class A last, Class B 1:1, ~$2.94B unpaid strike ignored); outstanding `13,571,069,199` = cover A+B + Cursor 8-K item (i) `389,289,254`; **four accessions** `0001104659-26-075213`, `0001628280-26-044069`, `0001628280-26-052535`, `0001628280-26-056945`.

`## Deferred` body is the literal `None.`

Task 10 declares WHAT (0.1.5 product path + pinned integers + stale marketing strings), HOW (`MUSKOMETER_SKIP_LIVE_YAHOO=1 ./scripts/verify.sh`, same command and skip flag as `.github/workflows/ci.yml` and `release.yml`, plus the integer/string greps), and WHO (this task, in-plan, paste the output tail). That is not narrower than CI. A no-commit DONE when `verify.sh` needs no tweak is verification evidence, not a maybe-no-op product task.

Dep graph is acyclic with existing IDs only: `1→4→7`; `3→7`; `5→7` and `5→8`; `1–8→9→10`. Ready-set `1, 2, 3, 5, 6` matches those edges.

Signatures still match the code the implementer will edit: `classAEquivalentShares` still zeros `"option"` and `restrictedShares(from:)` is still added; `migrateStoredShareCount` still upgrades `6_068_547_515` and does not treat `6_068_734_060` as legacy; `loadShareCounts` remigrates only SPCX; `loadSharesOutstanding` has no remigration; `GainsViewModel.init` takes `comparisonLineSelector` / `tradingDayCalendar` and `updateComparisonLineIfNeeded` is the only calendar use; popover order is ownership → combined → caption → records → rows → parity; comparison pbxproj IDs are `A100`/`A200` `…2B`, `2E`, `3A`, `3B`; history keys are `comparisonHistoryEntries` / `comparisonHistoryEntries_<personID>`; `SeededComparisonRandomizer` lives on the selector file; `currentTSLAPrice` is asserted at the three named test sites plus the card preview. Holiday set is 2026–2027 only; plan adds the nine 2028 dates and does not add `2028-01-01` or `2027-12-31`.

Task 1 fixture math holds: current last-row-wins plus remarks is `6_068_734_060`; later By Trust Class A `0` drops `186_545`; counting 350M options and dropping remarks yields `5_116_475_230`.

TDD is present on the functional tasks (1–4, 6). Self-review spec map covers §1–§6, version tick, acceptance, and named non-goals. No TBD/TODO in steps.

## Issues

None that would lead a reasonable implementer off the spec. Residual suite updates (for example `Form4OwnershipParserTests.testSPCXUsesOwnershipAggregatorNotSingleRow`, which currently encodes remarks-add via the same calculator) remain covered by Task 10’s “fix only regressions introduced by this branch.”

## Assessment

Executable. Integers, files, signatures, remigration load-path, comparison cut, calendar rows, Task 7 HOLDINGS strike-mark + four accessions, literal Deferred `None.`, Task 10 in-plan verification, and the declared dep graph match the spec and the current worktree.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":2,"findings":[]}
```

VERDICT: APPROVED

reviewed-content-sha256: 9065a765b210744d3a9b847834f3ef77e3912a3e9f03e03e86f6930e7572af19

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
