# Task 03: Create 6 shared skills

Create skill files in `/tank/dump/DEV/deadfish-teams/skills/`. Skills encode deadfish invariants and output schemas. Agents reference them via `skills:` frontmatter — update one skill, all agents improve.

## File 1: `skills/deadfish-core/SKILL.md`

```markdown
---
name: deadfish-core
description: Core deadfish invariants and protocols. Referenced by all teammates.
---

# deadfish-core — Universal Invariants

## The Rule
If it's real work, it exists as a Task. If it's not a Task, it's chatter.

## Invariants (NEVER VIOLATE)
1. **Only Coder touches src/**. All other roles are read-only on source code.
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

Types: `SPEC`, `PLAN`, `TASK`, `VERDICT`, `CONDUCTOR`, `DOCSYNC`, `IMPLEMENT`, `INTEGRATE`

## Task Naming
```
{track_id}-P{phase}-T{NN}-{action}
```
Examples: `auth-P1-T01-setup`, `auth-P1-T02-jwt`, `auth-P1-BOUNDARY`

## Escalation Ladder
1. Coder retry (automatic, max 2)
2. Conductor stuck arbitration
3. Replan task
4. Replan track
5. ESCALATE to human

## Communication
- Keep messages to Lead SHORT: paths + decisions + unknowns.
- Lead only reads: Task Graph, Verdicts, Summaries. Never logs or diffs.
```

## File 2: `skills/deadfish-planning/SKILL.md`

```markdown
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
```

## File 3: `skills/deadfish-verify/SKILL.md`

```markdown
---
name: deadfish-verify
description: Verification protocol, criteria rubric, verdict format.
---

# deadfish-verify — Verification Protocol

## Order of Operations
1. **Deterministic gate** (verify.sh) — always first
2. **LLM criteria fan-out** — only if DET passes
3. **Aggregate** (build-verdict.py)

## verify.sh
```bash
bash bin/verify.sh --project-dir <path> --task-file <task.md>
```
Checks: tests, linter, diff budget (≤3x ESTIMATED_DIFF), blocked files, secrets, git clean.
Output: structured JSON. Exit 0 always (result in JSON `pass` field).

## Criteria Rubric (for LLM-tagged ACs)
Three levels — ALL must pass:
- **EXISTS**: Artifact appears in the diff
- **SUBSTANTIVE**: Real code, not TODO/stub/placeholder
- **WIRED**: Connected into the system (import/export/route/config/DI/CLI)

## Bias
False negatives are acceptable. False positives are expensive. If uncertain: FAIL.

## Verdict Sentinel

    ```deadfish:VERDICT
    scope: TASK
    task_id: auth-P1-T02
    verify_sh: PASS
    criteria:
      - id: AC-01
        status: PASS
        evidence: "src/auth/jwt.ts exports generateToken, imported in src/auth/index.ts"
      - id: AC-03
        status: FAIL
        evidence: "no error handling for expired tokens"
    decision: FAIL
    fix_forward:
      - "Add try/catch in jwt.ts:generateToken for TokenExpiredError"
    ```

## Build Verdict Aggregation
```bash
echo "$verdicts_json" | python3 bin/build-verdict.py
```
Output: PASS (all YES) | FAIL (any NO) | NEEDS_HUMAN (parse error)

## Track-Level QA (P10)
6 categories: C0 Scope, C1 Docs, C2 Consistency, C3 Architecture, C4 Completeness, C5 Safety.
Never set C*=FAIL without ≥1 MAJOR+ finding (R2 rule).
```

## File 4: `skills/deadfish-implement/SKILL.md`

```markdown
---
name: deadfish-implement
description: Implementation constraints, git conventions, Codex MCP usage.
---

# deadfish-implement — Implementation Protocol

## Hard Constraints
- Only modify files listed in TASK.FILES. Need a new file? Stop and ask Lead.
- Follow TASK.COMMANDS exactly.
- Run bin/verify.sh before reporting completion.
- Maximum 3 fix cycles per task. On failure, produce failure report and stop.
- Single commit per task: `"{task_id}: {short title}"`

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
```

## File 5: `skills/deadfish-docs/SKILL.md`

