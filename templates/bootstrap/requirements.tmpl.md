# Requirements Template (v3)

Target file: `docs/design/REQUIREMENTS.md`

Use this YAML schema:
```yaml
requirements:
  defined: "<YYYY-MM-DD>"
  core_value: "<from PROJECT.md>"

  v1:
    - id: "<CAT>-<NN>"
      category: "<stable category>"
      text: "<user-centric, testable requirement>"
      phase: <phase_number>
      status: "pending|in_progress|complete|blocked"
      acceptance:
        - id: "AC-01"
          type: "DET|LLM"
          criterion: "<testable criterion>"

  v2:
    - id: "<CAT>-<NN>"
      category: "<stable category>"
      text: "<deferred requirement>"

  out_of_scope:
    - feature: "<excluded feature>"
      reason: "<reason>"

  coverage:
    total_v1: <N>
    mapped: <N>
    unmapped: <N>
```

Rules:
- IDs are stable and never reused.
- `v1[].phase` must reference an existing phase in `ROADMAP.md`.
- Acceptance types are only `DET` or `LLM`.
- DET criteria should be verifiable using deterministic commands (tests, lint, `bin/verify.sh`).
- Coverage math must be consistent.

Field notes:
- `v1` is must-ship scope for near-term roadmap phases.
- `v2` is explicitly deferred scope.
- `out_of_scope` prevents silent scope creep.

Example:
```yaml
requirements:
  defined: "2026-02-09"
  core_value: "Given a selected track, produce task packets and verified implementations with traceable acceptance criteria."

  v1:
    - id: "PLAN-01"
      category: "Planning"
      text: "Planner emits schema-valid SPEC and PLAN blocks for each selected track"
      phase: 1
      status: "pending"
      acceptance:
        - id: "AC-01"
          type: "DET"
          criterion: "parse-blocks validates planner output against v3 schema without missing keys"
        - id: "AC-02"
          type: "LLM"
          criterion: "SPEC goal, constraints, and acceptance criteria are coherent and implementation-ready"

  v2:
    - id: "UX-01"
      category: "Operator UX"
      text: "Interactive dashboard for track and task status"

  out_of_scope:
    - feature: "Multi-repo orchestration"
      reason: "Not required for first reliable milestone"

  coverage:
    total_v1: 1
    mapped: 1
    unmapped: 0
```
