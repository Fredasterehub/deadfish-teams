<p align="center">
  <img src="https://img.shields.io/badge/Claude_Code-Agent_Teams-7C3AED?style=for-the-badge&logo=anthropic&logoColor=white" alt="Claude Code Agent Teams"/>
  <img src="https://img.shields.io/badge/Codex_CLI-GPT--5.3-10A37F?style=for-the-badge&logo=openai&logoColor=white" alt="Codex CLI"/>
  <img src="https://img.shields.io/badge/Protocol-Sentinel_v3-E34F26?style=for-the-badge&logo=markdown&logoColor=white" alt="Sentinel v3"/>
</p>

<h1 align="center">deadfish-teams</h1>

<p align="center">
  <strong>"Only a dead fish follows the flow."</strong>
</p>

<p align="center">
  An autonomous development pipeline that turns vibe coding<br/>
  into an engineered, verifiable process.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-0.0.0-blue?style=flat-square" alt="Version"/>
  <img src="https://img.shields.io/badge/node-%3E%3D18-339933?style=flat-square&logo=node.js&logoColor=white" alt="Node"/>
  <img src="https://img.shields.io/badge/python-3.x-3776AB?style=flat-square&logo=python&logoColor=white" alt="Python"/>
  <img src="https://img.shields.io/badge/license-TBD-lightgrey?style=flat-square" alt="License"/>
  <img src="https://img.shields.io/badge/tests-17%2F17_passing-brightgreen?style=flat-square" alt="Tests"/>
  <img src="https://img.shields.io/badge/agents-8_roles-blueviolet?style=flat-square" alt="Agents"/>
  <img src="https://img.shields.io/badge/sentinel_types-11-orange?style=flat-square" alt="Sentinel Types"/>
</p>

---

## The problem

You've seen it. Everyone has. You prompt an AI to build something, it writes code, you prompt again, it writes more code, and three hours later you're staring at a mess of half-working features with no tests, no plan, and no way to know what's actually done.

**This is vibe coding.** It works for prototypes. It collapses on anything real.

The failure modes are always the same:
- **Context drift** — the agent forgets what it was building by turn 40
- **Implicit decisions** — architecture choices buried in chat history, never written down
- **No quality gate** — nothing stops bad code from piling up
- **No crash recovery** — session dies, all progress lives in a dead conversation

deadfish-teams exists because we got tired of this.

---

## The fix

What if your AI development workflow worked like an **engineering team** instead of a chat session?

```
You define a bounded goal
    → a team plans it (with acceptance criteria)
        → another agent implements it (patch-sized, scoped)
            → verification gates decide: ship, replan, or escalate
```

That's deadfish. Not a framework. Not a wrapper. A **protocol** — a set of rules that multiple AI models follow to produce reliable software, with deterministic verification that no amount of LLM confidence can override.

<p align="center">
  <code>plan &rarr; implement &rarr; verify &rarr; verdict &rarr; repeat</code>
</p>

---

## Latest changes

<!-- BEGIN:LAST_UPDATES -->
_Last refreshed: 2026-02-09 03:26 UTC_

- 2026-02-09 &mdash; feat: Round 4 &mdash; npx installer, config gen, settings hooks, tests (efd7330)
- 2026-02-09 &mdash; fix: port repair template to v3 + align sentinel type lists (1caf039)
- 2026-02-09 &mdash; feat: Round 3 &mdash; discovery, tests, bootstrap, e2e smoke (1a696eb)
- 2026-02-09 &mdash; feat: Round 2 &mdash; v3 tooling + active templates (c607ede)
- 2026-02-09 &mdash; feat: Round 1 &mdash; v3 protocol foundation (e54b83e)
- 2026-02-06 &mdash; docs(readme): narrative README + latest updates section (fdab308)
- 2026-02-06 &mdash; feat: README + validation complete (d873801)
<!-- END:LAST_UPDATES -->

> This section auto-refreshes from git history. Run `./scripts/update_readme_latest_updates.sh --n 7` to update it.

---

## How it works

### Three ideas, fused

deadfish-teams is a fusion of three concepts that don't normally appear together:

