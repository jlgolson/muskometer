# Popover visual correction — correctness review

Author: Codex reviewer `/root/popover_spec_review`
Reviewed SHA: `4a1b9bb1126458125ed4eb02ab9fb4b128e28576`
Reviewed artifact: `docs/marshal/specs/2026-09-10-popover-visual-correction-design.md`
Dispatch: `0a5fc4d5-8513-4cb9-a98b-f40be3dede2c-task-0`

The specification is feasible, bounded, and ready for implementation planning. The existing main view places parity after records and stock cards, and the current chart explicitly includes zero in its domain; both observed causes match the source. Moving the methodology into the existing Holdings tab and prioritizing parity are compatible with the current view structure. The permitted spacing and metric-row adjustments provide room for the taller plot at the smallest required height.

Preserve the explicit requirement to verify the complete parity heading and implied price in the initial viewport. The current hosted regression proves scrollability and footer reachability only, so the required first-viewport evidence closes the actual coverage gap. Asset-backed captures, comparison with the user's before image, and independent inspection of the after images make the visual outcome demonstrable. The shared share-card surface, zero crossings, constant and single-point series, monetary scale context, and preservation of timestamps are all addressed.

The risk section identifies the relevant regressions and assigns concrete validation. `## Deferred` correctly contains `None.`. `## Scale & Validation` gives an appropriate in-scope strategy for a maximum of 400 samples and finite bounded coordinates; the change introduces no additional data or network work. The named shared launcher corroborates the stated app-lifecycle and serialized-test requirements. No blocking ambiguities or missing capabilities were found. This is a static specification review; no app launches, builds, or tests were performed.

## Findings

None.

## Findings (machine-readable)
<!-- MARSHAL_FINDINGS_JSON v1 -->
```json
{"schema_version":1,"dispatch_id":"0a5fc4d5-8513-4cb9-a98b-f40be3dede2c-task-0","verdict":"approved","round":1,"findings":[]}
```


reviewed-content-sha256: 9f8abc106b8008600b4f1eaf5d3d6ed7d2ab055ccbe18e15b0d5285e334c40d2

VERDICT: APPROVED
