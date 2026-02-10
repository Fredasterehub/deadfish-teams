---
name: deadfish-planning
description: Spec, plan, and task packet formats. GSD rules. Drift detection.
---

# deadfish-planning — Spec + Plan + Task Packets

## GSD Rules (Get Shit Done)
- **Plans-as-prompts**: TASK SUMMARY field IS the implementation prompt. No transformation.
- **Aggressive atomicity**: 2-5 tasks per track, ≤200 diff lines each, ≤5 files per task.
- **Every SPEC AC in exactly one task**: No gaps, no duplicates.
- **Context budget**: files_to_load ≤3000 tokens per task packet.
- **Dependency-change pairing**: If a task changes dependency manifests or lockfiles, that same task packet MUST include `docs/living/TECH_STACK.md` in `## FILES` and update it in-task.

## SPEC Format
Write to `tracks/{track_id}/SPEC.md`:
- Goal + non-goals
- Constraints
- Acceptance Criteria (numbered: AC-01, AC-02...)
- Each AC tagged DET (deterministic, testable) or LLM (requires judgment)
- Edge cases
- Out of scope

## PLAN Sentinel

    ```deadfish:PLAN
    track_id: auth
    base_commit: abc1234
    tasks:
      - id: T01
        title: "Set up auth module"
        depends_on: []
        packet_path: tracks/auth/TASKS/T01.md
      - id: T02
        title: "Implement JWT generation"
        depends_on: [T01]
        packet_path: tracks/auth/TASKS/T02.md
    ```

## Task Packet Format
Write each to `tracks/{track_id}/TASKS/{task_id}.md`:
Use canonical YAML list entries in `## FILES`; do not use pipe-delimited `path: x | action: y` lines.

```markdown
# {TASK_ID}: {TITLE}

## GOAL
{What this task accomplishes — 1-2 sentences}

## ACCEPTANCE_CRITERIA
- AC-01 (DET): {criterion from SPEC}
- AC-03 (LLM): {criterion from SPEC}

## FILES
- path: src/auth/jwt.ts
  action: add
  rationale: new JWT module
- path: tests/auth/jwt.test.ts
  action: add
  rationale: test coverage

## COMMANDS
- npm test
- npm run lint

## SUMMARY
{2-3 imperative sentences. THIS IS the Codex implementation prompt. Be specific.}

## ESTIMATED_DIFF
~80 lines

## RISKS
- {what could go wrong}

## ROLLBACK
- git revert {task commit}
```

## Drift Detection
When `base_commit` from PLAN ≠ current HEAD:
- Check if planned file paths still exist
- Check if interfaces changed
- If cosmetic: CONTINUE (adapt bindings)
- If structural: REPLAN
- Acceptance criteria NEVER change on drift — only bindings adapt.

## Dependency Manifest Guard
When composing `## FILES`, treat dependency manifests/lockfiles as a special planning trigger.

If any task includes a dependency manifest or lockfile (for example `package.json`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `requirements.txt`, `pyproject.toml`, `poetry.lock`, `Pipfile.lock`, `go.mod`, `go.sum`, `Cargo.toml`, `Cargo.lock`):
- include `docs/living/TECH_STACK.md` in the same task packet `## FILES`
- set it to `action: modify`
- state rationale as dependency/version update traceability
- require TASK `## SUMMARY` to explicitly say TECH_STACK is updated in-task
