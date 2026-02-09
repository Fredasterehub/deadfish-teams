#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DEADFISH_PLUGIN_ROOT:-}" ]]; then
  echo "ERROR: DEADFISH_PLUGIN_ROOT is not set. Export it to the deadfish plugin root." >&2
  exit 1
fi

plugin_root="${DEADFISH_PLUGIN_ROOT}"
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

trim_quotes() {
  local value="$1"
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"
  printf '%s' "${value}"
}

infer_track_from_task() {
  local task_id="$1"
  if [[ "${task_id}" =~ ^([a-z0-9][a-z0-9_-]*)-P[0-9]+-T[0-9]{2}$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  fi
}

resolve_current_task() {
  local candidate=""
  for candidate in \
    "${DEADFISH_CURRENT_TASK:-}" \
    "${CLAUDE_CODE_TASK_ID:-}" \
    "${CLAUDE_CODE_TASK_TITLE:-}" \
    "${CLAUDE_CODE_TASK:-}"; do
    if [[ -n "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return
    fi
  done
  printf 'unknown\n'
}

resolve_track_id() {
  local project_root="$1"
  local current_task="$2"
  local from_env="${DEADFISH_TRACK_ID:-}"

  if [[ -n "${from_env}" ]]; then
    printf '%s\n' "${from_env}"
    return
  fi

  local from_task=""
  from_task="$(infer_track_from_task "${current_task}" || true)"
  if [[ -n "${from_task}" ]]; then
    printf '%s\n' "${from_task}"
    return
  fi

  if [[ -f "${project_root}/TRACK.md" ]]; then
    local from_track_file=""
    from_track_file="$(grep -E '^[[:space:]]*track_id:[[:space:]]*[a-z0-9_-]+' "${project_root}/TRACK.md" | head -n 1 | sed -E 's/^[[:space:]]*track_id:[[:space:]]*//' || true)"
    if [[ -n "${from_track_file}" ]]; then
      printf '%s\n' "${from_track_file}"
      return
    fi
  fi

  if [[ -f "${project_root}/STATE.yaml" ]]; then
    local from_state=""
    from_state="$(awk '
      $0 ~ /^track:/ { in_track=1; next }
      in_track && $1 == "id:" { print $2; exit }
    ' "${project_root}/STATE.yaml" || true)"
    if [[ -n "${from_state}" ]]; then
      printf '%s\n' "${from_state}"
      return
    fi
  fi

  if [[ -d "${project_root}/tracks" ]]; then
    local tracks=()
    mapfile -t tracks < <(find "${project_root}/tracks" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort)
    if [[ "${#tracks[@]}" -eq 1 ]]; then
      printf '%s\n' "${tracks[0]}"
      return
    fi
  fi

  printf '\n'
}

collect_goal() {
  local project_root="$1"
  local track_dir="$2"

  if [[ -n "${track_dir}" && -f "${track_dir}/SPEC.md" ]]; then
    local goal=""
    goal="$(grep -E '^[[:space:]]*goal:[[:space:]]*.+$' "${track_dir}/SPEC.md" | head -n 1 | sed -E 's/^[[:space:]]*goal:[[:space:]]*//' || true)"
    if [[ -n "${goal}" ]]; then
      trim_quotes "${goal}"
      return
    fi
  fi

  if [[ -f "${project_root}/docs/design/VISION.md" ]]; then
    local line=""
    line="$(grep -E '^[^#[:space:]].+' "${project_root}/docs/design/VISION.md" | head -n 1 || true)"
    if [[ -n "${line}" ]]; then
      trim_quotes "${line}"
      return
    fi
  fi

  printf 'unknown\n'
}

collect_bullets() {
  local file_path="$1"
  local max_lines="$2"
  if [[ ! -f "${file_path}" ]]; then
    return
  fi
  grep -E '^[[:space:]]*-[[:space:]]+(\[[[:space:]xX]\][[:space:]]+)?[^[:space:]].*$' "${file_path}" \
    | sed -E 's/^[[:space:]]*-[[:space:]]+(\[[[:space:]xX]\][[:space:]]+)?//' \
    | head -n "${max_lines}" || true
}

collect_risks() {
  local project_root="$1"
  local track_dir="$2"
  if [[ -n "${track_dir}" && -f "${track_dir}/RISKS.md" ]]; then
    collect_bullets "${track_dir}/RISKS.md" 5
    return
  fi
  collect_bullets "${project_root}/docs/living/RISKS.md" 5
}

collect_next_actions() {
  local track_dir="$1"
  if [[ -n "${track_dir}" && -f "${track_dir}/NEXT_ACTIONS.md" ]]; then
    collect_bullets "${track_dir}/NEXT_ACTIONS.md" 5
    return
  fi

  if [[ -n "${track_dir}" && -f "${track_dir}/PLAN.md" ]]; then
    grep -E '^[[:space:]]*-[[:space:]]+id:[[:space:]]*T[0-9]+' "${track_dir}/PLAN.md" \
      | sed -E 's/^[[:space:]]*-[[:space:]]+id:[[:space:]]*/Complete /' \
      | head -n 5 || true
    return
  fi
}

collect_decisions() {
  local project_root="$1"
  local track_dir="$2"
  local tmp_file
  tmp_file="$(mktemp "${TMPDIR:-/tmp}/deadfish-decisions.XXXXXX")"

  if [[ -d "${project_root}/docs/adr" ]]; then
    find "${project_root}/docs/adr" -type f -name '*.md' -printf '%f\n' \
      | sed -nE 's/.*(ADR-[0-9]{4,}).*/\1/p' >> "${tmp_file}" || true
    grep -RhoE 'ADR-[0-9]{4,}' "${project_root}/docs/adr" >> "${tmp_file}" || true
  fi

  if [[ -n "${track_dir}" && -d "${track_dir}" ]]; then
    grep -RhoE 'ADR-[0-9]{4,}' "${track_dir}" >> "${tmp_file}" || true
  fi

  LC_ALL=C sort -u "${tmp_file}" | head -n 8
  rm -f "${tmp_file}"
}

write_section_list() {
  local section_name="$1"
  shift
  local values=("$@")
  printf '## %s\n' "${section_name}"
  if [[ "${#values[@]}" -eq 0 ]]; then
    printf -- '- none recorded\n\n'
    return
  fi
  local value=""
  for value in "${values[@]}"; do
    if [[ -n "${value}" ]]; then
      printf -- '- %s\n' "${value}"
    fi
  done
  printf '\n'
}

project_root="$(resolve_project_root)"
current_task="$(resolve_current_task)"
track_id="$(resolve_track_id "${project_root}" "${current_task}")"
track_dir=""

if [[ -n "${track_id}" && -d "${project_root}/tracks/${track_id}" ]]; then
  track_dir="${project_root}/tracks/${track_id}"
fi

snapshot_file=""
if [[ -n "${track_dir}" ]]; then
  snapshot_file="${track_dir}/STATE_SNAPSHOT.md"
else
  fallback_dir="${project_root}/.deadfish/session/${task_list_id}"
  if mkdir -p "${fallback_dir}" 2>/dev/null; then
    snapshot_file="${fallback_dir}/STATE_SNAPSHOT.md"
  else
    fallback_dir="${plugin_root}/.signals/${task_list_id}"
    mkdir -p "${fallback_dir}"
    snapshot_file="${fallback_dir}/STATE_SNAPSHOT.md"
  fi
fi

mkdir -p "$(dirname "${snapshot_file}")"

goal="$(collect_goal "${project_root}" "${track_dir}")"
timestamp_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

decisions=()
risks=()
next_actions=()

mapfile -t decisions < <(collect_decisions "${project_root}" "${track_dir}")
mapfile -t risks < <(collect_risks "${project_root}" "${track_dir}")
mapfile -t next_actions < <(collect_next_actions "${track_dir}")

{
  printf '# Deadfish State Snapshot\n'
  printf 'timestamp_utc: %s\n' "${timestamp_utc}"
  printf 'task_list_id: %s\n' "${task_list_id}"
  printf 'project_root: %s\n' "${project_root}"
  printf 'track_id: %s\n\n' "${track_id:-none}"

  printf '## Current Goal\n%s\n\n' "${goal}"
  printf '## Current Task\n%s\n\n' "${current_task}"
  write_section_list "Key Decisions" "${decisions[@]}"
  write_section_list "Open Risks" "${risks[@]}"
  write_section_list "Next Actions" "${next_actions[@]}"
} > "${snapshot_file}"

signal_dir="${plugin_root}/.signals/${task_list_id}"
mkdir -p "${signal_dir}"
printf '%s\n' "${snapshot_file}" > "${signal_dir}/latest-snapshot-path.txt"
echo "[$(date -Iseconds)] pre-compact snapshot: ${snapshot_file}" >> "${signal_dir}/events.log"

echo "[deadfish] pre-compact snapshot written: ${snapshot_file}"
