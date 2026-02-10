# Crystallize Outputs

Use these templates:
- `templates/bootstrap/brainstorm-session.tmpl.md`
- `templates/bootstrap/project.tmpl.md`
- `templates/bootstrap/requirements.tmpl.md`
- `templates/bootstrap/roadmap.tmpl.md`

Synthesize and confirm the following blocks in order.

Block 0: `BRAINSTORM_SESSION.md` (must be current before writing downstream docs)
- Write to `tracks/<track_id>/BRAINSTORM_SESSION.md`.
- Keep complete round log and append-only idea ledger.
- Ensure traceability chain is present:
  - ideas include `source_technique` and `source_round`
  - themes include `member_ideas`
  - requirement traceability includes `source_themes` + `source_ideas`
- Run convergence quality gates and record either pass or explicit override.

Block 1: `VISION.md`
- Problem and urgency
- Proposed solution boundaries
- Target users and environments
- Differentiators
- MVP in-scope and out-of-scope
- Success metrics
- Non-goals

Block 2: `PROJECT.md`
- Project identity and core value
- Constraints
- Context
- Key decisions with rationale and date
- Assumptions and open questions

Block 3: `REQUIREMENTS.md`
- Stable requirement IDs (`CAT-01` style)
- Requirement text + mapped roadmap phase
- DET/LLM acceptance criteria
- `source_themes` (theme IDs like `T01`)
- `source_ideas` (idea IDs like `I004`)
- Deferred requirements
- Out of scope
- Coverage summary

Block 4: `ROADMAP.md`
- Phase plan and dependency order
- Requirement ID mapping per phase
- Observable phase success criteria
- Progress snapshot
- Project-level risks
- Definition of done

Block 5: `BOOTSTRAP_TASKLIST.md`
- First 2-4 candidate tracks with rationale
- Suggested first track (`status: selected`)
- Initial task packet candidates using `{track}-P1-TNN` IDs
- Each task candidate links back to requirement IDs and supporting idea/theme IDs
- Deterministic verification commands to run per task
- Conductor check-ins to schedule at phase boundaries
- Docsync handoff notes for `docs/living/` updates once tasks pass verification

Confirm each block before moving to the next.
