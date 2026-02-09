#!/usr/bin/env bash
set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BIN_DIR="${REPO_ROOT}/bin"
SCHEMAS_PATH="${REPO_ROOT}/contracts/sentinel/v3/schemas.yaml"
DOCS_LIVING_DIR="${REPO_ROOT}/docs/living"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/deadfish-smoke.XXXXXX")"
LOG_DIR="${TMP_ROOT}/logs"
mkdir -p "${LOG_DIR}"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
PHASE_COUNT=0
BASE_COMMIT=""

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "FATAL: required command not found: ${cmd}" >&2
    exit 2
  fi
}

print_header() {
  echo "deadfish v3 smoke-run"
  echo "repo: ${REPO_ROOT}"
  echo "tmp : ${TMP_ROOT}"
  echo
}

phase_file() {
  local phase_num="$1"
  local slug="$2"
  echo "${LOG_DIR}/$(printf '%02d' "${phase_num}")_${slug}.log"
}

run_phase() {
  local name="$1"
  local slug="$2"
  shift 2

  PHASE_COUNT=$((PHASE_COUNT + 1))
  local logfile
  logfile="$(phase_file "${PHASE_COUNT}" "${slug}")"

  echo "==> ${name}"

  "$@" >"${logfile}" 2>&1
  local rc=$?

  if [[ ${rc} -eq 0 ]]; then
    echo "PASS ${name}"
    PASS_COUNT=$((PASS_COUNT + 1))
    return 0
  fi

  if [[ ${rc} -eq 100 ]]; then
    echo "SKIP ${name}"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    return 0
  fi

  echo "FAIL ${name} (exit ${rc})"
  echo "--- diagnostics (${logfile}) ---"
  sed -n '1,160p' "${logfile}"
  echo "--- end diagnostics ---"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  return 0
}

setup_minimal_temp_project() {
  local proj="${TMP_ROOT}/project"
  mkdir -p "${proj}/src"

  cd "${proj}" || return 1
  git init -q
  git config user.email "smoke-run@example.com"
  git config user.name "Smoke Run"

  cat > "TASK.md" <<'TASK'
## FILES
- path: src/example.txt
  action: modify
  rationale: deterministic smoke fixture

## ESTIMATED_DIFF
10
TASK

  echo "base" > "src/example.txt"

  git add TASK.md src/example.txt
  git commit -q -m "base fixture"
  BASE_COMMIT="$(git rev-parse --short HEAD)"

  echo "change" >> "src/example.txt"
  git add src/example.txt
  git commit -q -m "apply task change"
}

