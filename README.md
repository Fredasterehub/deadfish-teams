<p align="center">
  <img src="https://img.shields.io/badge/Claude_Code-Agent_Teams-7C3AED?style=for-the-badge&logo=anthropic&logoColor=white" alt="Claude Code Agent Teams"/>
  <img src="https://img.shields.io/badge/Codex_CLI-GPT--5.3-10A37F?style=for-the-badge&logo=openai&logoColor=white" alt="Codex CLI"/>
  <img src="https://img.shields.io/badge/Sentinel-v3_Protocol-E34F26?style=for-the-badge&logo=markdown&logoColor=white" alt="Sentinel v3"/>
</p>

<h1 align="center">🐟 deadfish-teams</h1>

<p align="center">
  <em>"Only a dead fish follows the flow."</em><br/><br/>
  <strong>An opinionated, multi-model workflow for building real software with AI agent teams.</strong><br/>
  <sub>Combining the best of <a href="https://github.com/bmad-code-org/BMAD-METHOD">BMAD</a>, <a href="https://github.com/code-yeongyu/oh-my-opencode">Oh My OpenCode</a>, <a href="https://github.com/gemini-cli-extensions/conductor">Google Conductor</a>, and <a href="https://github.com/glittercowboy/get-shit-done">GSD</a> into one pipeline.</sub>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-0.1.0-blue?style=flat-square" alt="Version"/>
  <img src="https://img.shields.io/badge/node-%3E%3D18-339933?style=flat-square&logo=node.js&logoColor=white" alt="Node"/>
  <img src="https://img.shields.io/badge/python-3.x-3776AB?style=flat-square&logo=python&logoColor=white" alt="Python"/>
  <img src="https://img.shields.io/badge/tests-17%2F17_passing-brightgreen?style=flat-square" alt="Tests"/>
  <img src="https://img.shields.io/badge/agents-8_roles-blueviolet?style=flat-square" alt="Agents"/>
  <img src="https://img.shields.io/badge/sentinel_types-11-orange?style=flat-square" alt="Sentinel Types"/>
  <img src="https://img.shields.io/badge/Claude_Code-Agent_Teams_%F0%9F%86%95-7C3AED?style=flat-square" alt="Agent Teams NEW"/>
</p>

---

## 🧭 The story

This is my attempt at creating what I would consider an efficient and optimized workflow to help you develop any &mdash; or at least most &mdash; ideas you might have.

Over the last couple of months I've had the chance to play around and get great results from some amazing open-source projects. Each one taught me something different, and each one left me wanting *just a little more*.

