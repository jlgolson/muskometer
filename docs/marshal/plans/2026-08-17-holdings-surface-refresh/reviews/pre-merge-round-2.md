---
main_sha_at_review: 3f22cf5c40f91b8047710e67b685d45e4462c794
branch_tip_sha: 22b2406ba17ee52291ea5d2843bf65c2196dbcbb
reviewed_at: 2026-08-17T20:20:00Z
pr_number: 4
---

# Pre-merge review — round 2

Fresh-eyes whole-PR pass of the 0.1.5 (build 26) holdings-surface refresh against `origin/main` (`3f22cf5…`) and the worktree at the assigned tip. GitHub PR 4 is 22,148 / 5,287 across 153 files (~27.4k combined, under the 50k overflow bar). Product matches Design §§1–7 and the ten-task plan: sellable SPCX ownership, inverted fingerprint remigration, Cursor outstanding bump, NYSE 2028, comparison deleted end-to-end, marketing/docs, unused `currentTSLAPrice` drop, version tick. Write/verify on the three remigration keys is closed (`String(Int64)` persist-if-changed; second init is a no-op). No critical or important defects.

## What's strong

- Calculator counts option titles 1:1 and never adds remarks; June 17 live-shaped fixture returns `5_116_475_230`; dual seeds match.
- Remigration is exact-integer on three disjoint keys; outstanding stays orthogonal to Form 4; comparison is a closed cut.
- Marketing PNGs and HTML mock match §5 (one Copy, 9:30 next-open, parity card, new share counts). Shipping identity is four `0.1.5` / `26` pairs.

## Findings I'd block on (Critical)

None.

## Findings I'd flag but not block on (Important / Minor)

None.

## Findings

None.

## Findings (machine-readable)

<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"1c4db3e7-3540-46aa-8f4e-8794bafb53d3","verdict":"approved","round":2,"role":"pre-merge-reviewer","pr_number":4,"main_sha_at_review":"3f22cf5c40f91b8047710e67b685d45e4462c794","branch_tip_sha":"22b2406ba17ee52291ea5d2843bf65c2196dbcbb","findings":[]}
```

VERDICT: APPROVED

Diff-sha256: 28e40a40866fa60e0213a0fd78712a035f3de140ca767603a9e31002930bec3c