| Concept | What it means here |
|---------|-------------------|
| **Claude Code Agent Teams** | 8 specialized AI agents with distinct roles, models, and permissions &mdash; coordinated through Claude's native task system |
| **Deterministic verification** | A shell script (`verify.sh`) whose exit code is **ground truth**. If the script says FAIL, the LLM's opinion is irrelevant. |
| **Multi-model routing** | Different models for different jobs: Opus for strategy, Sonnet for execution, Haiku for maintenance, GPT-5.2 for planning, GPT-5.3-Codex for implementation |

The result is a pipeline where AI agents don't just *write* code &mdash; they **plan** it against acceptance criteria, **implement** it within strict scope limits, **verify** it with deterministic tools, and **decide** whether it ships based on evidence, not vibes.

### The pipeline loop

Every unit of work follows the same cycle:

```
                    ┌─────────────────────────┐
                    │   1. SPEC & PLAN        │
                    │   bounded scope          │
                    │   acceptance criteria     │
                    │   task graph              │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   2. IMPLEMENT           │
                    │   one task at a time     │
                    │   ≤200 lines, ≤5 files   │
                    │   git commit per task     │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   3. VERIFY              │
                    │   verify.sh (det.)       │
                    │   + criteria fan-out     │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   4. VERDICT             │
                    │                          │
                    │   ✅ ship                │
                    │   🔁 replan              │
                    │   🧑‍⚖️ needs_human         │
                    └──────────────────────────┘
```

**The key insight:** tasks are the scheduler. No orchestrator loop, no cron, no external state machine. Claude Code's native task list (Ctrl+T) drives all work. Session crashes? Reopen. The task list is still there.

### The team

Eight agents. Each has a role, a model, and boundaries it cannot cross.

```
Lead (Opus) ─── delegate mode, never touches code
│
├── Discoverer (Sonnet)     brownfield detection, one-shot
├── Brainstormer (Opus)     BMAD ideation with human
├── Planner (Sonnet)        spec + plan + task packets via GPT-5.2
├── Coder (Sonnet)          implements tasks via GPT-5.3-Codex
├── QA Reviewer (Sonnet)    verify.sh + criteria → verdict
├── Conductor (Opus)        drift detection, stuck arbitration
├── Doc-keeper (Haiku)      living docs, significance-gated
└── Integrator (Sonnet)     cross-task friction, on-demand only
```

| Agent | Model | Why this model | What it cannot do |
|-------|-------|----------------|-------------------|
| **Lead** | Opus | Needs strategic judgment to delegate | Edit code, read logs, run tools |
| **Discoverer** | Sonnet | Fast evidence collection | Modify any files |
| **Brainstormer** | Opus | Creative ideation needs depth | Write implementation code |
| **Planner** | GPT-5.2 | Strong at structured decomposition | Implement, test, or commit |
| **Coder** | GPT-5.3-Codex | Fastest code generation | Skip verify.sh, modify specs |
| **QA** | Sonnet | Pessimistic judgment is a feature | Optimistically approve |
| **Conductor** | Opus | Needs full-context reasoning for drift | Write code or modify tasks |
| **Doc-keeper** | Haiku | Fast, cheap, significance-gated | Update docs without a PASS verdict |
| **Integrator** | Sonnet | Surgical cross-task fixes | Redesign architecture |

### Skills-first design

Instead of stuffing each agent with a massive system prompt, deadfish encodes its rules as **shared skills**. Update one skill, every agent that references it improves immediately.

| Skill | Encodes |
|-------|---------|
| `deadfish-core` | Universal invariants: verify.sh is truth, acceptance criteria are immutable, tasks are the scheduler |
| `deadfish-planning` | Spec format, plan format, task packets, scope limits (≤200 lines, ≤5 files) |
| `deadfish-verify` | verify.sh protocol, criteria rubric (EXISTS / SUBSTANTIVE / WIRED), verdict format |
| `deadfish-implement` | Git commit conventions, retry protocol, Codex MCP usage |
| `deadfish-docs` | Living docs format, 7 files with character budgets, significance gate |
| `deadfish-conductor` | Drift detection protocol, boundary evaluation, stuck arbitration flowchart |
| `deadfish-discovery` | Brownfield detection, evidence collection, `discovery.md` output |

