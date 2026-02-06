--- ORIENTATION (0a-0c) ---
0a. Read STATE.yaml: determine the current roadmap phase id from roadmap.current_phase.
0b. Read ROADMAP.md: for that phase id, load its goal, success_criteria, and requirements list.
0c. Read REQUIREMENTS.md: for those requirement IDs, collect status (pending/in_progress/complete/blocked).
    Also read VISION.md and PROJECT.md for strategic direction and constraints.

--- OBJECTIVE (1) ---
1. Select the next track to implement within the current roadmap phase.
   A track is a coherent unit of work (feature/fix/refactor) that advances one or more
   requirements toward completion and maximizes progress on unmet success criteria.

   Output EXACTLY ONE sentinel TRACK block using this format:
<<<TRACK:V1:NONCE={nonce}>>>
TRACK_ID=<bare>
TRACK_NAME="<quoted>"
PHASE={phase_id}
REQUIREMENTS=[<comma-separated REQ IDs>]
GOAL="<1-2 sentence goal>"
ESTIMATED_TASKS=<positive integer, 2-5 recommended>
<<<END_TRACK:NONCE={nonce}>>>

--- RULES ---
- Never select work outside the current phase.
- Maximize progress on unmet phase success_criteria.
- Prefer unblocked requirements; avoid blocked unless there is no other useful work.
- Prefer smaller tracks; target 2-5 tasks per track.
- REQUIREMENTS must be a subset of the current phase's requirement IDs from ROADMAP.md.
- If all requirements for the current phase are complete:
  output a TRACK sentinel block containing only PHASE_COMPLETE=true and PHASE={phase_id} (omit all other track fields).
- If all remaining (non-complete) requirements in the current phase are blocked:
  output a TRACK sentinel block containing only PHASE_BLOCKED=true, PHASE={phase_id},
  and REASONS= (1-5 concise reasons) (omit all other track fields).

--- GUARDRAILS (999+) ---
99999. Output ONLY the sentinel block. No preamble, no explanation.
999999. Do not invent requirement IDs.
9999999. For normal track selection, ESTIMATED_TASKS must be 2-5.
99999999. Never select work outside the current phase unless emitting PHASE_COMPLETE=true.
