# deadfish-teams v3: Agent Teams Native Implementation Plan

> **"Only a dead fish follows the flow."** — Autonomous dev pipeline on Claude Code Agent Teams. Four layers, zero Ralph.

---

## Mental Model: 4 Layers

| Layer | What | Lives where |
|-------|------|-------------|
| **State** | Claude Code Tasks + dependencies + status (Ctrl+T) | Native task list, shared via `CLAUDE_CODE_TASK_LIST_ID` |
| **Artifacts** | Track docs, spec, plan, task packets, conductor state, living docs | Git — reviewable, diffable, persistent |
| **Protocol** | Sentinel blocks (`deadfish:TYPE` fences) + verify.sh + build-verdict.py | `bin/` + `contracts/` — deterministic, parseable |
| **Roles** | Tight tool permissions + role prompts + skill injection + clean handoffs | `agents/` + `skills/` — Claude Code plugin |

No orchestrator script. No Ralph. No STATE.yaml-as-loop. Tasks ARE the scheduler.

---

## Core Invariant

> **If it's real work, it exists as a Task. If it's not a Task, it's chatter.**

Planner outputs a Task Graph → Lead immediately converts to Tasks with dependencies. Each Task description contains:
- Pointers to artifacts (`tracks/auth/SPEC.md`, `tracks/auth/TASKS/T03.md`)
- Commands (`bin/verify.sh`)
- Definition of Done

---

## Team Roster (7 roles)

| Teammate | Model | Lifecycle | Role |
|----------|-------|-----------|------|
| **Lead** | Opus | Persistent | Traffic cop. Delegate mode always. Never reads logs/diffs. Only: Task Graph, Verdicts, Summaries. |
| **Brainstormer** | Opus | One-shot | Human-in-loop product shaping. Writes seed docs. No implementation. |
| **Planner** | Sonnet | Per track | Spec + Plan → Task Graph + packets. Via GPT-5.2 (codex-planner MCP). |
| **Coder** | Sonnet | Per track | Implements ONE packet at a time. Via GPT-5.3-Codex (codex-coder MCP). |
| **QA** | Sonnet | Per track | verify.sh + criteria fan-out + verdict. Pessimistic by design. |
| **Conductor** | Opus | Persistent | Drift, boundary eval, stuck arbitration. "Are we building the right thing?" |
| **Doc-keeper** | Haiku | Persistent | Living docs maintenance. Significance-gated. |
| **Integrator** | Sonnet | On-demand | Cross-task friction: merge conflicts, refactor collisions, overlap. NOT a coder. |

### Why Integrator?
Atomic tasks + parallel work = adjacent code changes. When two tasks touch the same module, Integrator resolves the friction. Lead spawns it only when needed. It does not expand scope or redesign — it sutures.

---

## Skills-First Architecture

Instead of massive system prompts per agent, shared Skills encode deadfish invariants and output schemas. Each agent is short + role-specific, referencing skills via `skills:` frontmatter.

### 6 Shared Skills

| Skill | Encodes | Used by |
|-------|---------|---------|
| `deadfish-core` | Universal invariants: verify.sh is truth, acceptance immutable, tasks-as-scheduler, sentinel format, scope control | ALL |
| `deadfish-planning` | Spec format, Plan format, Task packet format, GSD rules (plans-as-prompts, ≤200 diff, ≤5 files), drift detection | Planner, Conductor |
| `deadfish-verify` | verify.sh protocol, criteria rubric (EXISTS/SUBSTANTIVE/WIRED), verdict format, build-verdict.py aggregation | QA, Coder (self-check) |
| `deadfish-implement` | Implementation constraints, git commit conventions, scope control, retry protocol, Codex MCP usage | Coder, Integrator |
| `deadfish-docs` | Living docs format, 7 files + budgets, significance gate, scratch buffer, NOP/BUFFER/UPDATE/FLUSH | Doc-keeper |
| `deadfish-conductor` | Conductor verdict format, drift protocol, boundary evaluation checklist, stuck arbitration flowchart | Conductor |

**Update one skill → all teammates get smarter instantly.**

---

## Sentinel Format (Simplified)

Single format everywhere. No `<<<TYPE:V1:NONCE=...>>>`. Markdown code fences:

````
```deadfish:PLAN
track_id: auth
base_commit: abc1234
tasks:
  - id: T01
    title: "Set up auth module"
    depends_on: []
    packet_path: tracks/auth/TASKS/T01.md
```
````

