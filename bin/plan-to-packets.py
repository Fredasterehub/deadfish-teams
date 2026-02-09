#!/usr/bin/env python3
"""Deterministically mirror a deadfish:PLAN into task packet stubs."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


class PlanError(Exception):
    """Raised when PLAN parsing or validation fails."""


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Mirror PLAN tasks into task packet files")
    parser.add_argument("plan_path", help="markdown file containing one deadfish:PLAN block")
    parser.add_argument("--repo-root", default=".", help="repo root containing bin/parse-blocks.py")
    parser.add_argument("--overwrite", action="store_true", help="overwrite packet files when content differs")
    parser.add_argument("--index-path", help="optional custom packet index path")
    return parser.parse_args(argv)


def parse_plan(plan_path: Path, parser_path: Path) -> dict[str, Any]:
    if not parser_path.is_file():
        raise PlanError(f"missing parser: {parser_path}")
    if not plan_path.is_file():
        raise PlanError(f"plan file not found: {plan_path}")

    payload = plan_path.read_text(encoding="utf-8")
    proc = subprocess.run(
        [sys.executable, str(parser_path), "--type", "PLAN", "--format", "v3", "--stdin"],
        input=payload,
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        raise PlanError(f"failed to parse PLAN: {proc.stderr.strip()}")

    try:
        parsed = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise PlanError(f"parser returned invalid JSON: {exc}") from exc

    if not isinstance(parsed, dict):
        raise PlanError("PLAN payload must decode to an object")
    return parsed


def validate_repo_relative_path(repo_root: Path, raw_path: str, field_name: str) -> Path:
    rel = raw_path.replace("\\", "/").strip()
    if not rel:
        raise PlanError(f"{field_name} must be non-empty")
    if rel.startswith("/"):
        raise PlanError(f"{field_name} must be repo-relative: {raw_path}")

    resolved = (repo_root / rel).resolve()
    root = repo_root.resolve()
    if resolved != root and root not in resolved.parents:
        raise PlanError(f"{field_name} escapes repo root: {raw_path}")
    return resolved


def normalize_tasks(plan: dict[str, Any]) -> tuple[str, list[dict[str, Any]]]:
    track_id = plan.get("track_id")
    tasks = plan.get("tasks")

    if not isinstance(track_id, str) or not track_id.strip():
        raise PlanError("PLAN.track_id must be a non-empty string")
    if not isinstance(tasks, list) or not tasks:
        raise PlanError("PLAN.tasks must be a non-empty list")

    normalized: list[dict[str, Any]] = []
    for idx, task in enumerate(tasks, start=1):
        if not isinstance(task, dict):
            raise PlanError(f"PLAN.tasks[{idx}] must be an object")

        task_id = task.get("id")
        title = task.get("title")
        depends_on = task.get("depends_on")
        packet_path = task.get("packet_path")

        if not isinstance(task_id, str) or not task_id.strip():
            raise PlanError(f"PLAN.tasks[{idx}].id must be a non-empty string")
        if not isinstance(title, str) or not title.strip():
            raise PlanError(f"PLAN.tasks[{idx}].title must be a non-empty string")
        if not isinstance(depends_on, list):
            raise PlanError(f"PLAN.tasks[{idx}].depends_on must be a list")
        if not isinstance(packet_path, str) or not packet_path.strip():
            raise PlanError(f"PLAN.tasks[{idx}].packet_path must be a non-empty string")

        normalized.append(
            {
                "id": task_id.strip(),
                "title": title.strip(),
                "depends_on": [str(dep).strip() for dep in depends_on if str(dep).strip()],
                "packet_path": packet_path.strip().replace("\\", "/"),
            }
        )

    return track_id.strip(), normalized


def render_packet(plan_rel: str, track_id: str, task: dict[str, Any]) -> str:
    deps = ", ".join(task["depends_on"]) if task["depends_on"] else "[]"
    lines = [
        f"# Task Packet: {task['id']} - {task['title']}",
        "",
        "## Metadata",
        f"- source_plan: `{plan_rel}`",
        f"- track_id: `{track_id}`",
        f"- task_id: `{task['id']}`",
        f"- depends_on: `{deps}`",
        "",
        "## Summary",
        f"Implement `{task['title']}` for track `{track_id}`.",
        "Update this summary with repo-specific implementation context before execution.",
        "",
        "## Files",
        "- path: REPLACE_ME.md",
        "  action: modify",
        "  rationale: Replace with actual file scope before execution.",
        "",
        "## Acceptance Criteria",
        "- AC-01: Replace with SPEC criterion text mapped to this task.",
        "",
        "## Verify",
        "- <command>",
        "",
    ]
    return "\n".join(lines)


def render_index(plan_rel: str, track_id: str, tasks: list[dict[str, Any]]) -> str:
    lines = [
        "# Task Packet Index",
        "",
        f"- source_plan: `{plan_rel}`",
        f"- track_id: `{track_id}`",
        "",
        "## Ordered Tasks",
    ]
    for task in tasks:
        deps = ", ".join(task["depends_on"]) if task["depends_on"] else "[]"
        lines.append(f"- [ ] {task['id']} - {task['title']}")
        lines.append(f"  packet: `{task['packet_path']}`")
        lines.append(f"  depends_on: `{deps}`")
    lines.append("")
    return "\n".join(lines)


def write_if_needed(path: Path, content: str, overwrite: bool) -> str:
    existed = path.exists()
    if existed:
        current = path.read_text(encoding="utf-8")
        if current == content:
            return "unchanged"
        if not overwrite:
            return "skipped"

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return "updated" if existed else "created"


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    repo_root = Path(args.repo_root).resolve()
    plan_path = Path(args.plan_path).resolve()
    parser_path = repo_root / "bin" / "parse-blocks.py"

    try:
        plan = parse_plan(plan_path, parser_path)
        track_id, tasks = normalize_tasks(plan)
    except PlanError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    try:
        plan_rel = plan_path.relative_to(repo_root).as_posix()
    except ValueError:
        print("ERROR: plan_path must be inside repo-root", file=sys.stderr)
        return 1

    created: list[str] = []
    updated: list[str] = []
    skipped: list[str] = []

    for task in tasks:
        try:
            packet_abs = validate_repo_relative_path(repo_root, task["packet_path"], "packet_path")
        except PlanError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 1

        result = write_if_needed(packet_abs, render_packet(plan_rel, track_id, task), overwrite=args.overwrite)
        packet_rel = packet_abs.relative_to(repo_root).as_posix()
        if result == "created":
            created.append(packet_rel)
        elif result == "updated":
            updated.append(packet_rel)
        elif result == "skipped":
            skipped.append(packet_rel)

    if args.index_path:
        try:
            index_target = validate_repo_relative_path(repo_root, args.index_path, "index_path")
        except PlanError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 1
    else:
        index_target = plan_path.parent / "task-packets" / "index.md"
        try:
            index_target.relative_to(repo_root)
        except ValueError:
            print("ERROR: computed index path escapes repo-root", file=sys.stderr)
            return 1

    index_result = write_if_needed(index_target, render_index(plan_rel, track_id, tasks), overwrite=True)
    index_rel = index_target.relative_to(repo_root).as_posix()
    if index_result == "created":
        created.append(index_rel)
    elif index_result == "updated":
        updated.append(index_rel)

    print(
        json.dumps(
            {
                "plan_path": plan_rel,
                "track_id": track_id,
                "created": sorted(set(created)),
                "updated": sorted(set(updated)),
                "skipped": sorted(set(skipped)),
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
