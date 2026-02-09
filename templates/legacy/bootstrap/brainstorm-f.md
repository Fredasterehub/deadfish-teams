# P2_F — Seed Docs Writer (VISION.md + PROJECT.md + REQUIREMENTS.md + ROADMAP.md + STATE.yaml)

If ANY of VISION.md, PROJECT.md, REQUIREMENTS.md, ROADMAP.md, or STATE.yaml already exist, ask once whether to overwrite or write new drafts before writing.

Output five codefenced YAML documents (no extra prose) with line limits:

VISION.md (<= 80 lines):
# Token budget: <=300t
```yaml
vision:
  problem:
    why: "<why this needs to exist>"
    pain: ["<pain point 1>", "<pain point 2>"]
  solution:
    what: "<one-sentence pitch>"
    boundaries: "<explicit scope limits>"
  users:
    primary: "<target user>"
    environments: ["<env1>", "<env2>"]
  differentiators:
    - "<differentiator 1>"
    - "<differentiator 2>"
  mvp_scope:
    in:
      - "<in-scope item>"
    out:
      - "<explicitly excluded>"
  success_metrics:
    - "<observable, verifiable metric>"
  non_goals:
    - "<specific non-goal>"
```

PROJECT.md (<= 80 lines):
```yaml
# PROJECT.md — {project_name}
project:
  name: "<project name>"
  description: "<2-3 sentences, current accurate description>"
  core_value: "<the ONE thing that must work>"

  constraints:
    - type: "<tech|timeline|budget|dependency|compatibility>"
      what: "<constraint>"
      why: "<rationale>"

  context: |
    <Background: tech environment, prior work, known issues.
     Updated as project evolves.>

  key_decisions:
    - decision: "<choice made>"
      rationale: "<why>"
      outcome: "pending|good|revisit"
      date: "<YYYY-MM-DD>"

  assumptions:
    - "<assumption>"
  open_questions:
    - "<unresolved question>"
```

REQUIREMENTS.md (<= 120 lines):
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

ROADMAP.md (<= 100 lines):
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

STATE.yaml (<= 60 lines):
```yaml
# STATE.yaml — initialized by P2, managed by orchestrator
project:
  name: "<project name>"
  core_value: "<from PROJECT.md>"
  initialized_at: "<ISO-8601>"

phase: "select-track"
mode: "yolo"

roadmap:
  current_phase: 1
  total_phases: <N>

track:
  id: null
  name: null
  status: null
  spec_path: null
  plan_path: null

task:
  id: null
  description: null
  sub_step: null
  files_to_load: []
  retry_count: 0
  max_retries: 3
  replan_attempted: false

loop:
  iteration: 0
  stuck_count: 0

last_good:
  commit: null
  task_id: null
  timestamp: null

last_result:
  ok: null
  details: null

budget:
  started_at: null

cycle:
  id: null
  nonce: null
  status: null
  started_at: null
  finished_at: null
```

Ask for approval and apply edits.
