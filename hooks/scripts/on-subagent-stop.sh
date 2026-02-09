#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DEADFISH_PLUGIN_ROOT:-}" ]]; then
  echo "ERROR: DEADFISH_PLUGIN_ROOT is not set. Export it to the deadfish plugin root." >&2
  exit 1
fi

signal_dir="${DEADFISH_PLUGIN_ROOT}/.signals/${CLAUDE_CODE_TASK_LIST_ID:-default}"
mkdir -p "${signal_dir}"
touch "${signal_dir}/subagent-stop"
echo "[$(date -Iseconds)] subagent-stop" >> "${signal_dir}/events.log"
