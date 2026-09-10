# Security advisory — holistic round 1

Advisory review limited to the corrective plan's public-network parsing, local persistence and notification lifecycle boundaries. Reviewed the relevant services and `SECURITY.md`; no unrelated repository security scan was performed. This scope introduces no authentication, secrets, cryptography, inbound listener, remote write API or release operation.

The existing SEC path uses fixed HTTPS origins and an ephemeral session with caching disabled and request/resource timeouts. Its parser currently includes unchecked numeric conversion and arithmetic. Task 2 directly requires rejecting malformed, nonintegral and overflowing values, preserving explicit zero separately from absence, resolving only recognized ownership identities, and keeping reconstruction bounded and cancellable. Ambiguous input must omit the symbol before the existing all-symbol persistence check. The companyfacts changes retain independent outstanding-count provenance and refuse conflicting facts instead of fabricating totals.

Tasks 3 and 5 explicitly invalidate outstanding notification completion identities at reset and stop/restart boundaries, so delayed callbacks cannot recreate cleared notified-day state, consume new pending work or clear replacement claims. Delivery outcomes and matching acknowledgements keep those persistence effects tied to their actual operation. These tokens are local lifecycle identities and do not require an authentication or cryptographic design.

Notification/login tests use controlled boundary mocks, and the integrated verification checks the signed test product's existing entitlements. The plan does not claim those checks certify unsigned distribution artifacts or real system authorization. No additional blocking security requirement is missing from the approved corrective scope.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON -->
```json
{"schema_version":1,"dispatch_id":"73ff9b02-3d25-4ba8-9ca1-bb963e401a5d-task-0","round":1,"verdict":"APPROVED","findings":[]}
```

## Findings

None.

VERDICT: APPROVED
