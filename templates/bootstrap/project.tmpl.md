# Project Template (v3)

Target file: `docs/design/PROJECT.md`

Use this YAML schema:
```yaml
project:
  name: "<project name>"
  description: "<2-3 sentence current truth>"
  core_value: "<single workflow that must work>"

  constraints:
    - type: "tech|timeline|budget|dependency|compatibility"
      what: "<constraint statement>"
      why: "<rationale>"

  context: |
    <background, prior attempts, known boundaries>

  key_decisions:
    - decision: "<choice made>"
      rationale: "<why this choice>"
      outcome: "pending|good|revisit"
      date: "<YYYY-MM-DD>"

  assumptions:
    - "<assumption>"
  open_questions:
    - "<unresolved item>"
```

Guidance:
- `core_value` should map to at least one requirement in `REQUIREMENTS.md`.
- Constraints should be actionable and tied to later roadmap tradeoffs.
- Keep key decisions durable and factual; avoid speculative prose.
- For updates, preserve historical decisions and append only what changed.

Example:
```yaml
project:
  name: "deadfish-teams"
  description: "Agent-team plugin for turning product intent into verified code changes. Focuses on deterministic verification and narrow task scopes."
  core_value: "Given a selected track, produce task packets and verified implementations with traceable acceptance criteria."

  constraints:
    - type: "tech"
      what: "Shell scripts must run on macOS and Linux."
      why: "Contributors run mixed local environments."
    - type: "dependency"
      what: "Deterministic checks must run through bin/verify.sh."
      why: "Single source of truth for PASS/FAIL gates."

  context: |
    The repo contains agent prompts, sentinel contracts, and orchestration scripts.
    Bootstrap docs need to align with v3 sentinel schemas and task lifecycle.

  key_decisions:
    - decision: "Use deadfish sentinel code fences for structured outputs."
      rationale: "Parser and linter enforce these schemas."
      outcome: "good"
      date: "2026-02-09"

  assumptions:
    - "Planner can split work into atomic tasks under one selected track."
  open_questions:
    - "How many tracks are needed for first end-to-end milestone?"
```
