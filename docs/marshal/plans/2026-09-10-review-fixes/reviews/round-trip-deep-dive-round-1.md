# Persistence round-trip review — round 1

dispatch_id: 1a9289cb-ab5c-4904-9bb8-3f87ccafdf44-task-0
MARSHAL_ROLE: round-trip-deep-dive

Scope: static review of `docs/marshal/plans/2026-09-10-review-fixes.md` and its current record, notification, settings, and view-model source paths. The associated design was read for the intended consumption semantics. No prior reviews or review history were read. This is a plan verdict, not a claim that the proposed implementation or tests already pass. No cryptography or authentication mechanism is involved.

## Round-trip mechanisms and evidence

### Saved threshold state and backward decoding

`GainThresholdNotificationService.swift:29–33,122–143,200–216` currently writes and reads the same JSON shape (`armed`, optional `lastGain`, optional `tradingDayKey`) under one key per person/preset; enabled IDs use a separate sorted string array. Missing or undecodable state falls back to an unobserved threshold. The plan preserves these keys and explicitly requires backward-compatible persisted decoding in Task 3, line 81. Adding runtime claim identities does not require a new persisted schema. If the implementation does persist new retry fields, absent fields in the old JSON must decode to deliberate defaults, rather than sending every old record through the fresh-state fallback.

The existing crossing writes occur after suspension (`GainThresholdNotificationService.swift:98–116`), allowing an older local copy to replace newer persisted observations. Task 3 requires all preset observations/claims before suspension and identity/version-checked completion, including failure/rearm/recross and reset/rollover cases. Task 5, line 119, ensures callers start observation processing in accepted-snapshot order. These are complementary requirements: moving the existing writes alone is insufficient, while the planned retry and identity requirements address that distinction.

### Unfinished records to durable pending day to acknowledgement

`DailyRecordTracker.swift:150–185,204–220,277–329` stores real sample gain/time and extremes, reloads unfinished state, finalizes to a complete `FinalizedTradingDay`, and writes that day under `dailyRecordPendingFinalized_<person>`. The finalized payload already contains the observation time, so Task 3's notification wording change needs no record migration. `DayExtremes.init(from:)` already accepts older payloads without `lastSampleGain`, using `peak` as the compatibility fallback (`50–57`); that decoder must remain intact as required by the preservation goal.

Current consumption removes whichever pending value exists (`DailyRecordTracker.swift:103–107`); the current view-model tail invokes it after awaiting delivery (`GainsViewModel.swift:524–534`). Task 3, line 85, adds equality against the supplied complete finalized value, and Task 5, lines 119 and 123, switches the production path to that acknowledgement. Thus completion of day A cannot delete pending day B in memory or UserDefaults. Equality should be tested through the durable reload as well as through the current instance. Existing relaunch coverage at `MuskometerTests.swift:3840–3858` confirms the underlying peek/store/consume persistence path and is retained by the mechanical test move.

Task 3's `advanceClock` contract explicitly loads unfinished data and forbids artificial samples and day regression (line 86). Task 5 uses it both from the real loop and failure paths (line 123). This connects the durable unfinished record to finalization even when no new quote can be written; existing persisted record and date encodings remain usable.

### Delivery confirmation, reset, stop, and retry

`DayCloseSummaryNotificationService.swift:43–48,68–75` currently conflates an in-flight duplicate with a terminal skip and writes `dayCloseSummaryNotifiedDay_<person>` unconditionally after successful `add`. Its static reset only deletes that key (`79–85`), so it does not invalidate a suspended writer. Task 3, lines 82–83, explicitly separates `.inFlight` from disabled/already-confirmed `.skipped`, creates instance lifecycle invalidation, and prohibits old completions from writing the notified day or clearing a replacement claim.

The actual reset path is synchronous: `SettingsView.performResetToDefaults` calls `AppSettings.resetToDefaults`, then `GainsViewModel.reloadPersistedDisplayState`, before scheduling a refresh (`SettingsView.swift:407–417`). AppSettings deletes the notification, record, sample, and milestone keys (`AppSettings.swift:574–583`). The current display reload resets threshold and record caches but omits day-close service invalidation (`GainsViewModel.swift:445–455`); current `stop` only cancels the refresh task (`140–144`). Task 5, lines 121–122, specifically fixes both call sites and requires a gated old completion released after reset/stop/restart to leave durable state, pending work, and new claims untouched. The service-level token check remains necessary even when the caller cancels because cancellation need not prevent an awaited delivery from returning success.

Runtime invalidation and destructive settings reset are appropriately distinct. Ordinary stop retains the pending finalized payload for subsequent retry; an intentional settings reset deletes it. Per the design, only confirmed delivery, previously confirmed delivery, or intentional disabled-feature skip acknowledges the matching pending payload; `.failed` and `.inFlight` retain it. Task 5 explicitly adopts Task 3's outcome and matching APIs, and depends on Task 3, so there is no caller-before-contract dependency gap.

### Settings persistence and bounded state

Holdings writes already preserve explicit zero: `AppSettings.applyHoldingsSync` accepts nonnegative complete symbol sets (`602–630`), `setShareCount` stores decimal `Int64` strings (`115–118`), and `loadShareCounts` parses them without a positivity filter (`405–435`). Task 2 preserves that acceptance boundary and introduces no bucket-history store. Issuer outstanding uses separate positive-only count/provenance keys (`AppSettings.swift:129–176,438–455`); those are not notification or ownership identities. The login preference is a Boolean loaded at initialization and written through `persistLaunchAtLoginPreference` (`297,512–521`); Task 4 keeps pending desired=true across restart rather than persisting the lossy `isEnabled` interpretation.

The app's profile registry is finite (`TrackedPersonProfile.swift:31`); threshold processing iterates the finite preset list, records retain one unfinished and one pending day per person, and notified-day persistence is one scalar per person. `IntradayGainSampleStore.swift:10,59–65` bounds app-produced sample arrays at 400. Task 3 requires bounded per-preset state; Task 5 owns and invalidates lifecycle tasks; Task 6, line 144, verifies person/preset and sample bounds. Nothing in the plan introduces an accumulating delivery ledger or persistent filing history. Bounds for arbitrary corrupted or externally injected defaults are outside this plan's stated app-produced-state scope.

## Findings

None.

The prescribed mechanisms cover the persistence chains in scope. Implementation review should verify the concrete decoder defaults, retry representation, and token checks against these contracts; their exact representation is properly left to implementation.

VERDICT: CHAIN-SAFE
