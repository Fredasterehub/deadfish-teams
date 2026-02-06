# P2_PROJECT_TEMPLATE — PROJECT.md

PROJECT.md (<= 80 lines, ~350 tokens)

Schema (verbatim):
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

Guidance:
- core_value: derive from vision/requirements; one critical workflow; phrased as must-work.
- constraints[].type: use only tech|timeline|budget|dependency|compatibility.
- key_decisions[]: list of objects; outcome in pending|good|revisit; date YYYY-MM-DD.
- Update vs blank: if file exists, update changed facts only, append new constraints/decisions; do not blank fields. For new files, populate all fields; use "TBD" only if blocked.

Field notes:
- project.name: short canonical name.
- project.description: 2-3 sentences; current truth.
- project.core_value: single must-work statement.
- project.constraints[].type: enum only.
- project.constraints[].what: constraint statement.
- project.constraints[].why: rationale.
- project.context: background block; keep current.
- project.key_decisions[].decision: choice made.
- project.key_decisions[].rationale: why chosen.
- project.key_decisions[].outcome: pending|good|revisit.
- project.key_decisions[].date: YYYY-MM-DD.
- project.assumptions[]: unstated truths relied on.
- project.open_questions[]: unresolved items.

Example PROJECT.md:
```yaml
# PROJECT.md — deadfish-cli
project:
  name: "deadfish-cli"
  description: "CLI that runs Deadfish programs from stdin or files. Focused on fast, deterministic output for teaching and scripts."
  core_value: "Given a Deadfish program, produce correct output deterministically."

  constraints:
    - type: "tech"
      what: "Rust 1.75+ only; no external runtime deps."
      why: "Keep the binary small and portable."
    - type: "timeline"
      what: "v1 in 4 weeks."
      why: "Align with course schedule."

  context: |
    Prototype exists in Python; output formatting differs by platform.
    Need unified stdin/file handling and clear error messages.

  key_decisions:
    - decision: "Single binary with run/format subcommands."
      rationale: "Avoid separate tools while keeping UX clear."
      outcome: "pending"
      date: "2026-01-31"

  assumptions:
    - "Most users run on macOS/Linux."
  open_questions:
    - "Do we need Windows support for v1?"
```