### The sentinel protocol

All structured communication between agents uses **sentinel blocks** &mdash; markdown code fences with typed YAML content:

````markdown
```deadfish:VERDICT
scope: TASK
task_id: auth-P1-T02
verify_sh: PASS
criteria:
  - criterion_id: AC-01
    status: PASS
    evidence: "JWT middleware wired in src/auth/middleware.ts:14"
decision: PASS
```
````

Eleven types, each with a schema: `SPEC`, `PLAN`, `TASK`, `TRACK`, `VERDICT`, `VERDICT_CRITERION`, `CONDUCTOR`, `DOCSYNC`, `IMPLEMENT`, `INTEGRATE`, `DIAGNOSTIC`.

Agents parse them with `bin/parse-blocks.py`. Verdicts aggregate with `bin/build-verdict.py`. The schemas live in `contracts/sentinel/v3/schemas.yaml`. If a block doesn't validate, it's a protocol error &mdash; not a matter of opinion.

---

## Install

### One command

```bash
npx deadfish-teams init
```

The interactive installer asks you five questions:

1. **Scope** &mdash; global (`~/.claude/`) or local (`./.claude/`)
2. **Provider routing** &mdash; `anthropic-only`, `codex-mcp`, or `hybrid`
3. **Model preferences** &mdash; which models for planner, coder, and QA
4. **Brownfield detection** &mdash; enable auto-detection of existing codebases
5. **Task list ID pattern** &mdash; naming convention for persistent task lists

Or skip the questions:

```bash
npx deadfish-teams --global                      # defaults, global scope
npx deadfish-teams --local --provider hybrid     # local, hybrid routing
npx deadfish-teams --uninstall                   # clean removal
npx deadfish-teams --local --dry-run             # preview without writing
```

### What gets installed

```
~/.claude/plugins/deadfish-teams/     # (or ./.claude/plugins/...)
├── agents/                           # 8 role definitions
├── skills/                           # 7 shared skill files
├── templates/                        # bootstrap + task + verify templates
├── contracts/sentinel/v3/            # protocol schemas
├── bin/                              # deterministic tools (Python + Shell)
├── hooks/                            # lifecycle event scripts
├── docs/living/                      # 7 living doc files + scratch buffer
├── CLAUDE.md                         # orchestrator contract
├── deadfish.config.yaml              # your model + provider choices
├── .mcp.json                         # Codex MCP server config (if applicable)
└── .deadfish-install/
    ├── manifest.json                 # SHA-256 hashes of every installed file
    └── backups/<timestamp>/          # your edits, preserved on upgrade
```

**Upgrade safety:** reinstalling backs up any file you've modified before overwriting. Your edits are never lost.

### Prerequisites

| Requirement | Why |
|-------------|-----|
| **Node.js >= 18** | Installer runtime |
| **Claude Code CLI** | Agent Teams host |
| **Codex CLI** | MCP server for GPT-5.x models (if using `codex-mcp` or `hybrid`) |
| **Python 3 + PyYAML** | Sentinel parsing and verification tools |
| **Git** | Task tracking, diff analysis, scope enforcement |

```bash
# Enable Agent Teams (required)
# Add to ~/.claude/settings.json:
{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }

# Install Python deps
pip install pyyaml
```

> **Dev checkout?** If you're hacking on deadfish-teams itself, symlink instead:
> `ln -s /path/to/deadfish-teams ~/.claude/plugins/deadfish-teams`

---

## Quick start

### 1. Install

```bash
npx deadfish-teams init
```

### 2. Open your project in Claude Code

```bash
cd your-project
claude
```

### 3. Spawn the team

Paste the kickoff prompt from [`CLAUDE.md`](./CLAUDE.md), or use this minimal version:

```
Create an AGENT TEAM named "deadfish" with these teammates:
  discoverer, brainstormer, planner, coder, qa-reviewer,
  conductor, doc-keeper, integrator

Rules:
- I (Lead) operate in delegate mode. I will not edit code.
- All work is represented as Tasks with dependencies.
- Deterministic truth is bin/verify.sh output.
- Use deadfish sentinel code fences for structured outputs.

Spawn the teammates and wait for my instruction.
```

