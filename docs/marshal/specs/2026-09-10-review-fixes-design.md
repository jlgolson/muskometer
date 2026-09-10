---
slug: 2026-09-10-review-fixes-design
date: 2026-09-10
---

# Muskometer review fixes

## Intent and scope

Fix all twelve issues reproduced in the September 10 full-codebase review of b4ff901. The user explicitly approved that concrete scope and the proposed remedies with “might as well go fix 'em all!” after receiving the report. This is a corrective change to the existing application, with no new external services or product features. That existing authorization covers ordinary implementation choices; do not add a redundant approval pause.

The original report and executable reproductions are at `/Users/jlgolson/grok/muskometer/build/review-2026-09-10/`. The current baseline passes 248 tests, typecheck, Release build, and entitlement checks.

## Ownership correctness (findings 1–3)

Preserve complete holdings across partial Form 4 reports, use effective transaction dates rather than submission order, and preserve valid zero balances. Form 4 reports changes by security class and distinguishes transaction and amendment dates: https://www.sec.gov/files/form4.pdf. Live SPCX XML reviewed for this change has a February periodOfReport but transactions through June, so periodOfReport alone is not a valid last-balance timestamp.

The ownership synchronization boundary continues returning `HoldingsSyncResult.sharesBySymbol`; AppSettings' existing all-expected-symbol completeness policy remains. Internally use a verified, dated baseline and dated ownership buckets. Prefer an explicit bundled baseline derived from the existing verified full Form 4 over guessing completeness from the presence of Class A/B. Overlay only recognized, unambiguously dated later changes; unchanged classes/trusts/options survive. Amendments correct the corresponding historical effective date, and cannot displace later observations. Where ambiguity, unsupported securities, missing dates, conflicting same-day data, or scan truncation prevents a complete reliable result, omit that symbol and preserve the user's prior whole holding rather than inventing a number.

Zero and absent data are different. A recognized zero balance replaces its bucket, including full disposal; unrecognized securities alone must not produce zero. Use checked integer conversion/arithmetic and preserve the existing option/preferred-share interpretation for verified fixtures. Store only bounded current bucket state, not an ever-growing filing history. Keep SEC requests rate-limited, cancellable, and bounded. Preserve the currently verified live defaults (TSLA 710,172,677; SPCX 5,116,475,230) when the same source observations are supplied.

## Outstanding facts (finding 12)

SEC companyfacts contains whole-entity facts: https://www.sec.gov/search-filings/edgar-application-programming-interfaces. Retain accession/form identity when choosing the latest eligible period and filing. A same-day original and amendment reporting 100 must yield 100, not 200. Duplicate identical totals are harmless; conflicting ambiguous totals return no result rather than being summed. Keep existing preferred-form/concept rules and positive, finite, representable integer validation. No ownership/count/provenance keys are conflated.

## Notification and refresh ordering (findings 4–6)

Accept quote snapshots with the existing generation protection. Commit all synchronous chart, milestone, and record state before the first notification await. No older async completion may append samples, regress the milestone zone, or overwrite newer threshold observations. Evaluate all enabled thresholds before awaiting deliveries, reserve each crossing before suspension, and complete delivery with identity/version checks. A failed crossing must remain retryable while the latest observation is still beyond that threshold; a below-threshold observation rearms it, and a later distinct crossing must survive an older completion. Cover multiple presets, consecutive above-threshold updates, failure interleavings, reset, and day rollover. Do not accumulate an unbounded queue of per-refresh tasks.

Distinguish an in-flight day-close delivery from a terminal skip. Only confirmed delivery, prior confirmed delivery, or an intentional disabled-feature skip consumes pending work. Acknowledge the specific pending day that was delivered; never remove a newer pending day. Preserve existing persisted records/threshold settings and backward decoding of existing state. Cancellation/reset must invalidate outstanding completion tokens.

## Refresh scheduling and close finalization (findings 7–8)

