#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
import os
import sys
from pathlib import Path


def to_rel_path(path_value: str, cwd: str) -> str:
    raw = Path(path_value)
    if raw.is_absolute():
        try:
            rel = raw.resolve().relative_to(Path(cwd).resolve())
            normalized = rel.as_posix()
        except Exception:
            normalized = raw.as_posix()
    else:
        normalized = os.path.normpath(path_value).replace("\\", "/")
    if normalized.startswith("./"):
        normalized = normalized[2:]
    return normalized


raw_input = sys.stdin.read()
try:
    payload = json.loads(raw_input)
except Exception:
    sys.exit(0)

tool_input = payload.get("tool_input") or {}
file_path = tool_input.get("file_path")
if not isinstance(file_path, str) or not file_path:
    sys.exit(0)

cwd = payload.get("cwd")
if not isinstance(cwd, str) or not cwd:
    cwd = os.getcwd()

candidate = to_rel_path(file_path, cwd)

protected_exact = {
    "bin/verify.sh",
    "contracts/sentinel/v3/schemas.yaml",
    "hooks/hooks.json",
    "bin/installer/copy.js",
    "bin/installer/hash.js",
    "bin/installer/settings.js",
    ".claude-plugin/plugin.json",
}
protected_prefixes = (
    "hooks/scripts/",
)

is_protected = candidate in protected_exact or any(
    candidate == prefix.rstrip("/") or candidate.startswith(prefix)
    for prefix in protected_prefixes
)
if not is_protected:
    sys.exit(0)

message = (
    f"Protected file edit denied: {candidate}. "
    "This file is locked by deadfish verification/hook integrity policy."
)
response = {
    "hookSpecificOutput": {
        "permissionDecision": "deny",
    },
    "systemMessage": message,
}
print(json.dumps(response), file=sys.stderr)
sys.exit(2)
PY
