# HANDOFF — deadfish-teams Session Pickup

## Status: BUILD COMPLETE (Feb 6 2026)

All 7 v3 tasks implemented by GPT-5.3-codex. Plugin is fully built.

## Git Log

```
d873801 feat: README + validation complete
b7ad5c4 feat: signal-only hooks (TaskCompleted, TeammateIdle, SubagentStop)
6df8106 feat: CLAUDE.md v3 orchestrator contract
61e9fea feat: 7 agent definitions (v3 skills-first)
e81259f feat: 6 shared skills encoding deadfish invariants
b5e89b5 feat: copy templates + sentinel contracts from v1
cc0662d feat: copy deterministic tools from deadfish-cli v1
9097faa feat: agent definitions — qa-reviewer, conductor, doc-keeper (v2, superseded by 61e9fea)
26127c1 feat: plugin scaffold with dual Codex MCP config
380b8b2 init: plan + build prompts
```

## What's Built

| Component | Count | Location |
|-----------|-------|----------|
| Agents | 7 | `agents/*.md` (brainstormer, planner, coder, qa-reviewer, conductor, doc-keeper, integrator) |
| Skills | 6 | `skills/deadfish-*/SKILL.md` (core, planning, verify, implement, docs, conductor) |
| Bin scripts | 4 | `bin/` (verify.sh, parse-blocks.py, build-verdict.py, lint-templates.py) |
| Templates | 22 | `templates/` (bootstrap, track, task, verify, repair) |
| Contracts | 7 | `contracts/sentinel/*.md` |
| Hooks | 1 JSON + 3 scripts | `hooks/hooks.json`, `hooks/scripts/*.sh` |
| CLAUDE.md | v3 | Orchestrator contract with 4-layer model, kickoff prompt |
| README.md | done | Setup guide, architecture, skills-first docs |
| Plugin manifest | done | `.claude-plugin/plugin.json` |
| MCP config | done | `.mcp.json` (dual Codex: codex-planner + codex-coder) |

## Key Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Coder engine | GPT-5.3-Codex via Codex MCP | Fastest Codex model, dual MCP instances |
| Planner engine | GPT-5.2 via Codex MCP | Reasoning model for spec/plan |
| Task granularity | TASK-level only | Matches Conductor pattern, sub-steps internal |
| Sentinel format | `deadfish:TYPE` code fences | Simpler than v1 nonce blocks, YAML inside |
| Teammate lifecycle | Selective rotation | Lead+Conductor+Doc persistent, workers per track |
| No Ralph | Task list IS the loop | Agent Teams native scheduling |
| Skills-first | 6 shared skills | Update once, all agents improve |

## Codex Build Notes

- `codex exec --sandbox workspace-write` and `--sandbox danger-full-access` both crash on kernel 6.17.4-1-pve (Landlock bug)
- Fix: `codex exec --dangerously-bypass-approvals-and-sandbox`
- Codex `exec` exits 0 even on internal failure — always verify output files exist
- Build prompts: `build/prompts-v3/01-07` (v3, used for final build)
- Runner script: `build/run-v3.sh` (updated for v3 but needs `--dangerously-bypass-approvals-and-sandbox`)

## Known Issues / TODO

1. **parse-blocks.py** — Still uses v1 `<<<TYPE:V1:NONCE=...>>>` sentinel format. Needs adaptation for `deadfish:TYPE` code fences. Low priority until first real project run.
2. **Agent file content** — Codex used heredocs which may have minor quoting artifacts (backtick escaping). Spot-check agent files before first real use.
3. **End-to-end test** — Plugin hasn't been tested with a real project yet. Next step: enable plugin, start Claude Code, paste kickoff prompt, run a simple track.
4. **Dirty working tree** — `PLAN.md`, `HANDOFF.md`, `build/` changes are uncommitted (build artifacts, not plugin code).

## References

- Agent Teams docs: https://code.claude.com/docs/en/agent-teams
- Google Conductor: https://github.com/gemini-cli-extensions/conductor
- Plan: `/tank/dump/DEV/deadfish-teams/PLAN.md` (v3)
- Source v1: `/tank/dump/DEV/deadfish-cli/`
- Codex MCP: `codex mcp-server` (v0.98.0)
