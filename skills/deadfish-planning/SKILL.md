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

```markdown
# {TASK_ID}: {TITLE}

## GOAL
{What this task accomplishes — 1-2 sentences}

## ACCEPTANCE_CRITERIA
- AC-01 (DET): {criterion from SPEC}
- AC-03 (LLM): {criterion from SPEC}

## FILES
- path: src/auth/jwt.ts | action: add | rationale: new JWT module
- path: tests/auth/jwt.test.ts | action: add | rationale: test coverage

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
