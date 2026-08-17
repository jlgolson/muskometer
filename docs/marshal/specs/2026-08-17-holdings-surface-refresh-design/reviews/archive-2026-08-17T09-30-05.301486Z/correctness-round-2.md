# Spec correctness review — holdings surface refresh

Independent full read of `docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md` against the current tree and the cited external tables. Ready for plan-writing.

Checked against: `SPCXHoldings.swift`, `IssuerSharesOutstanding.swift`, `AppSettings.swift`, `TrackedPersonProfile.swift`, `SPCXOwnershipCalculator.swift`, `MarketHoursService.swift`, `PopoverContentView.swift`, `GainsViewModel.swift`, `MergerMarketCapParity.swift`, `ComparisonHistoryStore.swift`, `Form4OwnershipParser.swift`, `ComparisonLine.swift`, `ComparisonLineSelector.swift`, `MergerParityCardView.swift`, `ShareCardView.swift`, `SettingsView.swift`, `MuskometerApp.swift`, `project.pbxproj`, `MuskometerTests.swift` (comparison types, June 2026 fixture, holiday/early-close cases, parity passthrough ~1172/1287/1504), `docs/HOLDINGS.md`, `docs/ARCHITECTURE.md`, `docs/PRIVACY.md`, `docs/README.md`, `docs/index.html`, `docs/screenshots/render-*.html` + `app-capture.png`, NYSE Holidays & Trading Hours, and live EDGAR fetches of the cited Form 4 / 8-K with User-Agent `Muskometer/0.1.4 (info@muskometer.org; https://muskometer.org)`.

## Assessment

The current-architecture section matches the code: dual ownership seeds (`TrackedPersonProfile.musk` + `SPCXHoldings.defaultShareCount`), outstanding fallbacks with no remigration today, SPCX load-path remigration that still upgrades `6_068_547_515` to `6_068_734_060`, comparison wired only after the combined card, share card caption-free, pbxproj IDs `A100/A200 …2B/2E/3A/3B`, comparison tests inside `MuskometerTests.swift`, `tradingDayCalendar` used only in `updateComparisonLineIfNeeded`, `currentTSLAPrice` unused in the card body.

Pinned integers and dates check out:

- TSLA Form 4 `0001104659-26-075213` last direct `D` row is `710,172,677`.
- SPCX Form 4 `0001628280-26-044069` last-row-wins per `(title, nature)` plus restricted remark `1,302,072,285`, options excluded, By Trust Class A later `0` → `6,068,547,515` (`6,068,734,060 − 186,545`).
- 10-Q cover A+B `13,181,779,945` + Cursor 8-K item (i) `389,289,254` = `13,571,069,199`.
- Official NYSE 2028 table: no New Year’s observed close; holidays and the two early closes (`2028-07-03`, `2028-11-24`) match §3; no 2028 Christmas Eve early close.

Deletion, remigration, upgrade/rollback, and acceptance criteria are specific enough to plan against (exact fingerprints, load-path vs one-shot, Reset + init key sweep, fixture must include By Trust → 0, no dead `tradingDayCalendar` on the VM). `## Deferred` is `None.`; `## Scale & Validation` is present.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":2,"findings":[]}
```

VERDICT: APPROVED

reviewed-content-sha256: a1051462c420eac227539bdcd8fbe1ed1dd5f4a1e14486fb2f28078fc6365a81
