#!/usr/bin/env bash
set -euo pipefail

plugin_root="${CLAUDE_PLUGIN_ROOT:-${DEADFISH_PLUGIN_ROOT:-}}"
if [[ -z "${plugin_root}" ]]; then
  echo "ERROR: CLAUDE_PLUGIN_ROOT or DEADFISH_PLUGIN_ROOT must be set to the deadfish plugin root." >&2
  exit 1
fi

sanitize_token() {
  local value="$1"
  value="${value//$'\n'/ }"
  value="${value//$'\r'/ }"
  value="${value//$'\t'/ }"
  value="$(printf '%s' "${value}" | sed -E 's/[[:space:]]+/_/g; s/[^[:alnum:]._:@+\/-]+/_/g; s/^_+//; s/_+$//')"
  if [[ -z "${value}" ]]; then
    value="unknown"
  fi
  printf '%s' "${value}"
}

hook_input="$(cat || true)"
agent_type=""

if command -v python3 >/dev/null 2>&1 && [[ -n "${hook_input}" ]]; then
  agent_type="$(
    HOOK_INPUT_JSON="${hook_input}" python3 - <<'PY'
import json
import os

raw = os.environ.get("HOOK_INPUT_JSON", "")
data = {}
if raw:
    try:
        data = json.loads(raw)
    except Exception:
        data = {}

def first(path_options):
    for path in path_options:
        cur = data
        ok = True
        for piece in path:
            if isinstance(cur, dict) and piece in cur:
                cur = cur[piece]
            else:
                ok = False
                break
        if ok and cur not in (None, ""):
            return str(cur)
    return ""

print(first([
    ("agent_type",),
    ("agent", "type"),
    ("teammate", "agent_type"),
    ("teammate", "type"),
    ("tool_input", "agent_type"),
    ("tool_input", "agent", "type"),
    ("payload", "agent_type"),
]))
PY
  )"
fi

agent_type="${agent_type:-${CLAUDE_CODE_AGENT_TYPE:-${DEADFISH_AGENT_TYPE:-unknown}}}"
agent_type="$(sanitize_token "${agent_type}")"

signal_dir="${plugin_root}/.signals/${CLAUDE_CODE_TASK_LIST_ID:-default}"
mkdir -p "${signal_dir}"
touch "${signal_dir}/teammate-idle"
printf '%s teammate_idle agent=%s\n' "$(date -Iseconds)" "${agent_type}" >> "${signal_dir}/events.log"
