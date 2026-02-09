# deadfish-teams

> "Only a dead fish follows the flow."

**deadfish-teams** ports the **deadfish autonomous dev pipeline** into **Claude Code Agent Teams**.

Instead of “vibe coding until it works,” it gives you a *repeatable story*:

1. You define a bounded goal.
2. A team plans it.
3. Another agent implements it.
4. Verification gates decide if it ships, replans, or escalates.

If you care about **quality, guardrails, and long-horizon execution**, this is the play.

---

## 🆕 Latest updates

<!-- BEGIN:LAST_UPDATES -->
_Last refreshed: 2026-02-06 10:14 UTC_

- 2026-02-06 — feat: README + validation complete (d873801)
- 2026-02-06 — feat: signal-only hooks (TaskCompleted, TeammateIdle, SubagentStop) (b7ad5c4)
- 2026-02-06 — feat: CLAUDE.md v3 orchestrator contract (6df8106)
- 2026-02-06 — feat: 7 agent definitions (v3 skills-first) (61e9fea)
- 2026-02-06 — feat: 6 shared skills encoding deadfish invariants (e81259f)
- 2026-02-06 — feat: copy templates + sentinel contracts from v1 (b5e89b5)
- 2026-02-06 — feat: copy deterministic tools from deadfish-cli v1 (cc0662d)
<!-- END:LAST_UPDATES -->

---

## Why this exists

Most multi-agent workflows fail in predictable ways: context drift, inconsistent “implicit decisions,” and no hard stop when quality slips.

**deadfish-teams** exists to make agentic development feel like an *engineered process*:
- **State lives in files**, not in chat scrollback.
- **Plans are explicit**, not implied.
- **Verification is mandatory**, not optional.
- The system knows when it’s stuck and **escalates**.

---

## What you get

- **Claude Code Agent Teams** setup (Lead + specialized agents)
- A **skills-first** design: update one skill → all agents improve
- A consistent **plan → implement → verify → verdict** loop
- A repo structure meant to survive long-running work

---

## Distribution / Install

Install via `npx`:

```bash
npx deadfish-teams init
npx deadfish-teams --global
npx deadfish-teams --local
npx deadfish-teams --uninstall
npx deadfish-teams --local --uninstall
```

Install targets:
- Global scope: `~/.claude/plugins/deadfish-teams`
- Local scope: `./.claude/plugins/deadfish-teams`

Settings/hook registration target:
- Global install: `~/.claude/settings.json`
- Local install: `./.claude/settings.json`

Upgrade safety and patch persistence:
- Reinstall preserves operator edits by backing up modified tracked files before overwrite.
- Backups are written under: `.deadfish-install/backups/<timestamp>/...` inside the plugin root.
- Example local backup path: `./.claude/plugins/deadfish-teams/.deadfish-install/backups/<timestamp>/README.md`

---

## Quick start (5 minutes)

### Prerequisites

- **Claude Code CLI** (Agent Teams enabled)
- **Codex CLI** (OAuth / subscription login)
- **Python 3**
- **Git**

> Note: The README you’re reading is written for our subscription/OAuth setup. If you’re using API keys, you can adapt it.

### 1) Enable Agent Teams

```json
// ~/.claude/settings.json
{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
```

### 2) Install the Claude Code plugin

```bash
npx deadfish-teams init        # interactive
# or: npx deadfish-teams --global   (non-interactive, defaults)
```

> **Dev checkout?** If you're working from a local clone, you can symlink instead:
> `ln -s /path/to/deadfish-teams ~/.claude/plugins/deadfish-teams`

### 3) Install Python dependencies

```bash
pip install -r requirements.txt
```

- `bin/parse-blocks.py` prefers PyYAML parsing.
- Stdlib fallback: if a `deadfish:TYPE` fence payload is valid JSON, parser paths can decode it via `json.loads()` without YAML-specific syntax.

### 4) Start a new project session

Open Claude Code inside your target repo, then paste the **Lead kickoff** prompt from [`CLAUDE.md`](./CLAUDE.md).

---

## How it works (the pipeline story)

### The loop

1. **Spec & plan** (bounded scope, acceptance criteria)
2. **Implementation** (patch-sized changes)
3. **Verification** (`verify.sh` + quality gates)
4. **Verdict**
   - ✅ ship
   - 🔁 replan
   - 🧑‍⚖️ needs_human

### Roles (Agent Teams)

```text
Lead (delegate mode)
├── Brainstormer     — generate options, name risks
├── Planner          — produces a concrete plan + acceptance criteria
├── Coder            — implements the plan
├── QA Reviewer      — runs verification gates + reports failures
├── Conductor        — arbitration / boundaries / “are we stuck?”
└── Doc-keeper       — keeps the docs aligned with reality
```

### Skills-first

Skills encode invariants (format, safety, verification, drift rules). Agents stay short and reference skills.

---

## Dynamic README updates

This repo includes a script that keeps the **Latest updates** section fresh from git history.

```bash
./scripts/update_readme_latest_updates.sh --n 7
```

Markers live in the README:

```md
<!-- BEGIN:LAST_UPDATES -->
_Last refreshed: 2026-02-06 10:14 UTC_

- 2026-02-06 — feat: README + validation complete (d873801)
- 2026-02-06 — feat: signal-only hooks (TaskCompleted, TeammateIdle, SubagentStop) (b7ad5c4)
- 2026-02-06 — feat: CLAUDE.md v3 orchestrator contract (6df8106)
- 2026-02-06 — feat: 7 agent definitions (v3 skills-first) (61e9fea)
- 2026-02-06 — feat: 6 shared skills encoding deadfish invariants (e81259f)
- 2026-02-06 — feat: copy templates + sentinel contracts from v1 (b5e89b5)
- 2026-02-06 — feat: copy deterministic tools from deadfish-cli v1 (cc0662d)
<!-- END:LAST_UPDATES -->
```

---

## Known limitations (right now)

- Some “vNext” model names (ex: GPT‑5.3 variants) may not be available under subscription/OAuth rails yet.
  - Verify availability before hardcoding model IDs.
- The pipeline is only as good as the **verification gates** you enforce.

---

## Repo map

- `agents/` — role prompts
- `skills/` — procedural guardrails (the real brain)
- `bin/` — verification + sentinel tooling
- `templates/` — reusable prompt and artifact templates
- `contracts/` — formats and conventions
- `docs/` — longer docs

---

## Contributing

If you contribute, keep it disciplined:
- small PRs
- acceptance criteria upfront
- verification before merge

---

## License

TBD.
