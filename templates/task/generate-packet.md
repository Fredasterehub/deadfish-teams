--- ORIENTATION (0a-0c) ---
0a. Read STATE.yaml: track info, task_current, task_count, retry_count, last_result, plan_base_commit.
0b. Read PLAN.md at track.plan_path. Extract TASK[task_current]. If retry, read existing .deadf/tracks/{track.id}/tasks/TASK_{NNN}.md.
0c. Read OPS.md. Check current HEAD vs plan_base_commit. Search codebase for planned file paths.

--- OBJECTIVE (1) ---
1. Produce an adapted execution packet for TASK[task_current]. This prompt is used ONLY on drift or retry paths (no happy-path usage).
   - If drift: resolve file path changes, update integration points, adjust files_to_load.
   - If retry: analyze last_result.details, add retry context (what failed, what to change, what not to repeat).
   - Keep acceptance criteria IMMUTABLE - never weaken on retry.
   - Keep SUMMARY from PLAN as primary prompt - append adaptations, do not replace.

Output: a structured markdown TASK file (not sentinel).

--- OUTPUT FORMAT (2) ---
Emit exactly ONE of the following:

A) TASK markdown (optional YAML frontmatter allowed):

---
(optional frontmatter)
---

# TASK — <TASK_ID>

## Meta
- task_id: <TASK_ID>
- attempt: <retry_count + 1>
- track_id: <track.id>
- task_index: <task_current> of <task_count>

## TITLE
<TITLE from PLAN>

## SUMMARY (verbatim)
<SUMMARY from PLAN, verbatim>
<If drift or retry, append a short "Adaptations" paragraph after the verbatim SUMMARY.>

## FILES (verbatim)
- path: <resolved path> | action: <add|modify|delete> | rationale: <from PLAN>
- path: <resolved path> | action: <add|modify|delete> | rationale: <from PLAN>
- missing_or_invalid: <path> | reason: <why it no longer makes sense>  (only if applicable)

## ACCEPTANCE (verbatim)
<ACCEPTANCE from PLAN, verbatim and ordered>

## ESTIMATED_DIFF (verbatim)
<ESTIMATED_DIFF>
max_diff: <3 × ESTIMATED_DIFF>

## DEPENDS_ON (verbatim)
<DEPENDS_ON>

## OPS COMMANDS
<commands from OPS.md>

## FILES_TO_LOAD (ordered by priority, ≤3000 tokens)
- <path> | why: <reason>
- <path> | why: <reason>

## HARD STOPS / SIGNALS
- REPLAN_REQUIRED: <true|false + reason>
- REQUEST_SPLIT: <true|false + reason>

B) REPLAN_REQUIRED signal only:
REPLAN_REQUIRED: <short reason(s) for why drift or missing files block safe adaptation>

If REPLAN_REQUIRED is emitted, do not output any TASK markdown.

C) REQUEST_SPLIT signal only:
REQUEST_SPLIT: <short reason why adapted task would exceed 3× ESTIMATED_DIFF>

If REQUEST_SPLIT is emitted, do not output any TASK markdown.

--- RULES ---
- Pass through TASK_ID, TITLE, SUMMARY, FILES, ACCEPTANCE, ESTIMATED_DIFF, DEPENDS_ON from PLAN.
- On drift: update FILES paths to current reality; flag any that no longer make sense.
- On retry: append retry guidance AFTER the original SUMMARY (do not replace or edit the SUMMARY).
- files_to_load priority: modify targets -> entrypoints -> tests -> config -> style anchors.
- Cap files_to_load at 3000 tokens.
- max_diff is always 3 × ESTIMATED_DIFF. If adaptation would exceed this, output REQUEST_SPLIT.
- If modify/delete targets are missing and cannot be resolved -> output REPLAN_REQUIRED (do not guess).

--- GUARDRAILS (999+) ---
99999. Do not re-plan. Only adapt bindings and context.
999999. Acceptance criteria are immutable.
9999999. If drift is unresolvable, output REPLAN_REQUIRED - do not guess.
