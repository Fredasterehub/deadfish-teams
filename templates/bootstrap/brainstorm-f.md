# Seed Docs Writer

If any target file already exists, ask once whether to overwrite or draft updates.

Write codefenced YAML for these artifacts:
- `docs/design/VISION.md`
- `docs/design/PROJECT.md`
- `docs/design/REQUIREMENTS.md`
- `docs/design/ROADMAP.md`
- `docs/design/BOOTSTRAP_TASKLIST.md`

Also write markdown for:
- `conductor-state.md`

## Output Skeletons

`VISION.md`
```yaml
vision:
  problem:
    why: "<why now>"
    pain: ["<pain 1>", "<pain 2>"]
  solution:
    what: "<one-sentence pitch>"
    boundaries: "<scope boundaries>"
  users:
    primary: "<target user>"
    environments: ["<env1>", "<env2>"]
  differentiators:
    - "<differentiator>"
  mvp_scope:
    in:
      - "<in-scope item>"
    out:
      - "<out-of-scope item>"
  success_metrics:
    - "<observable outcome>"
  non_goals:
    - "<explicit non-goal>"
```

`PROJECT.md`
```yaml
project:
  name: "<project name>"
  description: "<2-3 sentence current truth>"
  core_value: "<single must-work workflow>"
  constraints:
    - type: "tech|timeline|budget|dependency|compatibility"
      what: "<constraint>"
      why: "<rationale>"
  context: |
    <background and known conditions>
  key_decisions:
    - decision: "<choice made>"
      rationale: "<why>"
      outcome: "pending|good|revisit"
      date: "<YYYY-MM-DD>"
  assumptions:
    - "<assumption>"
  open_questions:
    - "<open question>"
```

`REQUIREMENTS.md`
```yaml
requirements:
  defined: "<YYYY-MM-DD>"
  core_value: "<from PROJECT.md>"
  v1:
    - id: "<CAT>-<NN>"
      category: "<theme>"
      text: "<user-centric, testable requirement>"
      phase: <phase_number>
      status: "pending|in_progress|complete|blocked"
      acceptance:
        - id: "AC-01"
          type: "DET|LLM"
          criterion: "<testable criterion>"
  v2:
    - id: "<CAT>-<NN>"
      category: "<theme>"
      text: "<deferred requirement>"
  out_of_scope:
    - feature: "<excluded feature>"
      reason: "<reason>"
  coverage:
    total_v1: <N>
    mapped: <N>
    unmapped: <N>
```

`ROADMAP.md`
```yaml
roadmap:
  version: "<version>"
  goal: "<strategic goal>"
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

`BOOTSTRAP_TASKLIST.md`
```yaml
task_bootstrap:
  selected_track:
    track_id: "<lowercase slug>"
    track_name: "<human-readable name>"
    status: "selected"
  candidate_tracks:
    - track_id: "<slug>"
      rationale: "<why now>"
  initial_tasks:
    - task_id: "<track>-P1-T01"
      title: "<task title>"
      acceptance_ids: ["AC-01"]
      files:
        - path: "<repo path>"
          action: "add|modify|delete"
          rationale: "<why>"
      commands:
        - "bash bin/verify.sh --project-dir . --task-file tracks/<track>/TASKS/<task>.md --mode pre-commit"
  conductor_checkpoints:
    - trigger: "phase_boundary"
      expected_output: "deadfish:CONDUCTOR"
  docsync_handoffs:
    - trigger: "task_pass_verification"
      touched_docs:
        - "docs/living/PATTERNS.md"
        - "docs/living/WORKFLOW.md"
```

`conductor-state.md`
```markdown
# Conductor State

## Current Phase
phase: <phase name>
plan_base_commit: <7-40 hex sha>

## Drift Log
| Track | Task | Drift Type | Resolution |
|---|---|---|---|

## Deviation Log
| Track | Deviation | Impact | Captured In |
|---|---|---|---|

## Stuck Log
| Track | Task | Attempts | Diagnosis | Resolution |
|---|---|---|---|---|

## Direction Assessment
Last evaluated: <ISO-8601>
Confidence: high|medium|low
Notes: <brief status>
```

After drafting, ask for approval before final write.
