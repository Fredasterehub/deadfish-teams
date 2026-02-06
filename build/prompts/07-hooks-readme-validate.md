# Task 07: Hooks, README, and Validation

Create the hooks configuration, README, and run validation.

## File 1: `hooks/hooks.json`

```json
{
  "description": "deadfish-teams event hooks for teammate coordination",
  "hooks": {
    "TeammateIdle": [
      {
        "type": "command",
        "command": "echo '{\"event\": \"teammate_idle\", \"timestamp\": \"'$(date -Iseconds)'\"}'",
        "description": "Log when a teammate becomes idle (finished current work)"
      }
    ],
    "TaskCompleted": [
      {
        "type": "command",
        "command": "echo '{\"event\": \"task_completed\", \"timestamp\": \"'$(date -Iseconds)'\"}'",
        "description": "Log when a task is marked complete in the shared task list"
      }
    ],
    "SubagentStop": [
      {
        "type": "command",
        "command": "echo '{\"event\": \"subagent_stop\", \"timestamp\": \"'$(date -Iseconds)'\"}'",
        "description": "Log when a subagent finishes execution"
      }
    ]
  }
}
```

## File 2: `README.md`

Write a comprehensive README at `/tank/dump/DEV/deadfish-teams/README.md`:

```markdown
# deadfish-teams

> "Only a dead fish follows the flow."

Autonomous development pipeline using Claude Code Agent Teams. Orchestrates brainstorm → plan → implement → verify → reflect cycles with specialized teammates and GPT-5.2/5.3-Codex integration.

## Prerequisites

- Claude Code CLI v2.1.32+ with Agent Teams enabled
- Codex CLI v0.75.0+ (`codex` in PATH)
- OpenAI API key configured (`~/.codex/config.toml` or `OPENAI_API_KEY`)
- Python 3.9+ (for parse-blocks.py, build-verdict.py)
- Git

## Quick Start

### 1. Enable Agent Teams

Add to `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### 2. Install Plugin

```bash
# Clone or copy to your plugins directory
cp -r /tank/dump/DEV/deadfish-teams ~/.claude/plugins/deadfish-teams

# Or symlink for development
ln -s /tank/dump/DEV/deadfish-teams ~/.claude/plugins/deadfish-teams
```

### 3. Start a Session

```bash
cd /path/to/your-project
claude
```

### 4. Create Team

In the Claude Code session:

```
Create a deadfish agent team for this project.
Use delegate mode. Start with brainstorm.
```

Or use the skill shortcut:

```
/brainstorm
```

### 5. Interact with Brainstorm

Use `Shift+Down` to select the Brainstormer teammate. Run the BMAD ideation session interactively.

After brainstorm completes, the Lead automatically enters delegate mode and begins autonomous execution.

## Architecture

```
Lead (Opus, delegate mode) — pure orchestration
├── Brainstormer (Opus)      — BMAD ideation, one-shot
├── Planner (Sonnet)         — spec + plan via GPT-5.2, per track
├── Coder (Sonnet)           — implementation via GPT-5.3-Codex, per track
├── QA Reviewer (Sonnet)     — verify.sh + LLM criteria, per track
├── Conductor (Opus)         — boundary evaluation, persistent
└── Doc-keeper (Haiku)       — living docs, persistent
```

## Key Concepts

### No Ralph
The shared task list IS the loop. The Lead IS the dispatcher. No Bash loop infrastructure needed.

### Plans-as-Prompts (GSD)
The SUMMARY field of each TASK packet IS the Codex implementation prompt. No transformation step between plan and execution.

### Selective Rotation
Lead + Conductor + Doc-keeper persist across tracks. Planner + Coder + QA rotate per track for fresh context. Files are the lossless handoff.

### Deterministic Verification
verify.sh runs tests, linter, diff budget, secret scanning — facts only, no LLM judgment. LLM criteria evaluated separately and aggregated.

### Conductor Boundaries
At every phase/track boundary, the Conductor evaluates: is the plan still valid? Is the direction still correct? Verdicts: CONTINUE | ADAPT | REPLAN | ESCALATE.

## Dual Codex MCP

