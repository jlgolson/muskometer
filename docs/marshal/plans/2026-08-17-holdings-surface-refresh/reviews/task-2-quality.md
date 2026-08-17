# Task 2 Code Quality Review — NYSE 2028 holidays and early closes

Reviewed the full Task 2 product at HEAD `176c190d40546b2ffc7a57b822fb2b5a68dea3d4` (landed in `a766040f9f5dd13189d86a6f5c02f98212591a0d`: `Extend NYSE holiday and early-close tables through 2028`). This dispatch was a no-op vs current HEAD.

## Strengths

The change is a data-table extension in the existing `MarketHoursService` maps. Nine 2028 holiday strings and two early-close keys were appended; session math, `isTradingDay`, and the public protocol are untouched. 2026–2027 holiday rows and the three pre-2028 early-close entries (including the 2027-12-24 “full holiday, no Christmas Eve early close” comment) are intact. Phantom New Year’s dates `2028-01-01` and `2027-12-31` were not added.

Tests live in `MarketHoursServiceTests` next to the 2027 cases and cover every plan-named instant: MLK closed / next day open, Jan 3 open, Good Friday and July 4 closed, July 3 11:00 open / 14:00 closed, Thanksgiving closed / day-after 14:00 closed. Existing 2026–2027 tests (`testHolidayIsClosed`, `test2027HolidayIsClosed`, `test2027GoodFridayIsClosed`, Thanksgiving and Christmas Eve early-close cases) remain.

`docs/ARCHITECTURE.md` holiday prose is 2026–2028, names the Saturday New Year’s rule, adds the two 2028 early-close rows, and moves the maintainer note to “after 2028”.

## Plan alignment

Planned functionality landed in the three named files. Approach matches the architecture: hardcoded `Set<String>` + `earlyCloses` map, no holiday API.

One wording drift: the plan said “same ET helper style as `test2027GoodFridayIsClosed`” (inline `DateComponents`). The new tests use `EasternTestDates`. That is a considered improvement, not a shortcut — the same helper already drives the later early-close and `lastMarketClose` cases in this class, and it keeps timezone construction in one place. Confirming it was deliberate is unnecessary; do not rewrite them to the older inline form.

## File organization

No new files or types. 2028 rows sit after the 2027 rows in both tables. Five small tests were inserted after `test2027GoodFridayIsClosed` and before the next-open / last-close block. Docs edits stay inside the existing Market holidays / Early closes section.

## Tests

Coverage matches the behavior that matters for this task: the first 2028 miss (MLK), the published “no observed New Year’s” rule, Good Friday, Independence Day, and both 2028 early-close afternoons. Untested 2028 rows (Presidents’ Day, Memorial Day, Juneteenth, Labor Day, Christmas) match the existing 2026–2027 style — spot checks plus a static table, not a date-per-test matrix. `isMarketOpen` is the right assertion; 2026 tests already pin `currentSession` / `regularCloseDate` on the shared early-close map.

## Clarity and patterns

Names read as calendar facts (`test2028HasNoObservedNewYearsClose`, `test2028July3EarlyClose`). Comments on the new early-close keys follow the existing “day after Thanksgiving” / “day before Independence Day” style. Year-range comments moved to 2026–2028. Lookup path is unchanged: `dayKey` → set/map. Pure, no I/O, no persistence.

## Next-request / round-trip

N/A. `isHoliday` and `regularCloseMinutes` are compiled-table lookups. The same instant always yields the same 2028 closed / early-close answer. 2029 remains a maintainer pass, as ARCHITECTURE already says.

## Assessment

Ready to merge on quality. Organization, tests, naming, and surrounding patterns are sound. 2026–2027 rows were not rewritten.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":null,"verdict":"approved","round":1,"findings":[]}
```

VERDICT: APPROVED

## Reviewed files

- Muskometer/Services/MarketHoursService.swift
- MuskometerTests/MuskometerTests.swift
- docs/ARCHITECTURE.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-2-description.md
- docs/marshal/plans/2026-08-17-holdings-surface-refresh/reviews/.tmp-task-2-summary.md

reviewed-content-sha256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

plan-graph-sha256: ae014630f4ddc5c26f9bf07a365c8ba9ae27e7e8bfed4ac7589d129073e57130
