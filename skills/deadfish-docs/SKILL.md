---
name: deadfish-docs
description: Track-boundary living-doc reconciliation and debate protocol.
---

# deadfish-docs — Track-Boundary Reconciliation

## 7 Living Docs (in `docs/living/`)

| Doc | Budget (chars) | Content |
|-----|---------------|---------|
| TECH_STACK.md | 3200 | Languages, frameworks, deps, versions |
| PATTERNS.md | 3200 | Architecture patterns, conventions, idioms |
| PITFALLS.md | 2800 | Known gotchas, footguns, anti-patterns |
| RISKS.md | 2000 | Security, operational, business risks |
| PRODUCT.md | 2800 | Features, API surface, user-facing behavior |
| WORKFLOW.md | 2800 | CI/CD, scripts, deployment, dev workflow |
| GLOSSARY.md | 2000 | Domain terms, abbreviations, naming |
| **Total** | **~18800** | |

## Trigger and Scope
- Reconciliation starts only when `.deadfish/reconcile/<track_id>.trigger` exists.
- This skill is track-boundary only. No per-task DOCSYNC, no scratch-buffer lifecycle.
- Default cadence: exactly one reconciliation run per completed track.

## Role Wiring (Required)
- **Doc-keeper (Haiku)**: Phase 1 proposal generation only.
- **Reviewer A (Conductor / Opus 4.6)**: independent review verdicts.
- **Reviewer B (Planner / GPT-5.2 high via `mcp__codex-planner__codex`)**: independent review verdicts.
- **Integrator (Sonnet)**: applies approved diffs, writes reconciliation record, commits once, deletes trigger.

## Phase 1 — Proposal (Doc-keeper)
For each of the seven living docs:
1. Read `tracks/<track_id>/SPEC.md`.
2. Read full track diff (`base_commit..HEAD`) and relevant commits.
3. Compare implementation evidence to current doc content.
4. Produce one proposal record per doc:

```yaml
doc: TECH_STACK.md
action: UPDATE # UPDATE or NOP
proposed_diff: |
  + - **PyYAML 6.0**: YAML parsing for sentinel blocks.
rationale: Track added parse-blocks.py importing yaml.
evidence:
  - file: bin/parse-blocks.py
  - file: requirements.txt
```

Phase 1 output is proposals only. Doc-keeper does not apply edits.

## Phase 2 — Multi-Model Debate
Run for each proposal where `action=UPDATE`.

Round 1:
- Reviewer A and Reviewer B independently return:
  - `verdict`: `APPROVE` | `REJECT` | `MODIFY`
  - `reasoning`
  - `concerns`
  - `modified_diff` (required for `MODIFY`)

Decision table:
- Both `APPROVE` -> `auto_approved` (apply original proposal)
- Both `REJECT` -> `auto_rejected` (skip apply)
- Both `MODIFY` with semantically equivalent diff -> `auto_approved_modified`
- Any disagreement -> continue to Round 2

Round 2:
- Each reviewer sees the other review and re-evaluates.

Round 3:
- Each reviewer sees full debate history and emits final verdict.
- If still unresolved after Round 3 -> `escalated_to_human`.

## Phase 3 — Apply, Record, Cleanup (Integrator)
Integrator actions:
1. Apply all auto-approved diffs to `docs/living/*`.
2. Escalate sustained disagreements with both reviewer perspectives.
3. Commit once:
   - `docs(deadfish): Reconcile docs for track '<track_id>'`
4. Write `.deadfish/reconcile/<track_id>.yaml`.
5. Delete `.deadfish/reconcile/<track_id>.trigger`.

Reconciliation record schema:

```yaml
track_id: v32-realignment
timestamp: 2026-02-09T14:30:00Z
trigger: .deadfish/reconcile/v32-realignment.trigger
docs_evaluated: 7
proposals:
  TECH_STACK:
    action: UPDATE
    debate_rounds: 1
    outcome: auto_approved
    reviewers: {opus: APPROVE, gpt52: APPROVE}
docs_changed: [TECH_STACK]
commit_sha: abc123
debate_log:
  - doc: TECH_STACK
    round: 1
    reviewer: opus
    verdict: APPROVE
    reasoning: Dependency manifest changed with matching implementation use.
```

Required top-level keys:
- `track_id`, `timestamp`, `trigger`, `docs_evaluated`, `proposals`, `docs_changed`, `commit_sha`

## Docsync Sentinel
Doc-keeper emits reconciliation-only sentinel:

```deadfish:DOCSYNC
action: RECONCILE
track_id: <track_id>
trigger: .deadfish/reconcile/<track_id>.trigger
phase: proposal|debate|apply
status: READY_FOR_DEBATE|AUTO_APPLY|ESCALATE_HUMAN|COMPLETED
summary: <concise track-boundary reconciliation status>
```

## Budget Enforcement
If a doc exceeds 80% of budget, prefer compression edits before expansion.