Then press **Shift+Tab** to enter delegate mode.

### 4. Give it a goal

```
Plan and implement user authentication with JWT.
Acceptance criteria:
- AC-01: Login endpoint returns signed JWT
- AC-02: Protected routes reject expired tokens
- AC-03: Refresh token rotation works
```

The team takes it from there: discovery pass, spec, plan, task packets, implementation, verification, verdict. You approve or redirect at each stage.

---

## What makes this different

### vs. "just prompting Claude"

| | Plain prompting | deadfish-teams |
|---|---|---|
| State | Chat history (lost on crash) | Git-tracked files + persistent task list |
| Quality gate | "Looks good to me" | `verify.sh` exit code is law |
| Scope control | Hope the LLM stays focused | ≤200 lines, ≤5 files, enforced |
| Recovery | Start over | Reopen session, task list intact |
| Architecture | Implicit in the conversation | Explicit spec + plan, immutable once approved |

### vs. Aider / OpenHands / other coding agents

| Capability | Aider | OpenHands | deadfish-teams |
|-----------|-------|-----------|----------------|
| Multi-model routing | Single model | Single model | 5 models, role-matched |
| Deterministic verification | None (LLM judgment) | Partial | `verify.sh` is ground truth |
| Living documentation | None | None | 7 docs, budget-capped, significance-gated |
| Drift detection | None | None | Conductor agent with boundary evaluation |
| Crash recovery | Git-based | Checkpoint-based | Task list persistence + git artifacts |
| Brownfield awareness | None | None | Discovery pass before planning |
| Structured protocol | None | None | 11 sentinel types with schemas |

---

## Architecture deep dive

### The four layers

```
┌─────────────────────────────────────────────────────────┐
│  LAYER 4: ROLES                                         │
│  8 agent definitions + 7 skills + tool permissions      │
├─────────────────────────────────────────────────────────┤
│  LAYER 3: PROTOCOL                                      │
│  11 sentinel types + schemas.yaml + parse-blocks.py     │
├─────────────────────────────────────────────────────────┤
│  LAYER 2: ARTIFACTS                                     │
│  Git-tracked files: spec, plan, packets, conductor      │
│  state, living docs, verdicts                           │
├─────────────────────────────────────────────────────────┤
│  LAYER 1: STATE                                         │
│  Claude Code Tasks (Ctrl+T) — deps, status, assignment  │
└─────────────────────────────────────────────────────────┘
```

**Layer 1** is the scheduler. **Layer 2** is the memory. **Layer 3** is the language. **Layer 4** is the team.

### Verification: the hard gate

`verify.sh` runs deterministic checks that no agent can override:

| Check | What it catches |
|-------|----------------|
| **Tests** | Test suite must pass |
| **Linter** | Code style violations |
| **Diff budget** | Changes exceeding 3x the estimated diff size |
| **Scope** | Files modified outside the task's declared scope |
| **Secrets** | Credentials or API keys in the diff |
| **Git clean** | Uncommitted changes (post-commit mode) |

Output is structured JSON. Exit code 0 always (result in the `pass` field). This means agents can always parse the output &mdash; they don't need to handle crashed verification scripts.

On top of verify.sh, the QA agent evaluates each acceptance criterion against a three-tier rubric:

- **EXISTS** &mdash; the artifact appears in the diff
- **SUBSTANTIVE** &mdash; it's real code, not a TODO or stub
- **WIRED** &mdash; it's connected (imported, routed, configured, tested)

All three must pass. The system is intentionally pessimistic: false negatives are OK, false positives are expensive.

### Living docs: bounded, not bloated

Seven documentation files maintained by the Doc-keeper agent, each with a **character budget**:

