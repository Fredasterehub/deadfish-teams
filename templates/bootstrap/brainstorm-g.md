# Adversarial Review

Review draft outputs and produce 5-15 concrete findings.

Target files:
- `docs/design/VISION.md`
- `docs/design/PROJECT.md`
- `docs/design/REQUIREMENTS.md`
- `docs/design/ROADMAP.md`
- `docs/design/BOOTSTRAP_TASKLIST.md`
- `conductor-state.md`

For each finding, include:
- severity: HIGH | MED | LOW
- what is missing or unclear
- why it matters
- specific fix

Checks:
- cross-file consistency
- testability of success criteria and acceptance criteria
- requirement-to-phase traceability
- feasibility of first selected track
- verification coverage via `bin/verify.sh`
- conductor checkpoint readiness

Prompt:
"Here are 5-15 issues with severity and fixes. Which should we apply now?"

Apply approved fixes, then write final files.
