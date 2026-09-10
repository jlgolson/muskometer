# Persistence advisory — round 1

dispatch_id: 1a9289cb-ab5c-4904-9bb8-3f87ccafdf44-task-0
MARSHAL_ROLE: round-trip-deep-dive

The plan is consistent across storage writers, reloaders, reset callers, and delivery acknowledgements. Tasks 3 and 5 jointly address the current races; Task 4 preserves pending login intent using the existing preference key. No blocking persistence gap was found. Detailed evidence is in `round-trip-deep-dive-round-1.md`.

Nonblocking execution guidance for the already required compatibility/retry tests:

- Seed the exact old threshold JSON, including absent optional fields, before constructing the revised service. Also exercise the existing unfinished-record payload without `lastSampleGain`; constructing both writer and reader from revised code alone cannot prove backward decoding.
- After a rejected old-day acknowledgement, construct a fresh tracker with the same isolated defaults suite and verify the newer pending value remains. Verify both pending retention and notified-day absence after reset/stop releases an old delivery.
- If new threshold retry fields are persisted, round-trip a failed crossing and a suspended/unconfirmed crossing through a new service instance. Keep transient claim identity distinct from confirmed delivery so saving observations before suspension does not accidentally suppress a retry after restart.
- Assert unchanged durable data after a stale completion, rather than relying only on an event count or view-model property. Use controlled notification and login boundaries throughout.

This is advisory coverage guidance within the existing plan requirements, not a demand for additional product scope. Static plan/source review only; no implementation or test-pass assertion.

VERDICT: APPROVED
