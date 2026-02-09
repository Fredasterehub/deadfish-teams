#!/bin/bash
# deadf(ish) Pipeline — verify.sh (Deterministic Verifier)
# Architecture: v2.4.2
#
# Runs purely deterministic checks against the current working tree:
#   1. Test suite        — run project test command, capture exit/count
#   2. Linter            — run project lint command, capture exit code
#   3. Git diff analysis — count changed lines, compare to ESTIMATED_DIFF
#   4. Path validation   — ensure only allowed files were modified
#   5. Secret scanning   — grep for common secret patterns
#   6. Git clean check   — no uncommitted files after implementation
#
# Output: structured JSON to stdout (all diagnostic logging to stderr).
# Exit 0 when pass=true.
# Exit non-zero when pass=false.
#
# This script NEVER interprets or judges results. Facts only.
# The orchestrator (Clawdbot) and LLM verifier handle judgment.

set -uo pipefail
SCRIPT_CONTRACT_VERSION="verify-exitcode-v1"
JSON_EMITTED=false

preflight_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

emit_preflight_json_and_exit() {
  local pass="$1"
  local exit_code="$2"
  local message="${3:-}"
  local timestamp
  JSON_EMITTED=true
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local failures_json="[]"
  if [[ "$pass" != "true" && -n "$message" ]]; then
    failures_json="[\"$(preflight_json_escape "$message")\"]"
  fi

  cat <<EOF
{
  "pass": ${pass},
  "checks": {
    "preflight": true,
    "error": "$(preflight_json_escape "$message")"
  },
  "failures": ${failures_json},
  "timestamp": "${timestamp}",
  "metadata": {
    "contract_version": "${SCRIPT_CONTRACT_VERSION}",
    "phase": "preflight"
  }
}
EOF
  exit "$exit_code"
}

emit_internal_error_fallback() {
  local exit_code="$1"
  trap - EXIT
  emit_preflight_json_and_exit false "${exit_code}" "internal verifier error (exit ${exit_code})"
}

trap 'status=$?; if [[ "${JSON_EMITTED}" != "true" ]]; then emit_internal_error_fallback "${status:-1}"; fi' EXIT

# ── CLI / Configuration ────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: verify.sh [--project-dir <dir>] [--task-file <path>] [--base-commit <sha>] [--mode <pre-commit|post-commit>]

Flags take precedence over env vars:
  --project-dir  > VERIFY_PROJECT_DIR
  --task-file    > VERIFY_TASK_FILE
  --base-commit  > VERIFY_BASE_COMMIT
  --mode         > VERIFY_MODE (default: post-commit)
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project-dir)
        [[ $# -ge 2 ]] || emit_preflight_json_and_exit false 1 "--project-dir requires a value"
        CLI_PROJECT_DIR="$2"
        shift 2
        ;;
      --project-dir=*)
        CLI_PROJECT_DIR="${1#*=}"
        shift
        ;;
      --task-file)
        [[ $# -ge 2 ]] || emit_preflight_json_and_exit false 1 "--task-file requires a value"
        CLI_TASK_FILE="$2"
        shift 2
        ;;
      --task-file=*)
        CLI_TASK_FILE="${1#*=}"
        shift
        ;;
      --base-commit)
        [[ $# -ge 2 ]] || emit_preflight_json_and_exit false 1 "--base-commit requires a value"
        CLI_BASE_COMMIT="$2"
        shift 2
        ;;
      --base-commit=*)
        CLI_BASE_COMMIT="${1#*=}"
        shift
        ;;
      --mode)
        [[ $# -ge 2 ]] || emit_preflight_json_and_exit false 1 "--mode requires a value"
        CLI_MODE="$2"
        shift 2
        ;;
      --mode=*)
        CLI_MODE="${1#*=}"
        shift
        ;;
      -h|--help)
        usage >&2
        emit_preflight_json_and_exit true 0 "help requested"
        ;;
      *)
        usage >&2
        emit_preflight_json_and_exit false 1 "unknown argument: $1"
        ;;
    esac
  done
}

