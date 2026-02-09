# P2_REQUIREMENTS_TEMPLATE — REQUIREMENTS.md

REQUIREMENTS.md (<= 120 lines, ~500 tokens).

Schema (verbatim):
```yaml
# REQUIREMENTS.md — {project_name}
requirements:
  defined: "<YYYY-MM-DD>"
  core_value: "<from PROJECT.md>"

  v1:
    - id: "<CAT>-<NN>"
      category: "<category name>"
      text: "<user-centric, testable requirement>"
      phase: <phase_number>
      status: "pending|in_progress|complete|blocked"
      acceptance:
        - type: "DET|LLM"
          criterion: "<testable acceptance criterion>"

  v2:
    - id: "<CAT>-<NN>"
      category: "<category>"
      text: "<deferred requirement>"

  out_of_scope:
    - feature: "<excluded feature>"
      reason: "<why excluded>"

  coverage:
    total_v1: <N>
    mapped: <N>
    unmapped: <N>
```

Key design principles:
1. IDs are stable — `AUTH-01` never changes meaning. New requirements get new IDs.
2. Categories derived from domain — P2 brainstorm organizes ideas into themes → themes become categories.
3. Acceptance criteria are pre-tagged — DET:/LLM: prefix assigned at P2 time, inherited by all downstream plans.
4. Traceability is bidirectional — requirement → phase (in REQUIREMENTS.md) AND phase → requirements (in ROADMAP.md).
5. Coverage audit — `coverage` section ensures every v1 requirement maps to a phase. Unmapped = gap.

Rules:
- ID format: `CAT-NN` (uppercase CAT, two digits). IDs never reused or renumbered.
- Category derivation: use brainstorm themes; keep names stable across v1/v2.
- DET vs LLM tagging: acceptance.type is `DET` or `LLM` only; pre-tag at P2; downstream inherits.
- Phase traceability: every v1 item has `phase`; ROADMAP phases list these IDs.
- Coverage audit: `total_v1` = count of v1; `mapped` = v1 with phase; `unmapped` = total_v1 - mapped.
- Status lifecycle: pending → in_progress → complete → blocked (only advance on phase start / criteria pass / external block).

Field notes:
- requirements: root object.
- requirements.defined: date requirements set.
- requirements.core_value: from PROJECT.md.
- requirements.v1: must-ship list.
- requirements.v1[].id: stable ID, `CAT-NN`.
- requirements.v1[].category: category label.
- requirements.v1[].text: user-centric, testable statement.
- requirements.v1[].phase: roadmap phase number.
- requirements.v1[].status: lifecycle status.
- requirements.v1[].acceptance: list of criteria.
- requirements.v1[].acceptance[].type: `DET` or `LLM`.
- requirements.v1[].acceptance[].criterion: testable criterion.
- requirements.v2: deferred list.
- requirements.v2[].id: stable ID, `CAT-NN`.
- requirements.v2[].category: category label.
- requirements.v2[].text: deferred requirement.
- requirements.out_of_scope: explicit exclusions.
- requirements.out_of_scope[].feature: excluded feature.
- requirements.out_of_scope[].reason: exclusion rationale.
- requirements.coverage: coverage audit summary.
- requirements.coverage.total_v1: count of v1 requirements.
- requirements.coverage.mapped: count of v1 with phase mapping.
- requirements.coverage.unmapped: unmapped v1 count.

Example REQUIREMENTS.md:
```yaml
# REQUIREMENTS.md — deadfish-cli
requirements:
  defined: "2026-01-31"
  core_value: "Single-command pipeline run with verified outputs"

  v1:
    - id: "CLI-01"
      category: "CLI"
      text: "User can run the full pipeline with a single command on macOS and Linux"
      phase: 1
      status: "pending"
      acceptance:
        - type: "DET"
          criterion: "ralph.sh exits 0 after a full cycle on a fresh repo"
        - type: "LLM"
          criterion: "README-based setup-to-first-run takes ≤5 minutes for a new user"

    - id: "PIPE-01"
      category: "PIPE"
      text: "Verification produces a machine-readable report per run"
      phase: 1
      status: "pending"
      acceptance:
        - type: "DET"
          criterion: "verify.sh writes verdict JSON to .deadf/verdict.json"

  v2:
    - id: "ORCH-01"
      category: "ORCH"
      text: "Interactive phase selection UI"

  out_of_scope:
    - feature: "Windows support"
      reason: "Non-goal for v1 due to tooling and CI limits"

  coverage:
    total_v1: 2
    mapped: 2
    unmapped: 0
```
