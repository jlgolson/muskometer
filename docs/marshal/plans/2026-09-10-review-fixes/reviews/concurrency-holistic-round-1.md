# Concurrency advisory — holistic round 1

Advisory review of the current corrective plan/spec and the actual notification, record and view-model source. No prior verdicts were consulted.

The plan addresses the concrete actor-reentrancy problems present in the source: threshold state held across `await`, summary claims confused with terminal skips, unconditional pending-day consumption, and sample/milestone updates after summary delivery. Task 3 defines pre-suspension reservations, identity/version completion rules, distinct `inFlight`, matching acknowledgement and lifecycle invalidation; Task 5 depends on it and verifies the actual caller under controlled interleavings.

The planned one-at-a-time SEC task, weak ownership, cancellation, generation checks and restart-handle identity cover the existing polling/SEC coupling. Its tests include canceled services that finish late, count changes during quotes, consecutive days and sleeper cancellation. The spec prohibits an unbounded queue of refresh side effects; per-preset state, one holdings task and the existing sample cap have explicit verification owners. The final review must check these implementation properties against the gated tests, rather than infer safety from `@MainActor` alone.

Task 1 isolates writable test files and project registration before fan-out; Task 5 waits for Task 3's APIs and Task 6 joins all production changes. No additional blocking concurrency requirement is missing from this scope.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"73ff9b02-3d25-4ba8-9ca1-bb963e401a5d-task-0","round":1,"verdict":"APPROVED","findings":[]}
```

## Findings

None.

VERDICT: APPROVED
