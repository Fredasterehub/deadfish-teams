---
name: deadfish-discovery
description: Brownfield discovery protocol (detect, collect evidence, analyze, and write docs/discovery.md).
---

# deadfish-discovery — Brownfield Discovery Protocol

## Goal
Produce a reliable repo snapshot before brainstorming, with deterministic evidence collection and explicit unknowns.

## Workflow
1. **Detect scenario**
   - Run `bin/discover-detect.sh --json`.
   - Scenario is one of `brownfield`, `greenfield`, `returning`.
2. **Collect evidence**
   - For `brownfield` or `returning`, run:
     `bin/discover-collect.sh --project . --depth <n>`
   - Default evidence dir: `docs/discovery/evidence/`.
3. **Analyze evidence**
   - Use only collected artifacts plus direct repo reads.
   - Prefer conservative claims. Mark uncertain items as `unknown`.
4. **Write discovery artifact**
   - Write `docs/discovery.md` with:
     - Scenario + signals
     - Repo snapshot (modules, entry points, tooling)
     - Inferred stack/workflow summary
     - Risks and protected areas
     - Open questions
     - Evidence path index

## Output Template
Use this structure in `docs/discovery.md`:

```markdown
# Discovery Report

## Scenario
- type: brownfield|greenfield|returning
- signals: [...]

## Repo Snapshot
- ...

## Stack and Tooling
- ...

## Risks and Constraints
- ...

## Open Questions
- ...

## Evidence
- docs/discovery/evidence/
```

## Guardrails
- No `STATE.yaml` dependency.
- No source implementation work during discovery.
- Keep handoff to Lead short: scenario, evidence location, unknowns.
