# Organize and Prioritize

Gate:
- enter when user asks
- or after large ideation volume and clear energy drop

Steps:
1. Cluster ideas into 5-12 themes.
2. Validate themes with the user.
3. Prioritize with MoSCoW:
   - Must-have
   - Should-have
   - Could-have
   - Won't-have (feeds non-goals)
4. Sequence must-haves by dependency, risk, and value.
5. Capture major risks per theme.
6. Run convergence quality gates before final recommendation.

Theme traceability format (write to `BRAINSTORM_SESSION.md`):
- `id`: `T01`, `T02`, ...
- `name`: concise theme label
- `summary`: one-line description
- `member_ideas`: list of idea IDs (`I###`) backing the theme
- `priority`: `Must|Should|Could|Won't`
- `risk`: major risk statement

Convergence quality gates (warn + override capable):
1. Divergence breadth gate
   - total ideas >= 12
   - unique domains >= 3
   - unique techniques >= 3
2. Mapping completeness gate
   - every active idea appears in at least one `member_ideas` list
3. Decision readiness gate
   - tradeoff table exists
   - recommendation and fallback are explicit

If any gate fails:
- emit a warning with failed gate(s) and evidence counts
- propose one additional divergence round
- allow explicit override with:
  - reason
  - human approver
  - timestamp
- record override under `quality_gates.override` in `BRAINSTORM_SESSION.md`

Ask:
"Are we optimizing for speed-to-MVP, technical ambition, or commercial viability?"
