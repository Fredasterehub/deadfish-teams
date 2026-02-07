

# deadfish-teams

> "Only a dead fish follows the flow."

---

You've tried multi-agent coding. It started well — then context drifted, implicit decisions piled up, and nobody noticed quality slipping until it was too late.

**deadfish-teams** replaces that chaos with a pipeline: **plan → implement → verify → verdict**. Every decision is a file. Every gate is deterministic. When something is stuck, the system knows — and escalates.

It runs on **Claude Code Agent Teams**. You define a bounded goal, a team plans it, another agent implements it, and verification gates decide whether it ships, replans, or asks a human.

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

## Quick start

### Prerequisites

- **Claude Code CLI** with Agent Teams enabled
- **Codex CLI** (OAuth / subscription login)
- **Python 3** and **Git**

### 1. Enable Agent Teams

```json
// ~/.claude/settings.json
{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
```

### 2. Install the plugin

```bash
ln -s /tank/dump/DEV/deadfish-teams ~/.claude/plugins/deadfish-teams
```

### 3. Start a session

Open Claude Code inside your target repo. Paste the **Lead kickoff prompt** from [`CLAUDE.md`](./CLAUDE.md). The Lead spawns the team and enters delegate mode.

That's it. The pipeline runs.

---

## The problem this solves

Multi-agent workflows fail in predictable ways:

| Failure mode | What happens | deadfish fix |
|---|---|---|
| **Context drift** | Agents forget the goal mid-session | State lives in files, not chat scrollback |
| **Implicit decisions** | "I assumed X" cascades into broken output | Plans are explicit artifacts with acceptance criteria |
| **Silent quality decay** | No one notices the code is wrong | `bin/verify.sh` gates are mandatory — LLM judgment is secondary |
| **Stuck loops** | Agent retries the same failing approach | Conductor detects stuck state and escalates |

The pipeline is only as good as the verification gates you enforce. That's by design — it forces you to define "done" upfront.

---

## How the pipeline works

```
Spec & Plan ──→ Implement ──→ Verify ──→ Verdict
                                           │
                              ┌─────────────┼─────────────┐
                              ▼             ▼             ▼
                           ✅ ship      🔁 replan    🧑‍⚖️ needs_human
```

Each cycle is bounded. Work is broken into patch-sized tasks with explicit dependencies. Verification is deterministic (`bin/verify.sh`), not vibes.

### The team

```
Lead (Opus, persistent, delegate mode)
├── Brainstormer     — ideation with the human; writes seed docs, then shuts down
├── Planner          — produces SPEC + PLAN + task packets, then shuts down
├── Coder            — implements one packet at a time; commits per task
├── QA Reviewer      — runs bin/verify.sh + acceptance criteria; produces a VERDICT
├── Conductor        — drift detection, boundary evaluation, stuck arbitration
├── Doc-keeper       — updates living docs only after a PASS verdict
└── Integrator       — resolves cross-task friction only when requested
```

**Persistent agents** (Lead, Conductor, Doc-keeper) carry context across tracks. **Rotating agents** (Planner, Coder, QA, Integrator) start fresh each track — no stale assumptions.

### Skills-first design

Agents are thin. The real logic lives in **skills** — shared procedural guardrails that encode format rules, safety checks, verification protocols, and drift detection. Update one skill, and every agent that references it improves.

---

## Repo structure

```
agents/       — role prompts (one per agent)
skills/       — procedural guardrails (the real brain)
bin/          — verification + sentinel tooling
contracts/    — formats and conventions
templates/    — reusable prompt and artifact templates
docs/         — longer-form documentation
CLAUDE.md     — orchestrator contract + Lead kickoff prompt
```

---

## Keeping the README current

This repo includes a script that refreshes the **Latest updates** section from git history:

```bash
./scripts/update_readme_latest_updates.sh --n 7
```

The markers `<!-- BEGIN:LAST_UPDATES -->` and `<!-- END:LAST_UPDATES -->` define the replacement zone.

---

## Known limitations

- Some model names referenced in agent configs (e.g., GPT-5.3 variants) may not yet be available under subscription/OAuth. Verify availability before use.
- The pipeline assumes you write meaningful acceptance criteria. Weak gates produce weak results.

---

## Contributing

Keep it disciplined:

- Small PRs with acceptance criteria defined upfront
- Verification passes before merge
- Skills changes reviewed for cross-agent impact

---

## License

TBD.