Start quote polling immediately with current stored/bundled holdings. Run at most one independent SEC synchronization task per view model, on its existing daily/backoff cadence. A slow or failing SEC endpoint cannot stall initial quotes or regular quote polling. Accepted ownership changes trigger at most one quote recomputation/refetch, and quote completion must use current holdings or be rejected if superseded. Stop cancels owned tasks and invalidates outstanding results; restart must not let old completions clear or overwrite new work.

Separate trading-clock advancement from receiving successful quotes. At session close or first post-close wake, finalize any real in-session record from its last observed regular sample even if Yahoo fails; do not create synthetic zero samples or claim the stale price is a newly received closing price. Keep the quote timestamp, stale status, and current session status distinct. Day-close text must make the last-observed nature/time clear when using that record.

Make one closing quote attempt when transitioning out of a previously observed regular session; allow at most one extra bounded retry for a transient closing failure, and avoid polling continuously overnight. Notification failures keep a durable pending day for subsequent retry; bounded off-market notification retry is allowed, but must not create a rapid or indefinite loop. Wake scheduling still refreshes promptly at the next regular open and respects early closes, holidays, and cancellation. Inject a sleeper/clock where needed so tests cover the real loop without waiting minutes.

## Popover and login state (findings 9–10)

The default populated main popover measured 360×1,002 points in an ImageRenderer and NSHostingView probe. Bound its height to the available screen and provide a scrolling region for expanding content, with header/footer actions reachable. Preserve normal width, share/settings routes, and accessibility. Test constrained heights of 600, 700, 800, and 900 points against the actual SwiftUI view; also keep embedded Settings reachable within the same screen constraint.

Expose the full relevant login-service status (not registered, enabled, requires approval, unavailable). Pending approval means already registered; repeated registration can throw. Evidence is Apple's installed macOS SDK SMAppService.h, and https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum/requiresapproval plus https://developer.apple.com/documentation/servicemanagement/smappservice/register(). Reopening Settings/activating/relaunching with a desired pending item must preserve the preference and not call register again. Approval subsequently becomes enabled without being unregistered. Explicit user disable still unregisters a pending/enabled item. Surface real registration errors without mutating unrelated system preferences. Tests use a documented-behavior mock; do not alter actual login items.

## Calendar (finding 11)

Remove December 31, 2027 from full holidays and update the conflicting test/docs. NYSE says no New Year's holiday is observed for Saturday January 1, 2028: https://www.nyse.com/trade/hours-calendars. Verify that December 31 is regular at 11 AM ET and the next regular opening after its close is January 3, 2028. Preserve the other 2026–2028 holidays and early closes.

## Tests and integration

Move existing tests into a small number of subsystem files without changing assertions first, preserving all 248 baseline tests and shared helpers. This gives independently edited fixes separate test ownership. Add regression tests before production fixes and confirm expected failures; after implementation confirm those tests pass. Use actual source paths with mock external transport/delivery only at the boundary. Verify the full unchanged-source probes against the finished implementation where APIs remain compatible, adapting only the test harness for intentional interface changes.

Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer MUSKOMETER_SKIP_LIVE_YAHOO=1 scripts/verify.sh` in the finished worktree. Run targeted live public-data checks separately and accurately distinguish endpoint availability from deterministic validation. Visually/structurally verify the populated SwiftUI popover at constrained height. Independent final review must account for all twelve findings and any regressions introduced by the fixes. No production deployment or release is part of this task.

## Risks

Ownership identity and temporal completeness are the main domain risks; conservative omission must be limited to genuinely ambiguous inputs, with the normal verified live path remaining useful. Concurrency fixes must preserve retries and avoid hiding races behind skipped observations. Moving tests must not drop discovery or broaden shared mutable fixtures. Clock changes must not relabel a stale quote as fresh or leak tasks after stop. The macOS notification/login boundary is mocked for controlled testing; no claim of real authorization/UI interaction follows from those tests.

## Scale & Validation

Prove bounded SEC scans, bounded current bucket/notification state, one owned holdings task, and cancellation at lifecycle boundaries. Retain the 400-sample cap. Exercise representative live-sized XML/companyfacts inputs, interleaved completions, early closes, and overnight failures. This change does not claim an exhaustive long-duration memory-profile certification.

## Deferred

None.
