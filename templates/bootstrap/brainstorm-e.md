# Crystallize Outputs

Use these templates:
- `templates/bootstrap/project.tmpl.md`
- `templates/bootstrap/requirements.tmpl.md`
- `templates/bootstrap/roadmap.tmpl.md`

Synthesize and confirm the following blocks in order.

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
- Deterministic verification commands to run per task
- Conductor check-ins to schedule at phase boundaries
- Docsync handoff notes for `docs/living/` updates once tasks pass verification

Confirm each block before moving to the next.
