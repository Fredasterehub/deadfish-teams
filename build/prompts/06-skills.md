# Task 06: Skills — Brainstorm, Verify, Reflect

Create 3 skill definitions in `/tank/dump/DEV/deadfish-teams/skills/`. Each skill is a `SKILL.md` file that defines a user-invocable command.

## File 1: `skills/brainstorm/SKILL.md`

```markdown
---
name: brainstorm
description: Start a BMAD-style brainstorm session for a new project or feature. Interactive — requires human participation.
user_invocable: true
---

# /brainstorm — Interactive Ideation Session

You are starting a brainstorm session. This is the entry point to the deadfish-teams pipeline.

## Instructions

1. **If no team exists yet**: Ask the Lead to create a team and spawn the Brainstormer teammate.
2. **If team exists**: Ask the Lead to spawn a Brainstormer teammate (if not already active).
3. **Direct the user** to message the Brainstormer teammate using Shift+Down.
4. **The Brainstormer will**:
   - Run the BMAD facilitated ideation session (Phases A-G)
   - Write 5 seed docs: VISION.md, PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.yaml
   - Run adversarial review
   - Shut down when complete

## After Brainstorm

Once the Brainstormer shuts down and the Lead confirms artifacts are ready:
- The Lead reads the seed docs
- The Lead creates the initial task list from the ROADMAP
- The Lead enters delegate mode for autonomous execution
- Workers are spawned for the first track

## Usage
```
/brainstorm                    # Start fresh brainstorm
/brainstorm --brownfield       # Existing project (runs mapper first)
```
```

## File 2: `skills/verify/SKILL.md`

```markdown
---
name: verify
description: Run verification on a task or track. Combines deterministic verify.sh with LLM acceptance criteria evaluation.
user_invocable: true
---

# /verify — Deterministic + LLM Verification

Run the verification pipeline on a task or track.

## Task-Level Verification

```
/verify task <task-id>
```

### Steps:
1. **Run verify.sh** against the project directory:
   ```bash
   bash bin/verify.sh --project-dir <project> --task-file tracks/<track>/tasks/TASK_<NNN>.md
   ```
   verify.sh checks: tests, linter, diff budget, blocked files, secrets, git clean.
   Output: structured JSON with pass/fail per check.

2. **If all DET checks pass**, fan out LLM criteria:
   - For each acceptance criterion tagged `LLM` in the task packet:
     - Prepare evidence bundle (diff hunks, test output, verify.sh results)
     - Evaluate with three-level rubric: EXISTS → SUBSTANTIVE → WIRED
     - Parse verdict using `bin/parse-blocks.py verdict`

3. **Aggregate** with build-verdict.py:
   ```bash
   echo "$verdicts" | python3 bin/build-verdict.py
   ```
   Output: PASS | FAIL | NEEDS_HUMAN

4. **Report** results to the Lead.

## Track-Level QA Review

```
/verify track <track-id>
```

Runs the P10 QA review across the entire track using `templates/verify/qa-review.md`.
Evaluates 6 categories: C0 Scope, C1 Docs, C2 Consistency, C3 Architecture, C4 Completeness, C5 Safety.

## Templates Used
- `templates/verify/verify-criterion.md` — Per-criterion evaluation rubric
- `templates/verify/qa-review.md` — Track-level QA review rubric
- `contracts/sentinel/verdict.v1.md` — VERDICT sentinel format
- `contracts/sentinel/qa-review.v1.md` — QA_REVIEW sentinel format
```

## File 3: `skills/reflect/SKILL.md`

```markdown
---
name: reflect
description: Run living docs reflection after a task passes verification. Significance-gated — may NOP if no meaningful changes.
user_invocable: true
---

# /reflect — Living Documentation Sync (P9.5)

Evaluate whether a completed task introduced knowledge worth capturing in the living docs.

## Usage

```
/reflect task <task-id>          # Per-task reflection (significance-gated)
/reflect flush                   # Force flush scratch buffer + reconcile all docs
/reflect status                  # Show current doc sizes vs budgets
```

## Per-Task Flow

1. **Evaluate significance triggers**:
   - manifest/lockfile changed?
   - diff_lines ≥ 120?
   - New CLI/script/CI artifact?
   - retry_count > 0?
   - Scope drift detected?
   - New architectural pattern?
   - Breaking change?

2. **Smart load** (only relevant docs):
   - Always: TECH_STACK, PATTERNS, PITFALLS
   - Conditional: WORKFLOW, PRODUCT, RISKS, GLOSSARY

3. **Decide action**:
   - **NOP**: No new information
   - **BUFFER**: Minor observation → append to `docs/living/.scratch.yaml`
   - **UPDATE**: Significant finding → edit specific doc
   - **FLUSH**: Track-end → flush buffer, reconcile all 7 docs

4. **Apply edits** within token budgets:
   | Doc | Budget (chars) |
   |-----|---------------|
   | TECH_STACK.md | 3200 |
   | PATTERNS.md | 3200 |
   | PITFALLS.md | 2800 |
   | RISKS.md | 2000 |
   | PRODUCT.md | 2800 |
   | WORKFLOW.md | 2800 |
   | GLOSSARY.md | 2000 |

   If doc exceeds 80% of budget → compress before commit.

## Template
Uses `templates/verify/reflect.md` and `contracts/sentinel/reflect.v1.md` for structured output.
```

## Commit

```bash
cd /tank/dump/DEV/deadfish-teams
git add skills/
git commit -m "feat: skills — brainstorm, verify, reflect

brainstorm: /brainstorm entry point for BMAD ideation
verify: /verify task/track for deterministic + LLM verification
reflect: /reflect for significance-gated living docs sync"
```

## Acceptance Criteria
- DET: `skills/brainstorm/SKILL.md` exists with `user_invocable: true`
- DET: `skills/verify/SKILL.md` exists with verify.sh command examples
- DET: `skills/reflect/SKILL.md` exists with all 7 doc budgets listed
- DET: All 3 files have valid `---` YAML frontmatter
- DET: Git commit created