CLI_PROJECT_DIR=""
CLI_TASK_FILE=""
CLI_BASE_COMMIT=""
CLI_MODE=""
parse_args "$@"

PROJECT_DIR="${CLI_PROJECT_DIR:-${VERIFY_PROJECT_DIR:-.}}"
TASK_FILE_OVERRIDE="${CLI_TASK_FILE:-${VERIFY_TASK_FILE:-}}"
BASE_COMMIT="${CLI_BASE_COMMIT:-${VERIFY_BASE_COMMIT:-}}"
MODE="${CLI_MODE:-${VERIFY_MODE:-post-commit}}"
CHECK_TIMEOUT="${VERIFY_CHECK_TIMEOUT:-120}"

case "$MODE" in
  pre-commit|post-commit) ;;
  *)
    emit_preflight_json_and_exit false 1 "--mode must be pre-commit or post-commit (got '$MODE')"
    ;;
esac

# ── Task Discovery ─────────────────────────────────────────────────────────
DEADF_ROOT="${VERIFY_DEADF_ROOT:-${PROJECT_DIR:-$(pwd)}}"
STATE_FILE="${DEADF_ROOT}/STATE.yaml"

if [[ -n "$TASK_FILE_OVERRIDE" ]]; then
  TASK_FILE="$TASK_FILE_OVERRIDE"
else
  TASK_FILE=""
  if command -v yq &>/dev/null && [[ -f "$STATE_FILE" ]]; then
    TRACK_ID=$(yq -r '.track.id // "null"' "$STATE_FILE" 2>/dev/null || echo "null")
    TASK_CURRENT=$(yq -r '.track.task_current // "null"' "$STATE_FILE" 2>/dev/null || echo "null")
    if [[ "$TRACK_ID" != "null" && "$TASK_CURRENT" != "null" && "$TASK_CURRENT" =~ ^[0-9]+$ ]]; then
      TASK_NUM=$(printf '%03d' "$TASK_CURRENT")
      TASK_FILE="${DEADF_ROOT}/tracks/${TRACK_ID}/tasks/${TASK_NUM}.task.md"
    fi
  fi

  if [[ -z "$TASK_FILE" ]]; then
    TASK_FILE="${DEADF_ROOT}/TASK.md"
  fi
fi

# ── Globals ────────────────────────────────────────────────────────────────
FAILURES=()
PASS=true
DIFF_BASE_REF=""

# ── Helpers ────────────────────────────────────────────────────────────────

log() { echo "[verify] $*" >&2; }

# Run a command with timeout. Returns the command's exit code (or 124 on timeout).
run_with_timeout() {
  local label="$1"; shift
  if command -v timeout &>/dev/null; then
    timeout "$CHECK_TIMEOUT" "$@"
  else
    log "WARN: 'timeout' not available, running $label without timeout"
    "$@"
  fi
  return $?
}

# Read a field from STATE.yaml using yq. Returns "null" if missing.
read_state() {
  local path="$1"
  if command -v yq &>/dev/null && [[ -f "$STATE_FILE" ]]; then
    yq -r ".$path // \"null\"" "$STATE_FILE" 2>/dev/null || echo "null"
  else
    echo "null"
  fi
}

# JSON-escape a string (handles quotes, backslashes, newlines, tabs).
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# Add a failure message and mark overall pass as false.
add_failure() {
  FAILURES+=("$1")
  PASS=false
}

