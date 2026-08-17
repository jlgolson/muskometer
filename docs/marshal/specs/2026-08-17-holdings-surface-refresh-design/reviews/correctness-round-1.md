# Spec-correctness review

Fresh read of `docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md` against the feature-worktree sources (not archived reviews). Cold hypotheses before confirming the author’s framing: wrong seed integers vs live EDGAR; fingerprint remigration that misses the current bundled default or still inflates; option-title rule that would fall through to `return 0`; outstanding remigration colliding with `shareCount_*`; invented 2028 NYSE dates / phantom New Year’s close; `tradingDayCalendar` used beyond caption debounce; incomplete comparison cut; unsourced external primitives; deferral-form failure; version tick that leaves a second source of truth.

None of those hold.

## Strengths

Current-architecture claims match the code: dual SPCX seeds (`TrackedPersonProfile.musk` + `SPCXHoldings.defaultShareCount`), TSLA seed only on the spec, `shareCount(for:)` / `sharesOutstanding(for:)` fallbacks, SPCX load-path remigration that still upgrades `6_068_547_515` to `6_068_734_060`, outstanding load with no remigration, comparison after the combined card only, share card caption-free, pbxproj IDs `A100`/`A200` `…2B/2E/3A/3B`, comparison tests inside `MuskometerTests.swift`, `tradingDayCalendar` used only in `updateComparisonLineIfNeeded`, `currentTSLAPrice` unused in `MergerParityCardView`.

Live EDGAR fetches (UA `Muskometer/0.1.4 (info@muskometer.org; https://muskometer.org)`) confirm the product integers: TSLA last direct `D` is `710,172,677`; SPCX last-row-wins Class A+B is `4,766,475,230` (By Trust later `0`) plus vested option title `Option to Buy (Class B Common Stock)` `350,000,000` = `5,116,475,230`; remarks `1,302,072,285` unvested awards stay out; 13G `6,418,547,515` is the rejected table+RSU+option headline; Cursor 8-K item (i) is `389,289,254` Class A → A+B `13,571,069,199`; TSLA companyfacts ECS is still `3,949,547,394` (end 2026-07-16); SPCX companyfacts has no `dei:EntityCommonStockSharesOutstanding` (WASO-only). Arithmetic is internally consistent: `4,766,475,230 + 1,302,072,285 = 6,068,547,515`, `6,068,547,515 + 186,545 = 6,068,734,060`, `7,696,293,669 + 389,289,254 = 8,085,582,923`.

SPCX inversion is the right fix for the live bug. The spec correctly adds `6_068_734_060` as a *new* legacy fingerprint (today it is `defaultShareCount` and therefore not a switch case). TSLA remigration is the same exact-integer load-path policy, not the one-shot `migrateLegacyShareCounts` copy. Outstanding remigration is a single stored integer next to `loadSharesOutstanding` / `IssuerSharesOutstanding` — no new type required.

NYSE 2028 table matches the official Holidays & Trading Hours page: no New Year’s observed close, MLK `2028-01-17` through Christmas `2028-12-25`, early closes only `2028-07-03` and `2028-11-24`. Named tests would catch a phantom Monday observed New Year’s and the early-close 13:00 boundary. `nextOpenDate`’s 10-day lookahead still covers 2028 holiday weekends.

Comparison deletion is a closed cut: four compile units + pbxproj IDs, VM API and `tradingDayCalendar` dead-dependency, known UserDefaults key shapes on init and Reset, four test types, site blurb. `SeededComparisonRandomizer` lives on the selector file. Registry remains `[.musk]`. `ComparisonLine.swift` is 4,520 lines as claimed.

Upgrade contract, rollback (including the old binary re-inflating SPCX), version tick (`0.1.4`/`25` → `0.1.5`/`26` on all four pbxproj assignments; `AppVersion.short` stays the single runtime source), CHANGELOG `0.1.5` + empty Unreleased, and non-goals (13G headline, strike subtraction, 8-K HTML parse, Sparkle/release cut, holiday API) are decided. `## Deferred` is the literal `None.`; Scale & Validation is present. External primitives (NYSE page, EDGAR Form 4 / 8-K / companyfacts GETs with UA and date) are sourced.

## Issues

None that would block plan-writing. Residual risks (fingerprint-only remigration, Cursor 1.75M omission, HTML-mock drift, unvested-option title later, ignored strike) are already accepted in Risks / Non-goals with implementable mitigations.

## Assessment

Plan-ready. Fingerprint remigration, calendar rows, comparison deletion, marketing/docs, and the 0.1.5 / build 26 tick are specified tightly enough to implement without an open design question.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

reviewed-content-sha256: 324958744ca9594f8a3edfb855638cc7292c6250161aad2a48e975829d33a5fd
