# P2_ROADMAP_TEMPLATE — ROADMAP.md (Phases Only)

ROADMAP.md limits: <= 100 lines, ~400 tokens. YAML in codefence.

Shift: old = tracks with steps/deliverables. new = phases with goals + success_criteria + requirement references. No task-level detail.

Exact schema (verbatim):
```yaml
# ROADMAP.md — {project_name}
roadmap:
  version: "<version>"
  goal: "<strategic goal>"

  phases:
    - id: <N>
      name: "<phase name>"
      goal: "<what this phase delivers>"
      depends_on: [<phase_ids>]
      requirements: ["<REQ-ID>", "<REQ-ID>"]
      success_criteria:
        - "<observable behavior — feeds verify.sh + P9>"
      estimated_tracks: <N>
      status: "not_started|in_progress|complete|deferred"

  progress:
    total_phases: <N>
    completed: <N>
    current_phase: <N>

  risks:
    - "<project-level risk>"

  definition_of_done:
    - "<overall completion criteria>"
```

Guidance:
- Phase structure: phases only. tracks are JIT later (P3/P4). no steps/tasks/deliverables here.
- success_criteria: observable, testable; feeds verify.sh + P9. avoid subjective phrasing.
- requirements: must be valid REQUIREMENTS.md IDs; keep bidirectional traceability.
- depends_on: list earlier phase IDs; keep ordering acyclic and explicit.
- progress: total/completed/current reflect real status; update as phases move.
- risks: project-level, not task-level; keep concise.
- definition_of_done: global completion, not phase-specific.

Field notes (every field):
- roadmap: root object.
- version: roadmap format/version string.
- goal: strategic objective for the entire roadmap.
- phases: ordered list of phase objects.
- id: integer phase identifier.
- name: short phase label.
- goal: outcome delivered by the phase.
- depends_on: list of prerequisite phase ids.
- requirements: list of REQUIREMENTS.md IDs mapped to this phase.
- success_criteria: observable pass/fail statements for the phase.
- estimated_tracks: count of expected tracks (rough, planning only).
- status: one of not_started|in_progress|complete|deferred.
- progress: summary block.
- total_phases: count of phases defined.
- completed: number of phases complete.
- current_phase: active phase id.
- risks: project-level risks affecting roadmap.
- definition_of_done: overall completion criteria for the project.

Example ROADMAP.md:
```yaml
# ROADMAP.md — deadfish-cli
roadmap:
  version: "0.2"
  goal: "Reliable autonomous cycle from spec to verified output"

  phases:
    - id: 1
      name: "Foundation"
      goal: "Core pipeline components run end-to-end"
      depends_on: []
      requirements: ["CLI-01", "PIPE-01", "STATE-01"]
      success_criteria:
        - "ralph.sh completes a single cycle with exit 0"
        - "verify.sh emits valid JSON for a sample task"
      estimated_tracks: 2
      status: "in_progress"

    - id: 2
      name: "Orchestration"
      goal: "Phase/track selection and loop control are stable"
      depends_on: [1]
      requirements: ["ORCH-01", "LOOP-01"]
      success_criteria:
        - "Phase transitions update STATE.yaml consistently"
        - "Stuck detection triggers replan after threshold"
      estimated_tracks: 2
      status: "not_started"

  progress:
    total_phases: 2
    completed: 0
    current_phase: 1

  risks:
    - "Model variability causes non-deterministic outputs"
    - "Permission differences prevent artifact writes"

  definition_of_done:
    - "All phase success criteria verified"
    - "README quickstart completes without manual fixes"
```
