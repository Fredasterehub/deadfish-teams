# deadfish-teams: Agent Teams Native Implementation Plan

> **"Only a dead fish follows the flow."** — v2 replaces the Bash plumbing with Claude Code Agent Teams native orchestration. Same methodology (GSD + BMAD + Conductor), zero Ralph.

---

## Context

deadfish-cli v1 is a working autonomous dev pipeline built on:
- **Ralph** (Bash loop) → kick.sh → Claude CLI → Codex MCP
- **STATE.yaml** as source of truth + loop driver
- **Sentinel blocks** as structured LLM communication protocol
- **verify.sh** as deterministic verification gate

The insight: Agent Teams' shared task list + Lead delegate mode + inter-teammate messaging replaces Ralph, STATE.yaml-as-loop, and sentinel-as-communication natively. What survives: verify.sh, parse-blocks.py, build-verdict.py, all template schemas, the entire GSD/BMAD/Conductor methodology.

**No Ralph.** The task list IS the loop. The Lead IS the dispatcher. Teammates self-coordinate.

---

## Decisions

| Question | Decision | Rationale |
|---|---|---|
| Coder engine | **GPT-5.3-Codex** via Codex MCP | Two MCP instances: `codex-planner` (gpt-5.2) + `codex-coder` (gpt-5.3-codex). Per-agent tool restrictions ensure separation. |
| Task granularity | **TASK-level only** | Matches Conductor pattern: plan.md tracks tasks with `[ ]`/`[~]`/`[x]`, sub-steps (implement/verify/reflect) run internally per teammate. |
| Output format | **Sentinels for GPT output, Markdown files for inter-teammate** | Sentinels + parse-blocks.py for parsing raw GPT-5.2 text output (nonce prevents hallucination). Structured Markdown files for teammate-to-teammate communication (written via Write tool, no hallucination risk). |
| Teammate lifecycle | **Selective rotation** | Lead + Conductor + Doc-keeper persistent (cross-track memory). Planner + Coder + QA rotate per track (fresh context). Files = lossless handoff. |
| Conductor state | **conductor-state.md, rotate per roadmap phase** | Grows per-track (drift/deviation/stuck entries). Archived + fresh file at phase boundaries. |

---

## Architecture

```
User (interactive brainstorm only)
  │
  ▼
Lead (Claude Opus, delegate mode)
  │  Pure orchestration: spawn, message, task list, shutdown
  │  Never touches code. Never runs templates directly.
  │
  ├── Brainstorm Teammate (Claude Opus) ← spawns once, shuts down after P2
  │     Interactive with user (BMAD-style)
  │     Writes: VISION.md, PROJECT.md, REQUIREMENTS.md, ROADMAP.md
  │
  ├── Planner Teammate (Codex MCP → GPT-5.2) ← rotates per track
  │     Reads: SPEC → produces PLAN with atomic TASK packets
  │     GSD pattern: plans-as-prompts, 2-3 tasks, ≤200 diff lines
  │     Parses GPT-5.2 output with parse-blocks.py (sentinel format)
  │
  ├── Coder Teammate (Codex MCP → GPT-5.3-Codex) ← rotates per track
  │     Receives TASK packet verbatim → dispatches to Codex → self-verify
  │     Only actor that touches src/
  │     Runs verify.sh before commit (self-backpressure)
  │
  ├── QA Teammate (Claude Sonnet) ← rotates per track
  │     Runs verify.sh (deterministic) → fans out LLM criteria
  │     Uses parse-blocks.py + build-verdict.py
  │     Track-level QA review (P10) at track boundaries
  │
  ├── Conductor Teammate (Claude Opus) ← PERSISTENT
  │     Consulted at phase/track boundaries
  │     Drift detection, plan adaptation, direction reassessment
  │     Maintains conductor-state.md
  │     Verdicts: CONTINUE | ADAPT | REPLAN | ESCALATE
  │
  └── Doc-keeper Teammate (Claude Haiku) ← PERSISTENT
        Per-task living docs sync (P9.5 Reflect, significance-gated)
        Maintains 7 docs + scratch buffer cross-track
        Token budgets enforced (~18800 chars total)
```

### MCP Configuration

Two separate Codex MCP instances with per-agent tool restrictions:

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

Agent tool restrictions:
- **planner.md**: `tools: ["Read", "Write", "Glob", "Grep", "Bash", "mcp__codex-planner__codex"]`
- **coder.md**: `tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash", "mcp__codex-coder__codex", "mcp__codex-coder__codex-reply"]`

### Why No Ralph

