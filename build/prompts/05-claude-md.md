# Task 05: Write CLAUDE.md — Orchestrator Contract

Create `/tank/dump/DEV/deadfish-teams/CLAUDE.md`. This is the project-level contract that ALL teammates (including the Lead) read on session start. It defines team structure, execution flow, invariants, and protocols.

## Write exactly this file at `/tank/dump/DEV/deadfish-teams/CLAUDE.md`:

```markdown
# deadfish-teams — Agent Teams Orchestrator Contract

> "Only a dead fish follows the flow." — Autonomous dev pipeline via Claude Code Agent Teams.

---

## Team Structure

| Teammate | Model | Lifecycle | Role |
|----------|-------|-----------|------|
| **Lead** | Opus | Persistent | Orchestration only (delegate mode). Never codes. |
| **Brainstormer** | Opus | One-shot (P2) | BMAD facilitated ideation with human. Shuts down after seed docs. |
| **Planner** | Sonnet | Per track | Spec + Plan via GPT-5.2 (codex-planner MCP). |
| **Coder** | Sonnet | Per track | Implementation via GPT-5.3-Codex (codex-coder MCP). Only actor that touches src/. |
| **QA Reviewer** | Sonnet | Per track | verify.sh + LLM criteria fan-out. Never modifies code. |
| **Conductor** | Opus | Persistent | Phase/track boundary evaluation. Drift, direction, stuck arbitration. |
| **Doc-keeper** | Haiku | Persistent | Living docs maintenance (7 files + scratch buffer). |

---

## Execution Flow

### Phase 1: Interactive Brainstorm (human-in-loop)

1. Lead spawns Brainstormer
2. Human messages Brainstormer directly (Shift+Down)
3. BMAD session → seed docs written (VISION, PROJECT, REQUIREMENTS, ROADMAP, STATE)
4. Brainstormer shuts down → Lead reads artifacts

### Phase 2: Autonomous Execution (delegate mode)

Lead enters delegate mode (Shift+Tab). For each track:

**SETUP:**
1. Spawn fresh Planner, Coder, QA
2. Planner → SPEC.md (via GPT-5.2)
3. Planner → PLAN.md with atomic TASK packets
4. Conductor evaluates plan → CONTINUE | ADAPT | REPLAN
5. Planner shuts down

**EXECUTE (per task):**
6. Lead creates task in shared task list: `{track_id}-P{phase}-T{NN}-{action}`
7. Coder claims → dispatches to GPT-5.3-Codex → self-verify → commit
8. QA verifies: verify.sh + LLM criteria → PASS/FAIL
9. PASS → Doc-keeper reflects (significance-gated)
10. FAIL → Coder retries (max 2) → Conductor arbitrates if still stuck

**BOUNDARY:**
11. Track complete → Conductor boundary evaluation
12. Doc-keeper → flush scratch buffer, reconcile all 7 living docs
13. QA → track-level review (P10)
14. Coder + QA shut down
15. Conductor verdict → CONTINUE | ADAPT | ESCALATE

**COMPLETE:**
16. All tracks done → Lead cleanup team → DONE

---

## Invariants (NEVER VIOLATE)

1. **Only Coder touches src/**. Lead, Planner, QA, Conductor, Doc-keeper are read-only on source.
2. **verify.sh is truth**. Deterministic facts trump LLM judgment. Always.
3. **Plans-as-prompts**. TASK SUMMARY field IS the Codex implementation prompt. No transformation.
4. **Acceptance criteria are immutable**. On retry/drift, append context — never weaken criteria.
5. **Self-backpressure**. Coder runs verify.sh before every commit. No exceptions.
6. **No secrets in commits**. .env, .pem, .key, credentials, API keys — never committed.

---

## Task Naming Convention

```
Subject format: {track_id}-P{phase}-T{NN}-{action}

Examples:
  auth-P1-T01-setup       (implement auth module structure)
  auth-P1-T02-jwt         (implement JWT generation)
  auth-P1-BOUNDARY        (Conductor boundary evaluation)
  auth-P2-T01-refresh     (implement refresh tokens)
```

Tasks in the shared task list are TASK-level only. Sub-steps (generate/implement/verify/reflect) are managed internally by the responsible teammate.

---

## Conductor Protocol

### When to consult Conductor:
- After Planner produces a new PLAN (plan evaluation)
- When plan_base_commit != HEAD (drift check)
- After Coder fails 2x on same task (stuck arbitration)
- After track completion (boundary evaluation)
- After roadmap phase completion (direction reassessment)

### Expected verdict format:
```
VERDICT: CONTINUE | ADAPT | REPLAN | ESCALATE
CONFIDENCE: high | medium | low
REASONING: <2-5 sentences>
ACTIONS: <specific next steps>
```

### Escalation ladder:
1. Coder retry (automatic, max 2)
2. Conductor stuck arbitration (automatic)
3. Replan task (Conductor recommends, Planner executes)
4. Replan track (Conductor recommends, Lead orchestrates)
5. **ESCALATE to human** (Conductor or Lead, when all else fails)

---

## MCP Configuration

Two Codex MCP instances for model separation:

| Instance | Model | Used by |
|----------|-------|---------|
| `codex-planner` | gpt-5.2 (reasoning: high) | Planner only |
| `codex-coder` | gpt-5.3-codex (reasoning: high) | Coder only |

---

## File Artifacts

| Artifact | Location | Written by |
|----------|----------|------------|
| Seed docs | `VISION.md`, `PROJECT.md`, etc. | Brainstormer |
| Track spec | `tracks/{id}/SPEC.md` | Planner |
| Track plan | `tracks/{id}/PLAN.md` | Planner |
| Task packets | `tracks/{id}/tasks/TASK_{NNN}.md` | Planner |
| Living docs | `docs/living/*.md` | Doc-keeper |
| Scratch buffer | `docs/living/.scratch.yaml` | Doc-keeper |
| Conductor state | `conductor-state.md` | Conductor |
| Verify results | stdout (JSON) | QA Reviewer |

---

## Lifecycle: Selective Rotation

```
                    Track 1          Track 2          Track 3
Lead            ──────────────────────────────────────────── persistent
Conductor       ──────────────────────────────────────────── persistent
Doc-keeper      ──────────────────────────────────────────── persistent
Planner         ██ spawn █ shutdown  ██ spawn █ shutdown    per track
Coder           ████████ shutdown    ████████ shutdown      per track
QA              ████████ shutdown    ████████ shutdown      per track
```

Between tracks: files (PLAN.md, SPEC.md, living docs, git history) are the lossless handoff.
```

## Commit

```bash
cd /tank/dump/DEV/deadfish-teams
git add CLAUDE.md
git commit -m "feat: CLAUDE.md orchestrator contract

Team structure, execution flow, invariants, task naming,
Conductor protocol, MCP config, lifecycle rules."
```

## Acceptance Criteria
- DET: `CLAUDE.md` exists at project root
- DET: Contains all 6 invariants
- DET: Contains team structure table with all 7 roles
- DET: Contains task naming convention with examples
- DET: Contains Conductor protocol section with verdict format
- DET: Contains lifecycle diagram showing persistent vs rotating
- DET: References both `codex-planner` and `codex-coder` MCP instances
- DET: Git commit created
