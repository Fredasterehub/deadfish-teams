#!/usr/bin/env bash
# deadfish-teams v3 builder
# Runs 7 Codex tasks sequentially to build the entire plugin (skills-first architecture)
#
# Usage: bash build/run-v3.sh [--dry-run] [--start-from N]
#
# Changes from v2 runner:
#   - Points to build/prompts-v3/ (skills-first, 7 agents, 6 skills)
#   - Uses --sandbox danger-full-access (workspace-write caused approval_policy failures)
#   - Updated validation for v3 structure (7 agents, 6 skills, integrator)

set -euo pipefail

PROJECT_DIR="/tank/dump/DEV/deadfish-teams"
PROMPTS_DIR="$PROJECT_DIR/build/prompts-v3"
LOG_DIR="$PROJECT_DIR/build/logs/v3"
CODEX_MODEL="${CODEX_MODEL:-gpt-5.3-codex}"
CODEX_EFFORT="${CODEX_EFFORT:-high}"
DRY_RUN=false
START_FROM=1

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    --start-from) START_FROM="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

mkdir -p "$LOG_DIR"

TASKS=(
  "01-copy-bin.md"
  "02-copy-templates.md"
  "03-skills.md"
  "04-agents.md"
  "05-claude-md.md"
  "06-hooks-scripts.md"
  "07-readme-validate.md"
)

echo "========================================"
echo "  deadfish-teams v3 builder"
echo "  Model: $CODEX_MODEL"
echo "  Effort: $CODEX_EFFORT"
echo "  Tasks: ${#TASKS[@]}"
echo "  Start from: $START_FROM"
echo "  Dry run: $DRY_RUN"
echo "  Sandbox: danger-full-access"
echo "========================================"
echo ""

TOTAL=${#TASKS[@]}
PASSED=0
FAILED=0

for i in "${!TASKS[@]}"; do
  TASK_NUM=$((i + 1))

  # Skip if before start-from
  if [[ $TASK_NUM -lt $START_FROM ]]; then
    echo "[SKIP] Task $TASK_NUM/${TOTAL}: ${TASKS[$i]} (before --start-from)"
    continue
  fi

  TASK_FILE="$PROMPTS_DIR/${TASKS[$i]}"
  LOG_FILE="$LOG_DIR/task-$(printf '%02d' $TASK_NUM).log"
  TASK_NAME=$(head -1 "$TASK_FILE" | sed 's/^# //')

  echo "──────────────────────────────────────"
  echo "[START] Task $TASK_NUM/${TOTAL}: $TASK_NAME"
  echo "  Prompt: ${TASKS[$i]}"
  echo "  Log: $LOG_FILE"
  echo "  Time: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""

  if $DRY_RUN; then
    if [[ -f "$TASK_FILE" ]]; then
      echo "[DRY RUN] PASS — prompt file exists"
    else
      echo "[DRY RUN] FAIL — prompt file missing: $TASK_FILE"
    fi
    echo ""
    continue
  fi

  # Read prompt content
  PROMPT=$(cat "$TASK_FILE")

  # Run Codex in full-auto mode with full access sandbox
  if codex exec \
    -m "$CODEX_MODEL" \
    -c "model_reasoning_effort=\"$CODEX_EFFORT\"" \
    --full-auto \
    --sandbox danger-full-access \
    -C "$PROJECT_DIR" \
    "$PROMPT" \
    > "$LOG_FILE" 2>&1; then

    echo "[PASS] Task $TASK_NUM completed successfully"
    PASSED=$((PASSED + 1))
  else
    EXIT_CODE=$?
    echo "[FAIL] Task $TASK_NUM failed (exit code: $EXIT_CODE)"
    echo "  Check log: $LOG_FILE"
    FAILED=$((FAILED + 1))

    echo "TASK_FAILED: $TASK_NUM ($TASK_NAME) exit=$EXIT_CODE time=$(date -Iseconds)" >> "$LOG_DIR/failures.log"
  fi

  echo "  Finished: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
done

echo "========================================"
echo "  SUMMARY"
echo "  Total: $TOTAL"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"
echo "  Skipped: $((TOTAL - PASSED - FAILED))"
echo "  Finished: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"

# Run v3 validation if all passed
if [[ $FAILED -eq 0 && $DRY_RUN == false ]]; then
  echo ""
  echo "All tasks passed. Running v3 validation..."
  echo ""
  bash -c '
    cd /tank/dump/DEV/deadfish-teams
    echo "=== deadfish-teams v3 Validation ==="

    # Core
    for f in .claude-plugin/plugin.json .mcp.json CLAUDE.md README.md; do
      test -f "$f" && echo "PASS: $f" || echo "FAIL: $f"
    done

    # Agents (7)
    for a in brainstormer planner coder qa-reviewer conductor doc-keeper integrator; do
      test -f "agents/${a}.md" && echo "PASS: agents/${a}.md" || echo "FAIL: agents/${a}.md"
    done

    # Skills (6)
    for s in deadfish-core deadfish-planning deadfish-verify deadfish-implement deadfish-docs deadfish-conductor; do
      test -f "skills/${s}/SKILL.md" && echo "PASS: skills/${s}/SKILL.md" || echo "FAIL: skills/${s}/SKILL.md"
    done

    # Hooks
    test -f hooks/hooks.json && echo "PASS: hooks/hooks.json" || echo "FAIL: hooks/hooks.json"
    ls hooks/scripts/*.sh 2>/dev/null | wc -l | xargs -I{} echo "  {} hook scripts"

    # Bin
    for b in verify.sh parse-blocks.py build-verdict.py; do
      test -f "bin/${b}" && echo "PASS: bin/${b}" || echo "FAIL: bin/${b}"
    done

    # Templates + contracts
    echo "  $(find templates -name "*.md" 2>/dev/null | wc -l) templates"
    echo "  $(find contracts -name "*.md" 2>/dev/null | wc -l) contracts"

    echo ""
    echo "=== Git Log ==="
    git log --oneline
  '
fi

exit $FAILED
