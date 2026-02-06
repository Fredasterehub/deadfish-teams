#!/usr/bin/env python3
import argparse
import re
import sys
from pathlib import Path


def parse_manifest_paths(manifest_path: Path) -> list[Path]:
    if not manifest_path.exists():
        raise FileNotFoundError(f"manifest missing: {manifest_path}")
    paths = []
    path_re = re.compile(r"^\s*-\s+path:\s*(.+?)\s*$")
    for line in manifest_path.read_text(encoding="utf-8").splitlines():
        m = path_re.match(line)
        if m:
            paths.append(Path(m.group(1)))
    return paths


def extract_sentinel_refs(text: str) -> list[tuple[str, str]]:
    # Match openers like <<<TRACK:V1:NONCE=...>>>
    # Ignore END_ blocks.
    refs = []
    for m in re.finditer(r"<<<([A-Z0-9_]+):V(\d+):", text):
        block_type = m.group(1)
        if block_type.startswith("END_"):
            continue
        version = m.group(2)
        refs.append((block_type, version))
    return refs


def type_to_grammar(block_type: str, version: str) -> str:
    name = block_type.lower().replace("_", "-")
    return f"{name}.v{version}.md"


def relpath(path: Path, base: Path) -> str:
    try:
        return str(path.relative_to(base))
    except ValueError:
        return str(path)


def main() -> int:
    parser = argparse.ArgumentParser(description="Template ↔ contract drift checker")
    parser.add_argument("--verbose", action="store_true", help="show OK lines")
    args = parser.parse_args()

    repo_root = Path.cwd()
    deadf = repo_root / ".deadf"
    manifest_path = deadf / "manifest.yaml"
    templates_dir = deadf / "templates"
    sentinel_dir = deadf / "contracts" / "sentinel"

    drift = False

    # 1) Manifest verification
    try:
        manifest_paths = parse_manifest_paths(manifest_path)
    except FileNotFoundError as e:
        print(f"[FAIL] {e}")
        return 1

    missing_manifest = [p for p in manifest_paths if not (repo_root / p).exists()]
    if missing_manifest:
        drift = True
        print(f"[FAIL] Missing {len(missing_manifest)} manifest files:")
        for p in missing_manifest:
            print(f"  - {p}")
    else:
        if args.verbose:
            print(f"[OK] All {len(manifest_paths)} manifest files present")
        else:
            print(f"[OK] All {len(manifest_paths)} manifest files present")

    # 2) Template → grammar references
    template_refs: dict[Path, list[Path]] = {}
    referenced_grammars: set[Path] = set()

    for template in sorted(templates_dir.rglob("*")):
        if not template.is_file():
            continue
        text = template.read_text(encoding="utf-8")
        refs = list(set(extract_sentinel_refs(text)))
        grammars = []
        has_marker = re.search(r"<<<[A-Z0-9_]+:V\d+:", text) is not None
        for block_type, version in refs:
            grammar_name = type_to_grammar(block_type, version)
            grammar_path = sentinel_dir / grammar_name
            grammars.append(grammar_path)
            if grammar_path.exists():
                referenced_grammars.add(grammar_path)
                if args.verbose:
                    tpl_rel = relpath(template, templates_dir)
                    gram_rel = relpath(grammar_path, deadf / "contracts")
                    print(f"[OK] Template {tpl_rel} → {gram_rel} ✓")
            else:
                drift = True
                tpl_rel = relpath(template, templates_dir)
                gram_rel = relpath(grammar_path, deadf / "contracts")
                print(
                    f"[FAIL] Template {tpl_rel} references {gram_rel} but file missing"
                )
        template_refs[template] = grammars
        if not grammars and has_marker:
            drift = True
            tpl_rel = relpath(template, templates_dir)
            print(f"[WARN] Orphaned template: {tpl_rel} (no sentinel references)")

    # 3) Orphaned grammars (no templates reference)
    for grammar in sorted(sentinel_dir.glob("*.md")):
        if grammar not in referenced_grammars:
            drift = True
            gram_rel = relpath(grammar, deadf / "contracts")
            print(
                f"[WARN] Orphaned grammar: {gram_rel} (no template references it)"
            )

    return 1 if drift else 0


if __name__ == "__main__":
    sys.exit(main())
