<p align="center">
  <img src="https://img.shields.io/badge/Claude_Code-Agent_Teams-7C3AED?style=for-the-badge&logo=anthropic&logoColor=white" alt="Claude Code Agent Teams"/>
  <img src="https://img.shields.io/badge/Codex_CLI-GPT--5.3-10A37F?style=for-the-badge&logo=openai&logoColor=white" alt="Codex CLI"/>
  <img src="https://img.shields.io/badge/Protocol-Sentinel_v3-E34F26?style=for-the-badge&logo=markdown&logoColor=white" alt="Sentinel v3"/>
</p>

<h1 align="center">deadfish-teams</h1>

<p align="center">
  <strong>"Only a dead fish follows the flow."</strong><br/>
  <sub>An opinionated workflow for building real software with AI agent teams.</sub>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-0.1.0-blue?style=flat-square" alt="Version"/>
  <img src="https://img.shields.io/badge/node-%3E%3D18-339933?style=flat-square&logo=node.js&logoColor=white" alt="Node"/>
  <img src="https://img.shields.io/badge/python-3.x-3776AB?style=flat-square&logo=python&logoColor=white" alt="Python"/>
  <img src="https://img.shields.io/badge/tests-17%2F17_passing-brightgreen?style=flat-square" alt="Tests"/>
  <img src="https://img.shields.io/badge/agents-8_roles-blueviolet?style=flat-square" alt="Agents"/>
  <img src="https://img.shields.io/badge/license-TBD-lightgrey?style=flat-square" alt="License"/>
</p>

---

## The story

This is my attempt at creating what I would consider an efficient and optimized workflow to help you develop any &mdash; or at least most &mdash; ideas you might have.

Over the last couple of months I've had the chance to play around and get great results from some amazing open-source projects:

| Project | What caught my attention |
|---------|------------------------|
| [**BMAD Method**](https://github.com/bmadcode/BMAD-METHOD) | Structured brainstorming that actually converges. Not "generate 10 ideas" &mdash; a real ideation-to-requirements pipeline with roles. |
| [**Oh My OpenCode**](https://github.com/nicekid1/Oh-my-OpenCode) | Showed me how far you can push a CLI dev tool with extensions and hooks. The composability was eye-opening. |
| [**Google Conductor**](https://github.com/google-gemini/gemini-cli) | Gemini CLI's orchestration layer. Proved multi-agent coordination is real &mdash; but also exposed the gap: zero context management. |
| [**GSD &mdash; Get Shit Done**](https://github.com/cline/gsd-protocol) | The one that's almost king. Plans-as-prompts, task packets, verification gates. The closest thing to "engineering discipline for AI coding." |

I tried to combine the different strengths of each and improve from the combination of all the concepts together. The result is deadfish-teams.

---

## What I took from each

**From BMAD:** the brainstorming pipeline. Deadfish doesn't just ask "what should we build?" &mdash; it runs a structured ideation process (7 brainstorm templates) that produces a real spec with acceptance criteria. Not vibes. Requirements.

**From OpenCode:** the plugin architecture. Deadfish installs as a Claude Code plugin with hooks, skills, and agent definitions. Composable, swappable, upgradeable without losing your customizations.

**From Conductor:** multi-agent coordination. But where Conductor stops at orchestration, deadfish adds **drift detection** (a dedicated Conductor agent that watches for scope creep) and **crash recovery** (tasks persist across sessions).

**From GSD:** almost everything structural. Plans-as-prompts, task packets, deterministic verification, scope limits. GSD is the backbone. What deadfish adds on top: **multi-model routing** (5 different models matched to roles), **living documentation** (7 budget-capped docs maintained automatically), and a **structured protocol** (11 sentinel types with schemas, not free-form text).

---

## What you actually get

```
You define a goal with acceptance criteria
    a team of 8 AI agents plans it
        another agent implements it (patch-sized, scoped)
            a verification script decides: ship, replan, or escalate
```

That loop &mdash; **plan, implement, verify, verdict** &mdash; runs for every task. No exceptions. The verification script (`verify.sh`) is law: if it says FAIL, no amount of LLM confidence overrides it.

Your agents use different models for different jobs:

```
Lead (Opus)            strategic delegation, never touches code
Brainstormer (Opus)    BMAD-style ideation with the human
Planner (GPT-5.2)      structured decomposition into task packets
Coder (GPT-5.3-Codex)  fastest code generation, scoped to one task
QA (Sonnet)            pessimistic by design, runs the hard gate
Conductor (Opus)       drift detection, "are we building the right thing?"
Doc-keeper (Haiku)     maintains 7 living docs, budget-capped
Discoverer (Sonnet)    brownfield detection before planning starts
```

State lives in files and tasks, not chat history. Session crashes? Reopen. The task list is still there.

---

## Get started

### Install

```bash
# From a git clone (npm publish coming soon)
git clone https://github.com/Fredasterehub/deadfish-teams.git
node deadfish-teams/bin/install.js --local
```

The installer copies the plugin into `.claude/plugins/deadfish-teams/`, generates your config, and registers hooks. Five questions if you run `init` interactively; sensible defaults if you pass flags.

<details>
<summary><strong>All installer options</strong></summary>

```bash
node bin/install.js init                          # interactive setup
node bin/install.js --global                      # install to ~/.claude/plugins/deadfish-teams
node bin/install.js --local                       # install to ./.claude/plugins/deadfish-teams
node bin/install.js --local --provider hybrid     # with overrides
node bin/install.js --uninstall                   # clean removal
node bin/install.js --local --dry-run             # preview without writing
```

**Interactive questions:** scope, provider routing (`anthropic-only` | `codex-mcp` | `hybrid`), model preferences (planner/coder/QA), brownfield detection toggle, task list ID pattern.

**Upgrade safety:** reinstalling backs up any file you've modified before overwriting. Backups go to `.deadfish-install/backups/<timestamp>/` inside the plugin root.

</details>

### Prerequisites

You need [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) with Agent Teams enabled, [Python 3](https://python.org) with PyYAML, and [Git](https://git-scm.com). If using multi-model routing, you'll also need [Codex CLI](https://github.com/openai/codex).

```bash
# Enable Agent Teams (add to ~/.claude/settings.json)
{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }

# Python deps
pip install pyyaml
```

### Run it

```bash
cd your-project
claude
```

Paste the kickoff prompt from [`CLAUDE.md`](./CLAUDE.md), press **Shift+Tab** for delegate mode, then give it a goal:

```
Plan and implement user authentication with JWT.
Acceptance criteria:
- AC-01: Login endpoint returns signed JWT
- AC-02: Protected routes reject expired tokens
- AC-03: Refresh token rotation works
```

The team handles the rest: discovery pass, spec, plan, task packets, implementation, verification, verdict. You approve or redirect at each stage.

---

## How it's different

I keep getting asked "why not just use X?" Fair question. Here's the honest answer:

| | Vibe coding | GSD alone | deadfish-teams |
|---|---|---|---|
| **State** | Chat history (gone on crash) | Git artifacts | Git artifacts + persistent task list |
| **Quality gate** | "Looks good to me" | verify.sh | verify.sh + 3-tier rubric (EXISTS/SUBSTANTIVE/WIRED) |
| **Models** | One model does everything | One model | 5 models, role-matched |
| **Docs** | None | None | 7 living docs, budget-capped, auto-maintained |
| **Drift detection** | None | None | Dedicated Conductor agent |
| **Brownfield** | None | None | Discovery pass before planning |
| **Scope enforcement** | Hope | Diff budget | Diff budget + file scope + blocked-file lists |

Deadfish doesn't replace GSD &mdash; it builds on it. If you're happy with GSD, you'll probably like this too.

---

## Under the hood

The sections below go deeper into the architecture. You don't need to read them to use deadfish, but they're here if you want to understand or customize it.

<details>
<summary><strong>The pipeline loop</strong></summary>

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
    │   ship / replan /        │
    │   needs_human            │
    └──────────────────────────┘
```

**Tasks are the scheduler.** No orchestrator loop, no cron, no state machine. Claude Code's native task list (`Ctrl+T`) drives all work. Dependencies between tasks are explicit. Session dies? Reopen &mdash; the task list survives.

</details>

<details>
<summary><strong>The four layers</strong></summary>

```
┌───────────────────────────────────────────────────┐
│  LAYER 4: ROLES                                   │
│  8 agents + 7 skills + tool permissions            │
├───────────────────────────────────────────────────┤
│  LAYER 3: PROTOCOL                                │
│  11 sentinel types + schemas + parse-blocks.py     │
├───────────────────────────────────────────────────┤
│  LAYER 2: ARTIFACTS                               │
│  Git-tracked: spec, plan, packets, verdicts, docs  │
├───────────────────────────────────────────────────┤
│  LAYER 1: STATE                                   │
│  Claude Code Tasks (Ctrl+T) — deps + status        │
└───────────────────────────────────────────────────┘
```

**Layer 1** is the scheduler. **Layer 2** is the memory. **Layer 3** is the language. **Layer 4** is the team.

</details>

<details>
<summary><strong>Skills-first design</strong></summary>

Instead of massive system prompts per agent, deadfish encodes rules as **shared skills**. Update one skill and every agent that references it improves.

| Skill | What it encodes |
|-------|----------------|
| [`deadfish-core`](./skills/deadfish-core/SKILL.md) | verify.sh is truth, acceptance criteria are immutable, tasks are the scheduler |
| [`deadfish-planning`](./skills/deadfish-planning/SKILL.md) | Spec/plan/packet format, scope limits (≤200 lines, ≤5 files) |
| [`deadfish-verify`](./skills/deadfish-verify/SKILL.md) | verify.sh protocol, 3-tier rubric (EXISTS/SUBSTANTIVE/WIRED), verdict format |
| [`deadfish-implement`](./skills/deadfish-implement/SKILL.md) | Git conventions, retry protocol, Codex MCP usage |
| [`deadfish-docs`](./skills/deadfish-docs/SKILL.md) | 7 living doc files with character budgets, significance gate |
| [`deadfish-conductor`](./skills/deadfish-conductor/SKILL.md) | Drift detection, boundary evaluation, stuck arbitration |
| [`deadfish-discovery`](./skills/deadfish-discovery/SKILL.md) | Brownfield detection, evidence collection |

</details>

<details>
<summary><strong>The sentinel protocol</strong></summary>

Agents communicate structured data through **sentinel blocks** &mdash; markdown code fences with typed YAML:

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

**11 types**, each with a [schema](./contracts/sentinel/v3/schemas.yaml): `SPEC`, `PLAN`, `TASK`, `TRACK`, `VERDICT`, `VERDICT_CRITERION`, `CONDUCTOR`, `DOCSYNC`, `IMPLEMENT`, `INTEGRATE`, `DIAGNOSTIC`.

Parsed by [`bin/parse-blocks.py`](./bin/parse-blocks.py). Verdicts aggregated by [`bin/build-verdict.py`](./bin/build-verdict.py). If a block doesn't validate against the schema, it's a protocol error &mdash; not a matter of opinion.

</details>

<details>
<summary><strong>Verification: the hard gate</strong></summary>

[`verify.sh`](./bin/verify.sh) runs deterministic checks no agent can override:

| Check | What it catches |
|-------|----------------|
| Tests | Test suite must pass |
| Linter | Style violations |
| Diff budget | Changes exceeding 3x estimated size |
| Scope | Files modified outside declared scope |
| Secrets | Credentials in the diff |
| Git clean | Uncommitted changes (post-commit mode) |

On top of that, the QA agent evaluates each acceptance criterion with a **three-tier rubric**:

- **EXISTS** &mdash; the artifact appears in the diff
- **SUBSTANTIVE** &mdash; real code, not a TODO or stub
- **WIRED** &mdash; connected into the system (imported, routed, tested)

All three must pass. The system is intentionally pessimistic: false negatives are OK, false positives are expensive.

</details>

<details>
<summary><strong>Living docs</strong></summary>

Seven documentation files maintained by the Doc-keeper agent, each with a **character budget**:

| File | Budget | Tracks |
|------|--------|--------|
| [`TECH_STACK.md`](./docs/living/TECH_STACK.md) | 3,200 | Languages, frameworks, versions |
| [`PATTERNS.md`](./docs/living/PATTERNS.md) | 3,200 | Architecture patterns, conventions |
| [`PITFALLS.md`](./docs/living/PITFALLS.md) | 2,800 | Known gotchas |
| [`RISKS.md`](./docs/living/RISKS.md) | 2,000 | Security & operational risks |
| [`PRODUCT.md`](./docs/living/PRODUCT.md) | 2,800 | Features, API surface |
| [`WORKFLOW.md`](./docs/living/WORKFLOW.md) | 2,800 | CI/CD, scripts |
| [`GLOSSARY.md`](./docs/living/GLOSSARY.md) | 2,000 | Domain terms |

Total: ~18,800 chars. Updates only happen after a PASS verdict **and** a significance trigger (manifest change, large diff, new pattern, etc.). A [scratch buffer](./docs/living/.scratch.yaml) holds observations below the significance threshold.

</details>

<details>
<summary><strong>Agent roster (full)</strong></summary>

| Agent | Model | Why this model | Boundaries |
|-------|-------|----------------|------------|
| **Lead** | Opus | Strategic judgment | Cannot edit code, read logs, or run tools |
| **Discoverer** | Sonnet | Fast evidence collection | Cannot modify files |
| **Brainstormer** | Opus | Creative depth | Cannot write implementation code |
| **Planner** | GPT-5.2 via MCP | Structured decomposition | Cannot implement, test, or commit |
| **Coder** | GPT-5.3-Codex via MCP | Fastest code generation | Cannot skip verify.sh or modify specs |
| **QA** | Sonnet | Pessimistic judgment is a feature | Cannot optimistically approve |
| **Conductor** | Opus | Full-context drift reasoning | Cannot write code or modify tasks |
| **Doc-keeper** | Haiku | Fast, cheap, gated | Cannot update docs without PASS verdict |
| **Integrator** | Sonnet | Surgical cross-task fixes | Cannot redesign architecture |

Agent definitions live in [`agents/`](./agents/). Each is a short markdown file that references shared skills.

</details>

<details>
<summary><strong>Configuration reference</strong></summary>

The installer generates two files in the plugin root:

**`deadfish.config.yaml`** &mdash; your choices:
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

**`.mcp.json`** &mdash; Codex MCP servers (for `codex-mcp` and `hybrid` providers):
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

For `anthropic-only` mode, no MCP servers are configured &mdash; all agents use Claude directly.

</details>

<details>
<summary><strong>Repo map</strong></summary>

```
deadfish-teams/
├── agents/                    8 role definitions (.md)
├── skills/                    7 shared skills (the real brain)
├── contracts/sentinel/v3/     protocol schemas + type contracts
├── templates/                 bootstrap, task, track, verify, repair
├── bin/                       deterministic tools
│   ├── verify.sh                the hard gate
│   ├── parse-blocks.py          sentinel parser
│   ├── build-verdict.py         verdict aggregator
│   ├── packet-to-task.py        task packet to prompt
│   ├── discover-detect.sh       brownfield classifier
│   ├── discover-collect.sh      evidence collector
│   └── installer/               npx install machinery
├── hooks/                     lifecycle event scripts
├── docs/living/               7 budget-capped living docs
├── tests/                     smoke + installer test suites
├── CLAUDE.md                  orchestrator contract
├── package.json               npm manifest
└── requirements.txt           Python deps (pyyaml)
```

</details>

---

## Latest changes

<!-- BEGIN:LAST_UPDATES -->
_Last refreshed: 2026-02-09 08:40 UTC_

- 2026-02-09 &mdash; chore: clean repo for public release + new README (0a4c215)
- 2026-02-09 &mdash; feat: Round 4 &mdash; npx installer, config gen, settings hooks, tests (efd7330)
- 2026-02-09 &mdash; fix: port repair template to v3 + align sentinel type lists (1caf039)
- 2026-02-09 &mdash; feat: Round 3 &mdash; discovery, tests, bootstrap, e2e smoke (1a696eb)
- 2026-02-09 &mdash; feat: Round 2 &mdash; v3 tooling + active templates (c607ede)
- 2026-02-09 &mdash; feat: Round 1 &mdash; v3 protocol foundation (e54b83e)
<!-- END:LAST_UPDATES -->

<sub>Auto-refreshed from git history. Run `./scripts/update_readme_latest_updates.sh --n 7` to update.</sub>

---

## Known limitations

- **Agent Teams is experimental** &mdash; requires the env flag above
- **GPT-5.3 model availability** &mdash; verify your subscription tier supports the model IDs you configure
- **No context budget management yet** &mdash; long sessions may hit token limits
- **The pipeline is only as good as your verification gates** &mdash; invest in your test suite

---

## Tests

```bash
bash tests/smoke-run.sh       # 10 protocol tests
bash tests/test-installer.sh  # 7 installer tests
```

---

## Contributing

If you want to contribute, follow the same rules the pipeline enforces on itself: small PRs, acceptance criteria upfront, verification before merge.

---

<p align="center">
  <sub>Built by <a href="mailto:fred@dimensionzero.net">Fred @ Dimension Zero</a> with <a href="https://claude.ai/claude-code">Claude Code</a> + <a href="https://github.com/openai/codex">Codex CLI</a></sub><br/>
  <sub>Inspired by <a href="https://github.com/bmadcode/BMAD-METHOD">BMAD</a> &bull; <a href="https://github.com/nicekid1/Oh-my-OpenCode">Oh My OpenCode</a> &bull; <a href="https://github.com/google-gemini/gemini-cli">Google Conductor</a> &bull; <a href="https://github.com/cline/gsd-protocol">GSD Protocol</a></sub>
</p>