Types: `SPEC`, `PLAN`, `TASK`, `VERDICT`, `CONDUCTOR`, `DOCSYNC`, `IMPLEMENT`, `INTEGRATE`

parse-blocks.py adapted to target `` ```deadfish: `` fences with YAML inside. Trivial to parse.

---

## Crash-Proof Continuity

```bash
export CLAUDE_CODE_TASK_LIST_ID="deadfish-$(date +%Y%m%d)"
```

This gives:
- **Restart safety**: Session crash → resume → task list intact
- **Multi-terminal**: Multiple SSH sessions can view the same task list
- **Wave runs**: Break work into waves without losing the roadmap
- **Persistence**: Tasks survive across sessions

---

## MCP Configuration

```json
{
  "mcpServers": {
    "codex-planner": {
      "command": "codex",
      "args": ["mcp-server", "-m", "gpt-5.2", "-c", "model_reasoning_effort=\"high\""]
    },
    "codex-coder": {
      "command": "codex",
      "args": ["mcp-server", "-m", "gpt-5.3-codex", "-c", "model_reasoning_effort=\"high\""]
    }
  }
}
```

---

## Execution Flow

### Phase 1: Brainstorm (human-in-loop)

1. Lead spawns Brainstormer
2. Human talks directly to Brainstormer (Shift+Down)
3. BMAD session → seed docs written (VISION, PRODUCT, REQUIREMENTS, ROADMAP, RISKS)
4. Brainstormer messages Lead: paths + decisions + unknowns
5. Brainstormer shuts down

### Phase 2: Autonomous (delegate mode)

Lead presses Shift+Tab → delegate mode. For each track:

**PLAN:**
1. Spawn fresh Planner
2. Planner → SPEC.md → PLAN.md → Task packets (all via GPT-5.2)
3. Planner emits `deadfish:PLAN` sentinel with Task Graph
4. Lead converts Task Graph → native Tasks with dependencies (blockedBy/blocks)
5. Lead messages Conductor: "evaluate plan"
6. Conductor: CONTINUE | ADAPT | REPLAN
7. Planner shuts down

**EXECUTE (per task):**
8. Coder claims next unblocked task
9. Coder reads task packet → dispatches to GPT-5.3-Codex → self-verify → commit
10. Coder emits `deadfish:IMPLEMENT` → marks task complete
11. QA claims verification task (blockedBy: implementation task)
12. QA: verify.sh → criteria → `deadfish:VERDICT` → PASS/FAIL
13. PASS → Doc-keeper evaluates significance → `deadfish:DOCSYNC`
14. FAIL → Coder retries (max 2) → Conductor arbitrates if still stuck
15. Cross-task friction detected → Lead spawns Integrator (rare)

**BOUNDARY:**
16. Track complete → Conductor boundary evaluation → `deadfish:CONDUCTOR`
17. Doc-keeper → flush scratch buffer, reconcile all docs
18. Coder + QA + Integrator shut down
19. Conductor verdict → CONTINUE | ADAPT | REPLAN | ESCALATE

**COMPLETE:**
20. All tracks done → Lead cleanup team → DONE

---

## Hooks (Signal-Only)

Hooks nudge the pipeline forward. They are NOT the scheduler. Don't let hooks become Ralph.

```
hooks/
├── hooks.json
└── scripts/
    ├── on-task-completed.sh    # touch .signals/task-completed
    ├── on-teammate-idle.sh     # touch .signals/teammate-idle
    └── on-subagent-stop.sh     # touch .signals/subagent-stop
```

Hooks write signals to files. Lead reads signals. That's it.

Supports both new events (TeammateIdle, TaskCompleted) and classic events (SubagentStop) as fallback.

---

## Plugin Structure

```
/tank/dump/DEV/deadfish-teams/
├── .claude-plugin/
│   └── plugin.json                  # Manifest (name, description, author)
├── .mcp.json                        # Dual Codex MCP config
├── CLAUDE.md                        # Project-level: 4 layers, invariants, flow
├── agents/                          # 7 short role definitions (reference skills)
│   ├── brainstormer.md
│   ├── planner.md
│   ├── coder.md
│   ├── qa-reviewer.md
│   ├── conductor.md
│   ├── doc-keeper.md
│   └── integrator.md
├── skills/                          # 6 shared skills (encode invariants)
│   ├── deadfish-core/SKILL.md
│   ├── deadfish-planning/SKILL.md
│   ├── deadfish-verify/SKILL.md
│   ├── deadfish-implement/SKILL.md
│   ├── deadfish-docs/SKILL.md
│   └── deadfish-conductor/SKILL.md
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       ├── on-task-completed.sh
│       ├── on-teammate-idle.sh
│       └── on-subagent-stop.sh
├── templates/                       # From v1 (reference material)
│   └── (track/, task/, verify/, bootstrap/, repair/)
├── contracts/
│   └── sentinel/                    # deadfish:TYPE format definitions
├── bin/                             # Deterministic tools (from v1)
│   ├── verify.sh
│   ├── parse-blocks.py              # Adapted for deadfish: fences
│   ├── build-verdict.py
│   └── lint-templates.py
└── docs/
    └── living/                      # 7 living docs + scratch buffer
