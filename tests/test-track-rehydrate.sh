#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/deadfish-track-rehydrate.XXXXXX")"

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

test_track_scaffold_and_mirror() {
  local fixture="${TMP_ROOT}/fixture"
  local track_dir="${fixture}/tracks/2026-02-09-smoke-track"
  local plan_path="${track_dir}/plan.md"

  mkdir -p "${fixture}/bin" "${fixture}/templates/track" "${fixture}/contracts/sentinel/v3"

  cp "${REPO_ROOT}/bin/new-track.py" "${fixture}/bin/new-track.py"
  cp "${REPO_ROOT}/bin/plan-to-packets.py" "${fixture}/bin/plan-to-packets.py"
  cp "${REPO_ROOT}/bin/parse-blocks.py" "${fixture}/bin/parse-blocks.py"
  cp "${REPO_ROOT}/bin/packet-to-task.py" "${fixture}/bin/packet-to-task.py"
  cp -R "${REPO_ROOT}/templates/track/durable-memory" "${fixture}/templates/track/durable-memory"
  cp "${REPO_ROOT}/contracts/sentinel/v3/schemas.yaml" "${fixture}/contracts/sentinel/v3/schemas.yaml"
  chmod +x \
    "${fixture}/bin/new-track.py" \
    "${fixture}/bin/plan-to-packets.py" \
    "${fixture}/bin/parse-blocks.py" \
    "${fixture}/bin/packet-to-task.py"

  python3 "${fixture}/bin/new-track.py" \
    --repo-root "${fixture}" \
    --date 2026-02-09 \
    --slug smoke-track \
    --track-name "Smoke Track" >/dev/null

  [[ -f "${track_dir}/index.md" ]]
  [[ -f "${track_dir}/spec.md" ]]
  [[ -f "${track_dir}/plan.md" ]]
  [[ -f "${track_dir}/notes.md" ]]
  [[ -d "${track_dir}/task-packets" ]]
  [[ -d "${track_dir}/verdicts" ]]
  [[ -d "${track_dir}/snapshots" ]]

  cat > "${plan_path}" <<'EOF_PLAN'
# Plan

## Sentinel
```deadfish:PLAN
track_id: smoke-track
base_commit: abc1234
tasks:
  - id: T01
    title: Mirror first packet
    depends_on: []
    packet_path: tracks/2026-02-09-smoke-track/task-packets/smoke-track-P1-T01.md
  - id: T02
    title: Mirror second packet
    depends_on:
      - T01
    packet_path: tracks/2026-02-09-smoke-track/task-packets/smoke-track-P1-T02.md
```
EOF_PLAN

  python3 "${fixture}/bin/plan-to-packets.py" --repo-root "${fixture}" "${plan_path}" > "${TMP_ROOT}/mirror-first.json"
  [[ -f "${track_dir}/task-packets/smoke-track-P1-T01.md" ]]
  [[ -f "${track_dir}/task-packets/smoke-track-P1-T02.md" ]]
  [[ -f "${track_dir}/task-packets/index.md" ]]

  python3 "${fixture}/bin/packet-to-task.py" "${track_dir}/task-packets/smoke-track-P1-T01.md" > "${TMP_ROOT}/packet-prompt.md"
  grep -q '^## Implementation Prompt' "${TMP_ROOT}/packet-prompt.md"
  grep -q 'source packet' "${TMP_ROOT}/packet-prompt.md"

  python3 "${fixture}/bin/plan-to-packets.py" --repo-root "${fixture}" "${plan_path}" > "${TMP_ROOT}/mirror-second.json"
  python3 - "${TMP_ROOT}/mirror-second.json" <<'PY'
import json
import sys
from pathlib import Path

result = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert result["created"] == []
assert result["updated"] == []
assert result["skipped"] == []
PY
}

test_installer_manifest_has_templates() {
  local home_dir="${TMP_ROOT}/home"
  local workspace="${TMP_ROOT}/workspace"
  local plugin_root="${workspace}/.claude/plugins/deadfish-teams"

  mkdir -p "${home_dir}" "${workspace}"

  (
    cd "${workspace}" || exit 1
    HOME="${home_dir}" node "${REPO_ROOT}/bin/install.js" --local >/dev/null
  )

  [[ -f "${plugin_root}/templates/rehydrate.md" ]]
  [[ -f "${plugin_root}/templates/track/durable-memory/index.md.tmpl" ]]

  python3 - "${plugin_root}/.deadfish-install/manifest.json" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
files = manifest.get("files", {})
assert "templates/rehydrate.md" in files
assert "templates/track/durable-memory/index.md.tmpl" in files
assert "templates/track/durable-memory/plan.md.tmpl" in files
assert "templates/track/durable-memory/spec.md.tmpl" in files
PY

  (
    cd "${workspace}" || exit 1
    HOME="${home_dir}" node "${REPO_ROOT}/bin/install.js" --local --uninstall >/dev/null
  )
}

main() {
  require_cmd bash
  require_cmd python3
  require_cmd node

  test_track_scaffold_and_mirror
  test_installer_manifest_has_templates

  echo "PASS tests/test-track-rehydrate.sh"
}

main "$@"