| Ralph responsibility | Agent Teams native replacement |
|---|---|
| While loop until done | Lead loops on task list until 0 pending |
| Timeout enforcement | systemd WatchdogSec or Lead self-timeout |
| Singleton lock | One team per session (enforced by Agent Teams) |
| Cycle dispatch | Lead dispatches to teammates |
| State persistence | Task list + artifact files (plan.md, spec.md, conductor-state.md) |
| Crash recovery | systemd Restart=on-failure |

### Conductor Teammate Detail

The Conductor is NOT the Lead. The Lead dispatches tasks. The Conductor evaluates whether the tasks are still the RIGHT tasks.

1. **Pre-task drift check**: Compare plan_base_commit vs HEAD. If drift: ADAPT bindings or REPLAN.
2. **Phase boundary evaluation**: When a track completes, evaluate: did implementation match spec? Do remaining tracks need adjustment?
3. **Tech stack alignment**: When implementation diverges from plan, capture deviation in TECH_STACK.md and assess downstream impact.
4. **Direction reassessment**: At roadmap phase boundaries, re-evaluate overall direction. Challenge assumptions from brainstorm.
5. **Stuck arbitration**: When Coder fails 2x on same task, diagnose: bad plan? bad task sizing? missing context?

### Task List Structure (Conductor-style)

Tasks in the shared task list follow Conductor's pattern — TASK-level only, sub-steps internal:

```
Task subject naming: "{track_id}-P{phase}-T{NN}-{action}"
Examples:
  auth-P1-T01-setup          (implement auth module structure)
  auth-P1-T02-jwt            (implement JWT token generation)
  auth-P1-T03-login          (implement login endpoint)
  auth-P1-BOUNDARY           (Conductor phase boundary eval)
  auth-P2-T01-refresh        (implement refresh tokens)
```

Each task's internal lifecycle (not tracked in task list, managed by teammates):
1. Planner generates TASK packet (or extracts from PLAN.md)
2. Coder implements → runs verify.sh self-check → commits
3. QA runs verify.sh + LLM criteria fan-out → PASS/FAIL verdict
4. Doc-keeper evaluates significance → NOP/BUFFER/UPDATE
5. On FAIL: Coder retries (max 2) → Conductor arbitrates if still stuck

---

## Execution Flow

### Phase 1: Interactive Brainstorm (one-time, human-in-loop)

```
1. User starts session, asks Lead to create team
2. Lead spawns Brainstorm teammate
3. User messages Brainstorm directly (Shift+Down)
4. BMAD session: 50-100+ ideas, anti-clustering, domain pivots
5. Brainstorm crystallizes → writes 5 seed docs to project root
6. Brainstorm runs adversarial review on own output
7. Brainstorm messages Lead: "artifacts ready"
8. Lead acknowledges, Brainstorm shuts down
9. Lead reads artifacts → context is clean (never saw brainstorm tokens)
```

### Phase 2: Autonomous Execution (delegate mode)

```
10. Lead creates task list from ROADMAP phases + tracks
11. Lead enters delegate mode (Shift+Tab)
12. For each track:
    ┌─ SETUP ─────────────────────────────────────────────┐
    │ a. Lead spawns fresh Planner, Coder, QA             │
    │ b. Lead messages Planner: "create spec for track X" │
    │ c. Planner writes SPEC.md (via Codex MCP → GPT-5.2) │
    │ d. Lead messages Planner: "create plan from spec"   │
    │ e. Planner writes PLAN.md with TASK packets         │
    │ f. Lead messages Conductor: "evaluate plan"         │
    │ g. Conductor: CONTINUE | ADAPT | REPLAN             │
    │ h. Planner shuts down (job done for this track)     │
    └─────────────────────────────────────────────────────┘
    ┌─ EXECUTE (per task) ────────────────────────────────┐
    │ i. Lead creates task in shared task list             │
    │ j. Coder claims task, dispatches to GPT-5.3-Codex   │
    │ k. Coder runs verify.sh self-check before commit    │
    │ l. Lead messages QA: "verify task {id}"             │
    │ m. QA: verify.sh + LLM criteria → PASS/FAIL        │
    │ n. PASS → Lead messages Doc-keeper for reflect      │
    │ o. FAIL → Lead messages Coder: retry with context   │
    │ p. 2x FAIL → Lead messages Conductor for arbitration│
    └─────────────────────────────────────────────────────┘
    ┌─ BOUNDARY ──────────────────────────────────────────┐
    │ q. Track complete → Lead messages Conductor         │
    │    Conductor evaluates: spec alignment, drift,      │
    │    downstream impact, direction still valid?         │
    │ r. Lead messages Doc-keeper: flush + reconcile      │
    │ s. Lead messages QA: track-level QA review (P10)    │
    │ t. Coder + QA shut down                             │
    │ u. Conductor verdict: CONTINUE next track           │
    │    or ADAPT plans or ESCALATE to human              │
    └─────────────────────────────────────────────────────┘
13. All tracks done → Lead cleanup team → DONE
```

