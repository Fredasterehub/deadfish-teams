#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

repo = Path.cwd()
verify_script = repo / "bin" / "verify.sh"


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)


def run(cmd: list[str], cwd: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True, check=False)
    if check and proc.returncode != 0:
        fail(f"command failed ({' '.join(cmd)}):\nstdout={proc.stdout}\nstderr={proc.stderr}")
    return proc


def write(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


def init_repo(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    run(["git", "init", "-q"], cwd=path)
    run(["git", "config", "user.email", "tests@example.com"], cwd=path)
    run(["git", "config", "user.name", "Fixture Tests"], cwd=path)

    (path / "src").mkdir(parents=True, exist_ok=True)
    write(path / "src" / "allowed.txt", "base\n")
    write(path / "src" / "disallowed.txt", "base\n")

    write(
        path / "task-canonical.md",
        """# TASK

## FILES
- path: src/allowed.txt
  action: modify

## ESTIMATED_DIFF
100
""",
    )
    write(
        path / "task-pipe.md",
        """# TASK

## FILES
- path: src/allowed.txt | action: modify

## ESTIMATED_DIFF
100
""",
    )
    write(
        path / "task-legacy.md",
        """# TASK
path=src/allowed.txt action=modify
estimated_diff: 100
""",
    )

    run(["git", "add", "."], cwd=path)
    run(["git", "commit", "-qm", "base"], cwd=path)


def run_verify(project: Path, task_file: str, mode: str) -> dict:
    proc = run(
        [
            "bash",
            str(verify_script),
            "--project-dir",
            str(project),
            "--task-file",
            str(project / task_file),
            "--mode",
            mode,
            "--base-commit",
            "HEAD",
        ],
        cwd=project,
        check=False,
    )
    if proc.returncode != 0:
        fail(f"verify.sh exited {proc.returncode}: stderr={proc.stderr}\nstdout={proc.stdout}")
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        fail(f"verify.sh output was not valid JSON: {exc}\nstdout={proc.stdout}\nstderr={proc.stderr}")


with tempfile.TemporaryDirectory(prefix="verify-modes-") as td:
    base = Path(td)

    # Case 1: mode behavior differences for git_clean.
    repo1 = base / "repo1"
    init_repo(repo1)
    write(repo1 / "src" / "allowed.txt", "base\nmodified\n")

    pre = run_verify(repo1, "task-canonical.md", "pre-commit")
    if pre["checks"]["git_clean"] is not True:
        fail(f"pre-commit should skip git_clean and report true, got: {pre}")
    if pre["checks"]["paths_ok"] is not True:
        fail(f"pre-commit with allowed file should pass paths_ok, got: {pre}")

    post = run_verify(repo1, "task-canonical.md", "post-commit")
    if post["checks"]["git_clean"] is not False:
        fail(f"post-commit should enforce git_clean with dirty tree, got: {post}")
    if not any("git_clean:" in item for item in post.get("failures", [])):
        fail(f"post-commit failures should include git_clean message, got: {post.get('failures')}")

    # Case 2: canonical FILES parsing blocks out-of-scope changes.
    repo2 = base / "repo2"
    init_repo(repo2)
    write(repo2 / "src" / "disallowed.txt", "base\nchanged\n")

    canonical = run_verify(repo2, "task-canonical.md", "pre-commit")
    if canonical["checks"]["paths_ok"] is not False:
        fail(f"canonical FILES should enforce scope, got: {canonical}")
    if "src/disallowed.txt" not in canonical["checks"]["blocked_files"]:
        fail(f"blocked_files should include src/disallowed.txt, got: {canonical['checks']['blocked_files']}")

    # Case 3: draft pipe-delimited FILES line is ignored (no allow-list enforcement).
    pipe = run_verify(repo2, "task-pipe.md", "pre-commit")
    if pipe["checks"]["paths_ok"] is not True:
        fail(f"pipe-delimited FILES should be ignored in v3 parser, got: {pipe}")
    if pipe["checks"]["blocked_files"]:
        fail(f"blocked_files should be empty when FILES allow-list is empty, got: {pipe['checks']['blocked_files']}")

    # Case 4: legacy path=... compat still enforces allow-list.
    repo3 = base / "repo3"
    init_repo(repo3)
    write(repo3 / "src" / "disallowed.txt", "base\nchanged\n")

    legacy = run_verify(repo3, "task-legacy.md", "pre-commit")
    if legacy["checks"]["paths_ok"] is not False:
        fail(f"legacy path= format should still enforce scope, got: {legacy}")
    if "src/disallowed.txt" not in legacy["checks"]["blocked_files"]:
        fail(f"legacy blocked_files missing src/disallowed.txt: {legacy['checks']['blocked_files']}")

print("test-verify-modes: PASS")
PY
