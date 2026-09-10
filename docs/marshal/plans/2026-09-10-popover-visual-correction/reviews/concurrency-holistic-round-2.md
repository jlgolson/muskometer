# Concurrency advisory review — round 2

Reviewed the complete revised plan at `3226e8b02dba23d0c5fc6a43a4957fa0a41d248b` against concurrency failure classes v1, and inspected the actual application entry point, delegate, launcher and nested test wrapper.

The added compile-time branch excludes production delegate registration, shared settings, service startup and menu-bar construction from hosted tests. The original production declaration matches the planned normal branch. A passing bootstrap assertion gates presentation runs; isolated fixtures remain mandatory. Previously compiled test products cannot be treated as isolated merely by supplying a later flag.

One implementer owns the eight tracked files and narrow wrapper edit. The wrapper preserves serial test hosts, while the unchanged shared lock covers prior-app shutdown and command completion. Conflicting build/test processes refuse launch. The controller creates the normal preview separately only after reviews, preventing reuse of an inert test product.

The presentation changes add no persistent writer, cache publication, job or retry path. No concrete reachable P0/P1 concurrency failure remains within this correction's declared boundaries.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"ca158880-92af-4b45-b3ff-509d39fafc05-task-0","verdict":"approved","round":2,"findings":[]}
```

reviewed-content-sha256: 328e9ad85ce8acba06d583ff49f88031d0888c62aeb164c8a5a9ce8a59b0092d

plan-graph-sha256: f10c3899ca6b0b2dffde07f086ac7df02642f933cad6463065b270c11b6e2037

VERDICT: APPROVED
