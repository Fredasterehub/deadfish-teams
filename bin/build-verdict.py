#!/usr/bin/env python3
"""build_verdict.py — Sentinel verdict parser for the deadf(ish) pipeline v2.4.2.

Reads JSON criterion responses from stdin, extracts sentinel-delimited verdicts,
validates them against the v2.4.2 spec, and emits structured JSON to stdout.

Exit 0: Valid verdict JSON emitted
Exit 1: Parse failure (actionable error on stderr)
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from typing import Any

# ---------------------------------------------------------------------------
# Sentinel regexes (line-anchored, exact per spec)
# ---------------------------------------------------------------------------
VERDICT_OPENER = re.compile(
    r'^<<<VERDICT:V1:(AC[0-9]+):NONCE=([0-9A-F]{6})>>>\s*$'
)
VERDICT_CLOSER = re.compile(
    r'^<<<END_VERDICT:(AC[0-9]+):NONCE=([0-9A-F]{6})>>>\s*$'
)

# ---------------------------------------------------------------------------
# Regexes for validation
# ---------------------------------------------------------------------------
RE_AC_ID = re.compile(r'^AC[0-9]+$')
RE_NONCE = re.compile(r'^[0-9A-F]{6}$')
RE_KV_LINE = re.compile(r'^([A-Z][A-Z0-9_]*)=(.*)')

ALLOWED_KEYS = frozenset({"ANSWER", "REASON"})
VALID_ANSWERS = frozenset({"YES", "NO"})

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


# ---------------------------------------------------------------------------
# Quoted-value unescaping (no \n or \r escapes allowed)
# ---------------------------------------------------------------------------
_ESCAPES = {"\\": "\\", '"': '"', "t": "\t"}


def unescape_quoted(raw: str, line: int | None = None) -> str:
    """Unescape a quoted value (without surrounding quotes).

    Processes: ``\\\\``, ``\\"``, ``\\t``.
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
# Payload parsing
# ---------------------------------------------------------------------------
def parse_payload(payload_lines: list[str]) -> dict[str, str]:
    """Parse the verdict payload lines into {ANSWER, REASON}."""
    fields: dict[str, str] = {}
    seen_keys: set[str] = set()

    for idx, raw_line in enumerate(payload_lines, start=1):
        # Tabs at line start are forbidden
        if raw_line.startswith('\t'):
            raise ParseError("tab character at start of line", idx)

        # Empty lines are skipped
        if len(raw_line) == 0:
            continue

        m_kv = RE_KV_LINE.match(raw_line)
        if not m_kv:
            raise ParseError("unrecognized line content", idx)

        key = m_kv.group(1)
        raw_val = m_kv.group(2)
        if key not in ALLOWED_KEYS:
            raise ParseError(f"unknown field '{key}'", idx)
        if key in seen_keys:
            raise ParseError(f"duplicate field '{key}'", idx)
        seen_keys.add(key)

        val, is_quoted = parse_value(raw_val, idx)

        if key == "ANSWER":
            if is_quoted:
                raise ParseError("ANSWER must be unquoted", idx)
            answer = val.strip().upper()
            if answer not in VALID_ANSWERS:
                raise ParseError(
                    f"ANSWER must be YES or NO, got '{val.strip()}'", idx
                )
            fields[key] = answer
        elif key == "REASON":
            if not is_quoted:
                raise ParseError("REASON must be quoted", idx)
            if len(val) == 0:
                raise ParseError("REASON cannot be empty", idx)
            if len(val) > 500:
                raise ParseError("REASON exceeds 500 chars", idx)
            if "\n" in val or "\r" in val:
                raise ParseError("REASON must be single-line", idx)
            fields[key] = val

    if "ANSWER" not in fields:
        raise ParseError("missing ANSWER field")
    if "REASON" not in fields:
        raise ParseError("missing REASON field")

    return {"answer": fields["ANSWER"], "reason": fields["REASON"]}


