---
name: deadfish-implement
description: Implementation constraints, git conventions, Codex MCP usage.
---

# deadfish-implement — Implementation Protocol

## Hard Constraints
- Only modify files listed in TASK.FILES. Need a new file? Stop and ask Lead.
- Follow TASK.COMMANDS exactly.
- Run verify in both phases:
  - Before commit: `bin/verify.sh --project-dir . --task-file <task.md> --mode pre-commit`
  - After commit: `bin/verify.sh --project-dir . --task-file <task.md> --mode post-commit --base-commit <sha>`
- Maximum 3 fix cycles per task. On failure, produce failure report and stop.
- Single commit per task: `"{task_id}: {short title}"`

## Living Docs Hot Exception
- Default rule: do not churn `docs/living/*` during per-task implementation.
- Hot exception (only one): `docs/living/TECH_STACK.md`.
- TECH_STACK may be updated in-task only when it is explicitly listed in `TASK.FILES` (typically alongside dependency manifest/lockfile changes).
- No other living-doc file is allowed as an in-task exception unless Lead explicitly amends the task packet.

## TaskCompleted Hook vs QA Protocol
- "TaskCompleted hook runs `verify.sh` only" refers to hook execution scope, not final QA scope.
- QA order remains:
  1. `verify.sh` deterministic gate
  2. criteria fan-out for acceptance checks
  3. build-verdict aggregation
- Do not treat hook completion as equivalent to a final PASS verdict.

## Codex MCP Usage

Start implementation:
```
Tool: mcp__codex-coder__codex
Parameters:
  prompt: "<TASK SUMMARY verbatim + FILES context>"
  cwd: "/path/to/project"
  sandbox: "workspace-write"
```

Continue if needed:
```
Tool: mcp__codex-coder__codex-reply
Parameters:
  prompt: "Fix: verify.sh reports <failure details>"
  threadId: "<from previous response>"
```

## Implement Sentinel

    ```deadfish:IMPLEMENT
    task_id: auth-P1-T02
    changed_files:
      - path: src/auth/jwt.ts
      - path: tests/auth/jwt.test.ts
    summary: "Added JWT generation with RS256 signing and 15min expiry"
    verify:
      command: "bin/verify.sh"
      result: PASS
    notes: null
    ```

## Retry Protocol
On retry (Lead sends QA feedback):
1. Read verdict + failure details
2. Append retry context AFTER SUMMARY (never replace original)
3. Re-dispatch to Codex with enriched prompt
4. Max 2 retries. After that → Conductor arbitration.

## Integration (Integrator only)

    ```deadfish:INTEGRATE
    why_called: "T02 and T03 both modified src/auth/index.ts"
    changes:
      - "Merged export lists from both tasks"
      - "Resolved import order conflict"
    verify_sh: PASS
    ```
