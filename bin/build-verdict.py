#!/usr/bin/env python3
"""Aggregate criterion verdicts into PASS | FAIL | NEEDS_HUMAN.

Supports two wire formats:
- v1: legacy criterion response pairs with embedded <<<VERDICT:V1...>>> blocks
- v3: parsed JSON objects (typically from parse-blocks.py) using
  VERDICT_CRITERION fields and optional aggregate VERDICT fields

Output JSON shape is stable:
{
  "verdict": "PASS|FAIL|NEEDS_HUMAN",
  "criteria": {"AC-01": {"answer": "YES|NO|NEEDS_HUMAN", "reason": "..."}},
  "missing": ["AC-02"],
  "total": 2,
  "passed": 1,
  "failed": 0
}
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from typing import Any


VERDICT_OPENER = re.compile(
    r"^<<<VERDICT:V1:(AC[0-9]+):NONCE=([0-9A-F]{6})>>>\s*$"
)
VERDICT_CLOSER = re.compile(
    r"^<<<END_VERDICT:(AC[0-9]+):NONCE=([0-9A-F]{6})>>>\s*$"
)
RE_NONCE = re.compile(r"^[0-9A-F]{6}$")
RE_AC_ID_ANY = re.compile(r"^AC(?:[0-9]+|-\d{2,})$")
RE_AC_ID_V1 = re.compile(r"^AC[0-9]+$")
RE_KV_LINE = re.compile(r"^([A-Z][A-Z0-9_]*)=(.*)")

VALID_V1_ANSWER = frozenset({"YES", "NO"})
VALID_STATUS = frozenset({"PASS", "FAIL"})
VALID_FORMATS = frozenset({"v1", "v3", "auto"})


class ParseError(Exception):
    """Raised for actionable input/validation errors."""

    def __init__(self, msg: str, line: int | None = None) -> None:
        self.line = line
        if line is not None:
            super().__init__(f"line {line}: {msg}")
        else:
            super().__init__(msg)


_ESCAPES = {"\\": "\\", '"': '"', "t": "\t"}


def _validate_criterion_id(value: str) -> None:
    if not RE_AC_ID_ANY.match(value):
        raise ParseError(
            f"invalid criterion id '{value}' "
            "(expected AC<number> or AC-<zero-padded number>)"
        )


def _normalize_answer(value: str) -> str:
    upper = value.strip().upper()
    if upper in {"YES", "PASS"}:
        return "YES"
    if upper in {"NO", "FAIL"}:
        return "NO"
    if upper == "NEEDS_HUMAN":
        return "NEEDS_HUMAN"
    raise ParseError(f"invalid answer/status '{value}'")


def _unescape_quoted(raw: str, line: int | None = None) -> str:
    out: list[str] = []
    i = 0
    while i < len(raw):
        ch = raw[i]
        if ch == '"':
            raise ParseError("unescaped quote inside quoted value", line)
        if ch == "\\":
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


def _parse_value(raw: str, line: int | None = None) -> tuple[str, bool]:
    stripped = raw.strip()
    if stripped.startswith('"'):
        if not stripped.endswith('"') or len(stripped) < 2:
            raise ParseError("unmatched quote in value", line)
        inner = stripped[1:-1]
        return _unescape_quoted(inner, line), True
    return stripped, False


def _parse_v1_payload(payload_lines: list[str]) -> dict[str, str]:
    fields: dict[str, str] = {}
    seen_keys: set[str] = set()

    for idx, raw_line in enumerate(payload_lines, start=1):
        if raw_line.startswith("\t"):
            raise ParseError("tab character at start of line", idx)
        if len(raw_line) == 0:
            continue

        m_kv = RE_KV_LINE.match(raw_line)
        if not m_kv:
            raise ParseError("unrecognized line content", idx)

        key = m_kv.group(1)
        raw_val = m_kv.group(2)
        if key not in {"ANSWER", "REASON"}:
            raise ParseError(f"unknown field '{key}'", idx)
        if key in seen_keys:
            raise ParseError(f"duplicate field '{key}'", idx)
        seen_keys.add(key)

        val, is_quoted = _parse_value(raw_val, idx)
        if key == "ANSWER":
            if is_quoted:
                raise ParseError("ANSWER must be unquoted", idx)
            answer = val.strip().upper()
            if answer not in VALID_V1_ANSWER:
                raise ParseError(
                    f"ANSWER must be YES or NO, got '{val.strip()}'",
                    idx,
                )
            fields[key] = answer
        else:
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


def _parse_v1_block(
    raw_text: str,
    expected_id: str,
    expected_nonce: str | None,
) -> dict[str, str]:
    if not RE_AC_ID_V1.match(expected_id):
        raise ParseError(
            f"v1 criterion id must match ^AC[0-9]+$, got '{expected_id}'"
        )

    text = raw_text.replace("\r\n", "\n").replace("\r", "")
    lines = text.split("\n")

    opener_indices: list[int] = []
    closer_indices: list[int] = []
    opener_ids: list[str] = []
    closer_ids: list[str] = []
    opener_nonces: list[str] = []
    closer_nonces: list[str] = []

    for i, line in enumerate(lines):
        m_open = VERDICT_OPENER.match(line)
        if m_open:
            opener_indices.append(i)
            opener_ids.append(m_open.group(1))
            opener_nonces.append(m_open.group(2))
        m_close = VERDICT_CLOSER.match(line)
        if m_close:
            closer_indices.append(i)
            closer_ids.append(m_close.group(1))
            closer_nonces.append(m_close.group(2))

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
    open_id = opener_ids[0]
    close_id = closer_ids[0]
    open_nonce = opener_nonces[0]
    close_nonce = closer_nonces[0]

    if opener_idx >= closer_idx:
        raise ParseError("opener must appear before closer")
    if open_id != close_id:
        raise ParseError(f"criterion mismatch: opener={open_id}, closer={close_id}")
    if open_nonce != close_nonce:
        raise ParseError(f"nonce mismatch: opener={open_nonce}, closer={close_nonce}")
    if open_id != expected_id:
        raise ParseError(f"criterion mismatch: block={open_id}, expected={expected_id}")
    if expected_nonce is not None and open_nonce != expected_nonce:
        raise ParseError(
            f"nonce mismatch: block={open_nonce}, expected={expected_nonce}"
        )

    payload_lines = lines[opener_idx + 1 : closer_idx]
    payload_text = "\n".join(payload_lines)
    if len(payload_text) > 16_000:
        raise ParseError(
            f"block content exceeds 16000 chars ({len(payload_text)})"
        )
    return _parse_v1_payload(payload_lines)


def _parse_expected_criteria(raw: str) -> list[str]:
    if raw.strip() == "":
        return []
    parts = [c.strip() for c in raw.split(",")]
    if any(c == "" for c in parts):
        raise ParseError("--criteria contains empty criterion id")
    seen: set[str] = set()
    for crit in parts:
        _validate_criterion_id(crit)
        if crit in seen:
            raise ParseError("--criteria contains duplicate ids")
        seen.add(crit)
    return parts


def _detect_format(data: Any) -> str:
    if isinstance(data, dict):
        if isinstance(data.get("criteria"), list):
            return "v3"
        if "criterion_id" in data and ("status" in data or "verify_sh" in data):
            return "v3"
        if "criterion_id" in data and "answer" in data:
            return "v1"

    if isinstance(data, list):
        if all(
            isinstance(item, list)
            and len(item) == 2
            and isinstance(item[0], str)
            and isinstance(item[1], str)
            for item in data
        ):
            return "v1"
        if all(isinstance(item, dict) for item in data):
            has_v3 = any(
                "status" in item or "verify_sh" in item or "criteria" in item
                for item in data
            )
            has_v1 = any("answer" in item and "reason" in item for item in data)
            if has_v3 and not has_v1:
                return "v3"
            if has_v1 and not has_v3:
                return "v1"
            if has_v3 and has_v1:
                return "v3"
    raise ParseError(
        "unable to auto-detect input format; pass --format v1 or --format v3"
    )


def _criteria_list_to_dict(
    criteria_items: list[dict[str, str]],
    expected_criteria: list[str],
) -> tuple[dict[str, dict[str, str]], list[str]]:
    by_id: dict[str, dict[str, str]] = {}
    for item in criteria_items:
        crit = item["criterion_id"]
        if crit in by_id:
            raise ParseError(f"duplicate criterion_id '{crit}'")
        by_id[crit] = {"answer": item["answer"], "reason": item["reason"]}

    if expected_criteria:
        for crit in by_id:
            if crit not in expected_criteria:
                raise ParseError(
                    f"unexpected criterion_id '{crit}' (not in --criteria)"
                )
        ordered: dict[str, dict[str, str]] = {}
        missing: list[str] = []
        for crit in expected_criteria:
            if crit in by_id:
                ordered[crit] = by_id[crit]
            else:
                ordered[crit] = {
                    "answer": "NEEDS_HUMAN",
                    "reason": "missing criterion response",
                }
                missing.append(crit)
        return ordered, missing

    return by_id, []


def _finalize(
    criteria_out: dict[str, dict[str, str]],
    missing: list[str],
    force_fail: bool = False,
    force_needs_human: bool = False,
    total_override: int | None = None,
) -> dict[str, Any]:
    passed = 0
    failed = 0
    needs_human = 0
    for item in criteria_out.values():
        answer = item["answer"]
        if answer == "YES":
            passed += 1
        elif answer == "NO":
            failed += 1
        else:
            needs_human += 1

    if force_needs_human or needs_human > 0:
        verdict = "NEEDS_HUMAN"
    elif force_fail or failed > 0:
        verdict = "FAIL"
    else:
        verdict = "PASS"

    total = total_override if total_override is not None else len(criteria_out)
    return {
        "verdict": verdict,
        "criteria": criteria_out,
        "missing": missing,
        "total": total,
        "passed": passed,
        "failed": failed,
    }


def _normalize_v1_items(
    data: Any,
    expected_criteria: list[str],
    nonce: str | None,
) -> tuple[dict[str, dict[str, str]], list[str]]:
    items: list[dict[str, str]] = []

    if isinstance(data, dict):
        data = [data]

    if not isinstance(data, list):
        raise ParseError(
            "v1 input must be either [criterion_id, raw_response] pairs "
            "or parsed verdict objects"
        )

    is_pairs = all(
        isinstance(item, list)
        and len(item) == 2
        and isinstance(item[0], str)
        and isinstance(item[1], str)
        for item in data
    )

    if is_pairs:
        responses: dict[str, str] = {}
        for item in data:
            crit_id, raw_response = item
            _validate_criterion_id(crit_id)
            if crit_id in responses:
                raise ParseError(f"duplicate criterion_id '{crit_id}'")
            responses[crit_id] = raw_response

        order = expected_criteria if expected_criteria else list(responses.keys())
        for crit in order:
            if crit not in responses:
                items.append(
                    {
                        "criterion_id": crit,
                        "answer": "NEEDS_HUMAN",
                        "reason": "missing criterion response",
                    }
                )
                continue
            try:
                parsed = _parse_v1_block(
                    responses[crit],
                    expected_id=crit,
                    expected_nonce=nonce,
                )
                items.append(
                    {
                        "criterion_id": crit,
                        "answer": parsed["answer"],
                        "reason": parsed["reason"],
                    }
                )
            except ParseError as exc:
                items.append(
                    {
                        "criterion_id": crit,
                        "answer": "NEEDS_HUMAN",
                        "reason": str(exc),
                    }
                )
        return _criteria_list_to_dict(items, expected_criteria)

    for item in data:
        if not isinstance(item, dict):
            raise ParseError("v1 input items must be objects")
        crit_id = item.get("criterion_id")
        answer = item.get("answer")
        reason = item.get("reason")
        if not isinstance(crit_id, str):
            raise ParseError("v1 object missing string 'criterion_id'")
        _validate_criterion_id(crit_id)
        if not isinstance(answer, str):
            items.append(
                {
                    "criterion_id": crit_id,
                    "answer": "NEEDS_HUMAN",
                    "reason": "v1 object missing string 'answer'",
                }
            )
            continue
        if not isinstance(reason, str) or reason == "":
            items.append(
                {
                    "criterion_id": crit_id,
                    "answer": "NEEDS_HUMAN",
                    "reason": "v1 object missing string 'reason'",
                }
            )
            continue
        try:
            normalized = _normalize_answer(answer)
            if normalized == "NEEDS_HUMAN":
                items.append(
                    {"criterion_id": crit_id, "answer": normalized, "reason": reason}
                )
            else:
                items.append(
                    {"criterion_id": crit_id, "answer": normalized, "reason": reason}
                )
        except ParseError as exc:
            items.append(
                {
                    "criterion_id": crit_id,
                    "answer": "NEEDS_HUMAN",
                    "reason": str(exc),
                }
            )

    return _criteria_list_to_dict(items, expected_criteria)


def _normalize_v3_criterion(item: dict[str, Any]) -> dict[str, str]:
    crit_id = item.get("criterion_id")
    if not isinstance(crit_id, str):
        raise ParseError("v3 criterion missing string 'criterion_id'")
    _validate_criterion_id(crit_id)

    status = item.get("status")
    verify_sh = item.get("verify_sh")
    evidence = item.get("evidence")

    if isinstance(verify_sh, str):
        verify_sh = verify_sh.strip().upper()
        if verify_sh not in VALID_STATUS:
            return {
                "criterion_id": crit_id,
                "answer": "NEEDS_HUMAN",
                "reason": f"invalid verify_sh '{verify_sh}'",
            }
    else:
        verify_sh = None

    if not isinstance(status, str):
        return {
            "criterion_id": crit_id,
            "answer": "NEEDS_HUMAN",
            "reason": "v3 criterion missing string 'status'",
        }
    status = status.strip().upper()
    if status not in VALID_STATUS:
        return {
            "criterion_id": crit_id,
            "answer": "NEEDS_HUMAN",
            "reason": f"invalid status '{status}'",
        }

    if not isinstance(evidence, str) or evidence.strip() == "":
        return {
            "criterion_id": crit_id,
            "answer": "NEEDS_HUMAN",
            "reason": "v3 criterion missing string 'evidence'",
        }

    if verify_sh == "FAIL":
        return {
            "criterion_id": crit_id,
            "answer": "NO",
            "reason": f"verify_sh=FAIL: {evidence.strip()}",
        }

    return {
        "criterion_id": crit_id,
        "answer": "YES" if status == "PASS" else "NO",
        "reason": evidence.strip(),
    }


def _normalize_v3_items(
    data: Any,
    expected_criteria: list[str],
) -> tuple[dict[str, dict[str, str]], list[str], bool, bool]:
    force_fail = False
    force_needs_human = False

    # Aggregate VERDICT object (or parse-blocks output for VERDICT).
    if isinstance(data, dict) and isinstance(data.get("criteria"), list):
        criteria_raw = data.get("criteria")
        verify_sh = data.get("verify_sh")
        decision = data.get("decision")

        items: list[dict[str, str]] = []
        for idx, crit in enumerate(criteria_raw, start=1):
            if not isinstance(crit, dict):
                items.append(
                    {
                        "criterion_id": f"UNKNOWN-{idx}",
                        "answer": "NEEDS_HUMAN",
                        "reason": "criteria item must be object",
                    }
                )
                continue
            # Aggregate VERDICT criteria use "id", normalize to criterion_id.
            crit_copy = dict(crit)
            if "criterion_id" not in crit_copy and isinstance(crit_copy.get("id"), str):
                crit_copy["criterion_id"] = crit_copy["id"]
            try:
                normalized = _normalize_v3_criterion(crit_copy)
            except ParseError as exc:
                force_needs_human = True
                crit_id = crit_copy.get("criterion_id") or crit_copy.get("id")
                if not isinstance(crit_id, str):
                    crit_id = f"UNKNOWN-{idx}"
                items.append(
                    {
                        "criterion_id": crit_id,
                        "answer": "NEEDS_HUMAN",
                        "reason": str(exc),
                    }
                )
                continue
            items.append(normalized)

        criteria_out, missing = _criteria_list_to_dict(items, expected_criteria)

        if isinstance(verify_sh, str):
            upper = verify_sh.strip().upper()
            if upper == "FAIL":
                force_fail = True
            elif upper != "PASS":
                force_needs_human = True

        if isinstance(decision, str):
            upper = decision.strip().upper()
            if upper == "FAIL":
                force_fail = True
            elif upper == "PASS":
                pass
            else:
                force_needs_human = True
        elif decision is not None:
            force_needs_human = True

        return criteria_out, missing, force_fail, force_needs_human

    # Single criterion object from parse-blocks output.
    if isinstance(data, dict):
        data = [data]

    if not isinstance(data, list):
        raise ParseError("v3 input must be an object or array")

    items: list[dict[str, str]] = []
    for item in data:
        if not isinstance(item, dict):
            raise ParseError("v3 input items must be objects")
        normalized = _normalize_v3_criterion(item)
        items.append(normalized)

    criteria_out, missing = _criteria_list_to_dict(items, expected_criteria)
    return criteria_out, missing, force_fail, force_needs_human


def build_verdict(
    criteria_input: Any,
    nonce: str | None = None,
    expected_criteria: list[str] | None = None,
    fmt: str = "auto",
) -> dict[str, Any]:
    """Build verdict output for v1 and v3 criterion inputs."""
    if fmt not in VALID_FORMATS:
        raise ValueError("fmt must be one of: v1, v3, auto")

    if nonce is not None and not RE_NONCE.match(nonce):
        raise ValueError(
            f"invalid nonce format: '{nonce}' (must match ^[0-9A-F]{{6}}$)"
        )

    expected = expected_criteria or []
    if len(set(expected)) != len(expected):
        raise ParseError("duplicate expected criteria")
    for crit in expected:
        _validate_criterion_id(crit)

    detected = _detect_format(criteria_input) if fmt == "auto" else fmt
    if detected == "v1":
        criteria_out, missing = _normalize_v1_items(criteria_input, expected, nonce)
        total = len(expected) if expected else len(criteria_out)
        return _finalize(
            criteria_out=criteria_out,
            missing=missing,
            total_override=total,
        )

    criteria_out, missing, force_fail, force_needs_human = _normalize_v3_items(
        criteria_input,
        expected,
    )
    total = len(expected) if expected else len(criteria_out)
    return _finalize(
        criteria_out=criteria_out,
        missing=missing,
        force_fail=force_fail,
        force_needs_human=force_needs_human,
        total_override=total,
    )


def _build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Build verdict JSON from criterion responses"
    )
    parser.add_argument(
        "--nonce",
        help="Expected 6-char uppercase hex nonce (v1 only, optional)",
    )
    parser.add_argument(
        "--criteria",
        default="",
        help="Comma-separated expected criterion IDs (optional)",
    )
    parser.add_argument(
        "--format",
        choices=("v1", "v3", "auto"),
        default="auto",
        help="Input format (default: auto)",
    )
    return parser


def main() -> None:
    args = _build_arg_parser().parse_args()

    try:
        expected_criteria = _parse_expected_criteria(args.criteria)
    except ParseError as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)

    if args.nonce is not None and not RE_NONCE.match(args.nonce):
        print(
            f"error: invalid --nonce format '{args.nonce}' "
            f"(must match ^[0-9A-F]{{6}}$)",
            file=sys.stderr,
        )
        sys.exit(1)

    raw_text = sys.stdin.read()
    try:
        criteria_input = json.loads(raw_text)
    except json.JSONDecodeError as exc:
        print(f"error: invalid JSON input: {exc}", file=sys.stderr)
        sys.exit(1)

    try:
        result = build_verdict(
            criteria_input=criteria_input,
            nonce=args.nonce,
            expected_criteria=expected_criteria,
            fmt=args.format,
        )
    except (ParseError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)

    json.dump(result, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()

