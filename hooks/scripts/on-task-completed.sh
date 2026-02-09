#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DEADFISH_PLUGIN_ROOT:-}" ]]; then
  echo "ERROR: DEADFISH_PLUGIN_ROOT is not set. Export it to the deadfish plugin root." >&2
  exit 1
fi

signal_dir="${DEADFISH_PLUGIN_ROOT}/.signals/${CLAUDE_CODE_TASK_LIST_ID:-default}"
mkdir -p "${signal_dir}"

hook_input="$(cat || true)"
verify_json="${signal_dir}/verify.task-completed.json"
verify_stderr="${signal_dir}/verify.task-completed.stderr.log"
events_log="${signal_dir}/events.log"
verify_script="${DEADFISH_PLUGIN_ROOT}/bin/verify.sh"

resolve_project_dir() {
  local candidate=""
  if command -v jq >/dev/null 2>&1 && [[ -n "${hook_input}" ]]; then
    for expr in \
      '.cwd // empty' \
      '.project_dir // empty' \
      '.working_directory // empty' \
      '.tool_input.cwd // empty' \
      '.tool_input.project_dir // empty'
    do
      candidate="$(printf '%s' "${hook_input}" | jq -r "${expr}" 2>/dev/null || true)"
      if [[ -n "${candidate}" && -d "${candidate}" ]]; then
        printf '%s' "${candidate}"
        return
      fi
    done
  fi
  printf '%s' "${PWD}"
}

resolve_optional_file() {
  local candidate=""
  if command -v jq >/dev/null 2>&1 && [[ -n "${hook_input}" ]]; then
    for expr in \
      '.task_file // empty' \
      '.tool_input.task_file // empty'
    do
      candidate="$(printf '%s' "${hook_input}" | jq -r "${expr}" 2>/dev/null || true)"
      if [[ -n "${candidate}" && -f "${candidate}" ]]; then
        printf '%s' "${candidate}"
        return
      fi
    done
  fi
}

resolve_optional_base_commit() {
  local value=""
  if command -v jq >/dev/null 2>&1 && [[ -n "${hook_input}" ]]; then
    value="$(printf '%s' "${hook_input}" | jq -r '.base_commit // .tool_input.base_commit // empty' 2>/dev/null || true)"
  fi
  printf '%s' "${value}"
}

project_dir="$(resolve_project_dir)"
task_file="$(resolve_optional_file)"
base_commit="$(resolve_optional_base_commit)"
timestamp="$(date -Iseconds)"

if [[ ! -x "${verify_script}" ]]; then
  echo "[$timestamp] task-completed blocked: missing verify script at ${verify_script}" >> "${events_log}"
  echo "Verification gate blocked task completion: missing ${verify_script}" >&2
  exit 2
fi

verify_cmd=(bash "${verify_script}" --project-dir "${project_dir}" --mode pre-commit)
if [[ -n "${task_file}" ]]; then
  verify_cmd+=(--task-file "${task_file}")
fi
if [[ -n "${base_commit}" ]]; then
  verify_cmd+=(--base-commit "${base_commit}")
fi

if "${verify_cmd[@]}" >"${verify_json}" 2>"${verify_stderr}"; then
  verify_exit=0
else
  verify_exit=$?
fi

verify_parse="$(
  python3 - "${verify_json}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    payload = json.loads(path.read_text(encoding="utf-8"))
except Exception:
    print("false\tinvalid JSON output from verify.sh")
    raise SystemExit(0)

passed = payload.get("pass") is True
failures = payload.get("failures")
reason = ""
if isinstance(failures, list) and failures:
    reason = str(failures[0]).replace("\n", " ").strip()
print(f"{'true' if passed else 'false'}\t{reason}")
PY
)"

pass_field="${verify_parse%%$'\t'*}"
first_failure="${verify_parse#*$'\t'}"
if [[ "${pass_field}" == "${verify_parse}" ]]; then
  first_failure=""
fi

if [[ "${verify_exit}" -ne 0 || "${pass_field}" != "true" ]]; then
  short_reason="${first_failure}"
  if [[ -z "${short_reason}" ]]; then
    short_reason="verify.sh failed (exit ${verify_exit})"
  fi
  echo "[$timestamp] task-completed blocked: ${short_reason}" >> "${events_log}"
  echo "Verification gate blocked task completion: ${short_reason}" >&2
  echo "Verification details JSON: ${verify_json}" >&2
  exit 2
fi

touch "${signal_dir}/task-completed"
echo "[$timestamp] task-completed pass (verify=${verify_json})" >> "${events_log}"