### Context Lifecycle (Selective Rotation)

```
                    Track 1          Track 2          Track 3
Lead            ────────────────────────────────────────────── (persistent, delegate mode)
Conductor       ────────────────────────────────────────────── (persistent, cross-track memory)
Doc-keeper      ────────────────────────────────────────────── (persistent, living docs + buffer)
Planner         ██ spawn ██ shutdown  ██ spawn ██ shutdown  ██ spawn ██ shutdown
Coder           ████████ shutdown     ████████ shutdown     ████████ shutdown
QA              ████████ shutdown     ████████ shutdown     ████████ shutdown
```

Handoff between tracks = files:
- `tracks/{id}/PLAN.md` — task status markers `[ ]`/`[~]`/`[x]`
- `tracks/{id}/SPEC.md` — requirements
- `conductor-state.md` — drift/deviation/stuck log
- Living docs (7 files) — project knowledge
- Git history + commits — what was actually done

---

## Implementation as Claude Code Plugin

### Directory Structure

```
/tank/dump/DEV/deadfish-teams/
├── PLAN.md                          # This file
├── README.md                        # Setup & usage
├── .claude-plugin/
│   └── plugin.json                  # Plugin manifest
├── agents/
│   ├── brainstormer.md              # BMAD-style brainstorm agent
│   ├── planner.md                   # GSD atomic task planning agent (GPT-5.2)
│   ├── coder.md                     # Implementation agent (GPT-5.3-Codex)
│   ├── qa-reviewer.md               # Deterministic + LLM verification agent
│   ├── conductor.md                 # Phase boundary evaluation agent
│   └── doc-keeper.md                # Living docs maintenance agent
├── skills/
│   ├── brainstorm/
│   │   └── SKILL.md                 # Interactive brainstorm skill (P2)
│   ├── verify/
│   │   └── SKILL.md                 # Wraps verify.sh + criterion fan-out
│   └── reflect/
│       └── SKILL.md                 # P9.5 living docs sync
├── hooks/
│   └── hooks.json                   # TeammateIdle, TaskCompleted handlers
├── templates/                       # Ported from .deadf/templates/
│   ├── track/
│   │   ├── select-track.md
│   │   ├── write-spec.md
│   │   └── write-plan.md
│   ├── task/
│   │   ├── generate-packet.md
│   │   └── implement.md
│   ├── verify/
│   │   ├── verify-criterion.md
│   │   ├── reflect.md
│   │   └── qa-review.md
│   ├── bootstrap/
│   │   ├── brainstorm-a.md through brainstorm-g.md
│   │   └── seed-project-docs.md
│   └── repair/
│       ├── format-repair.md
│       └── auto-diagnose.md
├── contracts/
│   └── sentinel/                    # Sentinel format definitions (for GPT output parsing)
│       ├── plan.v1.md
│       ├── track.v1.md
│       ├── spec.v1.md
│       ├── verdict.v1.md
│       ├── reflect.v1.md
│       └── qa-review.v1.md
├── bin/                             # Ported from .deadf/bin/ (unchanged)
│   ├── verify.sh                    # Deterministic verifier
│   ├── parse-blocks.py              # Sentinel parser
│   ├── build-verdict.py             # Verdict aggregator
│   └── lint-templates.py            # Template drift checker
├── docs/
│   └── design/
│       ├── conductor-role.md        # Conductor teammate design doc
│       └── lifecycle.md             # Teammate lifecycle management doc
└── CLAUDE.md                        # Project-level: team structure, flow, invariants
```

### Agent Definitions

Each agent is a markdown file with YAML frontmatter in `agents/`:

**brainstormer.md** (P2)
```yaml
---
name: brainstormer
description: |
  Use when starting a new project or track that needs ideation.
  <example>
  Context: User wants to brainstorm a new feature
  user: "Let's brainstorm the authentication system"
  assistant: "Spawning brainstormer teammate for BMAD-style ideation"
  <commentary>New feature needs divergent exploration</commentary>
  </example>
model: opus
color: magenta
tools: ["Read", "Write", "Glob", "Grep"]
memory: project
---
```
- BMAD facilitator role (ideas come from human, agent guides)
- Anti-clustering protocol (domain pivot every ~10 ideas)
- Crystallize → 5 seed docs → adversarial self-review
- Shuts down after artifacts written

