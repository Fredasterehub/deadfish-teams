# Roadmap Template (v3)

Target file: `docs/design/ROADMAP.md`

Use this YAML schema:
```yaml
roadmap:
  version: "<version>"
  goal: "<strategic objective>"

  phases:
    - id: 1
      name: "<phase name>"
      goal: "<phase outcome>"
      depends_on: []
      requirements: ["<REQ-ID>"]
      success_criteria:
        - "<observable behavior>"
      estimated_tracks: <N>
      status: "not_started|in_progress|complete|deferred"

  progress:
    total_phases: <N>
    completed: <N>
    current_phase: <N>

  risks:
    - "<project-level risk>"

  definition_of_done:
    - "<completion criterion>"
```

Guidance:
- Use phases only; task granularity belongs in per-track plan/task artifacts.
- Every requirement ID listed in a phase must exist in `REQUIREMENTS.md`.
- Success criteria should be binary or clearly reviewable.
- `estimated_tracks` is planning guidance, not a hard limit.
- Include conductor checkpoints at phase boundaries in your narrative notes or companion bootstrap task list.

Verification alignment:
- Ensure each phase has at least one deterministic success check.
- Deterministic checks should be executable via the normal command path, including `bin/verify.sh` where applicable.

Example:
```yaml
roadmap:
  version: "0.3"
  goal: "Reliable track-based delivery from product intent to verified implementation"

  phases:
    - id: 1
      name: "Foundation"
      goal: "Core planning and verification loop is stable"
      depends_on: []
      requirements: ["PLAN-01"]
      success_criteria:
        - "Planner output parses as valid v3 sentinels"
        - "At least one task passes pre-commit and post-commit verification"
      estimated_tracks: 2
      status: "in_progress"

    - id: 2
      name: "Scale Out"
      goal: "Multiple tracks execute without cross-track drift regressions"
      depends_on: [1]
      requirements: ["OPS-01", "DOC-01"]
      success_criteria:
        - "Conductor decisions remain CONTINUE or ADAPT across active tracks"
      estimated_tracks: 3
      status: "not_started"

  progress:
    total_phases: 2
    completed: 0
    current_phase: 1

  risks:
    - "Task packets may over-scope changes and exceed diff budgets"
    - "Acceptance criteria may be underspecified for complex tracks"

  definition_of_done:
    - "All phase success criteria pass"
    - "Critical v1 requirements are complete or explicitly deferred"
```
