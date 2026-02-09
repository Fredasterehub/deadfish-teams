---
name: deadfish-core
description: Core deadfish invariants and protocols. Referenced by all teammates.
---

# deadfish-core — Universal Invariants

## The Rule
If it's real work, it exists as a Task. If it's not a Task, it's chatter.

## Invariants (NEVER VIOLATE)
1. **Only implementers (Coder + Integrator) touch src/**. All other roles are read-only on source code. Doc-keeper writes only to docs/living/.
2. **verify.sh is truth**. Deterministic facts trump LLM judgment. Always.
3. **Acceptance criteria are immutable**. On retry/drift, append context — never weaken.
4. **Self-backpressure**. Coder runs verify.sh before every commit.
5. **No secrets in commits**. .env, .pem, .key, credentials, API keys — never committed.
6. **Tasks are the scheduler**. No external loops, no cron. The shared task list drives all work.

## Sentinel Format
All structured output uses deadfish code fences. Pick the right type and emit valid YAML:

    ```deadfish:TYPE
    key: value
    nested:
      - item
    ```

Types: `SPEC`, `PLAN`, `TASK`, `TRACK`, `ADR`, `VERDICT`, `VERDICT_CRITERION`, `CONDUCTOR`, `DOCSYNC`, `IMPLEMENT`, `INTEGRATE`, `DIAGNOSTIC`

## Task Naming
```
{track}-P{N}-T{NN}
```
Examples: `auth-P1-T01`, `auth-P1-T02`, `billing-P3-T07`

## Escalation Ladder
1. Coder retry (automatic, max 2)
2. Conductor stuck arbitration
3. Replan task
4. Replan track
5. ESCALATE to human

## Communication
- Keep messages to Lead SHORT: paths + decisions + unknowns.
- Lead only reads: Task Graph, Verdicts, Summaries. Never logs or diffs.