**planner.md** (P5-P7)
```yaml
---
name: planner
description: |
  Use when a track needs spec, plan, or task packet generation.
  <example>
  Context: Track selected, needs specification and planning
  user: "Create spec and plan for the auth track"
  assistant: "Spawning planner to generate SPEC and PLAN via GPT-5.2"
  <commentary>Planning phase requires GPT-5.2 for structured output</commentary>
  </example>
model: sonnet
color: blue
tools: ["Read", "Write", "Glob", "Grep", "Bash", "mcp__codex-planner__codex"]
memory: project
---
```
- Dispatches to GPT-5.2 via Codex MCP for spec/plan generation
- Parses GPT-5.2 output with parse-blocks.py (sentinel format)
- Plans-as-prompts: SUMMARY field IS the Codex implementation prompt
- 2-5 tasks, ≤200 diff lines each, ≤5 files/task
- Every SPEC AC appears in exactly one task

**coder.md** (P8)
```yaml
---
name: coder
description: |
  Use when a task packet is ready for implementation.
  <example>
  Context: Task packet generated, ready for coding
  user: "Implement task auth-P1-T02-jwt"
  assistant: "Dispatching to GPT-5.3-Codex for implementation"
  <commentary>Implementation uses Codex for atomic task execution</commentary>
  </example>
model: sonnet
color: green
tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash", "mcp__codex-coder__codex", "mcp__codex-coder__codex-reply"]
memory: project
---
```
- Dispatches TASK packet to GPT-5.3-Codex via Codex MCP
- Uses codex-reply for multi-turn iteration within a task
- Scope: only files listed in TASK.FILES
- Self-backpressure: runs verify.sh before commit
- Max 3 fix cycles before reporting failure
- Single commit per task: "{TASK_ID}: {TITLE}"

**qa-reviewer.md** (P9-P10)
```yaml
---
name: qa-reviewer
description: |
  Use when a task or track needs verification.
  <example>
  Context: Coder committed, needs verification
  user: "Verify task auth-P1-T02-jwt"
  assistant: "Running verify.sh + LLM criteria fan-out"
  <commentary>Post-implementation verification gate</commentary>
  </example>
model: sonnet
color: yellow
tools: ["Read", "Glob", "Grep", "Bash"]
memory: project
---
```
- Task-level: runs verify.sh → fans out LLM criteria → build-verdict.py
- Three-level rubric: EXISTS → SUBSTANTIVE → WIRED
- Track-level: 6-category QA review (C0-C5)
- False negatives > false positives (uncertain → NO)

**conductor.md** (Boundary evaluation)
```yaml
---
name: conductor
description: |
  Use at phase/track boundaries for plan evaluation and direction assessment.
  <example>
  Context: Track implementation complete
  user: "Evaluate track auth completion and plan validity"
  assistant: "Running boundary evaluation: drift check, spec alignment, direction assessment"
  <commentary>Phase boundary requires meta-evaluation before next track</commentary>
  </example>
model: opus
color: red
tools: ["Read", "Glob", "Grep", "Bash"]
memory: project
---
```
- Maintains `conductor-state.md`: drift tracking, stuck counts, deviation log
- Pre-task: drift check (plan_base_commit vs HEAD)
- Post-track: boundary evaluation (spec alignment, downstream impact)
- Stuck arbitration: diagnose repeated failures
- Verdicts: CONTINUE | ADAPT | REPLAN | ESCALATE

**doc-keeper.md** (P9.5)
```yaml
---
name: doc-keeper
description: |
  Use after task verification passes to sync living documentation.
  <example>
  Context: Task verified, need to check if docs need updates
  user: "Reflect on task auth-P1-T02-jwt changes"
  assistant: "Evaluating significance for living docs update"
  <commentary>Significance-gated doc sync after verified task</commentary>
  </example>
model: haiku
color: cyan
tools: ["Read", "Write", "Glob", "Grep"]
memory: project
---
```
- Significance-gated: only updates when meaningful changes detected
- 7 living docs with token budgets (~18800 chars total)
- Actions: NOP | BUFFER | UPDATE | FLUSH
- Track-end: flush scratch buffer, reconcile all 7 docs

---

## Migration: What Comes From v1

### Unchanged (copy directly)

| File | Source | Destination |
|---|---|---|
| verify.sh | `.deadf/bin/verify.sh` | `bin/verify.sh` |
| parse-blocks.py | `.deadf/bin/parse-blocks.py` | `bin/parse-blocks.py` |
| build-verdict.py | `.deadf/bin/build-verdict.py` | `bin/build-verdict.py` |
| lint-templates.py | `.deadf/bin/lint-templates.py` | `bin/lint-templates.py` |
| All sentinel contracts | `.deadf/contracts/sentinel/*.md` | `contracts/sentinel/*.md` |
| All templates | `.deadf/templates/**/*.md` | `templates/**/*.md` |

