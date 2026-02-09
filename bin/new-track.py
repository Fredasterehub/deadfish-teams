#!/usr/bin/env python3
"""Create tracks/<YYYY-MM-DD>-<slug>/ from durable-memory templates."""

from __future__ import annotations

import argparse
import datetime as dt
import re
import sys
from pathlib import Path

SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
TOKENS = {
    "{{TRACK_ID}}": "track_id",
    "{{TRACK_NAME}}": "track_name",
    "{{TRACK_DIR}}": "track_dir",
    "{{DATE}}": "date",
}


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create durable track scaffolding")
    parser.add_argument("--slug", required=True, help="lowercase kebab-case track slug")
    parser.add_argument("--track-name", help="human-readable track name")
    parser.add_argument("--date", default=dt.date.today().isoformat(), help="YYYY-MM-DD prefix")
    parser.add_argument("--repo-root", default=".", help="repo root containing templates/")
    parser.add_argument("--force", action="store_true", help="overwrite existing files")
    return parser.parse_args(argv)


def validate_slug(slug: str) -> None:
    if SLUG_RE.fullmatch(slug) is None:
        raise ValueError("slug must match ^[a-z0-9]+(?:-[a-z0-9]+)*$")


def validate_date(date_text: str) -> None:
    try:
        dt.date.fromisoformat(date_text)
    except ValueError as exc:
        raise ValueError("date must be YYYY-MM-DD") from exc


def default_track_name(slug: str) -> str:
    return " ".join(part.capitalize() for part in slug.split("-"))


def render(template_text: str, values: dict[str, str]) -> str:
    out = template_text
    for token, key in TOKENS.items():
        out = out.replace(token, values[key])
    return out


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    try:
        validate_slug(args.slug)
        validate_date(args.date)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    repo_root = Path(args.repo_root).resolve()
    template_root = repo_root / "templates" / "track" / "durable-memory"
    if not template_root.is_dir():
        print(f"ERROR: template root not found: {template_root}", file=sys.stderr)
        return 1

    track_name = args.track_name.strip() if args.track_name else default_track_name(args.slug)
    track_dir_name = f"{args.date}-{args.slug}"
    track_root = repo_root / "tracks" / track_dir_name

    values = {
        "track_id": args.slug,
        "track_name": track_name,
        "track_dir": track_dir_name,
        "date": args.date,
    }

    templates = sorted(template_root.rglob("*.tmpl"))
    if not templates:
        print(f"ERROR: no template files found under {template_root}", file=sys.stderr)
        return 1

    for template_path in templates:
        rel_path = template_path.relative_to(template_root)
        dest_path = track_root / rel_path.with_suffix("")
        if dest_path.exists() and not args.force:
            print(f"ERROR: refusing to overwrite existing file: {dest_path}", file=sys.stderr)
            return 1
        dest_path.parent.mkdir(parents=True, exist_ok=True)
        rendered = render(template_path.read_text(encoding="utf-8"), values)
        dest_path.write_text(rendered, encoding="utf-8")

    print(track_root.relative_to(repo_root).as_posix())
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