| Instance | Model | Purpose |
|----------|-------|---------|
| `codex-planner` | gpt-5.2 | Spec + plan generation |
| `codex-coder` | gpt-5.3-codex | Code implementation |

Both use `reasoning_effort: "high"`.

## Directory Structure

```
deadfish-teams/
├── .claude-plugin/plugin.json    # Plugin manifest
├── .mcp.json                     # Dual Codex MCP config
├── CLAUDE.md                     # Orchestrator contract
├── agents/                       # 6 teammate definitions
├── skills/                       # User-invocable skills
├── hooks/                        # Event handlers
├── templates/                    # Prompt templates (from v1)
├── contracts/sentinel/           # Sentinel format definitions
├── bin/                          # Deterministic tools
└── docs/                         # Design docs + living docs
```

## Methodology

Integrates three frameworks:
- **GSD** (Get Shit Done) — Plans-as-prompts, aggressive atomicity, context budgets
- **BMAD** — Facilitated brainstorm methodology (50-100+ ideas, anti-clustering)
- **Google Conductor** — Dynamic task generation, phase boundary re-evaluation, living docs

## Skills

| Skill | Usage | Description |
|-------|-------|-------------|
| `/brainstorm` | `/brainstorm` | Start BMAD ideation session |
| `/verify` | `/verify task <id>` | Run verification pipeline |
| `/reflect` | `/reflect task <id>` | Living docs sync |

## Lineage

Port of [deadfish-cli](../deadfish-cli/) from Bash+STATE.yaml orchestration to Claude Code Agent Teams native. Same methodology, zero Ralph.
```

## Validation Script

After creating all files, run this validation:

```bash
cd /tank/dump/DEV/deadfish-teams

echo "=== Plugin Validation ==="

# Check plugin manifest
test -f .claude-plugin/plugin.json && echo "PASS: plugin.json" || echo "FAIL: plugin.json"

# Check MCP config
test -f .mcp.json && echo "PASS: .mcp.json" || echo "FAIL: .mcp.json"

# Check all 6 agents
for agent in brainstormer planner coder qa-reviewer conductor doc-keeper; do
  test -f "agents/${agent}.md" && echo "PASS: agents/${agent}.md" || echo "FAIL: agents/${agent}.md"
done

# Check all 3 skills
for skill in brainstorm verify reflect; do
  test -f "skills/${skill}/SKILL.md" && echo "PASS: skills/${skill}/SKILL.md" || echo "FAIL: skills/${skill}/SKILL.md"
done

# Check hooks
test -f hooks/hooks.json && echo "PASS: hooks/hooks.json" || echo "FAIL: hooks/hooks.json"

# Check CLAUDE.md
test -f CLAUDE.md && echo "PASS: CLAUDE.md" || echo "FAIL: CLAUDE.md"

# Check README
test -f README.md && echo "PASS: README.md" || echo "FAIL: README.md"

# Check bin scripts
for script in verify.sh parse-blocks.py build-verdict.py; do
  test -f "bin/${script}" && echo "PASS: bin/${script}" || echo "FAIL: bin/${script}"
done

# Check contracts
test -d contracts/sentinel && echo "PASS: contracts/sentinel/" || echo "FAIL: contracts/sentinel/"
ls contracts/sentinel/*.md | wc -l | xargs -I{} echo "  {} sentinel contracts found"

# Check templates
find templates -name '*.md' | wc -l | xargs -I{} echo "  {} templates found"

# Git status
echo ""
echo "=== Git Status ==="
git log --oneline | head -10
echo ""
git status --short
```

## Commit

```bash
cd /tank/dump/DEV/deadfish-teams
git add hooks/ README.md
git commit -m "feat: hooks, README, validation complete

hooks: TeammateIdle, TaskCompleted, SubagentStop handlers
README: setup, architecture, methodology, usage guide"
```

## Acceptance Criteria
- DET: `hooks/hooks.json` exists and is valid JSON
- DET: `README.md` exists with Quick Start section
- DET: Validation script reports all PASS
- DET: All 7 git commits present (scaffold, artifacts, agents x2, CLAUDE.md, skills, hooks+readme)
