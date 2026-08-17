# Marshal delivery summary

Plan: `2026-08-17-holdings-surface-refresh`

## Coding vs reviewing split

- Coding (implementer): 2113635.6 ms across 12 dispatch(es)
- Reviewing: 0.0 ms across 0 dispatch(es)

## Real economics

- Total cost (joined from audit log): $0.0000
- Cache hit ratio: 0.0 (0 cache-read / 0 fresh-read tokens)
- no-cache list-price baseline: the 0 cache-read token(s) would be billed at full list input price with caching disabled (counterfactual on real token counts, not a fabrication)
- 12 dispatch(es): usage not captured on Agent-tool path (no audit row — reported as null economics, never $0)

## Catch ledger

Per-gate catches (gates that caught nothing shown with 0):

- `spec-reviewer`: 0 catch(es)
- `code-quality-reviewer`: 0 catch(es)
- `plan-correctness`: 0 catch(es)
- `holistic`: 0 catch(es)
- `execution-holistic`: 0 catch(es)
- `spec-correctness`: 0 catch(es)

- Persisted from prior round: 0
- Unstructured verdicts (no machine-readable sidecar, surfaced not dropped): 0

## Marginal cost of catches

- No critical/important findings caught.

## Concurrency

- Concurrency factor: 0.316 (Σ latency 2113635.6 ms ÷ execution wall-clock 6679.4 s)

_Measured-only: no hours-saved / cost-of-prevention multiplier. The catches plus their real marginal cost are the receipts._
