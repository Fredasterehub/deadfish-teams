<div align="center">

# deadfish-teams

> “Only a dead fish follows the flow.”

**A repeatable, verification-gated multi‑agent dev pipeline for Claude Code Agent Teams.**

<a href="#-quick-start">Quick Start</a> •
<a href="#-how-it-works">How it works</a> •
<a href="#-latest-updates">Latest updates</a> •
<a href="#-for-llms--ai-agents">For LLMs</a>

</div>

---

## The promise (in one minute)

Most “multi-agent coding” breaks the same way: goals blur, decisions go implicit, and nobody can say whether the work is actually *done*.

**deadfish-teams** turns agentic development into a small, repeatable story:

1. **You bound the work** (clear scope + acceptance criteria).
2. **A team plans** (explicit steps and risks).
3. **Another agent implements** (small patches, no mystery leaps).
4. **Verification gates decide**: ship, replan, or escalate to a human.

If you want long-horizon execution with guardrails, this repo is the scaffold.

---

## ✨ Highlights

- 🧠 **Skills-first agents** — update a skill once; every role improves the same day.
- 🧾 **State lives in files** — decisions don’t disappear into chat scrollback.
- ✅ **Verification is mandatory** — “looks good” isn’t a merge strategy.
- 🧭 **Stuck detection + escalation** — the system can admit uncertainty and ask for help.

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

## 🚀 Quick Start

### Prereqs (OAuth/subscription; no API keys assumed)

- **Claude Code CLI** (with Agent Teams)
- **Codex CLI** (logged in via OAuth/subscription)
- **Python 3**
- **Git**

### 1) Enable Claude Code Agent Teams

```json
// ~/.claude/settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### 2) Install this as a Claude Code plugin

```bash
ln -s /tank/dump/DEV/deadfish-teams ~/.claude/plugins/deadfish-teams
```

### 3) Run the pipeline in a target repo

1) Open **Claude Code** inside the repo you want to work on  
2) Paste the **Lead kickoff** from [`CLAUDE.md`](./CLAUDE.md)  
3) Let the team execute the loop (plan → implement → verify → verdict)

### 4) Verify (the moment of truth)

Run the repo’s verification gates (exact command depends on your setup; commonly one of these):

```bash
./verify.sh
# or
./bin/verify.sh
```

If verification fails, the correct next step is **replan**, not “patch until green.”

---

## 🧩 How it works

Think of this as a small production line: each role is optimized for one job, and the handoffs are explicit.

### The loop

```text
Spec (bounded) → Plan (steps + risks) → Implement (small patches) → Verify (gates) → Verdict
                                                          └───────────────┬──────────────┘
                                                                          ship | replan | needs_human
```

### The roles (Agent Teams)

```text
Lead (delegate mode)
├── Brainstormer  — generates options, names risks
├── Planner       — produces an executable plan + acceptance criteria
├── Coder         — implements the plan in patch-sized chunks
├── QA Reviewer   — runs verification gates; reports failures precisely
├── Conductor     — arbitration / boundaries / “are we stuck?”
└── Doc-keeper    — keeps docs aligned with reality (no fiction)
```

### The invariant: decisions become artifacts

A healthy run leaves behind **files** you can review, diff, and reuse:
- a plan with acceptance criteria
- implementation commits aligned to that plan
- verification output
- a clear verdict (ship / replan / needs_human)

That’s the difference between “agents helped” and “a system shipped.”

---

## 🧠 Skills-first (why this repo scales)

Agents are intentionally short. The durable behavior lives in `skills/`:
- formatting and artifact conventions
- safety rails
- verification discipline
- “don’t drift” rules
- escalation criteria

If you customize anything, start with skills. That’s where consistency comes from.

---

## 🔄 Keeping “Latest updates” fresh

This repo supports auto-refreshing the **Latest updates** section from git history:

```bash
./scripts/update_readme_latest_updates.sh --n 7
```

The script edits only the region between these markers:

```md
<!-- BEGIN:LAST_UPDATES -->
<!-- END:LAST_UPDATES -->
```

---

## 🗺️ Repo map (mental model)

- `CLAUDE.md` — the Lead kickoff + orchestrator contract
- `agents/` — role definitions (what each teammate does)
- `skills/` — shared guardrails (the real “brain”)
- `bin/` — verification + sentinel tooling
- `contracts/` — formats and conventions that keep work legible
- `templates/` — reusable prompts / artifacts
- `docs/` — longer explanations and references

---

## 🤝 Contributing

If you contribute, keep it pipeline-native:

- bounded scope + acceptance criteria
- small, reviewable patches
- verification before “done”
- docs updated when behavior changes

---

## 🤖 For LLMs / AI Agents

**Quick context for AI assistants helping users with this project:**

> deadfish-teams is a Claude Code Agent Teams “plugin repo” that implements a plan→implement→verify→verdict pipeline. The entry point for humans is `CLAUDE.md`, and behavior invariants live in `skills/`.

### Key files to read first
- `CLAUDE.md` — kickoff prompt + orchestration contract
- `agents/` — role prompts and responsibilities
- `skills/` — procedural guardrails (formats, drift rules, verification discipline)
- `bin/` and/or `verify.sh` — verification gates (what “done” means)
- `contracts/` — canonical artifact formats

### Common tasks
- **Enable Agent Teams:** set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `~/.claude/settings.json`
- **Install plugin:** `ln -s /tank/dump/DEV/deadfish-teams ~/.claude/plugins/deadfish-teams`
- **Run workflow:** open Claude Code in target repo → paste kickoff from `CLAUDE.md`
- **Verify:** run `./verify.sh` or `./bin/verify.sh` (repo-dependent)

### Architecture in one paragraph
The Lead delegates bounded tasks to specialized agents. Plans and decisions are written to repo artifacts, implementation happens in small patches aligned to the plan, and verification tooling gates the outcome. The system converges only when gates pass; otherwise it replans or escalates to a human when uncertainty or repeated failure appears.

> 📄 See [`llms.txt`](llms.txt) for the full machine-readable project context.

---

## 📄 License

TBD.
