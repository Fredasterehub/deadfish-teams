#!/usr/bin/env python3
"""Generate deterministic Codex task descriptions from task packets."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


HEADING_RE = re.compile(r"^\s*##\s+(.+?)\s*$")
FILE_ITEM_RE = re.compile(r"^\s*-\s*path\s*:\s*(.+?)\s*$")
FILE_ITEM_PIPE_RE = re.compile(
    r"^\s*-\s*path\s*:\s*(.*?)\s*\|\s*action\s*:\s*(.*?)\s*(?:\|\s*rationale\s*:\s*(.*?))?\s*$"
)
FILE_FIELD_RE = re.compile(r"^\s+([a-zA-Z_][a-zA-Z0-9_-]*)\s*:\s*(.*?)\s*$")


class ParseError(Exception):
    """Raised when a task packet cannot be parsed as expected."""


def normalize_heading(heading: str) -> str:
    normalized = heading.strip().upper()
    normalized = normalized.replace("-", "_")
    normalized = normalized.replace(" ", "_")
    normalized = re.sub(r"[^A-Z0-9_]", "", normalized)
    return normalized


def parse_sections(markdown: str) -> dict[str, list[str]]:
    sections: dict[str, list[str]] = {}
    current: str | None = None

    for line in markdown.splitlines():
        match = HEADING_RE.match(line)
        if match:
            current = normalize_heading(match.group(1))
            sections.setdefault(current, [])
            continue
        if current is not None:
            sections[current].append(line)

    return sections


def pick_section(sections: dict[str, list[str]], names: list[str]) -> list[str]:
    for name in names:
        if name in sections:
            return sections[name]
    raise ParseError(f"missing required section: one of {', '.join(names)}")


def parse_scalar(raw: str) -> str:
    value = raw.strip()
    if not value:
        return ""

    if value.startswith('"') and value.endswith('"') and len(value) >= 2:
        value = value[1:-1]
        value = value.replace(r"\\", "\\").replace(r"\"", '"').replace(r"\t", "\t")
        return value

    if value.startswith("'") and value.endswith("'") and len(value) >= 2:
        return value[1:-1]

    value = re.sub(r"\s+#.*$", "", value)
    return value.strip()


def parse_files(lines: list[str]) -> list[dict[str, str]]:
    files: list[dict[str, str]] = []
    current: dict[str, str] | None = None

    def flush_current() -> None:
        nonlocal current
        if current is not None:
            path = current.get("path", "").strip()
            if path:
                files.append(current)
            current = None

    for line in lines:
        if not line.strip():
            continue

        match_pipe = FILE_ITEM_PIPE_RE.match(line)
        if match_pipe:
            flush_current()
            item = {
                "path": parse_scalar(match_pipe.group(1)),
                "action": parse_scalar(match_pipe.group(2)),
            }
            rationale = match_pipe.group(3)
            if rationale is not None and rationale.strip():
                item["rationale"] = parse_scalar(rationale)
            if item["path"]:
                files.append(item)
            continue

        match_item = FILE_ITEM_RE.match(line)
        if match_item:
            flush_current()
            current = {"path": parse_scalar(match_item.group(1))}
            continue

        match_field = FILE_FIELD_RE.match(line)
        if match_field and current is not None:
            key = match_field.group(1).strip().lower().replace("-", "_")
            current[key] = parse_scalar(match_field.group(2))
            continue

    flush_current()

    if not files:
        raise ParseError("FILES section did not contain parseable entries")

    for item in files:
        path = item.get("path", "")
        if not path:
            raise ParseError("FILES entry missing path")

    return files


def section_text(lines: list[str], section_name: str) -> str:
    text = "\n".join(lines).rstrip()
    if not text.strip():
        raise ParseError(f"{section_name} section is empty")
    return text


def render_files(files: list[dict[str, str]]) -> list[str]:
    rendered: list[str] = []
    for item in files:
        path = item["path"]
        action = item.get("action", "").strip()
        rationale = item.get("rationale", "").strip()

        if action and rationale:
            rendered.append(f"- {path} ({action}) - {rationale}")
        elif action:
            rendered.append(f"- {path} ({action})")
        else:
            rendered.append(f"- {path}")
    return rendered


def render_output(
    packet_path_ref: str,
    summary_text: str,
    files: list[dict[str, str]],
    acceptance_text: str,
) -> str:
    lines: list[str] = []
    lines.append("## Implementation Prompt")
    lines.extend(summary_text.splitlines())
    lines.append("")
    lines.append("## Files")
    lines.extend(render_files(files))
    lines.append("")
    lines.append("## Acceptance Criteria")
    lines.extend(acceptance_text.splitlines())
    lines.append("")
    lines.append("## Verify")
    lines.append(f"- source packet: `{packet_path_ref}`")
    lines.append(
        f"- command: `bin/verify.sh --project-dir . --task-file {packet_path_ref} --mode pre-commit`"
    )
    lines.append("")
    return "\n".join(lines)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate deterministic Codex task descriptions from task packets."
    )
    parser.add_argument("packet_path", help="Path to task packet markdown file")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    packet_path_ref = args.packet_path
    packet_path = Path(packet_path_ref)

    if not packet_path.exists():
        print(f"ERROR: packet file not found: {packet_path_ref}", file=sys.stderr)
        return 1
    if not packet_path.is_file():
        print(f"ERROR: packet path is not a file: {packet_path_ref}", file=sys.stderr)
        return 1

    try:
        raw = packet_path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"ERROR: failed to read packet file: {exc}", file=sys.stderr)
        return 1

    try:
        sections = parse_sections(raw)

        summary_lines = pick_section(
            sections,
            ["SUMMARY", "SUMMARY_VERBATIM"],
        )
        files_lines = pick_section(
            sections,
            ["FILES", "FILES_VERBATIM"],
        )
        acceptance_lines = pick_section(
            sections,
            [
                "ACCEPTANCE_CRITERIA",
                "ACCEPTANCE",
                "ACCEPTANCE_CRITERIA_VERBATIM",
                "ACCEPTANCE_VERBATIM",
            ],
        )

        summary_text = section_text(summary_lines, "SUMMARY")
        acceptance_text = section_text(acceptance_lines, "ACCEPTANCE_CRITERIA")
        files = parse_files(files_lines)

        output = render_output(
            packet_path_ref=packet_path_ref,
            summary_text=summary_text,
            files=files,
            acceptance_text=acceptance_text,
        )
    except ParseError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    sys.stdout.write(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
