#!/usr/bin/env python3
"""Unified sentinel parser for deadfish v3 fences with v1 compatibility.

Primary mode:
- Detects fenced blocks: ```deadfish:TYPE ... ```
- Parses payload via JSON first, then YAML fallback.
- Validates against contracts/sentinel/v3/schemas.yaml.

Compatibility mode:
- Detects v1 sentinels (<<<TYPE:V1:NONCE=...>>>) when --format=v1|auto.
- Delegates full parsing to parse-blocks-v1-legacy.py.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

V3_OPENER_RE = re.compile(r"^```deadfish:(\w+)\s*$")
V3_CLOSER_RE = re.compile(r"^```\s*$")

V1_OPENER_RE = re.compile(
    r"^<<<(?P<type>[A-Z_]+):V1(?::(?P<variant>[^:>]+))?:NONCE=(?P<nonce>[0-9A-F]{6})>>>\s*$"
)
V1_CLOSER_RE = re.compile(
    r"^<<<END_(?P<type>[A-Z_]+)(?::(?P<variant>[^:>]+))?:NONCE=(?P<nonce>[0-9A-F]{6})>>>\s*$"
)

FATAL_PYYAML = "FATAL: PyYAML required. Install: pip install pyyaml"


class ParseError(Exception):
    """Raised for parsing and validation failures."""


def validate_path(path: str) -> None:
    """Validate a safe relative path for files[] entries."""
    if not isinstance(path, str):
        raise ParseError("path must be a string")
    if path.startswith("/"):
        raise ParseError(f"absolute path not allowed: '{path}'")
    if any(part == ".." for part in path.split("/")):
        raise ParseError(f"path traversal not allowed: '{path}'")
    if not re.match(r"^[a-zA-Z0-9_./-]+$", path):
        raise ParseError(f"invalid path characters: '{path}'")


@dataclass
class V3Block:
    block_type: str
    payload: str
    start_line: int
    end_line: int


@dataclass
class V1Block:
    block_type: str
    nonce: str
    variant: str | None
    full_text: str
    start_line: int
    end_line: int


def _require_yaml_module() -> Any:
    try:
        import yaml  # type: ignore
    except ImportError as exc:
        raise ParseError(FATAL_PYYAML) from exc
    return yaml


def _load_data_json_then_yaml(raw: str, context: str) -> Any:
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        pass

    yaml = _require_yaml_module()
    try:
        return yaml.safe_load(raw)
    except Exception as exc:
        raise ParseError(f"invalid {context}: {exc}") from exc


def extract_v3_blocks(raw_text: str) -> list[V3Block]:
    blocks: list[V3Block] = []
    lines = raw_text.splitlines()

    active_type: str | None = None
    active_start: int | None = None
    payload_lines: list[str] = []

    for idx, line in enumerate(lines, start=1):
        if active_type is None:
            m_open = V3_OPENER_RE.match(line)
            if m_open:
                active_type = m_open.group(1).upper()
                active_start = idx
                payload_lines = []
            continue

        if V3_CLOSER_RE.match(line):
            assert active_start is not None
            blocks.append(
                V3Block(
                    block_type=active_type,
                    payload="\n".join(payload_lines),
                    start_line=active_start,
                    end_line=idx,
                )
            )
            active_type = None
            active_start = None
            payload_lines = []
            continue

        payload_lines.append(line)

    if active_type is not None:
        raise ParseError(f"unclosed v3 fence for type '{active_type}' (opened at line {active_start})")

    return blocks


def extract_v1_blocks(raw_text: str) -> list[V1Block]:
    blocks: list[V1Block] = []
    lines = raw_text.splitlines()

    opener_line: str | None = None
    opener_match: re.Match[str] | None = None
    opener_idx: int | None = None
    payload_lines: list[str] = []

    for idx, line in enumerate(lines, start=1):
        if opener_match is None:
            m_open = V1_OPENER_RE.match(line)
            if m_open:
                opener_match = m_open
                opener_line = line
                opener_idx = idx
                payload_lines = []
            continue

        m_close = V1_CLOSER_RE.match(line)
        if m_close:
            open_type = opener_match.group("type")
            close_type = m_close.group("type")
            open_variant = opener_match.group("variant")
            close_variant = m_close.group("variant")
            open_nonce = opener_match.group("nonce")
            close_nonce = m_close.group("nonce")

            if open_type != close_type:
                raise ParseError(
                    f"v1 opener/closer type mismatch at lines {opener_idx}/{idx}: "
                    f"{open_type} vs {close_type}"
                )
            if (open_variant or "") != (close_variant or ""):
                raise ParseError(
                    f"v1 opener/closer variant mismatch at lines {opener_idx}/{idx}: "
                    f"{open_variant} vs {close_variant}"
                )
            if open_nonce != close_nonce:
                raise ParseError(
                    f"v1 opener/closer nonce mismatch at lines {opener_idx}/{idx}: "
                    f"{open_nonce} vs {close_nonce}"
                )

            assert opener_line is not None
            assert opener_idx is not None
            block_lines = [opener_line, *payload_lines, line]
            blocks.append(
                V1Block(
                    block_type=open_type,
                    nonce=open_nonce,
                    variant=open_variant,
                    full_text="\n".join(block_lines) + "\n",
                    start_line=opener_idx,
                    end_line=idx,
                )
            )
            opener_line = None
            opener_match = None
            opener_idx = None
            payload_lines = []
            continue

        payload_lines.append(line)

    if opener_match is not None:
        raise ParseError(
            f"unclosed v1 sentinel for type '{opener_match.group('type')}' "
            f"(opened at line {opener_idx})"
        )

    return blocks


def parse_v3_payload(payload: str) -> dict[str, Any]:
    parsed = _load_data_json_then_yaml(payload, "v3 payload")
    if parsed is None:
        raise ParseError("v3 payload is empty")
    if not isinstance(parsed, dict):
        raise ParseError("v3 payload must be a mapping/object")
    return parsed


def _normalize_field_specs(values: Any) -> tuple[list[str], dict[str, str]]:
    required: list[str] = []
    type_map: dict[str, str] = {}
    if not isinstance(values, list):
        return required, type_map

    for item in values:
        if isinstance(item, str):
            required.append(item)
            continue
        if isinstance(item, dict):
            for key, value in item.items():
                required.append(str(key))
                if isinstance(value, str):
                    type_map[str(key)] = value
                elif isinstance(value, dict):
                    maybe_type = value.get("type")
                    if isinstance(maybe_type, str):
                        type_map[str(key)] = maybe_type
    return required, type_map


def _coerce_dict_string_keys(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        return {}
    return {str(k): v for k, v in value.items()}


def _extract_keyed_validators(schema: dict[str, Any]) -> tuple[dict[str, str], dict[str, list[Any]]]:
    regex_map: dict[str, str] = {}
    enum_map: dict[str, list[Any]] = {}

    regex_direct = _coerce_dict_string_keys(schema.get("regex"))
    enum_direct = _coerce_dict_string_keys(schema.get("enum"))
    for key, pattern in regex_direct.items():
        if isinstance(pattern, str):
            regex_map[key] = pattern
    for key, values in enum_direct.items():
        if isinstance(values, list):
            enum_map[key] = values

    validators = _coerce_dict_string_keys(schema.get("validators"))
    for key, rule in validators.items():
        if not isinstance(rule, dict):
            continue
        if isinstance(rule.get("regex"), str):
            regex_map[key] = rule["regex"]
        if isinstance(rule.get("enum"), list):
            enum_map[key] = rule["enum"]

    fields = _coerce_dict_string_keys(schema.get("fields"))
    for key, rule in fields.items():
        if not isinstance(rule, dict):
            continue
        if isinstance(rule.get("regex"), str):
            regex_map[key] = rule["regex"]
        if isinstance(rule.get("enum"), list):
            enum_map[key] = rule["enum"]

    return regex_map, enum_map


def _extract_list_schemas(type_schema: dict[str, Any]) -> dict[str, dict[str, Any]]:
    list_schemas: dict[str, dict[str, Any]] = {}

    lists = _coerce_dict_string_keys(type_schema.get("lists"))
    for key, value in lists.items():
        if isinstance(value, dict):
            list_schemas[key] = _coerce_dict_string_keys(value)

    for key, value in type_schema.items():
        if not isinstance(value, dict):
            continue
        if key.endswith("[]"):
            list_schemas[key[:-2]] = _coerce_dict_string_keys(value)
        elif key.endswith("_item"):
            list_schemas[key[:-5]] = _coerce_dict_string_keys(value)

    return list_schemas


def _validate_type(field: str, expected: str, value: Any) -> None:
    expected_options = [part.strip() for part in expected.split("|") if part.strip()]
    if not expected_options:
        expected_options = [expected]

    def _is_valid_single(expected_type: str) -> bool:
        if expected_type == "string":
            return isinstance(value, str)
        if expected_type == "int":
            return isinstance(value, int)
        if expected_type == "number":
            return isinstance(value, (int, float))
        if expected_type == "bool":
            return isinstance(value, bool)
        if expected_type == "list":
            return isinstance(value, list)
        if expected_type in ("dict", "object", "map"):
            return isinstance(value, dict)
        return True

    if any(_is_valid_single(option) for option in expected_options):
        return

    if len(expected_options) == 1:
        normalized = expected_options[0]
        if normalized in ("dict", "map"):
            normalized = "object"
        raise ParseError(f"field '{field}' must be {normalized}")

    normalized_options = ["object" if item in ("dict", "map") else item for item in expected_options]
    raise ParseError(
        f"field '{field}' must be one of types [{', '.join(normalized_options)}]"
    )


def _validate_scalar_rules(prefix: str, payload: dict[str, Any], regex_map: dict[str, str], enum_map: dict[str, list[Any]]) -> None:
    for key, pattern in regex_map.items():
        if key not in payload:
            continue
        value = payload[key]
        if not isinstance(value, str):
            raise ParseError(f"field '{prefix}{key}' must be string for regex validation")
        if re.fullmatch(pattern, value) is None:
            raise ParseError(
                f"field '{prefix}{key}' does not match regex '{pattern}': '{value}'"
            )

    for key, options in enum_map.items():
        if key not in payload:
            continue
        value = payload[key]
        if value not in options:
            raise ParseError(
                f"field '{prefix}{key}' must be one of {options}; got '{value}'"
            )


def _validate_files_paths(payload: dict[str, Any]) -> None:
    files = payload.get("files")
    if isinstance(files, list):
        for idx, item in enumerate(files, start=1):
            if not isinstance(item, dict):
                continue
            if "path" in item:
                try:
                    validate_path(item["path"])
                except ParseError as exc:
                    raise ParseError(f"files[{idx}].{exc}") from exc

    changed_files = payload.get("changed_files")
    if isinstance(changed_files, list):
        for idx, item in enumerate(changed_files, start=1):
            if not isinstance(item, dict):
                continue
            if "path" in item:
                try:
                    validate_path(item["path"])
                except ParseError as exc:
                    raise ParseError(f"changed_files[{idx}].{exc}") from exc


def _validate_list_items(field: str, value: Any, list_schema: dict[str, Any]) -> None:
    if not isinstance(value, list):
        raise ParseError(f"field '{field}' must be list")

    req_keys, req_types = _normalize_field_specs(list_schema.get("required"))
    _, opt_types = _normalize_field_specs(list_schema.get("optional"))
    type_map = {**req_types, **opt_types, **_coerce_dict_string_keys(list_schema.get("types"))}
    item_regex, item_enum = _extract_keyed_validators(list_schema)

    for idx, item in enumerate(value, start=1):
        if not isinstance(item, dict):
            raise ParseError(f"field '{field}[{idx}]' must be object")

        for key in req_keys:
            if key not in item:
                raise ParseError(f"missing required key '{field}[{idx}].{key}'")

        for key, expected in type_map.items():
            if key in item and isinstance(expected, str):
                _validate_type(f"{field}[{idx}].{key}", expected, item[key])

        _validate_scalar_rules(f"{field}[{idx}].", item, item_regex, item_enum)

        if "path" in item:
            try:
                validate_path(item["path"])
            except ParseError as exc:
                raise ParseError(f"{field}[{idx}].{exc}") from exc


def load_schemas() -> dict[str, Any]:
    schema_path = Path(__file__).resolve().parent.parent / "contracts" / "sentinel" / "v3" / "schemas.yaml"
    if not schema_path.exists():
        raise ParseError(f"schema file not found: {schema_path}")

    try:
        raw = schema_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise ParseError(f"failed reading schema file '{schema_path}': {exc}") from exc

    parsed = _load_data_json_then_yaml(raw, f"schema file '{schema_path}'")
    if not isinstance(parsed, dict):
        raise ParseError(f"schema file '{schema_path}' must parse to a mapping")

    return {str(k): v for k, v in parsed.items()}


def validate_against_schema(payload: dict[str, Any], block_type: str, schemas: dict[str, Any]) -> None:
    if block_type not in schemas:
        raise ParseError(f"schema type not found: {block_type}")

    raw_type_schema = schemas[block_type]
    if not isinstance(raw_type_schema, dict):
        raise ParseError(f"schema for {block_type} must be a mapping")
    type_schema = _coerce_dict_string_keys(raw_type_schema)

    required_keys, required_types = _normalize_field_specs(type_schema.get("required"))
    _, optional_types = _normalize_field_specs(type_schema.get("optional"))

    type_map = {**required_types, **optional_types}
    type_map.update(_coerce_dict_string_keys(type_schema.get("types")))

    for key in required_keys:
        if key not in payload:
            raise ParseError(f"missing required key '{key}'")

    for key, expected in type_map.items():
        if key in payload and isinstance(expected, str):
            _validate_type(key, expected, payload[key])

    regex_map, enum_map = _extract_keyed_validators(type_schema)
    _validate_scalar_rules("", payload, regex_map, enum_map)

    list_schemas = _extract_list_schemas(type_schema)
    for list_field, list_schema in list_schemas.items():
        if list_field in payload and isinstance(payload[list_field], list):
            _validate_list_items(list_field, payload[list_field], list_schema)

    _validate_files_paths(payload)


def _legacy_command_for_type(block_type: str) -> str:
    mapping = {
        "PLAN": "plan",
        "TRACK": "track",
        "SPEC": "spec",
        "VERDICT": "verdict",
        "REFLECT": "reflect",
        "QA_REVIEW": "qa-review",
    }
    if block_type not in mapping:
        raise ParseError(f"v1 format not supported for type '{block_type}'")
    return mapping[block_type]


def parse_v1_block_with_legacy(block: V1Block) -> dict[str, Any]:
    legacy_script = Path(__file__).resolve().parent / "parse-blocks-v1-legacy.py"
    if not legacy_script.exists():
        raise ParseError(f"legacy parser not found: {legacy_script}")

    command = _legacy_command_for_type(block.block_type)
    cmd = [sys.executable, str(legacy_script), command, "--nonce", block.nonce]
    if block.block_type == "VERDICT":
        if not block.variant:
            raise ParseError("v1 VERDICT block missing criterion id")
        cmd.extend(["--criterion", block.variant])

    proc = subprocess.run(
        cmd,
        input=block.full_text,
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout).strip()
        if not detail:
            detail = f"legacy parser exited with code {proc.returncode}"
        raise ParseError(detail)

    try:
        parsed = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise ParseError(f"legacy parser emitted invalid JSON: {exc}") from exc

    if not isinstance(parsed, dict):
        raise ParseError("legacy parser output must be a JSON object")
    return parsed


def _select_blocks_or_error(blocks: list[Any], block_type: str, allow_multi: bool) -> list[Any]:
    if len(blocks) == 0:
        raise ParseError(f"no '{block_type}' block found")
    if len(blocks) > 1 and not allow_multi:
        raise ParseError(
            f"found {len(blocks)} '{block_type}' blocks; pass --allow-multi to accept multiple"
        )
    return blocks


def parse_with_v3(raw_text: str, block_type: str, allow_multi: bool) -> Any:
    blocks = [b for b in extract_v3_blocks(raw_text) if b.block_type == block_type]
    selected = _select_blocks_or_error(blocks, block_type, allow_multi)

    schemas = load_schemas()
    parsed_items: list[dict[str, Any]] = []
    for block in selected:
        payload = parse_v3_payload(block.payload)
        validate_against_schema(payload, block_type, schemas)
        parsed_items.append(payload)

    return parsed_items if allow_multi else parsed_items[0]


def parse_with_v1(raw_text: str, block_type: str, allow_multi: bool) -> Any:
    blocks = [b for b in extract_v1_blocks(raw_text) if b.block_type == block_type]
    selected = _select_blocks_or_error(blocks, block_type, allow_multi)

    parsed_items = [parse_v1_block_with_legacy(block) for block in selected]
    return parsed_items if allow_multi else parsed_items[0]


def detect_format(raw_text: str, block_type: str) -> str:
    lines = raw_text.splitlines()
    has_v3 = any(V3_OPENER_RE.match(line) for line in lines)
    has_v1 = any(V1_OPENER_RE.match(line) for line in lines)

    if has_v3 and not has_v1:
        return "v3"
    if has_v1 and not has_v3:
        return "v1"
    if not has_v1 and not has_v3:
        raise ParseError("no sentinel blocks found (expected v1 or v3 format)")

    v3_blocks = [b for b in extract_v3_blocks(raw_text) if b.block_type == block_type]
    if v3_blocks:
        return "v3"

    v1_blocks = [b for b in extract_v1_blocks(raw_text) if b.block_type == block_type]
    if v1_blocks:
        return "v1"

    # Both formats are present but none of the requested type were found.
    return "v3"


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Extract deadfish sentinel blocks from stdin and emit JSON"
    )
    parser.add_argument("--type", required=True, help="Expected block type (e.g. PLAN)")
    parser.add_argument(
        "--stdin",
        action="store_true",
        help="Read input from stdin (kept for CLI compatibility)",
    )
    parser.add_argument(
        "--format",
        choices=("v1", "v3", "auto"),
        default="auto",
        help="Sentinel format to parse (default: auto)",
    )
    parser.add_argument(
        "--allow-multi",
        action="store_true",
        help="Allow multiple blocks of the requested type",
    )
    return parser


def main() -> None:
    args = build_arg_parser().parse_args()
    expected_type = str(args.type).strip().upper()
    if not expected_type:
        print("error: --type cannot be empty", file=sys.stderr)
        sys.exit(1)

    raw_text = sys.stdin.read()

    try:
        fmt = args.format
        if fmt == "auto":
            fmt = detect_format(raw_text, expected_type)

        if fmt == "v3":
            parsed = parse_with_v3(raw_text, expected_type, args.allow_multi)
        else:
            parsed = parse_with_v1(raw_text, expected_type, args.allow_multi)
    except ParseError as exc:
        message = str(exc)
        if message == FATAL_PYYAML:
            print(message, file=sys.stderr)
        else:
            print(f"error: {message}", file=sys.stderr)
        sys.exit(1)

    json.dump(parsed, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
