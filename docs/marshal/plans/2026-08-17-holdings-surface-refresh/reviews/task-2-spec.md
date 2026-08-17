Task 2 (NYSE 2028 holidays and early closes) matches Design §3 and acceptance criterion 6. Reviewed the calendar, tests, and ARCHITECTURE table at HEAD `176c190` as the full Task 2 product (landed earlier in `a766040`; this dispatch was a no-op). Cross-checked the 2028 rows against the official NYSE Holidays & Trading Hours table cited in the spec.

What landed correctly

- Holiday set is additive. The nine 2028 dates in `MarketHoursService.swift:236-238` are exactly the spec table: `2028-01-17`, `2028-02-21`, `2028-04-14`, `2028-05-29`, `2028-06-19`, `2028-07-04`, `2028-09-04`, `2028-11-23`, `2028-12-25`. 2026 and 2027 rows are unchanged.
- New Year’s 2028 is not observed. The set does not contain `2028-01-01` or `2027-12-31`. Jan 1 2028 is a Saturday; `test2028HasNoObservedNewYearsClose` asserts Monday 2028-01-03 11:00 ET is open.
- Early closes add only `"2028-07-03"` and `"2028-11-24"` at `SessionMinutes.earlyClose` (13:00 ET). No 2028 Christmas Eve early close (Dec 24 2028 is a Sunday). 2026–2027 early-close rows stay.
- Comments and docs say 2026–2028. Early-close comment at `MarketHoursService.swift:79`. ARCHITECTURE holiday prose covers 2026 through 2028, names the Saturday New Year’s rule, adds the two 2028 early-close rows, and keeps the annual-extension note as “after 2028”.
- Required tests exist in `MarketHoursServiceTests` via `EasternTestDates` (same ET helper as the existing early-close cases):
  - 2028-01-17 11:00 closed; 2028-01-18 11:00 open
  - 2028-01-03 11:00 open
  - 2028-04-14 and 2028-07-04 11:00 closed
  - 2028-07-03 11:00 open; 2028-07-03 14:00 closed
  - 2028-11-23 11:00 closed; 2028-11-24 14:00 closed
- Existing 2026–2027 tests remain (`testHolidayIsClosed`, `test2027HolidayIsClosed`, `test2027GoodFridayIsClosed`, Thanksgiving/Christmas Eve early-close cases). No holiday API, no 2026–2027 mutation, no extra product surface.

Plan wording vs implementation

The plan asked for “the same ET helper style as `test2027GoodFridayIsClosed`.” The new tests use `EasternTestDates` rather than that test’s inline `DateComponents`. That matches the later early-close cases in the same suite and is a considered consistency choice, not a missed requirement. Confirm it was deliberate; do not rewrite them to the older inline form.

Next-request: `isHoliday` / `regularCloseMinutes` are pure lookups of a compiled set and map. Retry, replay, and concurrent `currentSession` / `isMarketOpen` calls on the same instant all see the same 2028 closed/early-close answer. No persisted calendar state and no freshness window, so no TTL hazard. 2029 is still a maintainer pass, as ARCHITECTURE already says.

No missing §3 calendar requirements, no extra product work, no misunderstood New Year’s or Christmas Eve rule.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- docs/marshal/specs/2026-08-17-holdings-surface-refresh-design.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-2-description.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-2-summary.md
- Muskometer/Services/MarketHoursService.swift
- MuskometerTests/MuskometerTests.swift
- docs/ARCHITECTURE.md

reviewed-content-sha256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
