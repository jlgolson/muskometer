# Plan-correctness review

Cold hypotheses before confirming the author’s framing: wrong or invented integers vs current seeds and spec pins; calculator steps that would still zero options or leave remarks in; remigration that still inflates SPCX or rewrites non-fingerprints; missing Form 4 / AppSettings test updates so Task 10’s full suite stays red; 2028 calendar rows that invent a New Year’s close; comparison deletion that leaves `tradingDayCalendar` / pbxproj IDs / UserDefaults keys; verification HOW narrower than CI `verify.sh`; maybe-no-op Task 10; placeholders or a non-literal Deferred.

None of those hold as blockers.

## Strengths

Pinned table matches the spec and the worktree: TSLA seed `710_172_677`, SPCX table last-row-wins `4_766_475_230` + vested options `350_000_000` = `5_116_475_230`, outstanding `13_181_779_945 + 389_289_254 = 13_571_069_199`, TSLA outstanding unchanged `3_949_547_394`, `MARKETING_VERSION` `0.1.5` / `CURRENT_PROJECT_VERSION` `26`. Current sources still hold the old values (`SPCXHoldings.defaultShareCount` / musk SPCX `6_068_734_060`, musk TSLA `699_580_882`, `IssuerSharesOutstanding.defaultSPCX` `13_181_779_945`, four pbxproj version pairs at `0.1.4` / `25`).

File paths exist. Signatures match the code the implementer will edit: `classAEquivalentShares` still zeros `"option"` and `restrictedShares(from:)` is still added; `migrateStoredShareCount` still upgrades `6_068_547_515` and does not treat `6_068_734_060` as legacy (it is today’s default); `loadShareCounts` remigrates only SPCX; `loadSharesOutstanding` has no remigration; `GainsViewModel.init` takes `comparisonLineSelector` / `tradingDayCalendar` and `updateComparisonLineIfNeeded` is the only calendar use; `PopoverContentView.dataView` is ownership → combined → caption → records → rows → parity; comparison pbxproj IDs are exactly `A100`/`A200` `…2B`, `2E`, `3A`, `3B`; `ComparisonHistoryStore` keys are `comparisonHistoryEntries` / `comparisonHistoryEntries_<personID>`; `SeededComparisonRandomizer` lives on the selector file; `MergerParityPresentation.currentTSLAPrice` is asserted at the three named test sites plus the card preview.

Task 1 fixture math is correct against the current June 2026 XML: existing last-row-wins plus remarks is `6_068_734_060`; adding later By Trust Class A `0` drops `186_545`, counting the 350M option and dropping remarks yields `5_116_475_230`. Deleting the option-zeroing line is enough for the live title (`Option to Buy (Class B Common Stock)` contains `class b common`); the plan also requires a synthetic no-class option title to count 1:1.

TDD is present on the functional tasks (1–4, 6). Dep graph is `1→4→7`, `3→7`, `5→7` and `5→8`, `1–8→9→10`. Ready-set `1, 2, 3, 5, 6` is consistent with those edges. `## Deferred` is the literal `None.`

Task 10 declares WHAT (0.1.5 product path + pinned integers + stale marketing strings), HOW (`MUSKOMETER_SKIP_LIVE_YAHOO=1 ./scripts/verify.sh`, same command and skip flag as `.github/workflows/ci.yml` and `release.yml`), and WHO (this task, in-plan, paste the output tail). That is not narrower than CI.

Self-review spec map covers §1–§6, version tick, acceptance, and named non-goals (13G, strike, 8-K parse, Sparkle, tag/DMG). No TBD/TODO in steps.

## Issues

None that would lead a reasonable implementer off the spec. Residual suite updates (for example `Form4OwnershipParserTests.testSPCXUsesOwnershipAggregatorNotSingleRow`, which currently encodes remarks-add via the same calculator) are covered by Task 10’s “fix only regressions introduced by this branch.” Task 10 listing `scripts/verify.sh` and allowing a no-commit DONE is verification evidence, not a maybe-no-op product task.

## Assessment

Executable. Integers, files, signatures, remigration load-path, comparison cut, calendar rows, docs/marketing, version tick, and in-plan verification match the spec and the current worktree.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

reviewed-content-sha256: f17377d2b60d59d9370c31ceee3b46c917113b8b289c7406ffcd1df43c50d922

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
