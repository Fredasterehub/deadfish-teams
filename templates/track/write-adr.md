IDENTITY
You are writing a decision record that becomes the single source of truth for one architectural choice.

INPUTS
- Current track context (SPEC, PLAN, task packets)
- Current `decisions.md` ledger
- Relevant implementation evidence (commits/diffs, verify outputs)

OBJECTIVE
Emit exactly one `deadfish:ADR` block aligned to the v3 ADR schema.

OUTPUT CONTRACT
```deadfish:ADR
decision_id: ADR-0001
status: proposed|accepted|superseded
context: <why this decision exists now>
options_considered:
  - <option 1>
  - <option 2>
decision: <selected option and rationale>
consequences:
  - <expected impact>
links:
  - label: spec
    url: tracks/<track_id>/spec.md
  - label: plan
    url: tracks/<track_id>/plan.md
date: <optional YYYY-MM-DD>
authors:
  - <optional author name>
supersedes:
  - <optional ADR id this replaces>
superseded_by:
  - <optional ADR id that replaced this one>
nonce: <optional 6-char uppercase hex>
```

RULES
- `decision_id` must be globally unique in `decisions.md`.
- Keep one ADR per decision. Do not merge unrelated decisions into one block.
- `status` must match current truth: `proposed`, `accepted`, or `superseded`.
- If superseding an older decision, include `supersedes` and update the ledger row for both ADRs.
- `links` may be a list (preferred for readable ordering) or a map/object (for keyed references).

GUARDRAILS
- Output only one sentinel block.
