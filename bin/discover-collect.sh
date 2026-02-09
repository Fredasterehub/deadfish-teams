#!/usr/bin/env bash
set -uo pipefail

usage() {
    cat <<'USAGE'
Usage: discover-collect.sh [--project <dir>] [--depth <n>] [--out-dir <dir>]

Collects discovery evidence for brownfield analysis.

Defaults:
  --project .
  --depth 1
  --out-dir <project>/docs/discovery/evidence
USAGE
}

PROJECT_PATH="."
DEPTH=1
OUT_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project)
            if [[ -z "${2:-}" ]]; then
                echo "Missing value for --project" >&2
                exit 1
            fi
            PROJECT_PATH="$2"
            shift 2
            ;;
        --depth)
            if [[ -z "${2:-}" ]]; then
                echo "Missing value for --depth" >&2
                exit 1
            fi
            DEPTH="$2"
            shift 2
            ;;
        --out-dir)
            if [[ -z "${2:-}" ]]; then
                echo "Missing value for --out-dir" >&2
                exit 1
            fi
            OUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ "$PROJECT_PATH" == "." ]]; then
                PROJECT_PATH="$1"
                shift
            else
                echo "Unknown arg: $1" >&2
                usage >&2
                exit 1
            fi
            ;;
    esac
done

if [[ ! -d "$PROJECT_PATH" ]]; then
    echo "Project path does not exist: $PROJECT_PATH" >&2
    exit 1
fi

if ! PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"; then
    echo "Failed to resolve project path: $PROJECT_PATH" >&2
    exit 1
fi

if ! [[ "$DEPTH" =~ ^[0-9]+$ ]]; then
    DEPTH=1
fi
if [[ "$DEPTH" -lt 1 ]]; then
    DEPTH=1
fi
if [[ "$DEPTH" -gt 3 ]]; then
    DEPTH=3
fi

if [[ -z "$OUT_DIR" ]]; then
    OUT_DIR="$PROJECT_PATH/docs/discovery/evidence"
elif [[ "${OUT_DIR:0:1}" != "/" ]]; then
    OUT_DIR="$PROJECT_PATH/$OUT_DIR"
fi

if ! mkdir -p "$OUT_DIR"; then
    echo "Failed to create evidence dir: $OUT_DIR" >&2
    exit 1
fi

FIND_MAX_DEPTH=4
if [[ "$DEPTH" -ge 2 ]]; then
    FIND_MAX_DEPTH=6
fi
if [[ "$DEPTH" -ge 3 ]]; then
    FIND_MAX_DEPTH=8
fi

EXCLUDE_DIRS=(.git node_modules vendor dist build .deadf .venv __pycache__ .next .cache .idea)
PRUNE_ARGS=()
for d in "${EXCLUDE_DIRS[@]}"; do
    PRUNE_ARGS+=( -name "$d" -o )
done
PRUNE_ARGS+=( -false )

safe_name() {
    printf '%s' "$1" | tr '/ ' '__'
}

write_snippet() {
    local src="$1"
    local out="$2"
    local limit="$3"
    if [[ -r "$src" ]]; then
        head -n "$limit" "$src" > "$out"
    else
        printf 'UNREADABLE: %s\n' "$src" > "$out"
    fi
}

(
    cd "$PROJECT_PATH" || exit 1
    find . -maxdepth "$FIND_MAX_DEPTH" \
        \( -type d \( "${PRUNE_ARGS[@]}" \) -prune \) -o -print \
        | sed 's|^\./||' \
        | grep -v '^\.$' \
        | sort \
        | head -n 1200
) > "$OUT_DIR/tree.txt"

DEP_FILES=(package.json package-lock.json pnpm-lock.yaml yarn.lock Cargo.toml go.mod requirements.txt pyproject.toml Gemfile pom.xml build.gradle composer.json mix.exs)
DEP_FIND_ARGS=()
for f in "${DEP_FILES[@]}"; do
    DEP_FIND_ARGS+=( -name "$f" -o )
done
DEP_FIND_ARGS+=( -false )
while IFS= read -r f; do
    rel="${f#$PROJECT_PATH/}"
    out="$OUT_DIR/deps-$(safe_name "$rel").txt"
    write_snippet "$f" "$out" 200
done < <(
    find "$PROJECT_PATH" -maxdepth "$FIND_MAX_DEPTH" \
        \( -type d \( "${PRUNE_ARGS[@]}" \) -prune \) -o \
        -type f \( "${DEP_FIND_ARGS[@]}" \) -print | sort
)

