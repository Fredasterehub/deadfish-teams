# Task 01: Plugin Scaffold

You are building a Claude Code plugin called `deadfish-teams` at `/tank/dump/DEV/deadfish-teams/`.

## Create these files exactly:

### `.claude-plugin/plugin.json`
```json
{
  "name": "deadfish-teams",
  "description": "Autonomous development pipeline using Claude Code Agent Teams. Orchestrates brainstorm, plan, implement, verify, reflect cycles with specialized teammates and GPT-5.2/5.3-Codex integration.",
  "author": {
    "name": "Fred",
    "email": "fred@dimensionzero.net"
  }
}
```

### `.mcp.json` (at project root `/tank/dump/DEV/deadfish-teams/.mcp.json`)
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

### Create these empty directories (with .gitkeep):
- `agents/`
- `skills/brainstorm/`
- `skills/verify/`
- `skills/reflect/`
- `hooks/`
- `templates/track/`
- `templates/task/`
- `templates/verify/`
- `templates/bootstrap/`
- `templates/repair/`
- `contracts/sentinel/`
- `bin/`
- `docs/design/`

### Initialize git repo
```bash
cd /tank/dump/DEV/deadfish-teams
git init
git add -A
git commit -m "feat: plugin scaffold with dual Codex MCP config"
```

## Acceptance Criteria
- DET: `.claude-plugin/plugin.json` exists and is valid JSON
- DET: `.mcp.json` exists with both `codex-planner` and `codex-coder` entries
- DET: All directories exist
- DET: Git repo initialized with initial commit
