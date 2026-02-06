--- ORIENTATION (0a-0c) ---
0a. Read STATE.yaml: track id, track name, phase, and spec_path.
0b. Read SPEC.md at {track.spec_path}. Extract every acceptance criterion.
0c. Read PROJECT.md constraints/decisions. Read OPS.md for build/test/lint commands (if present).

--- OBJECTIVE (1) ---
1. Generate an implementation plan for track "{track.name}" as 2-5 atomic tasks.
   Each task IS a prompt (plans-as-prompts) and will be executed directly by gpt-5.2-codex.

   Output format (sentinel PLAN block):
<<<PLAN:V1:NONCE={nonce}>>>
TRACK_ID={track.id}
TASK_COUNT=<N>

TASK[1]:
TASK_ID={track.id}-T01
TITLE="<quoted>"
SUMMARY=
  <2-space indented: what to implement, 2-3 sentences>
FILES:
- path=<bare> action=<add|modify|delete> rationale="<quoted>"
ACCEPTANCE:
- id=AC<n> text="<DET:|LLM: testable criterion>"
ESTIMATED_DIFF=<positive integer>
DEPENDS_ON=[]

TASK[2]:
TASK_ID={track.id}-T02
...

<<<END_PLAN:NONCE={nonce}>>>

--- RULES ---
- 2-5 tasks total.
- Each task <=200 diff lines; split if larger.
- <=5 files per task unless strictly necessary.
- Tasks execute sequentially; use DEPENDS_ON to point to prior TASK_IDs when needed.
- SUMMARY is the implementer's prompt: imperative, directly executable by gpt-5.2-codex, 2-3 sentences.
- SUMMARY must include concrete instructions on what to change and where; include tests/commands from OPS.md when relevant.
- Every acceptance criterion from SPEC.md must appear in exactly one task's ACCEPTANCE list (no duplicates, no omissions).
- Each task must include >=1 DET: criterion and >=1 meaningful criterion.
- DET: only for verify.sh checks (tests, lint, diff within 3x, path safety, no secrets, git clean). All other criteria must be LLM:.
- ESTIMATED_DIFF must be the smallest plausible implementation estimate; actual diff should stay within 3x.

--- GUARDRAILS (999+) ---
99999. Output ONLY the sentinel PLAN block. No preamble, no prose.
999999. No hallucinated files: every FILES path must already exist for modify/delete, or be explicitly created for add, and must fit repo structure.
9999999. The plan must be implementation-ready: "do this, then that", not "consider" or "discuss".
99999999. No vague acceptance criteria; each AC must be testable with a clear pass/fail.