I tried to combine the different strengths of each and improve from the combination of all the concepts together. The result is **deadfish-teams** &mdash; built on top of [**Claude Code Agent Teams**](https://code.claude.com/docs/en/agent-teams), Anthropic's brand-new multi-agent system that shipped with [Opus 4.6 on February 5, 2026](https://techcrunch.com/2026/02/05/anthropic-releases-opus-4-6-with-new-agent-teams/). Agent Teams lets multiple Claude Code instances work in parallel as a coordinated team &mdash; not subagents locked to one context, but fully independent sessions that communicate directly with each other. Deadfish gives that raw capability a *purpose*: a structured pipeline where each teammate has a defined role, strict boundaries, and a protocol to follow.

This is day-one tooling for a day-one feature. We're pushing the envelope together. 🚀

---

## 🧬 Standing on the shoulders of giants

<table>
<tr>
<td width="80" align="center">🧠</td>
<td>

### [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) &mdash; *the brainstorming engine*

I fell in love with BMAD's brainstorming capabilities. Not the "give me 10 ideas" kind &mdash; this is world-class, structured ideation that actually converges into real requirements. [Version 6](https://github.com/LarryBrin/BMAD-METHOD-V6) is just *crazy* good. Deadfish borrows BMAD's multi-template brainstorming pipeline (7 templates that guide you from wild ideas to a concrete spec with acceptance criteria).

**But here's the thing.** BMAD plans *everything* upfront. All phases, all tasks, all at once. And 82 tasks later, you're still following the same rigid structure &mdash; even though at task 32 you realized a better design was possible. But it was already planned, so... you keep going. 🤷 Deadfish keeps BMAD's brainstorming brilliance but replaces the rigid execution with something more adaptive.

</td>
</tr>
<tr>
<td width="80" align="center">🔁</td>
<td>

### [Oh My OpenCode](https://github.com/code-yeongyu/oh-my-opencode) &mdash; *the relentless loop*

This one is the looping method *on steroids*. It auto-answers prompts to keep things moving, and the results were genuinely impressive &mdash; I had a lot of success with it. What it showed me was how far you can push a CLI tool with extensions, hooks, and a composable plugin architecture. Deadfish takes that plugin DNA: it installs as a Claude Code plugin with hooks, skills, and agent definitions that you can swap, extend, and upgrade without losing your customizations. ♻️

</td>
</tr>
<tr>
<td width="80" align="center">🧭</td>
<td>

### [Google Conductor](https://github.com/gemini-cli-extensions/conductor) &mdash; *the adaptive navigator*

What really stood out with Conductor was the constant reevaluation. Where other systems define the entire roadmap on day one and never look back (*cough cough, BMAD* 😏), Conductor takes a more dynamic, more agile approach to development. It keeps asking: *is this still the right direction?* Deadfish embeds that philosophy in a dedicated **Conductor agent** whose entire job is drift detection and boundary evaluation &mdash; watching for scope creep, questioning assumptions, deciding if it's time to replan rather than push through a plan that's no longer optimal.

</td>
</tr>
<tr>
<td width="80" align="center">⚡</td>
<td>

### [GSD &mdash; Get Shit Done](https://github.com/glittercowboy/get-shit-done) &mdash; *almost perfection*

GSD is the backbone. Plans-as-prompts, task packets, deterministic verification, scope limits &mdash; the closest thing to real engineering discipline for AI coding. The first versions were *incredible*: high quality, high speed, just raw execution. 🔥 Then it slowly got more complex &mdash; better quality in some ways, but a different vibe than the initial lightning-fast runs. Still super good. Just... different.

Deadfish takes GSD's structural DNA and adds what I felt was missing: **multi-model routing** (5 different models matched to the right role), **living documentation** (7 budget-capped docs maintained automatically), and a **structured protocol** (11 sentinel types with schemas &mdash; not free-form text that LLMs can hallucinate past).

</td>
</tr>
</table>

---

## 🎯 What you actually get

```
  🎯 You define a goal with acceptance criteria
      📋 A team of 8 AI agents plans it
          🔨 Another agent implements it (patch-sized, scoped)
              ✅ A verification script decides: ship, replan, or escalate
```

That loop &mdash; **plan → implement → verify → verdict** &mdash; runs for every task. No exceptions.

The verification script ([`verify.sh`](./bin/verify.sh)) is law: if it says FAIL, no amount of LLM confidence overrides it. 🚫🤖

Your agents use **different models for different jobs**:

| Role | Model | Why |
|------|-------|-----|
| 🎯 **Lead** | Opus | Strategic delegation &mdash; never touches code |
| 🧠 **Brainstormer** | Opus | BMAD-style deep ideation with the human |
| 📋 **Planner** | GPT-5.2 | Structured decomposition into task packets |
| ⚡ **Coder** | GPT-5.3-Codex | Fastest code generation, scoped to one task |
| 🔍 **QA** | Sonnet | Pessimistic by design &mdash; runs the hard gate |
| 🧭 **Conductor** | Opus | Drift detection: *"are we still building the right thing?"* |
| 📝 **Doc-keeper** | Haiku | Maintains 7 living docs, budget-capped |
| 🔬 **Discoverer** | Sonnet | Brownfield detection before planning starts |

> 💡 **State lives in files and tasks, not chat history.** Session crashes? Reopen. The task list is still there.

---

## 📦 Get started

```bash
# Clone and install locally
git clone https://github.com/Fredasterehub/deadfish-teams.git
node deadfish-teams/bin/install.js --local
```

Then open Claude Code in your project, paste the kickoff prompt from [`CLAUDE.md`](./CLAUDE.md), press **Shift+Tab** for delegate mode, and give it a goal. That's it. 🎬

<details>
<summary>📖 <strong>Full install guide + all options</strong></summary>

### Interactive setup

```bash
node bin/install.js init    # asks 5 questions, sets everything up
```

**Questions asked:** scope (global/local), provider routing (`anthropic-only` | `codex-mcp` | `hybrid`), model preferences, brownfield detection toggle, task list ID pattern.

### Non-interactive

```bash
node bin/install.js --global                      # defaults, global scope
node bin/install.js --local --provider hybrid     # local, hybrid routing
node bin/install.js --uninstall                   # clean removal
node bin/install.js --local --dry-run             # preview without writing
```

### What gets installed

```
~/.claude/plugins/deadfish-teams/     (or ./.claude/plugins/...)
├── agents/          8 role definitions
├── skills/          7 shared skills (the real brain)
├── templates/       bootstrap, task, verify, repair
├── contracts/       sentinel v3 protocol schemas
├── bin/             deterministic tools + installer
├── hooks/           lifecycle event scripts
├── docs/living/     7 budget-capped living docs
├── CLAUDE.md        orchestrator contract
└── .deadfish-install/
    ├── manifest.json        SHA-256 hashes of every file
    └── backups/<timestamp>/ your edits, preserved on upgrade
```

### Prerequisites

| Need | Why |
|------|-----|
| [Claude Code CLI](https://code.claude.com) + Agent Teams enabled | Host for the team |
| [Codex CLI](https://github.com/openai/codex) | MCP server for GPT-5.x *(only if using `codex-mcp` or `hybrid`)* |
| [Python 3](https://python.org) + PyYAML | Sentinel parsing & verification |
| [Git](https://git-scm.com) | Task tracking, diff analysis, scope enforcement |

```bash
# Enable Agent Teams (add to ~/.claude/settings.json)
{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }

# Python deps
pip install pyyaml
```

> 🛠️ **Dev checkout?** Symlink instead: `ln -s /path/to/deadfish-teams ~/.claude/plugins/deadfish-teams`

**Upgrade safety:** reinstalling backs up any file you've modified before overwriting. Your edits are never lost. 🔒

</details>

---

## ⚖️ How it's different

| | 💬 Vibe coding | ⚡ GSD alone | 🐟 deadfish-teams |
|---|---|---|---|
| **State** | Chat history (gone on crash) | Git artifacts | Git artifacts + persistent task list |
| **Quality gate** | "Looks good to me" | verify.sh | verify.sh + 3-tier rubric |
| **Models** | One model does everything | One model | 5 models, role-matched |
| **Docs** | None | None | 7 living docs, budget-capped |
| **Drift detection** | None | None | Dedicated Conductor agent |
| **Brownfield** | None | None | Discovery pass before planning |
| **Scope enforcement** | Hope 🤞 | Diff budget | Diff budget + file scope + blocked files |

> Deadfish doesn't replace GSD &mdash; it builds on it. If you're happy with GSD, you'll probably like this too. 🤝

---

## 🔬 Under the hood

Everything below is the deep dive. You don't need any of it to use deadfish &mdash; but it's here if you want to understand, customize, or contribute.

<details>
<summary>🔄 <strong>The pipeline loop</strong></summary>

Every unit of work follows the same cycle:

```
    ┌─────────────────────────┐
    │  📋 1. SPEC & PLAN      │
    │  bounded scope           │
    │  acceptance criteria     │
    │  task graph              │
    └────────────┬────────────┘
                 │
    ┌────────────▼────────────┐
    │  ⚡ 2. IMPLEMENT        │
    │  one task at a time      │
    │  ≤200 lines, ≤5 files    │
    │  git commit per task     │
    └────────────┬────────────┘
                 │
    ┌────────────▼────────────┐
    │  🔍 3. VERIFY           │
    │  verify.sh (det.)        │
    │  + criteria fan-out      │
    └────────────┬────────────┘
                 │
    ┌────────────▼────────────┐
    │  🏛️ 4. VERDICT          │
    │  ✅ ship                 │
    │  🔁 replan               │
    │  🧑‍⚖️ needs_human          │
    └──────────────────────────┘
```

**Tasks are the scheduler.** No orchestrator loop, no cron, no state machine. Claude Code's native task list (`Ctrl+T`) drives all work. Dependencies are explicit. Session dies? Reopen &mdash; the task list survives.

</details>

<details>
<summary>🏗️ <strong>The four layers</strong></summary>

```
┌───────────────────────────────────────────────────┐
│  🎭 LAYER 4: ROLES                               │
│  8 agents + 7 skills + tool permissions            │
├───────────────────────────────────────────────────┤
│  📡 LAYER 3: PROTOCOL                             │
│  11 sentinel types + schemas + parse-blocks.py     │
├───────────────────────────────────────────────────┤
│  📁 LAYER 2: ARTIFACTS                            │
│  Git-tracked: spec, plan, packets, verdicts, docs  │
├───────────────────────────────────────────────────┤
│  📌 LAYER 1: STATE                                │
│  Claude Code Tasks (Ctrl+T) — deps + status        │
└───────────────────────────────────────────────────┘
```

**Layer 1** is the scheduler. **Layer 2** is the memory. **Layer 3** is the language. **Layer 4** is the team.

</details>

<details>
<summary>🧩 <strong>Skills-first design</strong></summary>

Instead of massive system prompts per agent, deadfish encodes rules as **shared skills**. Update one skill and every agent that references it improves. ✨

| Skill | What it encodes |
|-------|----------------|
| [`deadfish-core`](./skills/deadfish-core/SKILL.md) | 🔑 verify.sh is truth, acceptance criteria are immutable, tasks are the scheduler |
| [`deadfish-planning`](./skills/deadfish-planning/SKILL.md) | 📋 Spec/plan/packet format, scope limits (≤200 lines, ≤5 files) |
| [`deadfish-verify`](./skills/deadfish-verify/SKILL.md) | ✅ verify.sh protocol, 3-tier rubric (EXISTS/SUBSTANTIVE/WIRED), verdict format |
| [`deadfish-implement`](./skills/deadfish-implement/SKILL.md) | ⚡ Git conventions, retry protocol, Codex MCP usage |
| [`deadfish-docs`](./skills/deadfish-docs/SKILL.md) | 📝 7 living doc files with character budgets, significance gate |
| [`deadfish-conductor`](./skills/deadfish-conductor/SKILL.md) | 🧭 Drift detection, boundary evaluation, stuck arbitration |
| [`deadfish-discovery`](./skills/deadfish-discovery/SKILL.md) | 🔬 Brownfield detection, evidence collection |

</details>

<details>
<summary>📡 <strong>The sentinel protocol</strong></summary>

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

**11 types**, each with a [schema](./contracts/sentinel/v3/schemas.yaml):

`SPEC` · `PLAN` · `TASK` · `TRACK` · `VERDICT` · `VERDICT_CRITERION` · `CONDUCTOR` · `DOCSYNC` · `IMPLEMENT` · `INTEGRATE` · `DIAGNOSTIC`

Parsed by [`parse-blocks.py`](./bin/parse-blocks.py). Verdicts aggregated by [`build-verdict.py`](./bin/build-verdict.py). If a block doesn't validate, it's a protocol error &mdash; not a matter of opinion.

</details>

<details>
<summary>🛡️ <strong>Verification: the hard gate</strong></summary>

[`verify.sh`](./bin/verify.sh) runs deterministic checks no agent can override:

| Check | What it catches |
|-------|----------------|
| 🧪 Tests | Suite must pass |
| 🎨 Linter | Style violations |
| 📏 Diff budget | Changes exceeding 3x estimated size |
| 🎯 Scope | Files modified outside declared scope |
| 🔐 Secrets | Credentials in the diff |
| 🧹 Git clean | Uncommitted changes (post-commit) |

The QA agent evaluates each acceptance criterion with a **three-tier rubric**:

| Tier | Meaning |
|------|---------|
| **EXISTS** | The artifact appears in the diff |
| **SUBSTANTIVE** | Real code, not a TODO or stub |
| **WIRED** | Connected into the system (imported, routed, tested) |

All three must pass. Intentionally pessimistic: false negatives are OK, false positives are expensive. 🎯

</details>

<details>
<summary>📝 <strong>Living docs</strong></summary>

Seven docs maintained by the Doc-keeper, each with a **character budget** to prevent bloat:

| File | Budget | Tracks |
|------|--------|--------|
| [`TECH_STACK.md`](./docs/living/TECH_STACK.md) | 3,200 | Languages, frameworks, versions |
| [`PATTERNS.md`](./docs/living/PATTERNS.md) | 3,200 | Architecture patterns, conventions |
| [`PITFALLS.md`](./docs/living/PITFALLS.md) | 2,800 | Known gotchas |
| [`RISKS.md`](./docs/living/RISKS.md) | 2,000 | Security & operational risks |
| [`PRODUCT.md`](./docs/living/PRODUCT.md) | 2,800 | Features, API surface |
| [`WORKFLOW.md`](./docs/living/WORKFLOW.md) | 2,800 | CI/CD, scripts |
| [`GLOSSARY.md`](./docs/living/GLOSSARY.md) | 2,000 | Domain terms |

Updates only happen after a PASS verdict **and** a significance trigger (manifest change, large diff, new pattern). A [scratch buffer](./docs/living/.scratch.yaml) holds observations below threshold. 📋

</details>

<details>
<summary>👥 <strong>Agent roster (full details)</strong></summary>

| Agent | Model | Why | Boundaries |
|-------|-------|-----|------------|
| 🎯 **Lead** | Opus | Strategic judgment | Cannot edit code, read logs, or run tools |
| 🔬 **Discoverer** | Sonnet | Fast evidence collection | Cannot modify files |
| 🧠 **Brainstormer** | Opus | Creative depth | Cannot write implementation code |
| 📋 **Planner** | GPT-5.2 via MCP | Structured decomposition | Cannot implement, test, or commit |
| ⚡ **Coder** | GPT-5.3-Codex via MCP | Fastest code gen | Cannot skip verify.sh or modify specs |
| 🔍 **QA** | Sonnet | Pessimism is a feature | Cannot optimistically approve |
| 🧭 **Conductor** | Opus | Full-context drift reasoning | Cannot write code or modify tasks |
| 📝 **Doc-keeper** | Haiku | Fast, cheap, gated | Cannot update docs without PASS |
| 🔗 **Integrator** | Sonnet | Surgical cross-task fixes | Cannot redesign architecture |

Agent definitions: [`agents/`](./agents/) &mdash; each is a short markdown file that references shared skills.

</details>

<details>
<summary>⚙️ <strong>Configuration reference</strong></summary>

The installer generates two files:

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

**`.mcp.json`** &mdash; Codex MCP servers (for `codex-mcp` / `hybrid`):
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

For `anthropic-only` mode, no MCP servers are configured.

</details>

<details>
<summary>🗂️ <strong>Repo map</strong></summary>

```
deadfish-teams/
├── agents/                    8 role definitions (.md)
├── skills/                    7 shared skills
├── contracts/sentinel/v3/     protocol schemas
├── templates/                 bootstrap, task, verify, repair
├── bin/                       deterministic tools
│   ├── verify.sh                the hard gate
│   ├── parse-blocks.py          sentinel parser
│   ├── build-verdict.py         verdict aggregator
│   ├── packet-to-task.py        task packet → prompt
│   ├── discover-detect.sh       brownfield classifier
│   ├── discover-collect.sh      evidence collector
│   └── installer/               install machinery
├── hooks/                     lifecycle events
├── docs/living/               7 living docs
├── tests/                     17 tests (smoke + installer)
├── CLAUDE.md                  orchestrator contract
├── package.json               npm manifest
└── requirements.txt           Python deps
```

</details>

---

## 📰 Latest changes

<!-- BEGIN:LAST_UPDATES -->
_Last refreshed: 2026-02-09 08:40 UTC_

- 2026-02-09 &mdash; chore: clean repo for public release + new README (0a4c215)
- 2026-02-09 &mdash; feat: Round 4 &mdash; npx installer, config gen, settings hooks, tests (efd7330)
- 2026-02-09 &mdash; fix: port repair template to v3 + align sentinel type lists (1caf039)
- 2026-02-09 &mdash; feat: Round 3 &mdash; discovery, tests, bootstrap, e2e smoke (1a696eb)
- 2026-02-09 &mdash; feat: Round 2 &mdash; v3 tooling + active templates (c607ede)
- 2026-02-09 &mdash; feat: Round 1 &mdash; v3 protocol foundation (e54b83e)
<!-- END:LAST_UPDATES -->

<sub>Auto-refreshed from git history &mdash; run <code>./scripts/update_readme_latest_updates.sh --n 7</code> to update.</sub>

---

## 🧪 Tests

```bash
bash tests/smoke-run.sh       # 10 protocol tests
bash tests/test-installer.sh  # 7 installer tests
```

---

## ⚠️ Known limitations

- 🆕 **Agent Teams is experimental** &mdash; [just shipped Feb 5, 2026](https://techcrunch.com/2026/02/05/anthropic-releases-opus-4-6-with-new-agent-teams/) &mdash; expect rough edges
- 🤖 **GPT-5.3 model availability** &mdash; verify your subscription supports the model IDs you configure
- 📊 **No context budget management yet** &mdash; long sessions may hit token limits
- 🧪 **Quality depends on your gates** &mdash; invest in your test suite and linter config

---

## 🤝 Contributing

Follow the same rules the pipeline enforces on itself: small PRs, acceptance criteria upfront, verification before merge.

---

<p align="center">
  <sub>Built by <a href="mailto:fred@dimensionzero.net">Fred @ Dimension Zero</a> 🐟</sub><br/>
  <sub>Powered by <a href="https://code.claude.com/docs/en/agent-teams">Claude Code Agent Teams</a> + <a href="https://github.com/openai/codex">Codex CLI</a></sub><br/>
  <sub>Standing on: <a href="https://github.com/bmad-code-org/BMAD-METHOD">BMAD</a> · <a href="https://github.com/code-yeongyu/oh-my-opencode">Oh My OpenCode</a> · <a href="https://github.com/gemini-cli-extensions/conductor">Google Conductor</a> · <a href="https://github.com/glittercowboy/get-shit-done">GSD</a></sub>
</p>