# Extract the first integer found in a string.
extract_first_int() {
  local s="$1"
  if [[ "$s" =~ ([0-9]+) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}

# Extract content under a markdown "## SECTION" heading until the next "## ...".
extract_markdown_section() {
  local task_file="$1"
  local section="$2"
  awk -v want="$(printf '%s' "$section" | tr '[:upper:]' '[:lower:]')" '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    {
      if ($0 ~ /^[[:space:]]*##[[:space:]]+/) {
        heading=$0
        sub(/^[[:space:]]*##[[:space:]]+/, "", heading)
        heading=tolower(trim(heading))
        if (in_section == 1) exit
        if (heading == want) {
          in_section=1
          next
        }
      }
      if (in_section == 1) print
    }
  ' "$task_file" 2>/dev/null || true
}

# Determine which git base ref should be used by checks.
resolve_diff_base() {
  DIFF_BASE_REF=""

  if ! command -v git &>/dev/null; then
    return
  fi

  cd "$PROJECT_DIR" || return

  if [[ -n "$BASE_COMMIT" ]]; then
    if git rev-parse --verify "${BASE_COMMIT}^{commit}" &>/dev/null; then
      DIFF_BASE_REF="$BASE_COMMIT"
    else
      add_failure "base_commit invalid or not found: $BASE_COMMIT"
      if git rev-parse --verify HEAD^{commit} &>/dev/null; then
        DIFF_BASE_REF="HEAD"
      fi
    fi
  elif git rev-parse --verify HEAD^{commit} &>/dev/null; then
    DIFF_BASE_REF="HEAD"
    if [[ "$MODE" == "post-commit" ]]; then
      log "WARN: --base-commit not set in post-commit mode; using HEAD"
    fi
  fi
}

# Return numstat output for the configured mode.
git_collect_numstat() {
  if [[ "$MODE" == "pre-commit" ]]; then
    if [[ -n "$DIFF_BASE_REF" ]]; then
      git diff --numstat "$DIFF_BASE_REF" 2>/dev/null || true
    else
      { git diff --numstat 2>/dev/null || true; git diff --cached --numstat 2>/dev/null || true; } | awk 'NF'
    fi
  else
    if [[ -n "$DIFF_BASE_REF" ]]; then
      git diff --numstat "${DIFF_BASE_REF}..HEAD" 2>/dev/null || true
    fi
  fi
}

# Return changed file list for the configured mode.
git_collect_changed_files() {
  if [[ "$MODE" == "pre-commit" ]]; then
    if [[ -n "$DIFF_BASE_REF" ]]; then
      git diff --name-only "$DIFF_BASE_REF" 2>/dev/null || true
    else
      { git diff --name-only 2>/dev/null || true; git diff --cached --name-only 2>/dev/null || true; } | awk 'NF' | sort -u
    fi
  else
    if [[ -n "$DIFF_BASE_REF" ]]; then
      git diff --name-only "${DIFF_BASE_REF}..HEAD" 2>/dev/null || true
    fi
  fi
}

# Return raw diff content for the configured mode.
git_collect_diff_content() {
  if [[ "$MODE" == "pre-commit" ]]; then
    if [[ -n "$DIFF_BASE_REF" ]]; then
      git diff "$DIFF_BASE_REF" 2>/dev/null || true
    else
      { git diff 2>/dev/null || true; git diff --cached 2>/dev/null || true; }
    fi
  else
    if [[ -n "$DIFF_BASE_REF" ]]; then
      git diff "${DIFF_BASE_REF}..HEAD" 2>/dev/null || true
    fi
  fi
}

# Parse TASK file for estimated_diff and allowed paths.
parse_task_file() {
  local task_file="$1"
  TASK_ESTIMATED_DIFF=""
  TASK_ALLOWED_PATHS=()

  [[ -f "$task_file" ]] || return 0

  local first_line
  first_line=$(head -n 1 "$task_file" 2>/dev/null || true)

  # Optional YAML frontmatter support (legacy).
  if [[ "$first_line" == "---" ]]; then
    local frontmatter
    frontmatter=$(sed -n '2,/^---$/{ /^---$/d; p }' "$task_file" 2>/dev/null || true)
    if [[ -n "$frontmatter" ]] && command -v yq &>/dev/null; then
      TASK_ESTIMATED_DIFF=$(printf '%s\n' "$frontmatter" | yq -r '.estimated_diff // ""' 2>/dev/null || true)
      mapfile -t TASK_ALLOWED_PATHS < <(printf '%s\n' "$frontmatter" | yq -r '.files[].path // empty' 2>/dev/null || true)
    fi
  fi

  # Canonical v3 markdown section:
  # ## FILES
  # - path: src/file.ts
  #   action: add
  if [[ ${#TASK_ALLOWED_PATHS[@]} -eq 0 ]]; then
    local files_section
    files_section=$(extract_markdown_section "$task_file" "FILES")
    if [[ -n "$files_section" ]]; then
      while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*path:[[:space:]]*(.+)$ ]]; then
          local raw_path="${BASH_REMATCH[1]}"
          raw_path="${raw_path%%#*}"
          raw_path=$(echo "$raw_path" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
          # Drop draft pipe-delimited format: "path: x | action: y"
          if [[ -z "$raw_path" || "$raw_path" == *"|"* ]]; then
            continue
          fi
          if [[ "$raw_path" =~ ^\"(.*)\"$ ]]; then
            raw_path="${BASH_REMATCH[1]}"
          elif [[ "$raw_path" =~ ^\'(.*)\'$ ]]; then
            raw_path="${BASH_REMATCH[1]}"
          fi
          TASK_ALLOWED_PATHS+=("$raw_path")
        fi
      done <<< "$files_section"
    fi
  fi

  # v1 compat (accepted): path=src/foo.ts action=add
  if [[ ${#TASK_ALLOWED_PATHS[@]} -eq 0 ]]; then
    mapfile -t TASK_ALLOWED_PATHS < <(grep -oP 'path=\K[^\s]+' "$task_file" 2>/dev/null || true)
  fi

  # ESTIMATED_DIFF from frontmatter, section, or inline yaml-like key.
  TASK_ESTIMATED_DIFF=$(extract_first_int "${TASK_ESTIMATED_DIFF:-}")
  if [[ -z "$TASK_ESTIMATED_DIFF" ]]; then
    local estimated_section
    estimated_section=$(extract_markdown_section "$task_file" "ESTIMATED_DIFF")
    TASK_ESTIMATED_DIFF=$(extract_first_int "$estimated_section")
  fi
  if [[ -z "$TASK_ESTIMATED_DIFF" ]]; then
    local estimate_line
    estimate_line=$(grep -im1 -E 'estimated_diff[[:space:]]*:' "$task_file" 2>/dev/null || true)
    TASK_ESTIMATED_DIFF=$(extract_first_int "$estimate_line")
  fi
}

# ── Check 1: Test Suite ───────────────────────────────────────────────────

check_tests() {
  local test_exit=0
  local test_count=0
  local test_summary="no tests found"
  local test_output=""

  # Detect test runner
  local test_cmd=""
  if [[ -f "${PROJECT_DIR}/package.json" ]]; then
    if command -v npm &>/dev/null; then
      test_cmd="npm test"
    fi
  elif [[ -f "${PROJECT_DIR}/pytest.ini" ]] || [[ -f "${PROJECT_DIR}/setup.py" ]] || \
       [[ -f "${PROJECT_DIR}/pyproject.toml" ]] || [[ -d "${PROJECT_DIR}/tests" ]]; then
    if command -v pytest &>/dev/null; then
      test_cmd="pytest --tb=short -q"
    elif command -v python3 &>/dev/null; then
      test_cmd="python3 -m pytest --tb=short -q"
    fi
  elif [[ -f "${PROJECT_DIR}/Makefile" ]] && grep -q '^test:' "${PROJECT_DIR}/Makefile" 2>/dev/null; then
    test_cmd="make test"
  fi

  if [[ -z "$test_cmd" ]]; then
    log "WARN: No test runner detected, skipping test check"
    test_summary="skipped (no test runner detected)"
    # Not a failure — missing test infrastructure is not a verify failure
  else
    log "Running tests: $test_cmd"
    test_output=$(cd "$PROJECT_DIR" && run_with_timeout "tests" bash -c "$test_cmd" 2>&1) && test_exit=0 || test_exit=$?

    # Try to extract test count from common output formats
    # pytest: "X passed, Y failed" or "X passed"
    # jest/mocha: "X passing" / "X failing"
    if echo "$test_output" | grep -qP '\d+ passed'; then
      local passed failed
      passed=$(echo "$test_output" | grep -oP '\d+(?= passed)' | tail -1)
      failed=$(echo "$test_output" | grep -oP '\d+(?= failed)' | tail -1)
      failed="${failed:-0}"
      test_count=$((passed + failed))
      test_summary="${passed} passed, ${failed} failed"
    elif echo "$test_output" | grep -qP '\d+ passing'; then
      local passing failing
      passing=$(echo "$test_output" | grep -oP '\d+(?= passing)' | tail -1)
      failing=$(echo "$test_output" | grep -oP '\d+(?= failing)' | tail -1)
      failing="${failing:-0}"
      test_count=$((passing + failing))
      test_summary="${passing} passed, ${failing} failed"
    elif echo "$test_output" | grep -qP 'Tests:\s+\d+'; then
      # Jest summary line: Tests: X passed, Y total
      test_count=$(echo "$test_output" | grep -oP 'Tests:\s+.*?(\d+)\s+total' | grep -oP '\d+(?=\s+total)' | tail -1)
      test_count="${test_count:-0}"
      test_summary="exit code $test_exit ($test_count tests detected)"
    else
      test_summary="exit code $test_exit (count unknown)"
    fi

    if [[ "$test_exit" -eq 5 ]]; then
      # pytest exit code 5 = no tests collected (non-fatal)
      test_summary="no tests found (non-fatal)"
    elif [[ "$test_exit" -ne 0 ]]; then
      add_failure "test_exit != 0: tests failed (exit $test_exit)"
    fi
  fi

  # Export for JSON assembly
  CHECK_TEST_EXIT="$test_exit"
  CHECK_TEST_COUNT="$test_count"
  CHECK_TEST_SUMMARY="$test_summary"
}

# ── Check 2: Linter ──────────────────────────────────────────────────────

check_lint() {
  local lint_exit=0
  local lint_cmd=""

  # Detect linter
  if [[ -f "${PROJECT_DIR}/package.json" ]]; then
    if command -v npx &>/dev/null && { ls "${PROJECT_DIR}"/.eslintrc* &>/dev/null || \
       grep -q '"eslint"' "${PROJECT_DIR}/package.json" 2>/dev/null; }; then
      lint_cmd="npx eslint . --max-warnings=0"
    fi
  elif [[ -f "${PROJECT_DIR}/pyproject.toml" ]] || [[ -f "${PROJECT_DIR}/setup.cfg" ]]; then
    if command -v ruff &>/dev/null; then
      lint_cmd="ruff check ."
    elif command -v flake8 &>/dev/null; then
      lint_cmd="flake8 ."
    fi
  elif [[ -f "${PROJECT_DIR}/Makefile" ]] && grep -q '^lint:' "${PROJECT_DIR}/Makefile" 2>/dev/null; then
    lint_cmd="make lint"
  fi

  if [[ -z "$lint_cmd" ]]; then
    log "WARN: No linter detected, skipping lint check"
    lint_exit=0  # Skip gracefully — not a failure
  else
    log "Running linter: $lint_cmd"
    local lint_output
    lint_output=$(cd "$PROJECT_DIR" && run_with_timeout "lint" bash -c "$lint_cmd" 2>&1) && lint_exit=0 || lint_exit=$?

    if [[ "$lint_exit" -ne 0 ]]; then
      add_failure "lint_exit != 0: linter reported issues (exit $lint_exit)"
    fi
  fi

  CHECK_LINT_EXIT="$lint_exit"
}

# ── Check 3: Git Diff Analysis ───────────────────────────────────────────

check_diff() {
  local diff_lines=0
  local diff_ok=true
  local numstat_output=""

  if ! command -v git &>/dev/null; then
    log "WARN: git not available, skipping diff check"
    CHECK_DIFF_LINES=0
    CHECK_DIFF_OK=true
    return
  fi

  cd "$PROJECT_DIR" || return

  # Count diff lines with mode-aware base selection.
  numstat_output=$(git_collect_numstat)

  if [[ -n "$numstat_output" ]]; then
    local total=0
    while IFS=$'\t' read -r added deleted _path; do
      [[ -z "$added" && -z "$deleted" ]] && continue
      [[ "$added" == "-" ]] && added=0
      [[ "$deleted" == "-" ]] && deleted=0
      [[ "$added" =~ ^[0-9]+$ ]] || added=0
      [[ "$deleted" =~ ^[0-9]+$ ]] || deleted=0
      total=$((total + added + deleted))
    done <<< "$numstat_output"
    diff_lines="$total"
  fi

  local estimated_diff="${TASK_ESTIMATED_DIFF}"
  if [[ -n "$estimated_diff" && "$estimated_diff" =~ ^[0-9]+$ && "$estimated_diff" -gt 0 ]]; then
    # Allow 3x the estimate as a reasonable tolerance
    local max_allowed=$((estimated_diff * 3))
    if [[ "$diff_lines" -gt "$max_allowed" ]]; then
      diff_ok=false
      add_failure "diff_lines ($diff_lines) exceeds 3x ESTIMATED_DIFF ($estimated_diff, max=$max_allowed)"
    fi
  fi

  CHECK_DIFF_LINES="$diff_lines"
  CHECK_DIFF_OK="$diff_ok"
}

# ── Check 4: Path Validation ─────────────────────────────────────────────

check_paths() {
  local paths_ok=true
  local -a blocked_files=()
  local -a hard_blocked_files=()
  local -a scope_violations=()

  if ! command -v git &>/dev/null; then
    log "WARN: git not available, skipping path check"
    CHECK_PATHS_OK=true
    CHECK_BLOCKED_FILES=()
    return
  fi

  cd "$PROJECT_DIR" || return

  # Get list of changed files
  local -a changed_files=()
  mapfile -t changed_files < <(git_collect_changed_files)

  # Get allowed paths from TASK file (canonical v3 or compat v1)
  local -a allowed_paths=()
  if [[ ${#TASK_ALLOWED_PATHS[@]} -gt 0 ]]; then
    allowed_paths=("${TASK_ALLOWED_PATHS[@]}")
  fi

  # Always-blocked patterns (security-sensitive)
  local -a blocked_patterns=(
    "^\.env$"
    "^\.env\."
    ".*\.pem$"
    ".*\.key$"
    "^\.ssh/"
    "^\.git/"  # Should never appear, but safety net
  )

  for f in "${changed_files[@]}"; do
    [[ -z "$f" ]] && continue

    # Check against blocked patterns
    for pattern in "${blocked_patterns[@]}"; do
      if echo "$f" | grep -qP "$pattern"; then
        blocked_files+=("$f")
        hard_blocked_files+=("$f")
        paths_ok=false
      fi
    done

    # If we have an allowed list, check the file is on it
    if [[ ${#allowed_paths[@]} -gt 0 ]]; then
      local found=false
      for allowed in "${allowed_paths[@]}"; do
        if [[ "$f" == "$allowed" ]]; then
          found=true
          break
        fi
      done
      if [[ "$found" == "false" ]]; then
        scope_violations+=("$f")
        blocked_files+=("$f")
        paths_ok=false
      fi
    fi
  done

  if [[ ${#scope_violations[@]} -gt 0 ]]; then
    add_failure "paths_ok: scope violations (not in TASK FILES): ${scope_violations[*]}"
  fi
  if [[ ${#hard_blocked_files[@]} -gt 0 ]]; then
    add_failure "paths_ok: blocked files modified: ${hard_blocked_files[*]}"
  fi

  CHECK_PATHS_OK="$paths_ok"
  CHECK_BLOCKED_FILES=("${blocked_files[@]}")
}

# ── Check 5: Secret Scanning ─────────────────────────────────────────────

check_secrets() {
  local secrets_found=false
  local -a secret_matches=()

  if ! command -v git &>/dev/null; then
    log "WARN: git not available, skipping secret scan"
    CHECK_SECRETS_FOUND=false
    CHECK_SECRET_MATCHES=()
    return
  fi

  cd "$PROJECT_DIR" || return

  # Get diff content to scan
  local diff_content=""
  diff_content=$(git_collect_diff_content)

  # Secret patterns (added lines only — lines starting with +)
  local -a patterns=(
    # API keys / tokens
    'AKIA[0-9A-Z]{16}'                          # AWS Access Key
    'sk-[a-zA-Z0-9]{20,}'                       # OpenAI / Stripe secret key
    'ghp_[a-zA-Z0-9]{36}'                       # GitHub personal access token
    'gho_[a-zA-Z0-9]{36}'                       # GitHub OAuth token
    'github_pat_[a-zA-Z0-9_]{82}'               # GitHub fine-grained PAT
    'glpat-[a-zA-Z0-9\-]{20}'                   # GitLab PAT
    'xox[bpras]-[a-zA-Z0-9\-]+'                 # Slack tokens
    # Generic patterns
    '["\x27]?[a-zA-Z_]*(?:SECRET|TOKEN|KEY|PASSWORD|PASSWD|API_KEY|APIKEY|ACCESS_KEY)["\x27]?\s*[=:]\s*["\x27][^\s"'\'']{8,}["\x27]'
    # Private keys
    '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'
    # Connection strings
    '(?:mysql|postgres|mongodb|redis)://[^\s]{10,}'
  )

  # Only scan added lines (lines starting with +, but not +++ header)
  local added_lines
  added_lines=$(echo "$diff_content" | grep '^+[^+]' | sed 's/^+//' || true)

  for pattern in "${patterns[@]}"; do
    local matches
    matches=$(echo "$added_lines" | grep -oP "$pattern" 2>/dev/null || true)
    if [[ -n "$matches" ]]; then
      secrets_found=true
      while IFS= read -r match; do
        # Truncate match for safety (don't leak actual secrets in output)
        local truncated="${match:0:20}..."
        secret_matches+=("$truncated")
      done <<< "$matches"
    fi
  done

  if [[ "$secrets_found" == "true" ]]; then
    add_failure "secrets_found: potential secrets detected in diff (${#secret_matches[@]} matches)"
  fi

  CHECK_SECRETS_FOUND="$secrets_found"
  CHECK_SECRET_MATCHES=("${secret_matches[@]}")
}

# ── Check 6: Git Clean ───────────────────────────────────────────────────

check_git_clean() {
  local git_clean=true
  local -a uncommitted_files=()

  if [[ "$MODE" == "pre-commit" ]]; then
    log "Skipping git clean check in pre-commit mode"
    CHECK_GIT_CLEAN=true
    CHECK_UNCOMMITTED_FILES=()
    return
  fi

  if ! command -v git &>/dev/null; then
    log "WARN: git not available, skipping git clean check"
    CHECK_GIT_CLEAN=true
    CHECK_UNCOMMITTED_FILES=()
    return
  fi

  cd "$PROJECT_DIR" || return

  # Check for uncommitted changes
  local status_output
  status_output=$(git status --porcelain 2>/dev/null || true)

  if [[ -n "$status_output" ]]; then
    git_clean=false
    mapfile -t uncommitted_files < <(echo "$status_output" | awk '{print $2}')
    add_failure "git_clean: uncommitted files found (${#uncommitted_files[@]} files)"
  fi

  CHECK_GIT_CLEAN="$git_clean"
  CHECK_UNCOMMITTED_FILES=("${uncommitted_files[@]}")
}

# ── JSON Assembly ─────────────────────────────────────────────────────────

emit_json() {
  local timestamp
  JSON_EMITTED=true
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build JSON arrays for blocked_files, secret_matches, uncommitted_files, failures
  local blocked_json="[]"
  if [[ ${#CHECK_BLOCKED_FILES[@]} -gt 0 ]]; then
    blocked_json="["
    local first=true
    for f in "${CHECK_BLOCKED_FILES[@]}"; do
      [[ "$first" == "true" ]] && first=false || blocked_json+=","
      blocked_json+="\"$(json_escape "$f")\""
    done
    blocked_json+="]"
  fi

  local secrets_json="[]"
  if [[ ${#CHECK_SECRET_MATCHES[@]} -gt 0 ]]; then
    secrets_json="["
    local first=true
    for s in "${CHECK_SECRET_MATCHES[@]}"; do
      [[ "$first" == "true" ]] && first=false || secrets_json+=","
      secrets_json+="\"$(json_escape "$s")\""
    done
    secrets_json+="]"
  fi

  local uncommitted_json="[]"
  if [[ ${#CHECK_UNCOMMITTED_FILES[@]} -gt 0 ]]; then
    uncommitted_json="["
    local first=true
    for u in "${CHECK_UNCOMMITTED_FILES[@]}"; do
      [[ "$first" == "true" ]] && first=false || uncommitted_json+=","
      uncommitted_json+="\"$(json_escape "$u")\""
    done
    uncommitted_json+="]"
  fi

  local failures_json="[]"
  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    failures_json="["
    local first=true
    for f in "${FAILURES[@]}"; do
      [[ "$first" == "true" ]] && first=false || failures_json+=","
      failures_json+="\"$(json_escape "$f")\""
    done
    failures_json+="]"
  fi

  # Emit the full JSON
  cat <<EOF
{
  "pass": ${PASS},
  "checks": {
    "test_exit": ${CHECK_TEST_EXIT},
    "test_count": ${CHECK_TEST_COUNT},
    "test_summary": "$(json_escape "$CHECK_TEST_SUMMARY")",
    "lint_exit": ${CHECK_LINT_EXIT},
    "diff_lines": ${CHECK_DIFF_LINES},
    "diff_ok": ${CHECK_DIFF_OK},
    "paths_ok": ${CHECK_PATHS_OK},
    "blocked_files": ${blocked_json},
    "secrets_found": ${CHECK_SECRETS_FOUND},
    "secret_matches": ${secrets_json},
    "git_clean": ${CHECK_GIT_CLEAN},
    "uncommitted_files": ${uncommitted_json}
  },
  "failures": ${failures_json},
  "timestamp": "${timestamp}",
  "metadata": {
    "contract_version": "${SCRIPT_CONTRACT_VERSION}",
    "mode": "$(json_escape "$MODE")",
    "project_dir": "$(json_escape "$PROJECT_DIR")",
    "task_file": "$(json_escape "$TASK_FILE")",
    "base_commit": "$(json_escape "$BASE_COMMIT")",
    "diff_base_ref": "$(json_escape "$DIFF_BASE_REF")",
    "check_timeout_seconds": "$(json_escape "$CHECK_TIMEOUT")"
  }
}
EOF
}

# ── Main ──────────────────────────────────────────────────────────────────

main() {
  log "Starting deterministic verification (mode=${MODE}, timeout=${CHECK_TIMEOUT}s per check)"

  # Initialize all check variables to safe defaults
  CHECK_TEST_EXIT=0
  CHECK_TEST_COUNT=0
  CHECK_TEST_SUMMARY="not run"
  CHECK_LINT_EXIT=0
  CHECK_DIFF_LINES=0
  CHECK_DIFF_OK=true
  CHECK_PATHS_OK=true
  CHECK_BLOCKED_FILES=()
  CHECK_SECRETS_FOUND=false
  CHECK_SECRET_MATCHES=()
  CHECK_GIT_CLEAN=true
  CHECK_UNCOMMITTED_FILES=()

  # Resolve task metadata and mode-aware git base once for all checks.
  parse_task_file "$TASK_FILE"
  resolve_diff_base

  # Run all checks (order matters: fast/simple first)
  check_git_clean
  check_paths
  check_secrets
  check_diff
  check_lint
  check_tests

  # Emit structured JSON to stdout
  emit_json

  local exit_code=1
  if [[ "$PASS" == "true" ]]; then
    exit_code=0
  fi

  log "Verification complete. pass=${PASS}, failures=${#FAILURES[@]}, exit_code=${exit_code}"
  exit "${exit_code}"
}

main