# ---------------------------------------------------------------------------
# Per-criterion parsing
# ---------------------------------------------------------------------------
def parse_verdict(raw_text: str, nonce: str, expected_id: str) -> dict[str, str]:
    """Extract and parse a verdict block from raw text."""
    # Step 1: CRLF normalize
    text = raw_text.replace("\r\n", "\n").replace("\r", "")

    # Step 2: Locate sentinel lines
    lines = text.split("\n")
    opener_indices: list[int] = []
    closer_indices: list[int] = []
    opener_ac: list[str] = []
    closer_ac: list[str] = []
    opener_nonces: list[str] = []
    closer_nonces: list[str] = []

    for i, line in enumerate(lines):
        m = VERDICT_OPENER.match(line)
        if m:
            opener_indices.append(i)
            opener_ac.append(m.group(1))
            opener_nonces.append(m.group(2))
        m = VERDICT_CLOSER.match(line)
        if m:
            closer_indices.append(i)
            closer_ac.append(m.group(1))
            closer_nonces.append(m.group(2))

    # Step 3: Enforce exactly-one-block
    if len(opener_indices) != 1:
        raise ParseError(
            f"expected exactly 1 <<<VERDICT: block, found {len(opener_indices)}"
        )
    if len(closer_indices) != 1:
        raise ParseError(
            f"expected exactly 1 <<<END_VERDICT: block, found {len(closer_indices)}"
        )

    opener_idx = opener_indices[0]
    closer_idx = closer_indices[0]
    open_ac = opener_ac[0]
    close_ac = closer_ac[0]
    open_nonce = opener_nonces[0]
    close_nonce = closer_nonces[0]

    if opener_idx >= closer_idx:
        raise ParseError("opener must appear before closer")

    # Step 4: Validate sentinel IDs/nonces
    if open_ac != close_ac:
        raise ParseError(
            f"criterion mismatch: opener={open_ac}, closer={close_ac}"
        )
    if open_nonce != close_nonce:
        raise ParseError(
            f"nonce mismatch: opener={open_nonce}, closer={close_nonce}"
        )
    if open_nonce != nonce:
        raise ParseError(
            f"nonce mismatch: block={open_nonce}, expected={nonce}"
        )
    if open_ac != expected_id:
        raise ParseError(
            f"criterion mismatch: block={open_ac}, expected={expected_id}"
        )

    # Step 5: Extract payload
    payload_lines = lines[opener_idx + 1: closer_idx]

    # Step 6: Block size cap
    payload_text = "\n".join(payload_lines)
    if len(payload_text) > 16_000:
        raise ParseError(
            f"block content exceeds 16000 chars ({len(payload_text)})"
        )

    # Step 7: Parse payload
    return parse_payload(payload_lines)


