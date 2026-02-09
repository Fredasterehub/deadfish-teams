#!/usr/bin/env python3
"""Template ↔ contract drift checker for deadfish v3 repo layout.

Validates that sentinel references inside active templates resolve to contract docs.
- Active templates: templates/** (excluding templates/legacy/**)
- Contracts: contracts/sentinel/{v3,legacy}/
- Sentinel formats supported:
  - v1: <<<TYPE:V1:...>>>
  - v3: ```deadfish:TYPE
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

V1_REF_RE = re.compile(r"<<<([A-Z0-9_]+):V(\d+)(?::[^>]*)?>>>\s*")
V3_REF_RE = re.compile(r"^[ \t]*```deadfish:([A-Z0-9_]+)[ \t]*$", re.MULTILINE)
ANY_MARKER_RE = re.compile(r"```deadfish:|<<<")

# v3 docs mostly follow lower-hyphen naming. Keep explicit overrides for exceptions.
V3_DOC_OVERRIDES = {
    "VERDICT_CRITERION": "verdict-criterion",
}


def relpath(path: Path, base: Path) -> str:
    try:
        return str(path.relative_to(base))
    except ValueError:
        return str(path)


def is_under(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def extract_sentinel_refs(text: str) -> list[tuple[str, str]]:
    refs: list[tuple[str, str]] = []

    for match in V1_REF_RE.finditer(text):
        block_type = match.group(1).upper()
        if block_type.startswith("END_"):
            continue
        refs.append((block_type, match.group(2)))

    for match in V3_REF_RE.finditer(text):
        refs.append((match.group(1).upper(), "3"))

    return refs


def type_to_contract(block_type: str, version: str, contracts_dir: Path) -> Path:
    if version == "3":
        slug = V3_DOC_OVERRIDES.get(block_type, block_type.lower().replace("_", "-"))
        return contracts_dir / "v3" / f"{slug}.v3.md"
    if version == "1":
        slug = block_type.lower().replace("_", "-")
        return contracts_dir / "legacy" / f"{slug}.v1.md"

    slug = block_type.lower().replace("_", "-")
    return contracts_dir / f"{slug}.v{version}.md"


def load_v3_schema_types(schema_path: Path) -> set[str]:
    if not schema_path.exists():
        return set()

    try:
        import yaml  # type: ignore

        parsed = yaml.safe_load(schema_path.read_text(encoding="utf-8"))
        if isinstance(parsed, dict):
            return {str(k).upper() for k in parsed.keys()}
    except Exception:
        pass

    # Fallback: top-level YAML keys in UPPER_CASE.
    types: set[str] = set()
    for line in schema_path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^([A-Z][A-Z0-9_]+):\s*$", line)
        if m:
            types.add(m.group(1).upper())
    return types


def main() -> int:
    parser = argparse.ArgumentParser(description="Template ↔ contract drift checker (v3 layout)")
    parser.add_argument("--verbose", action="store_true", help="show OK lines")
    args = parser.parse_args()

    repo_root = Path.cwd()
    templates_dir = repo_root / "templates"
    legacy_templates_dir = templates_dir / "legacy"
    contracts_dir = repo_root / "contracts" / "sentinel"
    v3_schema_path = contracts_dir / "v3" / "schemas.yaml"

    if not templates_dir.exists():
        print(f"[FAIL] templates directory missing: {templates_dir}")
        return 1
    if not contracts_dir.exists():
        print(f"[FAIL] contracts directory missing: {contracts_dir}")
        return 1

    v3_schema_types = load_v3_schema_types(v3_schema_path)
    if not v3_schema_types:
        print(f"[WARN] could not load v3 schema types from {relpath(v3_schema_path, repo_root)}")

    failing = False
    warnings = 0
    referenced_contracts: set[Path] = set()
    scanned_files = 0

    active_templates = sorted(
        p for p in templates_dir.rglob("*") if p.is_file() and not is_under(p, legacy_templates_dir)
    )

    if args.verbose:
        print(
            f"[INFO] scanning {len(active_templates)} active template files under "
            f"{relpath(templates_dir, repo_root)} (skipping {relpath(legacy_templates_dir, repo_root)})"
        )

    for template in active_templates:
        scanned_files += 1
        text = template.read_text(encoding="utf-8")
        refs = sorted(set(extract_sentinel_refs(text)))

        for block_type, version in refs:
            contract_path = type_to_contract(block_type, version, contracts_dir)

            if version == "3" and v3_schema_types and block_type not in v3_schema_types:
                failing = True
                print(
                    f"[FAIL] Template {relpath(template, templates_dir)} references "
                    f"deadfish:{block_type} but type is missing from "
                    f"{relpath(v3_schema_path, repo_root)}"
                )
                continue

            if contract_path.exists():
                referenced_contracts.add(contract_path)
                if args.verbose:
                    print(
                        f"[OK] Template {relpath(template, templates_dir)} -> "
                        f"{relpath(contract_path, contracts_dir)}"
                    )
            else:
                failing = True
                print(
                    f"[FAIL] Template {relpath(template, templates_dir)} references "
                    f"{block_type} v{version} but contract missing: "
                    f"{relpath(contract_path, repo_root)}"
                )

        if not refs and ANY_MARKER_RE.search(text):
            warnings += 1
            print(
                f"[WARN] Template {relpath(template, templates_dir)} contains marker text "
                "but no recognizable sentinel opener"
            )

    # Informational orphan report (does not fail lint).
    contract_docs = sorted((contracts_dir / "v3").glob("*.md")) + sorted(
        (contracts_dir / "legacy").glob("*.md")
    )
    orphan_count = 0
    for contract in contract_docs:
        if contract not in referenced_contracts:
            orphan_count += 1
            if args.verbose:
                print(
                    f"[WARN] Orphaned contract (unreferenced by active templates): "
                    f"{relpath(contract, contracts_dir)}"
                )

    print(
        f"[OK] scanned={scanned_files} active templates, "
        f"refs={len(referenced_contracts)} contracts, warnings={warnings}, "
        f"orphans={orphan_count}, fail={str(failing).lower()}"
    )
    return 1 if failing else 0


if __name__ == "__main__":
    sys.exit(main())
