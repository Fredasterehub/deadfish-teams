#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

repo = Path.cwd()
parser = [sys.executable, str(repo / "bin" / "parse-blocks.py"), "--stdin"]


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)


def run_parse(
    block_type: str,
    fixture_path: Path,
    fmt: str = "v3",
    allow_multi: bool = False,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    cmd = [*parser, "--type", block_type, "--format", fmt]
    if allow_multi:
        cmd.append("--allow-multi")
    return subprocess.run(
        cmd,
        input=fixture_path.read_text(encoding="utf-8"),
        text=True,
        capture_output=True,
        env=env,
        check=False,
    )


def run_parse_input(
    block_type: str,
    payload: str,
    fmt: str = "v3",
    allow_multi: bool = False,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    cmd = [*parser, "--type", block_type, "--format", fmt]
    if allow_multi:
        cmd.append("--allow-multi")
    return subprocess.run(cmd, input=payload, text=True, capture_output=True, env=env, check=False)


def pick(obj: object, path: str) -> object:
    cur = obj
    for part in path.split("."):
        m = re.fullmatch(r"([A-Za-z0-9_]+)(?:\[(\d+)\])?", part)
        if not m:
            fail(f"invalid lookup path: {path}")
        key = m.group(1)
        idx = m.group(2)
        if not isinstance(cur, dict) or key not in cur:
            fail(f"missing key '{key}' while evaluating path '{path}'")
        cur = cur[key]
        if idx is not None:
            if not isinstance(cur, list):
                fail(f"path '{path}' expected list at '{key}'")
            i = int(idx)
            if i >= len(cur):
                fail(f"path '{path}' index {i} out of range")
            cur = cur[i]
    return cur


valid_cases: list[tuple[str, str, list[tuple[str, object]]]] = [
    ("plan.valid.yaml.md", "PLAN", [("track_id", "auth"), ("tasks[0].id", "T01")]),
    ("plan.valid.json.md", "PLAN", [("base_commit", "89abcde"), ("tasks[0].packet_path", "tracks/auth/tasks/002.task.md")]),
    ("spec.valid.yaml.md", "SPEC", [("track_id", "auth"), ("acceptance_criteria[0].id", "AC-01")]),
    ("spec.valid.json.md", "SPEC", [("constraints[0]", "No DB migrations")]),
    ("task.valid.yaml.md", "TASK", [("task_id", "auth-P1-T01"), ("files[0].path", "src/auth/jwt.ts")]),
    ("task.valid.json.md", "TASK", [("estimated_diff", 25), ("commands[0]", "npm test -- refresh")]),
    ("track.valid.yaml.md", "TRACK", [("status", "planning")]),
    ("track.valid.json.md", "TRACK", [("status", "executing")]),
    ("verdict_criterion.valid.yaml.md", "VERDICT_CRITERION", [("criterion_id", "AC-01"), ("status", "PASS")]),
    ("verdict_criterion.valid.json.md", "VERDICT_CRITERION", [("verify_sh", "FAIL")]),
    ("verdict.valid.yaml.md", "VERDICT", [("criteria[0].id", "AC-01"), ("decision", "PASS")]),
    ("verdict.valid.json.md", "VERDICT", [("decision", "FAIL"), ("criteria[0].status", "FAIL")]),
    ("conductor.valid.yaml.md", "CONDUCTOR", [("decision", "CONTINUE")]),
    ("conductor.valid.json.md", "CONDUCTOR", [("decision", "ADAPT")]),
    ("docsync.valid.yaml.md", "DOCSYNC", [("action", "UPDATE")]),
    ("docsync.valid.json.md", "DOCSYNC", [("action", "BUFFER"), ("nonce", "ABC123")]),
    ("implement.valid.yaml.md", "IMPLEMENT", [("verify.command", "npm test -- jwt")]),
    ("implement.valid.json.md", "IMPLEMENT", [("verify.result", "PASS")]),
    ("integrate.valid.yaml.md", "INTEGRATE", [("verify_sh", "PASS")]),
    ("integrate.valid.json.md", "INTEGRATE", [("verify_sh", "FAIL")]),
]

invalid_cases: list[tuple[str, str, str]] = [
    ("plan.invalid.missing_tasks.md", "PLAN", "missing required key 'tasks'"),
    ("spec.invalid.ac_format.md", "SPEC", "acceptance_criteria[1].id"),
    ("task.invalid.missing_files.md", "TASK", "missing required key 'files'"),
    ("track.invalid.status.md", "TRACK", "field 'status' must be one of"),
    ("verdict_criterion.invalid.ac_format.md", "VERDICT_CRITERION", "field 'criterion_id'"),
    ("verdict.invalid.missing_decision.md", "VERDICT", "missing required key 'decision'"),
    ("conductor.invalid.decision.md", "CONDUCTOR", "field 'decision' must be one of"),
    ("docsync.invalid.action.md", "DOCSYNC", "field 'action' must be one of"),
    ("implement.invalid.missing_verify.md", "IMPLEMENT", "missing required key 'verify'"),
    ("integrate.invalid.verify_sh.md", "INTEGRATE", "field 'verify_sh' must be one of"),
]

fixture_dir = repo / "tests" / "fixtures" / "v3"

for fixture_name, block_type, expectations in valid_cases:
    proc = run_parse(block_type, fixture_dir / fixture_name)
    if proc.returncode != 0:
        fail(f"{fixture_name} expected success, got {proc.returncode}: {proc.stderr.strip()}")
    try:
        parsed = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        fail(f"{fixture_name} produced invalid JSON: {exc}")
    if not isinstance(parsed, dict):
        fail(f"{fixture_name} expected JSON object, got {type(parsed).__name__}")
    for path, expected in expectations:
        value = pick(parsed, path)
        if value != expected:
            fail(f"{fixture_name} expected {path}={expected!r}, got {value!r}")

for fixture_name, block_type, expected_msg in invalid_cases:
    proc = run_parse(block_type, fixture_dir / fixture_name)
    if proc.returncode == 0:
        fail(f"{fixture_name} expected failure but succeeded")
    err = proc.stderr.strip()
    if expected_msg not in err:
        fail(f"{fixture_name} expected stderr containing {expected_msg!r}, got: {err!r}")

# Multi-block behavior: fail without --allow-multi, succeed with it.
multi_block = """```deadfish:VERDICT_CRITERION
task_id: auth-P1-T01
criterion_id: AC-01
verify_sh: PASS
status: PASS
evidence: first criterion
```
```deadfish:VERDICT_CRITERION
task_id: auth-P1-T01
criterion_id: AC-02
verify_sh: PASS
status: FAIL
evidence: second criterion
```
"""
proc = run_parse_input("VERDICT_CRITERION", multi_block, fmt="v3", allow_multi=False)
if proc.returncode == 0:
    fail("multi-block parse should fail without --allow-multi")
if "pass --allow-multi" not in proc.stderr:
    fail(f"multi-block failure did not mention --allow-multi: {proc.stderr.strip()}")

proc = run_parse_input("VERDICT_CRITERION", multi_block, fmt="v3", allow_multi=True)
if proc.returncode != 0:
    fail(f"multi-block parse with --allow-multi failed: {proc.stderr.strip()}")
parsed_multi = json.loads(proc.stdout)
if not isinstance(parsed_multi, list) or len(parsed_multi) != 2:
    fail("multi-block parse with --allow-multi should return list of 2 items")
if parsed_multi[1].get("criterion_id") != "AC-02":
    fail("multi-block parse returned unexpected second criterion_id")

# Backward-compat parsing in auto mode (v1 payload).
v1_payload = """<<<PLAN:V1:NONCE=ABC123>>>
TASK_ID=auth-P1-T01
TITLE="Legacy plan"
SUMMARY=
  v1 summary line
FILES:
- path=src/auth/jwt.ts action=add rationale="Legacy fixture"
ACCEPTANCE:
- id=AC1 text="legacy acceptance"
ESTIMATED_DIFF=12
<<<END_PLAN:NONCE=ABC123>>>
"""
proc = run_parse_input("PLAN", v1_payload, fmt="auto")
if proc.returncode != 0:
    fail(f"v1 auto-detect parse failed: {proc.stderr.strip()}")
legacy = json.loads(proc.stdout)
if legacy.get("task_id") != "auth-P1-T01":
    fail("v1 auto parse returned wrong task_id")
if legacy.get("files", [{}])[0].get("path") != "src/auth/jwt.ts":
    fail("v1 auto parse returned wrong file path")

# Missing PyYAML behavior: parser fails early with clear fatal (schema file is YAML).
with tempfile.TemporaryDirectory(prefix="parse-blocks-no-yaml-") as td:
    fake_yaml = Path(td) / "yaml.py"
    fake_yaml.write_text("raise ImportError('forced missing PyYAML')\n", encoding="utf-8")
    env = os.environ.copy()
    current = env.get("PYTHONPATH", "")
    env["PYTHONPATH"] = f"{td}:{current}" if current else td

    for fixture in ("plan.valid.json.md", "plan.valid.yaml.md"):
        proc = run_parse("PLAN", fixture_dir / fixture, env=env)
        if proc.returncode == 0:
            fail(f"{fixture} should fail when PyYAML import is unavailable")
        if "FATAL: PyYAML required" not in proc.stderr:
            fail(f"{fixture} expected PyYAML fatal message, got: {proc.stderr.strip()}")

print("test-parse-blocks-v3: PASS")
PY
