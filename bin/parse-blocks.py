#!/usr/bin/env python3
"""parse-blocks.py — Unified sentinel block parser for deadf(ish).

Reads raw LLM output from stdin, extracts a sentinel-delimited block,
validates it against the configured grammar spec, and emits structured JSON.

Exit 0: Valid block extracted (JSON on stdout)
Exit 1: Parse/validation failure (actionable error on stderr)
Exit 2: Nonce mismatch (block nonce exists but doesn't match --nonce)
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from typing import Any, Callable

# ---------------------------------------------------------------------------
# Regexes shared across block types
# ---------------------------------------------------------------------------
RE_NONCE = re.compile(r'^[0-9A-F]{6}$')
RE_TOP_KEY = re.compile(r'^[A-Z][A-Z0-9_]*$')
RE_ITEM_KEY = re.compile(r'^[a-z][a-z_]*$')
RE_SECTION_HEADER = re.compile(r'^([A-Z_]+):$')
RE_KV_LINE = re.compile(r'^([A-Z][A-Z0-9_]*)=(.*)')
RE_PATH = re.compile(r'^[a-zA-Z0-9_./-]+$')
RE_AC_ID = re.compile(r'^AC[0-9]+$')
RE_SC_ID = re.compile(r'^SC[0-9]+$')
RE_BARE = re.compile(r'^[A-Za-z0-9_-]+$')
RE_CRITERION = re.compile(r'^[A-Za-z0-9_:-]+$')

# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------
class ParseError(Exception):
    """Parse error with optional line number."""
    def __init__(self, msg: str, line: int | None = None) -> None:
        self.line = line
        if line is not None:
            super().__init__(f"line {line}: {msg}")
        else:
            super().__init__(msg)


class NonceMismatch(Exception):
    """Nonce mismatch error (expected nonce != block nonce)."""
    def __init__(self, block_nonce: str, expected_nonce: str) -> None:
        super().__init__(f"nonce mismatch: block={block_nonce}, expected={expected_nonce}")
        self.block_nonce = block_nonce
        self.expected_nonce = expected_nonce


# ---------------------------------------------------------------------------
# Quoted-value unescaping
# ---------------------------------------------------------------------------
_ESCAPES = {"\\": "\\", '"': '"', "n": "\n", "t": "\t", "r": "\r"}


def unescape_quoted(raw: str, line: int | None = None) -> str:
    """Unescape a quoted value (without surrounding quotes).

    Processes: ``\\\\``, ``\\"``, ``\\n``, ``\\t``, ``\\r``.
    Raises ParseError on invalid escapes or unmatched quotes.
    """
    out: list[str] = []
    i = 0
    while i < len(raw):
        ch = raw[i]
        if ch == '"':
            raise ParseError("unescaped quote inside quoted value", line)
        if ch == '\\':
            i += 1
            if i >= len(raw):
                raise ParseError("unterminated escape sequence", line)
            esc = raw[i]
            if esc not in _ESCAPES:
                raise ParseError(f"invalid escape \\{esc}", line)
            out.append(_ESCAPES[esc])
        else:
            out.append(ch)
        i += 1
    return "".join(out)


def parse_value(raw: str, line: int | None = None) -> tuple[str, bool]:
    """Parse a raw value string. Returns (decoded_value, is_quoted)."""
    stripped = raw.strip()
    if stripped.startswith('"'):
        if not stripped.endswith('"') or len(stripped) < 2:
            raise ParseError("unmatched quote in value", line)
        inner = stripped[1:-1]
        return unescape_quoted(inner, line), True
    return stripped, False


# ---------------------------------------------------------------------------
# Token splitting for list items (handles quoted strings)
# ---------------------------------------------------------------------------
def split_tokens(s: str, line: int | None = None) -> list[str]:
    """Split string into tokens by unquoted whitespace."""
    tokens: list[str] = []
    i = 0
    n = len(s)
    while i < n:
        # skip whitespace
        while i < n and s[i] in (' ', '\t'):
            i += 1
        if i >= n:
            break
        # collect token
        start = i
        while i < n and (s[i] not in (' ', '\t')):
            if s[i] == '"':
                i += 1
                while i < n and s[i] != '"':
                    if s[i] == '\\':
                        i += 1  # skip escaped char
                    i += 1
                if i >= n:
                    raise ParseError("unterminated quoted string in token", line)
                i += 1  # skip closing quote
            else:
                i += 1
        tokens.append(s[start:i])
    return tokens


def parse_item_kv(
    s: str,
    line: int | None = None,
    required_quoted_keys: set[str] | None = None,
) -> dict[str, str]:
    """Parse a list item into key=value pairs with unescaped values."""
    tokens = split_tokens(s, line)
    result: dict[str, str] = {}
    required_quoted_keys = required_quoted_keys or set()
    for tok in tokens:
        eq = tok.find('=')
        if eq < 0:
            raise ParseError(f"expected key=value, got '{tok}'", line)
        key = tok[:eq]
        raw_val = tok[eq + 1:]
        if not RE_ITEM_KEY.match(key):
            raise ParseError(
                f"invalid item key '{key}' (must match ^[a-z][a-z_]*$)", line
            )
        if key in result:
            raise ParseError(f"duplicate item key '{key}'", line)
        val, is_quoted = parse_value(raw_val, line)
        if key in required_quoted_keys and not is_quoted:
            raise ParseError(f"{key} must be quoted", line)
        result[key] = val
    return result


# ---------------------------------------------------------------------------
# Path safety check
# ---------------------------------------------------------------------------
def validate_path(path: str, line: int | None = None) -> None:
    """Validate a file path per spec."""
    if not RE_PATH.match(path):
        raise ParseError(f"invalid path characters: '{path}'", line)
    if path.startswith('/'):
        raise ParseError(f"absolute path not allowed: '{path}'", line)
    parts = path.split('/')
    if '..' in parts:
        raise ParseError(f"path traversal not allowed: '{path}'", line)


# ---------------------------------------------------------------------------
# Block config
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class BlockConfig:
    name: str
    opener_re: re.Pattern[str]
    closer_re: re.Pattern[str]
    allowed_fields: set[str]
    required_fields: set[str]
    section_fields: set[str]
    multiline_fields: set[str]
    force_multiline_fields: set[str]
    required_multiline_fields: set[str]
    nonempty_multiline_fields: set[str]
    field_quoted: dict[str, bool | None]
    section_parsers: dict[str, Callable[[str, int, str], Any]]
    validator: Callable[[dict[str, Any], dict[str, list[Any]], list[str]], dict[str, Any]]


# ---------------------------------------------------------------------------
# Shared parsing logic
# ---------------------------------------------------------------------------
def parse_payload(payload_lines: list[str], config: BlockConfig) -> dict[str, Any]:
    """Parse payload lines into fields and sections, then validate via config."""
    fields: dict[str, Any] = {}
    seen_keys: set[str] = set()
    sections: dict[str, list[Any]] = {k: [] for k in config.section_fields}
    warnings: list[str] = []

    current_section: str | None = None
    pending_multiline: str | None = None
    pending_multiline_line: int | None = None
    multiline_parts: list[str] = []

    def _flush_multiline() -> None:
        nonlocal pending_multiline, pending_multiline_line, multiline_parts
        if pending_multiline is not None:
            if pending_multiline in config.required_multiline_fields:
                if len(multiline_parts) == 0:
                    raise ParseError(
                        f"{pending_multiline} must have at least one continuation line",
                        pending_multiline_line,
                    )
            joined = "\n".join(multiline_parts)
            if pending_multiline in config.nonempty_multiline_fields and len(joined.strip()) == 0:
                raise ParseError(f"{pending_multiline} cannot be empty", pending_multiline_line)
            fields[pending_multiline] = joined
            pending_multiline = None
            pending_multiline_line = None
            multiline_parts = []

    for idx, raw_line in enumerate(payload_lines, start=1):
        # Tab at start → error
        if raw_line.startswith('\t'):
            raise ParseError("tab character at start of line", idx)

        # Blank line (0 chars) → skip; ends any active continuation
        if len(raw_line) == 0:
            _flush_multiline()
            # Do not reset current_section; sections end at next header/field
            continue

        # Continuation line (2+ leading spaces)
        if raw_line.startswith('  '):
            if pending_multiline is not None:
                multiline_parts.append(raw_line[2:])
                continue
            raise ParseError("unexpected continuation (no active multi-line field)", idx)

        # If we get here with non-continuation, flush any pending multi-line
        _flush_multiline()

        # List item
        if raw_line.startswith('- '):
            if current_section is None:
                raise ParseError("list item outside section", idx)
            item_text = raw_line[2:]
            parser = config.section_parsers.get(current_section)
            if parser is None:
                raise ParseError(f"no parser for section '{current_section}'", idx)
            item = parser(item_text, idx, raw_line)
            sections[current_section].append(item)
            continue

        # Section header
        m_section = RE_SECTION_HEADER.match(raw_line)
        if m_section:
            key = m_section.group(1)
            if not RE_TOP_KEY.match(key):
                raise ParseError(f"invalid field name '{key}'", idx)
            if key not in config.allowed_fields:
                raise ParseError(f"unknown field '{key}'", idx)
            if key not in config.section_fields:
                raise ParseError(f"'{key}' cannot be a section header", idx)
            if key in seen_keys:
                raise ParseError(f"duplicate field '{key}'", idx)
            seen_keys.add(key)
            current_section = key
            continue

        # Key=value line
        m_kv = RE_KV_LINE.match(raw_line)
        if m_kv:
            key = m_kv.group(1)
            raw_val = m_kv.group(2)
            if key not in config.allowed_fields:
                raise ParseError(f"unknown field '{key}'", idx)
            if key in config.section_fields:
                raise ParseError(f"'{key}' must be a section header (use '{key}:')", idx)
            if key in seen_keys:
                raise ParseError(f"duplicate field '{key}'", idx)
            seen_keys.add(key)
            current_section = None

            if key in config.force_multiline_fields and raw_val.strip() != '':
                raise ParseError(f"{key} must be multi-line (use {key}=)", idx)

            if key in config.multiline_fields and raw_val.strip() == '':
                pending_multiline = key
                pending_multiline_line = idx
                multiline_parts = []
                continue

            val, is_quoted = parse_value(raw_val, idx)
            quoted_req = config.field_quoted.get(key)
            if quoted_req is True and not is_quoted:
                raise ParseError(f"{key} must be quoted", idx)
            if quoted_req is False and is_quoted:
                raise ParseError(f"{key} must be unquoted", idx)
            fields[key] = val
            continue

        # Unrecognized line
        raise ParseError("unrecognized line content", idx)

    _flush_multiline()

    missing_fields = config.required_fields - seen_keys
    if missing_fields:
        raise ParseError(f"missing required fields: {', '.join(sorted(missing_fields))}")

    return config.validator(fields, sections, warnings)


# ---------------------------------------------------------------------------
# Block extraction
# ---------------------------------------------------------------------------
def extract_block(raw_text: str, nonce: str, config: BlockConfig) -> dict[str, Any]:
    if not RE_NONCE.match(nonce):
        raise ValueError(f"invalid nonce format: '{nonce}' (must match ^[0-9A-F]{{6}}$)")

    text = raw_text.replace("\r\n", "\n").replace("\r", "")
    lines = text.split("\n")

    opener_indices: list[int] = []
    closer_indices: list[int] = []
    opener_nonces: list[str] = []
    closer_nonces: list[str] = []

    for i, line in enumerate(lines):
        m = config.opener_re.match(line)
        if m:
            opener_indices.append(i)
            opener_nonces.append(m.group("nonce"))
        m = config.closer_re.match(line)
        if m:
            closer_indices.append(i)
            closer_nonces.append(m.group("nonce"))

    if len(opener_indices) != 1:
        raise ParseError(
            f"expected exactly 1 <<<{config.name}: block, found {len(opener_indices)}"
        )
    if len(closer_indices) != 1:
        raise ParseError(
            f"expected exactly 1 <<<END_{config.name}: block, found {len(closer_indices)}"
        )

    opener_idx = opener_indices[0]
    closer_idx = closer_indices[0]
    open_nonce = opener_nonces[0]
    close_nonce = closer_nonces[0]

    if opener_idx >= closer_idx:
        raise ParseError("opener must appear before closer")

    if open_nonce != close_nonce:
        raise ParseError(
            f"nonce mismatch: opener={open_nonce}, closer={close_nonce}"
        )
    if open_nonce != nonce:
        raise NonceMismatch(open_nonce, nonce)

    payload_lines = lines[opener_idx + 1: closer_idx]
    payload_text = "\n".join(payload_lines)
    if len(payload_text) > 16_000:
        raise ParseError(
            f"block content exceeds 16000 chars ({len(payload_text)})"
        )

    return parse_payload(payload_lines, config)


# ---------------------------------------------------------------------------
# Plan-specific logic (kept behavior-identical to extract_plan.py)
# ---------------------------------------------------------------------------
FILES_REQUIRED_KEYS = frozenset({"path", "action", "rationale"})
ACCEPTANCE_REQUIRED_KEYS = frozenset({"id", "text"})
VALID_ACTIONS = frozenset({"add", "modify", "delete"})

VAGUE_VERBS = frozenset({
    "improve", "optimize", "enhance", "better",
    "cleanup", "refactor",
})


def make_plan_config() -> BlockConfig:
    opener = re.compile(r'^<<<PLAN:V1:NONCE=(?P<nonce>[0-9A-F]{6})>>>\s*$')
    closer = re.compile(r'^<<<END_PLAN:NONCE=(?P<nonce>[0-9A-F]{6})>>>\s*$')

    def parse_files(item_text: str, line: int, raw_line: str) -> dict[str, str]:
        if len(raw_line) > 1000:
            raise ParseError("FILES line exceeds 1000 chars", line)
        kv = parse_item_kv(item_text, line, required_quoted_keys={"rationale"})
        unknown = set(kv.keys()) - FILES_REQUIRED_KEYS
        if unknown:
            raise ParseError(f"unknown FILES keys: {sorted(unknown)}", line)
        missing = FILES_REQUIRED_KEYS - set(kv.keys())
        if missing:
            raise ParseError(f"missing FILES keys: {sorted(missing)}", line)
        validate_path(kv["path"], line)
        if kv["action"] not in VALID_ACTIONS:
            raise ParseError(
                f"invalid action '{kv['action']}' (must be add/modify/delete)", line
            )
        if "\n" in kv["rationale"] or "\r" in kv["rationale"]:
            raise ParseError("rationale must be single-line", line)
        if len(kv["rationale"]) > 300:
            raise ParseError("rationale exceeds 300 chars", line)
        return kv

    # NOTE: acceptance_items and warnings are tracked via sections dict and
    # a mutable list created per-call in validate_plan, NOT via closure capture.
    # This avoids stale-state bugs when BlockConfig is reused across calls.

    def parse_acceptance(item_text: str, line: int, raw_line: str) -> dict[str, str]:
        if len(raw_line) > 600:
            raise ParseError("ACCEPTANCE line exceeds 600 chars", line)
        kv = parse_item_kv(item_text, line, required_quoted_keys={"text"})
        unknown = set(kv.keys()) - ACCEPTANCE_REQUIRED_KEYS
        if unknown:
            raise ParseError(f"unknown ACCEPTANCE keys: {sorted(unknown)}", line)
        missing = ACCEPTANCE_REQUIRED_KEYS - set(kv.keys())
        if missing:
            raise ParseError(f"missing ACCEPTANCE keys: {sorted(missing)}", line)
        ac_id = kv["id"]
        if not RE_AC_ID.match(ac_id):
            raise ParseError(f"invalid AC id '{ac_id}' (must match ^AC[0-9]+$)", line)
        text = kv["text"]
        if len(text) == 0:
            raise ParseError("acceptance text is empty", line)
        if "\n" in text or "\r" in text:
            raise ParseError("acceptance text must be single-line", line)
        if len(text) > 400:
            raise ParseError("acceptance text exceeds 400 chars", line)
        return kv

    def validate_plan(
        fields: dict[str, Any],
        sections: dict[str, list[Any]],
        _warnings: list[str],
    ) -> dict[str, Any]:
        task_id = fields.get("TASK_ID", "")
        title = fields.get("TITLE", "")
        summary = fields.get("SUMMARY", "")
        notes = fields.get("NOTES")
        est_raw = fields.get("ESTIMATED_DIFF", "")
        files_items = sections.get("FILES", [])
        acceptance = sections.get("ACCEPTANCE", [])

        if len(est_raw) > 10:
            raise ParseError(f"ESTIMATED_DIFF exceeds 10 chars ({len(est_raw)})")
        if not re.fullmatch(r'[1-9][0-9]*', est_raw):
            raise ParseError(
                f"ESTIMATED_DIFF must be a positive integer, got '{est_raw}'"
            )

        if len(files_items) == 0:
            raise ParseError("FILES must have at least 1 item")
        if len(acceptance) == 0:
            raise ParseError("ACCEPTANCE must have at least 1 item")

        if len(task_id) > 64:
            raise ParseError(f"TASK_ID exceeds 64 chars ({len(task_id)})")
        if len(title) > 200:
            raise ParseError(f"TITLE exceeds 200 chars ({len(title)})")
        if len(summary) > 4000:
            raise ParseError(f"SUMMARY exceeds 4000 chars ({len(summary)})")
        if notes is not None and len(notes) > 4000:
            raise ParseError(f"NOTES exceeds 4000 chars ({len(notes)})")
        if len(files_items) > 50:
            raise ParseError(f"FILES has {len(files_items)} items (max 50)")
        if len(acceptance) > 30:
            raise ParseError(f"ACCEPTANCE has {len(acceptance)} items (max 30)")

        # Duplicate-ID check (done here, not in parse_acceptance, to avoid closure state)
        seen_ac_ids: set[str] = set()
        for a in acceptance:
            if a["id"] in seen_ac_ids:
                raise ParseError(f"duplicate acceptance id '{a['id']}'")
            seen_ac_ids.add(a["id"])

        # Vague verb warnings (computed fresh per call)
        warnings: list[str] = []
        for a in acceptance:
            text_lower = a["text"].lower()
            for verb in sorted(VAGUE_VERBS):
                if re.search(rf'\b{re.escape(verb)}\b', text_lower):
                    warnings.append(f"{a['id']} uses vague verb '{verb}' without metrics")
                    break

        return {
            "task_id": task_id,
            "title": title,
            "summary": summary,
            "files": [
                {"path": f["path"], "action": f["action"], "rationale": f["rationale"]}
                for f in files_items
            ],
            "acceptance": [
                {"id": a["id"], "text": a["text"]}
                for a in acceptance
            ],
            "estimated_diff": int(est_raw),
            "notes": notes,
            "warnings": warnings,
        }

    return BlockConfig(
        name="PLAN",
        opener_re=opener,
        closer_re=closer,
        allowed_fields={
            "TASK_ID", "TITLE", "SUMMARY", "FILES",
            "ACCEPTANCE", "ESTIMATED_DIFF", "NOTES",
        },
        required_fields={
            "TASK_ID", "TITLE", "SUMMARY", "FILES",
            "ACCEPTANCE", "ESTIMATED_DIFF",
        },
        section_fields={"FILES", "ACCEPTANCE"},
        multiline_fields={"SUMMARY", "NOTES"},
        force_multiline_fields={"SUMMARY"},
        required_multiline_fields={"SUMMARY"},
        nonempty_multiline_fields={"SUMMARY"},
        field_quoted={
            "TITLE": True,
            "TASK_ID": False,
            "ESTIMATED_DIFF": False,
        },
        section_parsers={
            "FILES": parse_files,
            "ACCEPTANCE": parse_acceptance,
        },
        validator=validate_plan,
    )


# ---------------------------------------------------------------------------
# Track
# ---------------------------------------------------------------------------
TRACK_REQUIRED = {
    "TRACK_ID", "NAME", "PHASE", "GOAL", "REQUIREMENTS", "ESTIMATED_TASKS",
}


def validate_bare(value: str, line: int | None = None, field: str | None = None) -> str:
    if len(value) == 0:
        raise ParseError(f"{field or 'value'} cannot be empty", line)
    if not RE_BARE.match(value):
        raise ParseError(f"invalid bare value '{value}'", line)
    if len(value) > 64:
        raise ParseError(f"{field or 'value'} exceeds 64 chars ({len(value)})", line)
    return value


def parse_bool(value: str, line: int | None = None, field: str | None = None) -> bool:
    if value not in {"true", "false"}:
        raise ParseError(f"{field or 'value'} must be true or false", line)
    return value == "true"


def make_track_config() -> BlockConfig:
    opener = re.compile(r'^<<<TRACK:V1:NONCE=(?P<nonce>[0-9A-F]{6})>>>\s*$')
    closer = re.compile(r'^<<<END_TRACK:NONCE=(?P<nonce>[0-9A-F]{6})>>>\s*$')

    def validate_track(fields: dict[str, Any], _sections: dict[str, list[Any]], _w: list[str]) -> dict[str, Any]:
        track_id = validate_bare(fields.get("TRACK_ID", ""), field="TRACK_ID")
        name = fields.get("NAME", "")
        phase = validate_bare(fields.get("PHASE", ""), field="PHASE")
        goal = fields.get("GOAL", "")
        req_raw = fields.get("REQUIREMENTS", "")
        est_raw = fields.get("ESTIMATED_TASKS", "")

        if len(name) == 0:
            raise ParseError("NAME cannot be empty")
        if len(goal) == 0:
            raise ParseError("GOAL cannot be empty")
        if len(name) > 200:
            raise ParseError(f"NAME exceeds 200 chars ({len(name)})")
        if len(goal) > 500:
            raise ParseError(f"GOAL exceeds 500 chars ({len(goal)})")

        requirements: list[str] = []
        for part in [p.strip() for p in req_raw.split(',')]:
            if part == "":
                raise ParseError("REQUIREMENTS has empty item")
            requirements.append(validate_bare(part, field="REQUIREMENTS"))
        if len(requirements) == 0:
            raise ParseError("REQUIREMENTS must have at least 1 item")
        if len(requirements) > 30:
            raise ParseError(f"REQUIREMENTS has {len(requirements)} items (max 30)")

        if not re.fullmatch(r'[1-9][0-9]*', est_raw):
            raise ParseError(
                f"ESTIMATED_TASKS must be a positive integer, got '{est_raw}'"
            )

        phase_complete = None
        phase_blocked = None
        if "PHASE_COMPLETE" in fields:
            phase_complete = parse_bool(fields["PHASE_COMPLETE"], field="PHASE_COMPLETE")
        if "PHASE_BLOCKED" in fields:
            phase_blocked = parse_bool(fields["PHASE_BLOCKED"], field="PHASE_BLOCKED")

        reasons = fields.get("REASONS")
        if phase_blocked is True and not reasons:
            raise ParseError("REASONS required when PHASE_BLOCKED=true")
        if reasons is not None:
            if "\n" in reasons or "\r" in reasons:
                raise ParseError("REASONS must be single-line")
            if len(reasons) > 500:
                raise ParseError("REASONS exceeds 500 chars")

        return {
            "track_id": track_id,
            "name": name,
            "phase": phase,
            "goal": goal,
            "requirements": requirements,
            "estimated_tasks": int(est_raw),
            "phase_complete": phase_complete,
            "phase_blocked": phase_blocked,
            "reasons": reasons,
        }

    return BlockConfig(
        name="TRACK",
        opener_re=opener,
        closer_re=closer,
        allowed_fields={
            "TRACK_ID", "NAME", "PHASE", "GOAL", "REQUIREMENTS",
            "ESTIMATED_TASKS", "PHASE_COMPLETE", "PHASE_BLOCKED", "REASONS",
        },
        required_fields=set(TRACK_REQUIRED),
        section_fields=set(),
        multiline_fields=set(),
        force_multiline_fields=set(),
        required_multiline_fields=set(),
        nonempty_multiline_fields=set(),
        field_quoted={
            "NAME": True,
            "GOAL": True,
            "REASONS": True,
            "TRACK_ID": False,
            "PHASE": False,
            "REQUIREMENTS": False,
            "ESTIMATED_TASKS": False,
            "PHASE_COMPLETE": False,
            "PHASE_BLOCKED": False,
        },
        section_parsers={},
        validator=validate_track,
    )


# ---------------------------------------------------------------------------
# Spec
# ---------------------------------------------------------------------------
SUCCESS_REQUIRED_KEYS = frozenset({"id", "text"})


def make_spec_config() -> BlockConfig:
    opener = re.compile(r'^<<<SPEC:V1:NONCE=(?P<nonce>[0-9A-F]{6})>>>\s*$')
    closer = re.compile(r'^<<<END_SPEC:NONCE=(?P<nonce>[0-9A-F]{6})>>>\s*$')

    # NOTE: duplicate-ID check moved to validate_spec to avoid closure state leak.

    def parse_success(item_text: str, line: int, raw_line: str) -> dict[str, str]:
        if len(raw_line) > 600:
            raise ParseError("SUCCESS_CRITERIA line exceeds 600 chars", line)
        kv = parse_item_kv(item_text, line, required_quoted_keys={"text"})
        unknown = set(kv.keys()) - SUCCESS_REQUIRED_KEYS
        if unknown:
            raise ParseError(f"unknown SUCCESS_CRITERIA keys: {sorted(unknown)}", line)
        missing = SUCCESS_REQUIRED_KEYS - set(kv.keys())
        if missing:
            raise ParseError(f"missing SUCCESS_CRITERIA keys: {sorted(missing)}", line)
        sc_id = kv["id"]
        if not RE_SC_ID.match(sc_id):
            raise ParseError(f"invalid SC id '{sc_id}' (must match ^SC[0-9]+$)", line)
        text = kv["text"]
        if len(text) == 0:
            raise ParseError("success criteria text is empty", line)
        if "\n" in text or "\r" in text:
            raise ParseError("success criteria text must be single-line", line)
        if len(text) > 400:
            raise ParseError("success criteria text exceeds 400 chars", line)
        return kv

    def parse_dependency(item_text: str, line: int, raw_line: str) -> str:
        if len(raw_line) > 600:
            raise ParseError("DEPENDENCIES line exceeds 600 chars", line)
        val, is_quoted = parse_value(item_text, line)
        if not is_quoted:
            raise ParseError("dependency must be quoted", line)
        if len(val) == 0:
            raise ParseError("dependency cannot be empty", line)
        if "\n" in val or "\r" in val:
            raise ParseError("dependency must be single-line", line)
        if len(val) > 400:
            raise ParseError("dependency exceeds 400 chars", line)
        return val

    def validate_spec(fields: dict[str, Any], sections: dict[str, list[Any]], _w: list[str]) -> dict[str, Any]:
        track_id = validate_bare(fields.get("TRACK_ID", ""), field="TRACK_ID")
        title = fields.get("TITLE", "")
        scope = fields.get("SCOPE", "")
        approach = fields.get("APPROACH", "")
        constraints = fields.get("CONSTRAINTS", "")
        est_raw = fields.get("ESTIMATED_TASKS", "")

        if len(title) == 0:
            raise ParseError("TITLE cannot be empty")
        if len(title) > 200:
            raise ParseError(f"TITLE exceeds 200 chars ({len(title)})")
        if len(scope) > 4000:
            raise ParseError(f"SCOPE exceeds 4000 chars ({len(scope)})")
        if len(approach) > 4000:
            raise ParseError(f"APPROACH exceeds 4000 chars ({len(approach)})")
        if len(constraints) > 4000:
            raise ParseError(f"CONSTRAINTS exceeds 4000 chars ({len(constraints)})")

        if not re.fullmatch(r'[1-9][0-9]*', est_raw):
            raise ParseError(
                f"ESTIMATED_TASKS must be a positive integer, got '{est_raw}'"
            )

        success = sections.get("SUCCESS_CRITERIA", [])
        deps = sections.get("DEPENDENCIES", [])
        if len(success) == 0:
            raise ParseError("SUCCESS_CRITERIA must have at least 1 item")
        if len(success) > 30:
            raise ParseError(f"SUCCESS_CRITERIA has {len(success)} items (max 30)")
        if len(deps) > 30:
            raise ParseError(f"DEPENDENCIES has {len(deps)} items (max 30)")

        # Duplicate-ID check (done here, not in parse_success, to avoid closure state)
        seen_sc_ids: set[str] = set()
        for sc in success:
            if sc["id"] in seen_sc_ids:
                raise ParseError(f"duplicate success criteria id '{sc['id']}'")
            seen_sc_ids.add(sc["id"])

        return {
            "track_id": track_id,
            "title": title,
            "scope": scope,
            "approach": approach,
            "constraints": constraints,
            "success_criteria": [
                {"id": sc["id"], "text": sc["text"]} for sc in success
            ],
            "dependencies": list(deps),
            "estimated_tasks": int(est_raw),
        }

    return BlockConfig(
        name="SPEC",
        opener_re=opener,
        closer_re=closer,
        allowed_fields={
            "TRACK_ID", "TITLE", "SCOPE", "APPROACH", "CONSTRAINTS",
            "SUCCESS_CRITERIA", "DEPENDENCIES", "ESTIMATED_TASKS",
        },
        required_fields={
            "TRACK_ID", "TITLE", "SCOPE", "APPROACH", "CONSTRAINTS",
            "SUCCESS_CRITERIA", "DEPENDENCIES", "ESTIMATED_TASKS",
        },
        section_fields={"SUCCESS_CRITERIA", "DEPENDENCIES"},
        multiline_fields={"SCOPE", "APPROACH", "CONSTRAINTS"},
        force_multiline_fields={"SCOPE", "APPROACH", "CONSTRAINTS"},
        required_multiline_fields={"SCOPE", "APPROACH", "CONSTRAINTS"},
        nonempty_multiline_fields={"SCOPE", "APPROACH", "CONSTRAINTS"},
        field_quoted={
            "TITLE": True,
            "TRACK_ID": False,
            "ESTIMATED_TASKS": False,
        },
        section_parsers={
            "SUCCESS_CRITERIA": parse_success,
            "DEPENDENCIES": parse_dependency,
        },
        validator=validate_spec,
    )


# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------

def make_verdict_config(criterion: str) -> BlockConfig:
    opener = re.compile(
        rf'^<<<VERDICT:V1:{re.escape(criterion)}:NONCE=(?P<nonce>[0-9A-F]{{6}})>>>\s*$'
    )
    closer = re.compile(
        rf'^<<<END_VERDICT:{re.escape(criterion)}:NONCE=(?P<nonce>[0-9A-F]{{6}})>>>\s*$'
    )

    def validate_verdict(fields: dict[str, Any], _sections: dict[str, list[Any]], _w: list[str]) -> dict[str, Any]:
        answer = fields.get("ANSWER", "")
        reason = fields.get("REASON", "")

        if answer not in {"YES", "NO"}:
            raise ParseError("ANSWER must be YES or NO")
        if "\n" in reason or "\r" in reason:
            raise ParseError("REASON must be single-line")
        if len(reason) == 0:
            raise ParseError("REASON cannot be empty")
        if len(reason) > 500:
            raise ParseError("REASON exceeds 500 chars")

        return {
            "criterion_id": criterion,
            "answer": answer,
            "reason": reason,
        }

    return BlockConfig(
        name="VERDICT",
        opener_re=opener,
        closer_re=closer,
        allowed_fields={"ANSWER", "REASON"},
        required_fields={"ANSWER", "REASON"},
        section_fields=set(),
        multiline_fields=set(),
        force_multiline_fields=set(),
        required_multiline_fields=set(),
        nonempty_multiline_fields=set(),
        field_quoted={
            "ANSWER": False,
            "REASON": True,
        },
        section_parsers={},
        validator=validate_verdict,
    )


# ---------------------------------------------------------------------------
# Reflect
# ---------------------------------------------------------------------------
REFLECT_DOCS = frozenset({
    "TECH_STACK", "PATTERNS", "PITFALLS", "RISKS", "PRODUCT", "WORKFLOW", "GLOSSARY",
})
REFLECT_ACTIONS = frozenset({"append", "replace_section", "noop"})
REFLECT_REQUIRED_KEYS = frozenset({"doc", "action", "section", "content"})


def make_reflect_config() -> BlockConfig:
    opener = re.compile(r'^<<<REFLECT:V1:NONCE=(?P<nonce>[0-9A-F]{6})>>>\s*$')
    closer = re.compile(r'^<<<END_REFLECT:NONCE=(?P<nonce>[0-9A-F]{6})>>>\s*$')

    def parse_update(item_text: str, line: int, raw_line: str) -> dict[str, str]:
        if len(raw_line) > 1000:
            raise ParseError("UPDATES line exceeds 1000 chars", line)
        kv = parse_item_kv(item_text, line, required_quoted_keys={"section", "content"})
        unknown = set(kv.keys()) - REFLECT_REQUIRED_KEYS
        if unknown:
            raise ParseError(f"unknown UPDATES keys: {sorted(unknown)}", line)
        missing = REFLECT_REQUIRED_KEYS - set(kv.keys())
        if missing:
            raise ParseError(f"missing UPDATES keys: {sorted(missing)}", line)
        if kv["doc"] not in REFLECT_DOCS:
            raise ParseError(f"invalid doc '{kv['doc']}'", line)
        if kv["action"] not in REFLECT_ACTIONS:
            raise ParseError(f"invalid action '{kv['action']}'", line)
        if "\n" in kv["section"] or "\r" in kv["section"]:
            raise ParseError("section must be single-line", line)
        if "\n" in kv["content"] or "\r" in kv["content"]:
            raise ParseError("content must be single-line", line)
        if len(kv["section"]) == 0:
            raise ParseError("section cannot be empty", line)
        if len(kv["section"]) > 200:
            raise ParseError("section exceeds 200 chars", line)
        if len(kv["content"]) > 1000:
            raise ParseError("content exceeds 1000 chars", line)
        return kv

    def validate_reflect(fields: dict[str, Any], sections: dict[str, list[Any]], _w: list[str]) -> dict[str, Any]:
        updates = sections.get("UPDATES", [])
        scratch = fields.get("SCRATCH", "")

        if len(updates) > 50:
            raise ParseError(f"UPDATES has {len(updates)} items (max 50)")
        if len(scratch) > 4000:
            raise ParseError(f"SCRATCH exceeds 4000 chars ({len(scratch)})")

        return {
            "updates": [
                {
                    "doc": u["doc"],
                    "action": u["action"],
                    "section": u["section"],
                    "content": u["content"],
                }
                for u in updates
            ],
            "scratch": scratch,
        }

    return BlockConfig(
        name="REFLECT",
        opener_re=opener,
        closer_re=closer,
        allowed_fields={"UPDATES", "SCRATCH"},
        required_fields={"UPDATES", "SCRATCH"},
        section_fields={"UPDATES"},
        multiline_fields={"SCRATCH"},
        force_multiline_fields={"SCRATCH"},
        required_multiline_fields={"SCRATCH"},
        nonempty_multiline_fields={"SCRATCH"},
        field_quoted={},
        section_parsers={"UPDATES": parse_update},
        validator=validate_reflect,
    )


# ---------------------------------------------------------------------------
# QA Review
# ---------------------------------------------------------------------------
QA_SEVERITIES = frozenset({"CRITICAL", "MAJOR", "MINOR"})
QA_CATEGORIES = frozenset({"C0", "C1", "C2", "C3", "C4", "C5"})
QA_FINDING_KEYS = frozenset({"severity", "category", "file", "issue"})
QA_REMEDIATION_KEYS = frozenset({"file", "action"})


def make_qa_review_config() -> BlockConfig:
    opener = re.compile(r'^<<<QA_REVIEW:V1:NONCE=(?P<nonce>[0-9A-F]{6})>>>\s*$')
    closer = re.compile(r'^<<<END_QA_REVIEW:NONCE=(?P<nonce>[0-9A-F]{6})>>>\s*$')

    def parse_finding(item_text: str, line: int, raw_line: str) -> dict[str, str]:
        if len(raw_line) > 1200:
            raise ParseError("FINDINGS line exceeds 1200 chars", line)
        kv = parse_item_kv(item_text, line, required_quoted_keys={"file", "issue"})
        unknown = set(kv.keys()) - QA_FINDING_KEYS
        if unknown:
            raise ParseError(f"unknown FINDINGS keys: {sorted(unknown)}", line)
        missing = QA_FINDING_KEYS - set(kv.keys())
        if missing:
            raise ParseError(f"missing FINDINGS keys: {sorted(missing)}", line)
        if kv["severity"] not in QA_SEVERITIES:
            raise ParseError(f"invalid severity '{kv['severity']}'", line)
        if kv["category"] not in QA_CATEGORIES:
            raise ParseError(f"invalid category '{kv['category']}'", line)
        validate_path(kv["file"], line)
        if "\n" in kv["issue"] or "\r" in kv["issue"]:
            raise ParseError("issue must be single-line", line)
        if len(kv["issue"]) == 0:
            raise ParseError("issue cannot be empty", line)
        if len(kv["issue"]) > 400:
            raise ParseError("issue exceeds 400 chars", line)
        return kv

    def parse_remediation(item_text: str, line: int, raw_line: str) -> dict[str, str]:
        if len(raw_line) > 800:
            raise ParseError("REMEDIATION line exceeds 800 chars", line)
        kv = parse_item_kv(item_text, line, required_quoted_keys={"file", "action"})
        unknown = set(kv.keys()) - QA_REMEDIATION_KEYS
        if unknown:
            raise ParseError(f"unknown REMEDIATION keys: {sorted(unknown)}", line)
        missing = QA_REMEDIATION_KEYS - set(kv.keys())
        if missing:
            raise ParseError(f"missing REMEDIATION keys: {sorted(missing)}", line)
        validate_path(kv["file"], line)
        if "\n" in kv["action"] or "\r" in kv["action"]:
            raise ParseError("action must be single-line", line)
        if len(kv["action"]) == 0:
            raise ParseError("action cannot be empty", line)
        if len(kv["action"]) > 200:
            raise ParseError("action exceeds 200 chars", line)
        return kv

    def validate_qa_review(fields: dict[str, Any], sections: dict[str, list[Any]], _w: list[str]) -> dict[str, Any]:
        verdict = fields.get("VERDICT", "")
        risk = fields.get("RISK", "")
        notes = fields.get("NOTES", "")
        findings_count_raw = fields.get("FINDINGS_COUNT", "")
        remediation_count_raw = fields.get("REMEDIATION_COUNT", "")

        if verdict not in {"PASS", "FAIL"}:
            raise ParseError("VERDICT must be PASS or FAIL")
        if risk not in {"LOW", "MEDIUM", "HIGH"}:
            raise ParseError("RISK must be LOW, MEDIUM, or HIGH")

        for key in ["C0", "C1", "C2", "C3", "C4", "C5"]:
            val = fields.get(key, "")
            if val not in {"PASS", "FAIL"}:
                raise ParseError(f"{key} must be PASS or FAIL")

        if not re.fullmatch(r'[0-9]+', findings_count_raw):
            raise ParseError(f"FINDINGS_COUNT must be a non-negative integer")
        if not re.fullmatch(r'[0-9]+', remediation_count_raw):
            raise ParseError(f"REMEDIATION_COUNT must be a non-negative integer")

        findings_count = int(findings_count_raw)
        remediation_count = int(remediation_count_raw)

        if "\n" in notes or "\r" in notes:
            raise ParseError("NOTES must be single-line")
        if len(notes) > 500:
            raise ParseError("NOTES exceeds 500 chars")

        findings = sections.get("FINDINGS", [])
        remediation = sections.get("REMEDIATION", [])

        if len(findings) != findings_count:
            raise ParseError(
                f"FINDINGS_COUNT={findings_count} but {len(findings)} findings provided"
            )
        if len(remediation) != remediation_count:
            raise ParseError(
                f"REMEDIATION_COUNT={remediation_count} but {len(remediation)} items provided"
            )

        if len(findings) > 200:
            raise ParseError(f"FINDINGS has {len(findings)} items (max 200)")
        if len(remediation) > 200:
            raise ParseError(f"REMEDIATION has {len(remediation)} items (max 200)")

        return {
            "verdict": verdict,
            "risk": risk,
            "c0": fields["C0"],
            "c1": fields["C1"],
            "c2": fields["C2"],
            "c3": fields["C3"],
            "c4": fields["C4"],
            "c5": fields["C5"],
            "findings_count": findings_count,
            "findings": [
                {
                    "severity": f["severity"],
                    "category": f["category"],
                    "file": f["file"],
                    "issue": f["issue"],
                }
                for f in findings
            ],
            "remediation_count": remediation_count,
            "remediation": [
                {"file": r["file"], "action": r["action"]} for r in remediation
            ],
            "notes": notes,
        }

    return BlockConfig(
        name="QA_REVIEW",
        opener_re=opener,
        closer_re=closer,
        allowed_fields={
            "VERDICT", "RISK", "C0", "C1", "C2", "C3", "C4", "C5",
            "FINDINGS_COUNT", "FINDINGS", "REMEDIATION_COUNT", "REMEDIATION", "NOTES",
        },
        required_fields={
            "VERDICT", "RISK", "C0", "C1", "C2", "C3", "C4", "C5",
            "FINDINGS_COUNT", "FINDINGS", "REMEDIATION_COUNT", "REMEDIATION", "NOTES",
        },
        section_fields={"FINDINGS", "REMEDIATION"},
        multiline_fields=set(),
        force_multiline_fields=set(),
        required_multiline_fields=set(),
        nonempty_multiline_fields=set(),
        field_quoted={
            "NOTES": True,
            "VERDICT": False,
            "RISK": False,
            "C0": False,
            "C1": False,
            "C2": False,
            "C3": False,
            "C4": False,
            "C5": False,
            "FINDINGS_COUNT": False,
            "REMEDIATION_COUNT": False,
        },
        section_parsers={
            "FINDINGS": parse_finding,
            "REMEDIATION": parse_remediation,
        },
        validator=validate_qa_review,
    )


# ---------------------------------------------------------------------------
# Command dispatch
# ---------------------------------------------------------------------------

def build_config(command: str, criterion: str | None = None) -> BlockConfig:
    if command == "plan":
        return make_plan_config()
    if command == "track":
        return make_track_config()
    if command == "spec":
        return make_spec_config()
    if command == "reflect":
        return make_reflect_config()
    if command == "qa-review":
        return make_qa_review_config()
    if command == "verdict":
        if criterion is None:
            raise ParseError("--criterion is required for verdict")
        if not RE_CRITERION.match(criterion):
            raise ParseError("invalid --criterion format")
        return make_verdict_config(criterion)
    raise ParseError(f"unknown command '{command}'")


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Extract sentinel-delimited blocks from LLM output"
    )
    sub = parser.add_subparsers(dest="command", required=True)

    def add_block(name: str, with_criterion: bool = False) -> None:
        p = sub.add_parser(name)
        p.add_argument(
            "--nonce", required=True,
            help="Expected 6-char uppercase hex nonce (e.g. 4F2C9A)"
        )
        if with_criterion:
            p.add_argument(
                "--criterion", required=True,
                help="Expected criterion id (e.g. AC1)"
            )

    add_block("track")
    add_block("spec")
    add_block("plan")
    add_block("verdict", with_criterion=True)
    add_block("reflect")
    add_block("qa-review")

    args = parser.parse_args()

    if not RE_NONCE.match(args.nonce):
        print(
            f"error: invalid --nonce format '{args.nonce}' "
            f"(must match ^[0-9A-F]{{6}}$)",
            file=sys.stderr,
        )
        sys.exit(1)

    raw_text = sys.stdin.read()

    try:
        config = build_config(args.command, getattr(args, "criterion", None))
        result = extract_block(raw_text, args.nonce, config)
    except NonceMismatch as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(2)
    except (ParseError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)

    json.dump(result, sys.stdout, ensure_ascii=False, indent=None)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
