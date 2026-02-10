#!/usr/bin/env bash
set -euo pipefail

plugin_root="${CLAUDE_PLUGIN_ROOT:-${DEADFISH_PLUGIN_ROOT:-}}"
if [[ -z "${plugin_root}" ]]; then
  echo "ERROR: CLAUDE_PLUGIN_ROOT or DEADFISH_PLUGIN_ROOT must be set to the deadfish plugin root." >&2
  exit 1
fi

task_list_id="${CLAUDE_CODE_TASK_LIST_ID:-default}"

resolve_project_root() {
  local candidate=""
  for candidate in \
    "${DEADFISH_PROJECT_ROOT:-}" \
    "${CLAUDE_CODE_PROJECT_DIR:-}" \
    "${CLAUDE_PROJECT_DIR:-}" \
    "${PWD}"; do
    if [[ -n "${candidate}" && -d "${candidate}" ]]; then
      (cd "${candidate}" && pwd)
      return
    fi
  done
  pwd
}

infer_track_from_task() {
  local task_id="$1"
  if [[ "${task_id}" =~ ^([a-z0-9][a-z0-9_-]*)-P[0-9]+-T[0-9]{2}$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  fi
}

resolve_track_id() {
  local project_root="$1"
  local current_task="${CLAUDE_CODE_TASK_ID:-${DEADFISH_CURRENT_TASK:-}}"
  if [[ -n "${DEADFISH_TRACK_ID:-}" ]]; then
    printf '%s\n' "${DEADFISH_TRACK_ID}"
    return
  fi
  if [[ -n "${current_task}" ]]; then
    infer_track_from_task "${current_task}" || true
    return
  fi
  if [[ -f "${project_root}/TRACK.md" ]]; then
    grep -E '^[[:space:]]*track_id:[[:space:]]*[a-z0-9_-]+' "${project_root}/TRACK.md" \
      | head -n 1 \
      | sed -E 's/^[[:space:]]*track_id:[[:space:]]*//' || true
    return
  fi
}

resolve_snapshot_path() {
  local project_root="$1"
  local track_id="$2"
  local pointer_file="${plugin_root}/.signals/${task_list_id}/latest-snapshot-path.txt"

  if [[ -f "${project_root}/.deadfish/session/${task_list_id}/STATE_SNAPSHOT.md" ]]; then
    printf '%s\n' "${project_root}/.deadfish/session/${task_list_id}/STATE_SNAPSHOT.md"
    return
  fi

  if [[ -f "${pointer_file}" ]]; then
    local pointed_path
    pointed_path="$(head -n 1 "${pointer_file}")"
    if [[ -n "${pointed_path}" && -f "${pointed_path}" ]]; then
      printf '%s\n' "${pointed_path}"
      return
    fi
  fi

  if [[ -n "${track_id}" && -f "${project_root}/tracks/${track_id}/STATE_SNAPSHOT.md" ]]; then
    printf '%s\n' "${project_root}/tracks/${track_id}/STATE_SNAPSHOT.md"
    return
  fi

  local latest=""
  latest="$(find "${plugin_root}/.signals" -type f -name 'STATE_SNAPSHOT.md' 2>/dev/null | LC_ALL=C sort | tail -n 1 || true)"
  if [[ -n "${latest}" && -f "${latest}" ]]; then
    printf '%s\n' "${latest}"
    return
  fi
}

project_root="$(resolve_project_root)"
track_id="$(resolve_track_id "${project_root}")"
snapshot_path="$(resolve_snapshot_path "${project_root}" "${track_id}")"

if [[ -z "${snapshot_path}" ]]; then
  echo "[deadfish] session-start: no compaction snapshot found"
  exit 0
fi

echo "[deadfish] session-start rehydration from ${snapshot_path}"
echo "----- DEADFISH SNAPSHOT START -----"
sed -n '1,200p' "${snapshot_path}"
echo "----- DEADFISH SNAPSHOT END -----"
