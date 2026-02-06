# deadfish-teams

> "Only a dead fish follows the flow."

Autonomous development pipeline on Claude Code Agent Teams. Four layers, zero Ralph.

## Prerequisites

- Claude Code CLI v2.1.32+
- Codex CLI v0.75.0+ (`codex --version`)
- OpenAI API key configured
- Python 3.9+
- Git

## Setup

1. Enable Agent Teams:
```json
// ~/.claude/settings.json
{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
```

2. Install plugin:
```bash
ln -s /tank/dump/DEV/deadfish-teams ~/.claude/plugins/deadfish-teams
```

3. Set task list ID for crash-proof continuity:
```bash
export CLAUDE_CODE_TASK_LIST_ID="deadfish-$(date +%Y%m%d)"
```

4. Start Claude Code in your project and paste the Lead Kickoff Prompt from CLAUDE.md.

## Architecture

```
Lead (Opus, delegate mode)
├── Brainstormer (Opus)     — BMAD ideation, one-shot
├── Planner (Sonnet)        — spec + plan via GPT-5.2, per track
├── Coder (Sonnet)          — implementation via GPT-5.3-Codex, per track
├── QA Reviewer (Sonnet)    — verify.sh + criteria, per track
├── Conductor (Opus)        — boundary evaluation, persistent
├── Doc-keeper (Haiku)      — living docs, persistent
└── Integrator (Sonnet)     — cross-task friction, on-demand
```

## 4 Layers

| Layer | What | Where |
|-------|------|-------|
| State | Tasks + deps + status | Native task list |
| Artifacts | Spec, plan, packets, docs | Git |
| Protocol | deadfish sentinels + verify.sh | bin/ |
| Roles | Permissions + prompts + skills | agents/ + skills/ |

## Skills-First

6 shared skills encode deadfish invariants. Agents are short role prompts that reference skills. Update one skill → all agents improve.

| Skill | Encodes |
|-------|---------|
| deadfish-core | Universal invariants, sentinel format, escalation |
| deadfish-planning | Spec/plan/task formats, GSD rules, drift |
| deadfish-verify | verify.sh protocol, criteria rubric, verdict |
| deadfish-implement | Codex MCP usage, git conventions, scope |
| deadfish-docs | Living docs format, budgets, significance |
| deadfish-conductor | Drift protocol, boundary eval, stuck arbitration |

## Dual Codex MCP

| Instance | Model | Used by |
|----------|-------|---------|
| codex-planner | gpt-5.2 (reasoning: high) | Planner |
| codex-coder | gpt-5.3-codex (reasoning: high) | Coder |

## Lineage

Port of [deadfish-cli](../deadfish-cli/) v1 from Bash+STATE.yaml to Agent Teams native. Same methodology (GSD + BMAD + Conductor), zero Ralph.