while IFS= read -r f; do
    rel="${f#$PROJECT_PATH/}"
    out="$OUT_DIR/config-$(safe_name "$rel").txt"
    write_snippet "$f" "$out" 120
done < <(
    find "$PROJECT_PATH" -maxdepth "$FIND_MAX_DEPTH" \
        \( -type d \( "${PRUNE_ARGS[@]}" \) -prune \) -o \
        -type f \( \
            -name "tsconfig.json" -o -name "tsconfig.*.json" \
            -o -name ".eslintrc" -o -name ".eslintrc.*" -o -name "eslint.config.*" \
            -o -name "vite.config.*" -o -name "webpack.config.*" -o -name "rollup.config.*" \
            -o -name "babel.config.*" -o -name ".babelrc" -o -name ".babelrc.*" \
            -o -name "jest.config.*" -o -name "vitest.config.*" -o -name "playwright.config.*" \
            -o -name "pytest.ini" -o -name "setup.cfg" -o -name "tox.ini" \
            -o -name ".prettierrc" -o -name ".prettierrc.*" -o -name ".editorconfig" -o -name ".nvmrc" \
            -o -name ".env.example" -o -name ".env.sample" \
        \) -print | sort
)

while IFS= read -r f; do
    rel="${f#$PROJECT_PATH/}"
    out="$OUT_DIR/doc-$(safe_name "$rel").md"
    write_snippet "$f" "$out" 240
done < <(
    find "$PROJECT_PATH" -maxdepth "$FIND_MAX_DEPTH" \
        \( -type d \( "${PRUNE_ARGS[@]}" \) -prune \) -o \
        -type f \( -iname "README.md" -o -iname "CONTRIBUTING.md" -o -iname "ARCHITECTURE.md" -o -iname "DESIGN.md" -o -iname "ADR*.md" \) -print | sort
)

ci_files=()
if [[ -d "$PROJECT_PATH/.github/workflows" ]]; then
    while IFS= read -r f; do
        ci_files+=("$f")
    done < <(find "$PROJECT_PATH/.github/workflows" -type f \( -name "*.yml" -o -name "*.yaml" \) -print | sort)
fi
for f in "$PROJECT_PATH/.gitlab-ci.yml" "$PROJECT_PATH/Jenkinsfile" "$PROJECT_PATH/.circleci/config.yml" "$PROJECT_PATH/azure-pipelines.yml"; do
    if [[ -f "$f" ]]; then
        ci_files+=("$f")
    fi
done
for f in "${ci_files[@]}"; do
    rel="${f#$PROJECT_PATH/}"
    out="$OUT_DIR/ci-$(safe_name "$rel").txt"
    write_snippet "$f" "$out" 120
done

while IFS= read -r f; do
    rel="${f#$PROJECT_PATH/}"
    out="$OUT_DIR/entry-$(safe_name "$rel").txt"
    write_snippet "$f" "$out" 120
done < <(
    find "$PROJECT_PATH" -maxdepth "$FIND_MAX_DEPTH" \
        \( -type d \( "${PRUNE_ARGS[@]}" \) -prune \) -o \
        -type f \( \
            -name "main.ts" -o -name "main.js" -o -name "main.py" -o -name "main.go" -o -name "main.rs" \
            -o -name "index.ts" -o -name "index.js" -o -name "index.py" \
            -o -name "app.ts" -o -name "app.js" -o -name "app.py" -o -name "app.rb" \
        \) -print | sort
)

if git -C "$PROJECT_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$PROJECT_PATH" log --oneline -n 50 > "$OUT_DIR/git-log.txt" 2>/dev/null || true
    git -C "$PROJECT_PATH" status --short > "$OUT_DIR/git-status.txt" 2>/dev/null || true
    git -C "$PROJECT_PATH" branch --show-current > "$OUT_DIR/git-branch.txt" 2>/dev/null || true
fi

artifact_count="$(find "$OUT_DIR" -maxdepth 1 -type f | wc -l | tr -d ' ')"
{
    printf 'project=%s\n' "$PROJECT_PATH"
    printf 'depth=%s\n' "$DEPTH"
    printf 'find_max_depth=%s\n' "$FIND_MAX_DEPTH"
    printf 'artifact_count=%s\n' "$artifact_count"
} > "$OUT_DIR/summary.txt"

printf '%s\n' "$OUT_DIR"
exit 0