```

---

## Lead Kickoff Prompt

Paste this in the main session to start:

```
Create an AGENT TEAM named "deadfish" with these teammates:

1) brainstormer: product ideation + writes track seed docs only
2) planner: writes SPEC + PLAN + TASK packets only
3) coder: implements TASK packets; runs bin/verify.sh; commits per task
4) qa-reviewer: runs bin/verify.sh + acceptance criteria checks; produces VERDICT blocks
5) conductor: drift + boundary evaluation; produces CONDUCTOR verdict blocks
6) doc-keeper: updates living docs only after PASS verdict
7) integrator: resolves cross-task friction ONLY when requested by Lead

Rules:
- I (Lead) will operate in delegate mode and will not edit code.
- All work must be represented as Tasks with dependencies.
- Every artifact written must be referenced by task ID and path.
- Deterministic truth is bin/verify.sh output; LLM judgment is secondary.
- Use deadfish sentinel code fences for structured outputs.

Now spawn the teammates and wait for my next instruction.
```

Then Shift+Tab into delegate mode.

---

## Migration from v1

### Unchanged
- `bin/verify.sh` — deterministic verifier
- `bin/build-verdict.py` — verdict aggregator
- `bin/lint-templates.py` — template drift checker
- All templates (reference material for skills)
- Contracts/sentinel definitions (adapted to new fence format)

### Adapted
- `bin/parse-blocks.py` — adapt to parse `` ```deadfish:TYPE `` fences + YAML
- Sentinel format → simplified code fences
- STATE.yaml → native Task list + conductor-state.md
- DECIDE table → Task dependencies (blockedBy/blocks)

### Deleted
- ralph.sh, kick.sh, cron-kick.sh
- Root-level wrappers
- flock locking, nonce derivation
- POLICY.yaml modes (replaced by delegate mode + permissions)

---

## Implementation Steps

### Step 1: Scaffold
Plugin manifest, .mcp.json, directories, git init, CLAUDE_CODE_TASK_LIST_ID setup.

### Step 2: Copy artifacts
bin/ scripts, templates, contracts from deadfish-cli v1.

### Step 3: Skills (6)
Write the 6 shared skill SKILL.md files encoding deadfish invariants.

### Step 4: Agents (7)
Write 7 short agent definitions referencing skills via `skills:` frontmatter.

### Step 5: CLAUDE.md
4-layer model, core invariant, team roster, execution flow, Lead kickoff prompt.

### Step 6: Hooks + scripts
hooks.json with signal-only scripts. Fallback for classic events.

### Step 7: Adapt parse-blocks.py
Update parser to handle `deadfish:TYPE` code fences with YAML content.

### Step 8: README + validation
Setup guide, architecture overview, validation script.

---

## Verification

| Check | How |
|---|---|
| Plugin loads | `claude` sees all 7 agents + 6 skills |
| Team creation | Lead kickoff prompt spawns all teammates |
| Brainstorm | Human talks to Brainstormer, seed docs written |
| Task Graph | Planner emits `deadfish:PLAN`, Lead creates Tasks |
| Task list | `CLAUDE_CODE_TASK_LIST_ID` persists across sessions |
| Codex routing | Planner uses gpt-5.2, Coder uses gpt-5.3-codex |
| Sentinel parsing | `deadfish:TYPE` fences parsed by adapted parse-blocks.py |
| verify.sh gate | QA runs verify.sh, deterministic results |
| Conductor | Boundary eval returns structured `deadfish:CONDUCTOR` |
| Integrator | Spawned only on cross-task friction, resolves cleanly |
| Skills update | Change one skill → all referencing agents inherit |
| Crash recovery | Kill session → resume → task list intact |
| Hooks | Signal-only, don't block pipeline |
