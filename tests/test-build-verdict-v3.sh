#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

repo = Path.cwd()
parse_cmd = [sys.executable, str(repo / "bin" / "parse-blocks.py"), "--stdin", "--format", "v3"]
build_cmd = [sys.executable, str(repo / "bin" / "build-verdict.py")]
fixture_dir = repo / "tests" / "fixtures" / "v3"


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)


def parse_fixture(block_type: str, fixture_name: str, allow_multi: bool = False):
    cmd = [*parse_cmd, "--type", block_type]
    if allow_multi:
        cmd.append("--allow-multi")
    proc = subprocess.run(
        cmd,
        input=(fixture_dir / fixture_name).read_text(encoding="utf-8"),
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        fail(f"parse-blocks failed for {fixture_name}: {proc.stderr.strip()}")
    return json.loads(proc.stdout)


def parse_inline(block_type: str, payload: str, allow_multi: bool = False):
    cmd = [*parse_cmd, "--type", block_type]
    if allow_multi:
        cmd.append("--allow-multi")
    proc = subprocess.run(cmd, input=payload, text=True, capture_output=True, check=False)
    if proc.returncode != 0:
        fail(f"parse-blocks failed for inline payload: {proc.stderr.strip()}")
    return json.loads(proc.stdout)


def build(criteria_input, fmt: str = "v3", criteria: list[str] | None = None):
    cmd = [*build_cmd, "--format", fmt]
    if criteria:
        cmd += ["--criteria", ",".join(criteria)]
    proc = subprocess.run(
        cmd,
        input=json.dumps(criteria_input),
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        fail(f"build-verdict failed: {proc.stderr.strip()}")
    return json.loads(proc.stdout)


# 1) PASS criterion fixture => PASS verdict.
criterion_pass = parse_fixture("VERDICT_CRITERION", "verdict_criterion.valid.yaml.md")
out = build(criterion_pass, fmt="v3", criteria=["AC-01"])
if out.get("verdict") != "PASS":
    fail(f"expected PASS verdict, got: {out}")
if out["criteria"]["AC-01"]["answer"] != "YES":
    fail("expected AC-01 answer YES for passing criterion")

# 2) verify_sh=FAIL overrides status=PASS => FAIL verdict with NO answer.
criterion_verify_fail = parse_fixture("VERDICT_CRITERION", "verdict_criterion.valid.json.md")
out = build(criterion_verify_fail, fmt="v3", criteria=["AC-01"])
if out.get("verdict") != "FAIL":
    fail(f"verify_sh FAIL should force FAIL verdict, got: {out}")
if out["criteria"]["AC-01"]["answer"] != "NO":
    fail("verify_sh FAIL should map answer to NO")
if "verify_sh=FAIL" not in out["criteria"]["AC-01"]["reason"]:
    fail("expected reason to include verify_sh=FAIL context")

# 3) Aggregate VERDICT fixture with decision/status FAIL => FAIL verdict.
aggregate_fail = parse_fixture("VERDICT", "verdict.valid.json.md")
out = build(aggregate_fail, fmt="v3", criteria=["AC-01"])
if out.get("verdict") != "FAIL":
    fail(f"aggregate fail fixture should produce FAIL verdict, got: {out}")
if out["criteria"]["AC-01"]["answer"] != "NO":
    fail("aggregate FAIL criterion should map to NO")

# 4) Missing expected criterion yields NEEDS_HUMAN and missing list.
aggregate_pass = parse_fixture("VERDICT", "verdict.valid.yaml.md")
out = build(aggregate_pass, fmt="v3", criteria=["AC-01", "AC-02"])
if out.get("verdict") != "NEEDS_HUMAN":
    fail(f"missing criterion should yield NEEDS_HUMAN, got: {out}")
if out.get("missing") != ["AC-02"]:
    fail(f"expected missing=['AC-02'], got: {out.get('missing')}")
if out["criteria"]["AC-02"]["answer"] != "NEEDS_HUMAN":
    fail("missing criterion should be synthesized as NEEDS_HUMAN")
if out.get("total") != 2:
    fail("expected total=2 when two criteria requested")

# 5) Multi-block parse output array feeds build-verdict auto-detect.
multi = """```deadfish:VERDICT_CRITERION
task_id: auth-P1-T01
criterion_id: AC-01
verify_sh: PASS
status: PASS
evidence: first is good
```
```deadfish:VERDICT_CRITERION
task_id: auth-P1-T01
criterion_id: AC-02
verify_sh: PASS
status: FAIL
evidence: second failed
```
"""
criteria_list = parse_inline("VERDICT_CRITERION", multi, allow_multi=True)
out = build(criteria_list, fmt="auto", criteria=["AC-01", "AC-02"])
if out.get("verdict") != "FAIL":
    fail(f"mixed criterion list should produce FAIL verdict, got: {out}")
if out.get("passed") != 1 or out.get("failed") != 1:
    fail(f"expected passed=1 failed=1, got: {out}")

print("test-build-verdict-v3: PASS")
PY
