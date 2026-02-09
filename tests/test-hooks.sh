#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/deadfish-hook-test.XXXXXX")"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file_exists() {
  local path="$1"
  [[ -f "${path}" ]] || fail "missing expected file: ${path}"
}

assert_json_field_equals() {
  local path="$1"
  local key="$2"
  local expected="$3"
  python3 - "$path" "$key" "$expected" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
key = sys.argv[2]
expected = sys.argv[3]
payload = json.loads(path.read_text(encoding="utf-8"))
actual = payload.get(key)
if str(actual).lower() != expected.lower():
    raise SystemExit(f"{path}: expected {key}={expected}, got {actual}")
PY
}

run_protected_write_tests() {
  local script="${REPO_ROOT}/hooks/scripts/on-protected-write.sh"
  [[ -x "${script}" ]] || fail "hook script is not executable: ${script}"

  local input_unprotected='{"cwd":"/tmp/proj","tool_input":{"file_path":"src/main.ts"}}'
  local output=""
  set +e
  output="$(printf '%s' "${input_unprotected}" | bash "${script}" 2>&1)"
  local rc=$?
  set -e
  [[ ${rc} -eq 0 ]] || fail "unprotected path should be allowed (rc=${rc}, output=${output})"

  local input_protected='{"cwd":"/tmp/proj","tool_input":{"file_path":"bin/verify.sh"}}'
  set +e
  output="$(printf '%s' "${input_protected}" | bash "${script}" 2>&1)"
  rc=$?
  set -e
  [[ ${rc} -eq 2 ]] || fail "protected path should be denied (rc=${rc}, output=${output})"
  python3 - "${output}" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
decision = payload.get("hookSpecificOutput", {}).get("permissionDecision")
if decision != "deny":
    raise SystemExit(f"expected permissionDecision=deny, got: {decision}")
message = payload.get("systemMessage", "")
if "bin/verify.sh" not in message:
    raise SystemExit(f"expected protected path in systemMessage, got: {message}")
PY

  local abs_path="${TMP_ROOT}/proj/bin/verify.sh"
  mkdir -p "${TMP_ROOT}/proj/bin"
  : > "${abs_path}"
  local input_abs
  input_abs="$(python3 - "${TMP_ROOT}/proj" "${abs_path}" <<'PY'
import json
import sys
print(json.dumps({"cwd": sys.argv[1], "tool_input": {"file_path": sys.argv[2]}}))
PY
)"
  set +e
  output="$(printf '%s' "${input_abs}" | bash "${script}" 2>&1)"
  rc=$?
  set -e
  [[ ${rc} -eq 2 ]] || fail "absolute protected path should be denied (rc=${rc}, output=${output})"
}

write_verify_stub() {
  local path="$1"
  local mode="$2"
  cat > "${path}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "${mode}" == "pass" ]]; then
  cat <<'JSON'
{"pass": true, "checks": {"stub": true}, "failures": [], "timestamp": "2026-02-09T00:00:00Z"}
JSON
  exit 0
fi
cat <<'JSON'
{"pass": false, "checks": {"stub": true}, "failures": ["stub failure reason"], "timestamp": "2026-02-09T00:00:00Z"}
JSON
exit 1
EOF
  chmod +x "${path}"
}

run_task_completed_tests() {
  local script="${REPO_ROOT}/hooks/scripts/on-task-completed.sh"
  [[ -x "${script}" ]] || fail "hook script is not executable: ${script}"

  local plugin_root="${TMP_ROOT}/plugin"
  mkdir -p "${plugin_root}/bin" "${plugin_root}/.signals"

  write_verify_stub "${plugin_root}/bin/verify.sh" "pass"

  local pass_input='{"cwd":"/tmp/project"}'
  set +e
  local output
  output="$(printf '%s' "${pass_input}" | DEADFISH_PLUGIN_ROOT="${plugin_root}" CLAUDE_CODE_TASK_LIST_ID="hooks-pass" bash "${script}" 2>&1)"
  local rc=$?
  set -e
  [[ ${rc} -eq 0 ]] || fail "task-completed pass case should allow completion (rc=${rc}, output=${output})"

  local pass_signal_dir="${plugin_root}/.signals/hooks-pass"
  assert_file_exists "${pass_signal_dir}/task-completed"
  assert_file_exists "${pass_signal_dir}/verify.task-completed.json"
  assert_json_field_equals "${pass_signal_dir}/verify.task-completed.json" "pass" "true"

  write_verify_stub "${plugin_root}/bin/verify.sh" "fail"

  local fail_input='{"cwd":"/tmp/project"}'
  set +e
  output="$(printf '%s' "${fail_input}" | DEADFISH_PLUGIN_ROOT="${plugin_root}" CLAUDE_CODE_TASK_LIST_ID="hooks-fail" bash "${script}" 2>&1)"
  rc=$?
  set -e
  [[ ${rc} -eq 2 ]] || fail "task-completed fail case should block completion (rc=${rc}, output=${output})"
  [[ "${output}" == *"Verification gate blocked task completion"* ]] || fail "missing block message in output: ${output}"

  local fail_signal_dir="${plugin_root}/.signals/hooks-fail"
  assert_file_exists "${fail_signal_dir}/verify.task-completed.json"
  assert_json_field_equals "${fail_signal_dir}/verify.task-completed.json" "pass" "false"
}

main() {
  run_protected_write_tests
  run_task_completed_tests
  echo "test-hooks: PASS"
}

main "$@"