find_discovery_script() {
  local kind="$1"
  local candidate=""

  local -a explicit=()
  if [[ "${kind}" == "detect" ]]; then
    explicit=(
      "${REPO_ROOT}/bin/discover-detect.py"
      "${REPO_ROOT}/bin/discover-detect.sh"
      "${REPO_ROOT}/scripts/discover-detect.py"
      "${REPO_ROOT}/scripts/discover-detect.sh"
      "${REPO_ROOT}/bin/detect-brownfield.py"
      "${REPO_ROOT}/bin/detect-brownfield.sh"
      "${REPO_ROOT}/scripts/detect-brownfield.py"
      "${REPO_ROOT}/scripts/detect-brownfield.sh"
      "${REPO_ROOT}/bin/discovery-detect.py"
      "${REPO_ROOT}/bin/discovery-detect.sh"
      "${REPO_ROOT}/scripts/discovery-detect.py"
      "${REPO_ROOT}/scripts/discovery-detect.sh"
    )
  else
    explicit=(
      "${REPO_ROOT}/bin/discover-collect.py"
      "${REPO_ROOT}/bin/discover-collect.sh"
      "${REPO_ROOT}/scripts/discover-collect.py"
      "${REPO_ROOT}/scripts/discover-collect.sh"
      "${REPO_ROOT}/bin/collect-brownfield.py"
      "${REPO_ROOT}/bin/collect-brownfield.sh"
      "${REPO_ROOT}/scripts/collect-brownfield.py"
      "${REPO_ROOT}/scripts/collect-brownfield.sh"
      "${REPO_ROOT}/bin/discovery-collect.py"
      "${REPO_ROOT}/bin/discovery-collect.sh"
      "${REPO_ROOT}/scripts/discovery-collect.py"
      "${REPO_ROOT}/scripts/discovery-collect.sh"
    )
  fi

  for candidate in "${explicit[@]}"; do
    if [[ -f "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done

  candidate="$(find "${REPO_ROOT}/bin" "${REPO_ROOT}/scripts" -maxdepth 1 -type f 2>/dev/null | awk -v k="${kind}" '
    {
      base=$0
      sub(/^.*\//, "", base)
      low=tolower(base)
      if (index(low, k) > 0 && (index(low, "discover") > 0 || index(low, "brownfield") > 0)) {
        print $0
        exit
      }
    }
  ')"

  if [[ -n "${candidate}" ]]; then
    echo "${candidate}"
    return 0
  fi

  return 1
}

run_discovery_kind() {
  local kind="$1"
  local script_path=""
  local proj="${TMP_ROOT}/project"

  if ! script_path="$(find_discovery_script "${kind}")"; then
    echo "no discovery ${kind} script found"
    return 100
  fi

  if [[ "${kind}" == "detect" ]]; then
    local rc=0
    local output=""
    if [[ "${script_path}" == *.py ]]; then
      output="$(python3 "${script_path}" --project "${proj}" --json 2>&1)" || rc=$?
    else
      output="$(bash "${script_path}" --project "${proj}" --json 2>&1)" || rc=$?
    fi

    if [[ ${rc} -gt 2 ]]; then
      echo "${output}"
      return 1
    fi
    [[ -n "${output}" ]]
    return 0
  fi

  local out_dir="${TMP_ROOT}/discovery-evidence"
  local output=""
  if [[ "${script_path}" == *.py ]]; then
    output="$(python3 "${script_path}" --project "${proj}" --depth 1 --out-dir "${out_dir}" 2>&1)"
  else
    output="$(bash "${script_path}" --project "${proj}" --depth 1 --out-dir "${out_dir}" 2>&1)"
  fi

  [[ -n "${output}" ]]
  [[ -d "${out_dir}" ]]
  [[ "$(find "${out_dir}" -type f | wc -l | tr -d ' ')" -gt 0 ]]
}

parse_plan_fixture() {
  cat > "${TMP_ROOT}/plan.fixture.md" <<'EOF_PLAN'
```deadfish:PLAN
track_id: smoke
base_commit: abc1234
tasks:
  - id: T01
    title: Smoke task
    depends_on: []
    packet_path: tracks/smoke/tasks/T01.md
```
EOF_PLAN

  python3 "${BIN_DIR}/parse-blocks.py" --type PLAN --format v3 --stdin < "${TMP_ROOT}/plan.fixture.md" > "${TMP_ROOT}/plan.json"

  python3 - "${TMP_ROOT}/plan.json" <<'PY'
import json
import sys
from pathlib import Path

plan = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert plan["track_id"] == "smoke"
assert plan["base_commit"] == "abc1234"
assert isinstance(plan["tasks"], list) and len(plan["tasks"]) == 1
assert plan["tasks"][0]["id"] == "T01"
PY
}

generate_task_description() {
  cat > "${TMP_ROOT}/task.packet.md" <<'EOF_PACKET'
## Summary
Update `src/example.txt` for smoke coverage and keep behavior deterministic.

## Files
- path: src/example.txt
  action: modify
  rationale: exercise packet parsing in deterministic smoke test

## Acceptance Criteria
- AC-01: Packet parses and renders deterministic implementer prompt.
EOF_PACKET

  python3 "${BIN_DIR}/packet-to-task.py" "${TMP_ROOT}/task.packet.md" > "${TMP_ROOT}/task.prompt.md"

  grep -q "^## Implementation Prompt" "${TMP_ROOT}/task.prompt.md"
  grep -q "source packet" "${TMP_ROOT}/task.prompt.md"
  grep -q "src/example.txt" "${TMP_ROOT}/task.prompt.md"
}

run_verify_pre_commit() {
  local proj="${TMP_ROOT}/project"
  python3 - "${BASE_COMMIT}" "${BIN_DIR}/verify.sh" "${proj}" <<'PY'
import json
import subprocess
import sys

base_commit = sys.argv[1]
verify_script = sys.argv[2]
project_dir = sys.argv[3]

cmd = [
    "bash",
    verify_script,
    "--project-dir",
    project_dir,
    "--task-file",
    f"{project_dir}/TASK.md",
    "--base-commit",
    base_commit,
    "--mode",
    "pre-commit",
]

proc = subprocess.run(cmd, capture_output=True, text=True, check=True)
result = json.loads(proc.stdout)
if result.get("pass") is not True:
    raise SystemExit(f"verify pre-commit did not pass: {result}")
PY
}

run_verify_post_commit() {
  local proj="${TMP_ROOT}/project"
  python3 - "${BASE_COMMIT}" "${BIN_DIR}/verify.sh" "${proj}" <<'PY'
import json
import subprocess
import sys

base_commit = sys.argv[1]
verify_script = sys.argv[2]
project_dir = sys.argv[3]

cmd = [
    "bash",
    verify_script,
    "--project-dir",
    project_dir,
    "--task-file",
    f"{project_dir}/TASK.md",
    "--base-commit",
    base_commit,
    "--mode",
    "post-commit",
]

proc = subprocess.run(cmd, capture_output=True, text=True, check=True)
result = json.loads(proc.stdout)
if result.get("pass") is not True:
    raise SystemExit(f"verify post-commit did not pass: {result}")
PY
}

parse_and_build_verdict() {
  cat > "${TMP_ROOT}/verdict.fixture.md" <<'EOF_VERDICT'
```deadfish:VERDICT_CRITERION
task_id: smoke-P1-T01
criterion_id: AC-01
verify_sh: PASS
status: PASS
evidence: src/example.txt updated
```

```deadfish:VERDICT_CRITERION
task_id: smoke-P1-T01
criterion_id: AC-02
verify_sh: PASS
status: PASS
evidence: verify.sh pre/post both passed
```
EOF_VERDICT

  python3 "${BIN_DIR}/parse-blocks.py" --type VERDICT_CRITERION --format v3 --allow-multi --stdin < "${TMP_ROOT}/verdict.fixture.md" > "${TMP_ROOT}/criteria.json"
  python3 "${BIN_DIR}/build-verdict.py" --format v3 --criteria AC-01,AC-02 < "${TMP_ROOT}/criteria.json" > "${TMP_ROOT}/verdict.json"

  python3 - "${TMP_ROOT}/verdict.json" <<'PY'
import json
import sys
from pathlib import Path

verdict = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if verdict.get("verdict") != "PASS":
    raise SystemExit(f"expected PASS verdict, got: {verdict}")
if verdict.get("missing"):
    raise SystemExit(f"expected no missing criteria, got: {verdict['missing']}")
PY
}

check_docs_living_writable() {
  [[ -d "${DOCS_LIVING_DIR}" ]]
  local probe="${DOCS_LIVING_DIR}/.smoke-write-$$.tmp"
  : > "${probe}"
  rm -f "${probe}"
}

check_schemas_load() {
  python3 - "${SCHEMAS_PATH}" <<'PY'
from pathlib import Path
import sys

import yaml  # type: ignore

schema_path = Path(sys.argv[1])
schemas = yaml.safe_load(schema_path.read_text(encoding="utf-8"))
if not isinstance(schemas, dict):
    raise SystemExit("schema file did not parse as mapping")
for key in ("PLAN", "TASK", "ADR", "VERDICT", "VERDICT_CRITERION"):
    if key not in schemas:
        raise SystemExit(f"missing schema key: {key}")
PY
}

main() {
  require_cmd bash
  require_cmd git
  require_cmd python3

  [[ -x "${BIN_DIR}/parse-blocks.py" ]]
  [[ -x "${BIN_DIR}/packet-to-task.py" ]]
  [[ -x "${BIN_DIR}/build-verdict.py" ]]
  [[ -x "${BIN_DIR}/verify.sh" ]]

  print_header

  run_phase "setup minimal temp project" "setup_temp" setup_minimal_temp_project
  run_phase "discovery detect (if present)" "discover_detect" run_discovery_kind detect
  run_phase "discovery collect (if present)" "discover_collect" run_discovery_kind collect
  run_phase "parse v3 PLAN fixture" "parse_plan" parse_plan_fixture
  run_phase "generate task description from packet" "packet_to_task" generate_task_description
  run_phase "run verify.sh pre-commit" "verify_pre" run_verify_pre_commit
  run_phase "run verify.sh post-commit" "verify_post" run_verify_post_commit
  run_phase "parse+build verdict (v3)" "verdict" parse_and_build_verdict
  run_phase "docs/living exists and writable" "docs_living" check_docs_living_writable
  run_phase "v3 schemas load" "schemas" check_schemas_load

  echo
  echo "Summary: pass=${PASS_COUNT} fail=${FAIL_COUNT} skip=${SKIP_COUNT}"

  if [[ ${FAIL_COUNT} -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
