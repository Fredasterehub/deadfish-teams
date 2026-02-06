#!/usr/bin/env bash
set -euo pipefail

# Update README.md with a dynamic "Latest updates" section from git history.
# Inserts content between markers:
#   <!-- BEGIN:LAST_UPDATES -->
#   <!-- END:LAST_UPDATES -->
#
# Usage:
#   ./scripts/update_readme_latest_updates.sh [--readme README.md] [--n 7]

README="README.md"
N=7

while [[ $# -gt 0 ]]; do
  case "$1" in
    --readme) README="$2"; shift 2;;
    --n) N="$2"; shift 2;;
    -h|--help)
      echo "Usage: $0 [--readme README.md] [--n 7]"; exit 0;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

if [[ ! -f "$README" ]]; then
  echo "README not found: $README" >&2
  exit 1
fi

BEGIN='<!-- BEGIN:LAST_UPDATES -->'
END='<!-- END:LAST_UPDATES -->'

if ! grep -qF "$BEGIN" "$README" || ! grep -qF "$END" "$README"; then
  echo "Missing markers in $README. Add:\n$BEGIN\n$END" >&2
  exit 2
fi

# Generate updates block
NOW_UTC=$(date -u +"%Y-%m-%d %H:%M UTC")

UPDATES=$(git log -n "$N" --date=short --pretty=format:'- %ad — %s (%h)' 2>/dev/null || true)
if [[ -z "${UPDATES}" ]]; then
  UPDATES="- (no git history available)"
fi

BLOCK=$(cat <<EOF
$BEGIN
_Last refreshed: ${NOW_UTC}_

$UPDATES
$END
EOF
)

# Replace content between markers (inclusive)
TMP=$(mktemp)
awk -v begin="$BEGIN" -v end="$END" -v block="$BLOCK" '
  $0==begin {print block; inblock=1; next}
  $0==end {inblock=0; next}
  !inblock {print}
' "$README" > "$TMP"

mv "$TMP" "$README"

echo "Updated $README latest updates (last $N commits)."