| Doc | Budget | Tracks |
|-----|--------|--------|
| `TECH_STACK.md` | 3,200 chars | Languages, frameworks, versions |
| `PATTERNS.md` | 3,200 chars | Architecture patterns, conventions |
| `PITFALLS.md` | 2,800 chars | Known gotchas, anti-patterns |
| `RISKS.md` | 2,000 chars | Security, operational risks |
| `PRODUCT.md` | 2,800 chars | Features, API surface |
| `WORKFLOW.md` | 2,800 chars | CI/CD, scripts, dev workflow |
| `GLOSSARY.md` | 2,000 chars | Domain terms, naming |

Total budget: ~18,800 characters. Updates only happen after a PASS verdict and only when significance triggers fire (manifest changed, diff > 120 lines, new pattern discovered, etc.). A scratch buffer (`docs/living/.scratch.yaml`) holds observations that haven't reached the significance threshold yet.

---

## Repo map

```
deadfish-teams/
├── agents/                    # 8 agent role definitions
│   ├── brainstormer.md
│   ├── coder.md
│   ├── conductor.md
│   ├── discoverer.md
│   ├── doc-keeper.md
│   ├── integrator.md
│   ├── planner.md
│   └── qa-reviewer.md
├── skills/                    # 7 shared skills (the real brain)
│   ├── deadfish-core/
│   ├── deadfish-planning/
│   ├── deadfish-verify/
│   ├── deadfish-implement/
│   ├── deadfish-docs/
│   ├── deadfish-conductor/
│   └── deadfish-discovery/
├── contracts/sentinel/v3/     # protocol schemas + type contracts
├── templates/                 # bootstrap, task, track, verify, repair
├── bin/                       # deterministic tools
│   ├── verify.sh              #   the hard gate
│   ├── parse-blocks.py        #   sentinel parser
│   ├── build-verdict.py       #   verdict aggregator
│   ├── packet-to-task.py      #   task packet → prompt
│   ├── discover-detect.sh     #   brownfield classifier
│   ├── discover-collect.sh    #   evidence collector
│   └── installer/             #   npx install machinery
├── hooks/                     # lifecycle event scripts
├── docs/living/               # 7 budget-capped living docs
├── scripts/                   # repo maintenance utilities
├── tests/                     # smoke + installer test suites
├── CLAUDE.md                  # orchestrator contract
├── package.json               # npm manifest
└── requirements.txt           # Python dependencies (pyyaml)
```

---

## Configuration

The installer generates two config files:

### `deadfish.config.yaml`

```yaml
install:
  scope: 'global'
  provider: 'hybrid'
models:
  planner: 'gpt-5.2'
  coder: 'gpt-5.3-codex'
  qa: 'gpt-5.3-codex'
features:
  brownfield_detection: true
task_list_id_pattern: 'deadfish-YYYYMMDD'
```

### `.mcp.json` (generated for `codex-mcp` and `hybrid` providers)

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

For `anthropic-only` provider, `.mcp.json` contains an empty `mcpServers` object and all agents use Anthropic models directly.

---

## Tests

```bash
# v3 protocol smoke tests (10 cases)
bash tests/smoke-run.sh

# installer tests (7 cases)
bash tests/test-installer.sh
```

Both suites run in isolated temp directories and clean up after themselves.

---

## Known limitations

- **Agent Teams is experimental** &mdash; requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- **GPT-5.3 model availability** &mdash; some model IDs may not be available under all subscription tiers; verify before hardcoding
- **The pipeline is only as good as your verification gates** &mdash; invest in your test suite and linter config
- **No context budget management yet** &mdash; long sessions may hit token limits (tracking this gap)

---

## Contributing

deadfish-teams follows its own rules:

1. **Small PRs** &mdash; one concern per change
2. **Acceptance criteria upfront** &mdash; define "done" before writing code
3. **Verification before merge** &mdash; `bash tests/smoke-run.sh && bash tests/test-installer.sh`
4. **Sentinel protocol for structured output** &mdash; if it's a plan, spec, or verdict, use the fences

---

## License

TBD.

---

<p align="center">
  <sub>Built with <a href="https://claude.ai/claude-code">Claude Code</a> + <a href="https://openai.com/codex">Codex CLI</a> by <a href="mailto:fred@dimensionzero.net">Fred @ Dimension Zero</a></sub>
</p>
