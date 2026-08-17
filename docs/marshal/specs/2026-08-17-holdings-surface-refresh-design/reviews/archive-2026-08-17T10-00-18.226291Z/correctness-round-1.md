# Spec correctness: holdings surface refresh

Fresh read of the live spec against the feature-worktree sources (not archived reviews). Checked ownership/outstanding seeds and load paths, comparison wiring, holiday tables, version surfaces, and the cited NYSE 2028 calendar.

## Strengths

- Current-architecture claims match the code: dual SPCX seeds (`TrackedPersonProfile.musk` + `SPCXHoldings.defaultShareCount`), TSLA seed only on the spec, `shareCount(for:)` / `sharesOutstanding(for:)` fallbacks, SPCX load-path remigration that still upgrades `6_068_547_515` to `6_068_734_060`, outstanding load with no remigration, comparison after the combined card only, share card caption-free, pbxproj IDs `A100`/`A200` `…2B/2E/3A/3B`, comparison tests inside `MuskometerTests.swift`, `tradingDayCalendar` used only in `updateComparisonLineIfNeeded`, `currentTSLAPrice` unused in `MergerParityCardView`.
- SPCX inversion is the right fix for the live bug and is internally consistent: `6_068_734_060 − 186_545 = 6_068_547_515`, and `6_068_547_515 + 350_000_000 = 6_418_547_515` matches the out-of-scope 13G headline. Older fingerprints stay retargeted at the new default. TSLA remigration is the same exact-integer load-path policy, not the one-shot `migrateLegacyShareCounts` copy.
- Outstanding bump arithmetic is exact (`7_696_293_669 + 389_289_254 = 8_085_582_923`; `+ 5_485_486_276 = 13_571_069_199`). Orthogonal to Form 4 ownership. WASO-only companyfacts is why a pinned default is required.
- NYSE 2028 table matches the official Holidays & Trading Hours page (retrieved independently): no New Year’s observed close, MLK `2028-01-17` through Christmas `2028-12-25`, early closes only `2028-07-03` and `2028-11-24`. Tests named in §3 would catch a phantom Monday observed New Year’s and the early-close 13:00 boundary. `nextOpenDate`’s 10-day lookahead still covers 2028 holiday weekends.
- Comparison deletion is a closed cut: four compile units + pbxproj IDs, VM API and `tradingDayCalendar` dead-dependency, known UserDefaults key shapes on init and Reset, test types, site blurb. `SeededComparisonRandomizer` lives on the selector file. Registry remains `[.musk]`.
- Upgrade contract, rollback (including the old binary re-inflating SPCX), version tick (`0.1.4`/`25` → `0.1.5`/`26` on all four pbxproj assignments; `AppVersion.short` stays the single runtime source), CHANGELOG `0.1.5` + empty Unreleased, and non-goals (13G/options, 8-K HTML parse, Sparkle/release cut, holiday API) are decided. `## Deferred` is the literal `None.`; Scale & Validation is present. External primitives (NYSE page, EDGAR Form 4 / 8-K / companyfacts GETs with UA and date) are sourced.

## Issues

None that would block plan-writing. Unused `PortfolioHolding.defaults` still hardcodes the old TSLA preview count and is unreferenced; after `SPCXHoldings.defaultShareCount` changes, the SPCX preview row follows automatically. Not a seed or remigration path.

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

reviewed-content-sha256: 09f5fffd96a8c310c86ceff52228710663cc9bf2742b4dbe82829acfebe499d3
