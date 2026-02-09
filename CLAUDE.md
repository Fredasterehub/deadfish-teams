# deadfish-teams — Orchestrator Contract v3

> "Only a dead fish follows the flow."

## Mental Model: 4 Layers

| Layer | What | Where |
|-------|------|-------|
| **State** | Tasks + dependencies + status | Claude Code native task list (`CLAUDE_CODE_TASK_LIST_ID`) |
| **Artifacts** | Spec, plan, packets, conductor state, living docs | Git (reviewable, diffable) |
| **Protocol** | `deadfish:TYPE` sentinels + verify.sh + build-verdict.py | `bin/` + `contracts/` |
| **Roles** | Tool permissions + role prompts + skill injection | `agents/` + `skills/` |

## Core Invariant

**If it's real work, it exists as a Task. If it's not a Task, it's chatter.**

## Team

| Role | Model | Lifecycle | Purpose |
|------|-------|-----------|---------|
| Lead | Opus | Persistent | Traffic cop. Delegate mode always. Only reads: Task Graph, Verdicts, Summaries. |
| Discoverer | Sonnet | One-shot | Brownfield discovery pass. Detect + collect evidence + `docs/discovery.md`. |
| Brainstormer | Opus | One-shot | BMAD ideation with human. Writes seed docs. No implementation. |
| Planner | Sonnet | Per track | Spec + Plan + Task packets via GPT-5.2 (`codex-planner` MCP). |
| Coder | Sonnet | Per track | Implements one packet at a time via GPT-5.3-Codex (`codex-coder` MCP). |
| QA | Sonnet | Per track | verify.sh + criteria + verdict. Pessimistic by design. |
| Conductor | Opus | Persistent | Drift, boundaries, stuck arbitration. "Are we building the right thing?" |
| Doc-keeper | Haiku | Persistent | Living docs. Significance-gated. 7 files + scratch buffer. |
| Integrator | Sonnet | On-demand | Cross-task friction only. Sutures, not surgery. |

## Flow

### Phase 1: Brainstorm (human-in-loop)
1. Lead runs `bin/discover-detect.sh`
2. If result is `brownfield`: Lead spawns Discoverer → writes `docs/discovery.md`
3. Lead spawns Brainstormer (include `docs/discovery.md` context when available)
4. Human talks directly to Brainstormer (Shift+Down)
5. Seed docs written → Brainstormer shuts down
6. Lead reads artifacts (context clean)

### Phase 2: Autonomous (delegate mode)
Lead presses Shift+Tab. For each track:

**PLAN:** Spawn Planner → SPEC + PLAN + packets → Conductor evaluates → Planner shuts down
**EXECUTE:** Lead converts Task Graph to native Tasks with dependencies. For each packet, Lead runs `bin/packet-to-task.py <packet_path>` and uses that output verbatim as the Task description. On retry, Lead appends QA feedback AFTER the original description. Coder claims → implements → QA verifies → Doc-keeper reflects. On 2x fail → Conductor arbitrates.
**BOUNDARY:** Conductor evaluates track completion → CONTINUE | ADAPT | REPLAN | ESCALATE. Workers shut down. Next track.

## Lifecycle

Lead + Conductor + Doc-keeper: persistent (cross-track memory).
Planner + Coder + QA + Integrator: rotate per track (fresh context).
Handoff between tracks: files (plan.md, spec.md, living docs, git history).

## Sentinel Format

All structured output uses:

    ```deadfish:TYPE
    yaml: content
    ```

Types: SPEC, PLAN, TASK, TRACK, VERDICT, VERDICT_CRITERION, CONDUCTOR, DOCSYNC, IMPLEMENT, INTEGRATE, DIAGNOSTIC

## Crash Recovery

Set before starting: `export CLAUDE_CODE_TASK_LIST_ID="deadfish-<date>"`
Task list persists across session crashes and restarts.

## Lead Kickoff Prompt

Paste this to start:

    Create an AGENT TEAM named "deadfish" with these teammates:
    1) discoverer: one-shot brownfield discovery; writes docs/discovery.md
    2) brainstormer: product ideation + writes track seed docs only
    3) planner: writes SPEC + PLAN + TASK packets only
    4) coder: implements TASK packets; runs bin/verify.sh; commits per task
    5) qa-reviewer: runs bin/verify.sh + acceptance criteria checks; produces VERDICT
    6) conductor: drift + boundary evaluation; produces CONDUCTOR verdicts
    7) doc-keeper: updates living docs only after PASS verdict
    8) integrator: resolves cross-task friction ONLY when requested by Lead

    Rules:
    - I (Lead) operate in delegate mode and will not edit code.
    - All work must be represented as Tasks with dependencies.
    - Deterministic truth is bin/verify.sh output; LLM judgment is secondary.
    - Use deadfish sentinel code fences for structured outputs.
    Now spawn the teammates and wait for my next instruction.

Then press Shift+Tab for delegate mode.
