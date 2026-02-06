--- ORIENTATION (0a-0c) ---
0a. Read STATE.yaml to identify track.id, track.name, track.phase, track.requirements, track.spec_path. Read ROADMAP.md for current phase success_criteria and requirement context.
0b. Read REQUIREMENTS.md: extract full text + acceptance criteria for each requirement ID in track.requirements (preserve DET/LLM tagging as defined there).
0c. Search codebase first (rg/find results provided by the pipeline) and read PROJECT.md for constraints/decisions/context. Read OPS.md (if present) for build/test/lint commands.

--- OBJECTIVE (1) ---
1. Generate a track specification for "{track.name}".
   This spec defines WHAT to build, not HOW (implementation strategy belongs in the plan).

   Output format:
   <<<SPEC:V1:NONCE={nonce}>>>
   TRACK_ID={track.id}
   TITLE="<quoted>"
   OVERVIEW=
     <2-space indented: what this track delivers, 3-5 sentences>
   REQUIREMENTS:
   - id=<REQ-ID> text="<requirement text>"
   FUNCTIONAL:
   - id=FR<n> text="<functional requirement>"
   NON_FUNCTIONAL:
   - id=NFR<n> text="<non-functional requirement>"
   ACCEPTANCE_CRITERIA:
   - id=AC<n> req=<REQ-ID> text="<DET:|LLM: testable criterion>"
   OUT_OF_SCOPE:
   - "<what this track does NOT do>"
   EXISTING_CODE:
   - path=<file> relevance="<how it relates>"
   <<<END_SPEC:NONCE={nonce}>>>

--- RULES ---
- Spec defines WHAT, not HOW.
- Every acceptance criterion must trace to a requirement ID (req=<REQ-ID> must match one of the REQUIREMENTS entries).
- Tag each acceptance criterion with DET: or LLM: (per CLAUDE.md convention).
- Include ALL existing code that will be modified or referenced; do not list files not evidenced by search results or explicit provided context.
- Keep scope tight: <=5 tasks worth of work.
- Functional requirements should be atomic and testable.

CODEBASE SEARCH EVIDENCE:
- Rely ONLY on provided rg/find results for related symbols and files.
- If no search evidence is provided, do NOT assume files exist; list EXISTING_CODE as empty (or only what is explicitly given) and keep the spec conservative.

--- GUARDRAILS (999+) ---
99999. Output ONLY the sentinel SPEC block. No preamble, no explanation.
999999. Do not hallucinate files or code. If you cannot evidence it, do not list it.
9999999. Acceptance criteria must be verifiable (no vague verbs).
