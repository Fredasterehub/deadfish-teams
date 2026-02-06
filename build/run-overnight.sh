#!/usr/bin/env bash
# deadfish-teams overnight builder
# Runs 7 Codex tasks sequentially to build the entire plugin
#
# Usage: bash build/run-overnight.sh [--dry-run] [--start-from N]
#
# Each task is self-contained with clear acceptance criteria.
# Codex runs in full-auto mode with workspace-write sandbox.

set -euo pipefail

PROJECT_DIR="/tank/dump/DEV/deadfish-teams"
PROMPTS_DIR="$PROJECT_DIR/build/prompts"
LOG_DIR="$PROJECT_DIR/build/logs"
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
  "01-scaffold.md"
  "02-copy-artifacts.md"
  "03-agents-brainstorm-planner-coder.md"
  "04-agents-qa-conductor-doc.md"
  "05-claude-md.md"
  "06-skills.md"
  "07-hooks-readme-validate.md"
)

echo "========================================"
echo "  deadfish-teams overnight builder"
echo "  Model: $CODEX_MODEL"
echo "  Effort: $CODEX_EFFORT"
echo "  Tasks: ${#TASKS[@]}"
echo "  Start from: $START_FROM"
echo "  Dry run: $DRY_RUN"
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
    echo "[DRY RUN] Would execute: codex exec -m $CODEX_MODEL ..."
    echo ""
    continue
  fi

  # Read prompt content
  PROMPT=$(cat "$TASK_FILE")

  # Run Codex in full-auto mode
  # No timeout — GPT-5.2/5.3 can be slow, that's normal
  if codex exec \
    -m "$CODEX_MODEL" \
    -c "model_reasoning_effort=\"$CODEX_EFFORT\"" \
    --full-auto \
    --sandbox workspace-write \
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

    # Don't abort — some tasks may be recoverable
    # But log the failure clearly
    echo "TASK_FAILED: $TASK_NUM ($TASK_NAME) exit=$EXIT_CODE" >> "$LOG_DIR/failures.log"
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

# Run validation if all passed
if [[ $FAILED -eq 0 && $DRY_RUN == false ]]; then
  echo ""
  echo "All tasks passed. Running validation..."
  echo ""
  bash -c '
    cd /tank/dump/DEV/deadfish-teams
    echo "=== Plugin Validation ==="
    test -f .claude-plugin/plugin.json && echo "PASS: plugin.json" || echo "FAIL: plugin.json"
    test -f .mcp.json && echo "PASS: .mcp.json" || echo "FAIL: .mcp.json"
    for agent in brainstormer planner coder qa-reviewer conductor doc-keeper; do
      test -f "agents/${agent}.md" && echo "PASS: agents/${agent}.md" || echo "FAIL: agents/${agent}.md"
    done
    for skill in brainstorm verify reflect; do
      test -f "skills/${skill}/SKILL.md" && echo "PASS: skills/${skill}/SKILL.md" || echo "FAIL: skills/${skill}/SKILL.md"
    done
    test -f hooks/hooks.json && echo "PASS: hooks/hooks.json" || echo "FAIL: hooks/hooks.json"
    test -f CLAUDE.md && echo "PASS: CLAUDE.md" || echo "FAIL: CLAUDE.md"
    test -f README.md && echo "PASS: README.md" || echo "FAIL: README.md"
    for script in verify.sh parse-blocks.py build-verdict.py; do
      test -f "bin/${script}" && echo "PASS: bin/${script}" || echo "FAIL: bin/${script}"
    done
    echo ""
    echo "=== Git Log ==="
    git log --oneline 2>/dev/null || echo "(no git repo)"
  '
fi

exit $FAILED