### Replaced (logic in Agent Teams native)

| v1 Component | v2 Replacement |
|---|---|
| ralph.sh (481 lines) | Lead delegate mode (0 lines of Bash) |
| kick.sh (150 lines) | Lead's initial prompt in CLAUDE.md |
| cron-kick.sh (254 lines) | systemd timer if needed |
| STATE.yaml (loop state) | Shared task list + conductor-state.md |
| STATE.yaml (track state) | Task metadata + artifact files |
| DECIDE table (15 rows) | Task dependency graph (blockedBy/blocks) |
| Sentinel as comm protocol | Agent Teams messages (sentinels kept for GPT output parsing only) |
| POLICY.yaml modes | Agent Teams permission settings + CLAUDE.md instructions |
| flock locking | Agent Teams file locking on task claiming |
| Nonce derivation | Agent Teams context IDs |

---

## Implementation Steps

### Step 1: Plugin Scaffold
- Create `.claude-plugin/plugin.json` with name, description, author
- Create full directory structure (agents/, skills/, hooks/, templates/, etc.)
- Enable `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `/root/.claude/settings.json`
- Write `.mcp.json` with dual Codex MCP instances

### Step 2: Agent Definitions (all 6)
- Write each agent .md with YAML frontmatter + system prompt
- Port role descriptions from v1 templates into agent system prompts
- Define tool restrictions per agent (especially Codex MCP routing)
- Set model selection: Opus (Conductor, Brainstorm), Sonnet (Planner, Coder, QA), Haiku (Doc)

### Step 3: Copy Surviving Artifacts
- Copy `bin/` scripts from `.deadf/bin/`
- Copy `contracts/sentinel/*.md`
- Copy `templates/` (all 27 surviving templates)
- Run `lint-templates.py` to verify contract-template alignment
- Test `verify.sh` and `parse-blocks.py` work from new paths

### Step 4: Write CLAUDE.md (Orchestrator Contract)
- Team structure: 6 teammates, roles, spawn/shutdown rules
- Execution flow: Phase 1 brainstorm → Phase 2 delegate mode
- Task naming convention: `{track_id}-P{phase}-T{NN}-{action}`
- Invariants: only Coder codes, verify.sh is truth, plans-as-prompts, acceptance immutable
- Conductor protocol: when to consult, verdict format, escalation
- Lifecycle rules: persistent vs rotating teammates, handoff via files

### Step 5: Skills (3)
- **brainstorm**: Wraps P2 flow (BMAD session → 5 seed docs → adversarial review)
- **verify**: Wraps verify.sh + criterion fan-out + build-verdict.py aggregation
- **reflect**: Wraps P9.5 living docs sync (significance gate → NOP/BUFFER/UPDATE/FLUSH)

### Step 6: Hooks
- `TeammateIdle` → Log idle event, Lead can reassign
- `TaskCompleted` → Trigger QA verification, update task status

### Step 7: Integration Test
- Enable plugin in a test project
- Start session, request team creation
- Run brainstorm on a simple feature (e.g., "add a hello world CLI")
- Execute one full track: spec → plan → implement → verify → reflect → QA
- Verify: task list driven, no Ralph, verify.sh works, Conductor consulted at boundary
- Verify: Planner uses GPT-5.2, Coder uses GPT-5.3-Codex (check Codex MCP logs)
- Verify: teammates rotate between tracks (fresh context)

---

## Verification Checklist

| Check | How to verify |
|---|---|
| Plugin loads | `claude` recognizes all 6 agents |
| Team creation | Lead spawns teammates, visible in Shift+Down |
| Brainstorm flow | User talks to Brainstorm teammate, seed docs written |
| Dual Codex MCP | Planner calls `codex-planner`, Coder calls `codex-coder` |
| Task list loop | Tasks created, claimed, completed, loop progresses |
| Sentinel parsing | GPT-5.2 output parsed by parse-blocks.py successfully |
| verify.sh gate | QA runs verify.sh, deterministic results returned |
| Conductor boundary | At track end, Conductor evaluates, returns verdict |
| Living docs | Doc-keeper updates docs with significance gating |
| Teammate rotation | Workers shut down between tracks, new ones spawned fresh |
| No Ralph | Zero Bash loop infrastructure. Task list drives everything. |
| Recovery | Coder fails 2x → Conductor arbitrates. Lead crash → systemd restarts. |