# ---------------------------------------------------------------------------
# Public API (for module use)
# ---------------------------------------------------------------------------
def build_verdict(
    criteria_pairs: list[list[str]],
    nonce: str,
    expected_criteria: list[str],
) -> dict[str, Any]:
    """Build a verdict JSON structure from criteria responses.

    Args:
        criteria_pairs: List of [criterion_id, raw_response] pairs.
        nonce: Expected 6-char uppercase hex nonce.
        expected_criteria: Ordered list of expected criterion IDs.

    Returns:
        Structured verdict dict.

    Raises:
        ParseError: On invalid input structure.
        ValueError: If nonce or criteria formats are invalid.
    """
    if not RE_NONCE.match(nonce):
        raise ValueError(
            f"invalid nonce format: '{nonce}' (must match ^[0-9A-F]{{6}}$)"
        )

    if len(expected_criteria) == 0:
        raise ValueError("expected_criteria cannot be empty")

    expected_set: set[str] = set()
    for crit in expected_criteria:
        if not RE_AC_ID.match(crit):
            raise ValueError(
                f"invalid criterion id: '{crit}' (must match ^AC[0-9]+$)"
            )
        if crit in expected_set:
            raise ParseError(f"duplicate expected criterion '{crit}'")
        expected_set.add(crit)

    if not isinstance(criteria_pairs, list):
        raise ParseError("input must be a JSON array of [criterion_id, raw_response]")

    responses: dict[str, str] = {}
    for item in criteria_pairs:
        if not isinstance(item, list) or len(item) != 2:
            raise ParseError("each item must be [criterion_id, raw_response]")
        crit_id, raw_response = item
        if not isinstance(crit_id, str) or not isinstance(raw_response, str):
            raise ParseError("criterion_id and raw_response must be strings")
        if crit_id in responses:
            raise ParseError(f"duplicate criterion_id '{crit_id}'")
        if crit_id not in expected_set:
            raise ParseError(
                f"unexpected criterion_id '{crit_id}' (not in --criteria)"
            )
        responses[crit_id] = raw_response

    criteria_out: dict[str, dict[str, str]] = {}
    missing: list[str] = []
    passed = 0
    failed = 0
    needs_human = 0

    for crit in expected_criteria:
        if crit not in responses:
            missing.append(crit)
            criteria_out[crit] = {
                "answer": "NEEDS_HUMAN",
                "reason": "missing criterion response",
            }
            needs_human += 1
            continue

        try:
            parsed = parse_verdict(responses[crit], nonce, crit)
            criteria_out[crit] = {
                "answer": parsed["answer"],
                "reason": parsed["reason"],
            }
            if parsed["answer"] == "YES":
                passed += 1
            else:
                failed += 1
        except ParseError as exc:
            criteria_out[crit] = {
                "answer": "NEEDS_HUMAN",
                "reason": str(exc),
            }
            needs_human += 1

    if needs_human > 0:
        verdict = "NEEDS_HUMAN"
    elif failed > 0:
        verdict = "FAIL"
    else:
        verdict = "PASS"

    return {
        "verdict": verdict,
        "criteria": criteria_out,
        "missing": missing,
        "total": len(expected_criteria),
        "passed": passed,
        "failed": failed,
    }


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------
def main() -> None:
    """CLI entry point: reads stdin, writes JSON to stdout or error to stderr."""
    parser = argparse.ArgumentParser(
        description="Build sentinel verdict JSON from criterion responses"
    )
    parser.add_argument(
        "--nonce", required=True,
        help="Expected 6-char uppercase hex nonce (e.g. 4F2C9A)"
    )
    parser.add_argument(
        "--criteria", required=True,
        help="Comma-separated criterion IDs (e.g. AC1,AC2,AC3)"
    )
    args = parser.parse_args()

    # Validate nonce format
    if not RE_NONCE.match(args.nonce):
        print(
            f"error: invalid --nonce format '{args.nonce}' "
            f"(must match ^[0-9A-F]{{6}}$)",
            file=sys.stderr,
        )
        sys.exit(1)

    criteria_raw = [c.strip() for c in args.criteria.split(",")]
    if any(c == "" for c in criteria_raw):
        print("error: --criteria contains empty criterion id", file=sys.stderr)
        sys.exit(1)

    try:
        expected_criteria = criteria_raw
        if len(expected_criteria) == 0:
            raise ValueError("--criteria cannot be empty")
        for crit in expected_criteria:
            if not RE_AC_ID.match(crit):
                raise ValueError(
                    f"invalid criterion id '{crit}' (must match ^AC[0-9]+$)"
                )
        if len(set(expected_criteria)) != len(expected_criteria):
            raise ParseError("--criteria contains duplicate ids")
    except (ParseError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)

    raw_text = sys.stdin.read()

    try:
        criteria_pairs = json.loads(raw_text)
    except json.JSONDecodeError as exc:
        print(f"error: invalid JSON input: {exc}", file=sys.stderr)
        sys.exit(1)

    try:
        result = build_verdict(criteria_pairs, args.nonce, expected_criteria)
    except (ParseError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)

    json.dump(result, sys.stdout, ensure_ascii=False, indent=None)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
