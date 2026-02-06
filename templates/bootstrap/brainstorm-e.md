# P2_E — Crystallize Statements

Use these templates as the target schemas:
- .pipe/p2/P2_PROJECT_TEMPLATE.md
- .pipe/p2/P2_REQUIREMENTS_TEMPLATE.md
- .pipe/p2/P2_ROADMAP_TEMPLATE.md

Synthesize, crystallize, and confirm data for all 5 outputs. Present each block, then ask for confirmation/edits before proceeding.

Block 1 — VISION.md
- Problem: why this needs to exist + pain points (2-3). (→ vision.problem.why + vision.problem.pain[])
- Solution: one-sentence pitch + explicit scope boundaries. (→ vision.solution.what + vision.solution.boundaries)
- Users: primary target user + environments. (→ vision.users.primary + vision.users.environments[])
- Differentiators (3-7): what makes it distinct. (→ vision.differentiators[])
- MVP scope: in-scope items + out-of-scope items. (→ vision.mvp_scope.in[] + vision.mvp_scope.out[])
- Success metrics (5-12): observable, verifiable outcomes. (→ vision.success_metrics[])
- Non-goals (3-7): explicit exclusions. (→ vision.non_goals[])
- Note: Key risks (3-5) are collected in Block 4 (ROADMAP) under roadmap.risks.
Confirm this block, then continue.

Block 2 — PROJECT.md
- project.name
- project.description (2-3 sentences, current truth)
- project.core_value (single must-work statement)
- project.constraints[]: objects with type (tech|timeline|budget|dependency|compatibility), what, why
- project.context (short, factual background; OK if minimal/empty for greenfield)
- project.key_decisions[]: objects with decision, rationale, outcome (pending|good|revisit), date (YYYY-MM-DD)
- project.assumptions[]
- project.open_questions[]
Confirm this block, then continue.

Block 3 — REQUIREMENTS.md
- requirements.defined (YYYY-MM-DD) and requirements.core_value (from PROJECT.md)
- v1 requirements with stable IDs (CAT-##, uppercase CAT + two digits). Each includes:
  - category (theme name)
  - text (user-centric, testable)
  - phase number
  - status (start as pending)
  - acceptance[] criteria with type DET or LLM and a testable criterion
- v2 deferred requirements (optional; stable IDs + category + text)
- out_of_scope: feature + reason
- coverage counts: total_v1, mapped, unmapped
Confirm this block, then continue.

Block 4 — ROADMAP.md (phases only, no tracks/steps/deliverables)
- roadmap.version and roadmap.goal
- phases[]: id, name, goal, depends_on, requirements (REQUIREMENTS.md IDs), success_criteria, estimated_tracks, status
- progress: total_phases, completed, current_phase
- risks: project-level risks
- definition_of_done: overall completion criteria
Confirm this block, then continue.

Block 5 — STATE.yaml (initialization only)
- project.name
- project.core_value
- total phases / current phase
Confirm this block, then continue.

Guidance:
- Vision statement and success truths must be crisp and testable (machine or human reviewer).
- Non-goals must be specific, not vague.
- Requirement IDs are stable CAT-## (uppercase CAT, two digits) and never reused; acceptance criteria must be DET or LLM.
- Roadmap phases must reference valid REQUIREMENTS.md IDs.
- Keep phrasing crisp and facilitator-oriented; confirm after each block.