```markdown
---
name: deadfish-docs
description: Living docs format, budgets, significance gate.
---

# deadfish-docs — Living Documentation

## 7 Living Docs (in `docs/living/`)

| Doc | Budget (chars) | Content |
|-----|---------------|---------|
| TECH_STACK.md | 3200 | Languages, frameworks, deps, versions |
| PATTERNS.md | 3200 | Architecture patterns, conventions, idioms |
| PITFALLS.md | 2800 | Known gotchas, footguns, anti-patterns |
| RISKS.md | 2000 | Security, operational, business risks |
| PRODUCT.md | 2800 | Features, API surface, user-facing behavior |
| WORKFLOW.md | 2800 | CI/CD, scripts, deployment, dev workflow |
| GLOSSARY.md | 2000 | Domain terms, abbreviations, naming |
| **Total** | **~18800** | |

## Scratch Buffer
`docs/living/.scratch.yaml` — observations not yet significant enough for a doc update:
```yaml
- task: auth-P1-T02
  doc: PATTERNS
  entry: "JWT uses RS256 with rotating keys"
  timestamp: 2026-02-06T10:30:00Z
```

## Significance Triggers
Only update docs when:
- manifest/lockfile changed
- diff_lines ≥ 120
- New CLI/script/CI artifact
- retry_count > 0 (unexpected complexity)
- Scope drift detected
- New architectural pattern
- Breaking change

## Actions
- **NOP**: No new information
- **BUFFER**: Minor observation → scratch buffer
- **UPDATE**: Significant → edit doc
- **FLUSH**: Track-end → flush buffer + reconcile all 7 docs

## Docsync Sentinel

    ```deadfish:DOCSYNC
    action: UPDATE
    touched_docs:
      - docs/living/PATTERNS.md
    summary: "Added JWT RS256 pattern with key rotation notes"
    ```

## Budget Enforcement
If doc exceeds 80% of budget → compress before commit. Prefer edits over expansion.
```

## File 6: `skills/deadfish-conductor/SKILL.md`

```markdown
---
name: deadfish-conductor
description: Conductor verdict format, drift protocol, boundary evaluation.
---

# deadfish-conductor — Boundary Evaluation Protocol

## Responsibilities
1. **Plan evaluation**: Is the plan valid, achievable, correctly sized?
2. **Drift check**: base_commit ≠ HEAD → assess impact on planned tasks
3. **Boundary evaluation**: Did implementation match spec? Do remaining tracks need adjustment?
4. **Stuck arbitration**: Coder failed 2x → diagnose root cause
5. **Direction reassessment**: At roadmap phase boundaries, challenge assumptions

## State File: `conductor-state.md`
Maintain at project root. Rotate (archive + fresh) at roadmap phase boundaries.

```markdown
# Conductor State

## Current Phase
phase: {name}
plan_base_commit: {sha}

## Drift Log
| Track | Task | Drift Type | Resolution |

## Deviation Log
| Track | Deviation | Impact | Captured In |

## Stuck Log
| Track | Task | Attempts | Diagnosis | Resolution |

## Direction Assessment
Last evaluated: {timestamp}
Confidence: high|medium|low
Notes: {free text}
```

## Verdicts
Always return exactly one of:
- **CONTINUE**: Plan is valid, proceed
- **ADAPT**: Plan valid but bindings/tasks need remap (specify what)
- **REPLAN**: Spec/plan needs rewrite (explain why)
- **ESCALATE**: Human decision needed (explain what's unclear)

## Conductor Sentinel

    ```deadfish:CONDUCTOR
    decision: CONTINUE
    because:
      - "All file paths still valid post-drift"
      - "Interface changes are additive only"
    recommended_changes: []
    risks_if_ignored: []
    ```

## Style
Blunt, specific, no poetry. If acceptance criteria are wrong or missing: REPLAN.
```

## Commit

```bash
cd /tank/dump/DEV/deadfish-teams
mkdir -p skills/deadfish-core skills/deadfish-planning skills/deadfish-verify skills/deadfish-implement skills/deadfish-docs skills/deadfish-conductor
# (files already written above)
git add skills/
git commit -m "feat: 6 shared skills encoding deadfish invariants

deadfish-core: universal invariants + sentinel format
deadfish-planning: spec/plan/task packet formats + GSD rules
deadfish-verify: verification protocol + criteria rubric + verdict
deadfish-implement: implementation constraints + Codex MCP + git
deadfish-docs: living docs format + budgets + significance gate
deadfish-conductor: boundary eval + drift + stuck arbitration"
```

## Acceptance Criteria
- DET: 6 directories exist under skills/ (deadfish-core, deadfish-planning, etc.)
- DET: Each contains a SKILL.md file
- DET: deadfish-core/SKILL.md contains "If it's real work, it exists as a Task"
- DET: deadfish-verify/SKILL.md contains "EXISTS", "SUBSTANTIVE", "WIRED"
- DET: deadfish-docs/SKILL.md contains budget table with 7 docs
- DET: git commit created
