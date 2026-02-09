# Task 02: Copy templates + contracts from deadfish-cli v1

Copy all templates and sentinel contracts. These are reference material for skills and agents.

## Commands

```bash
cd /tank/dump/DEV/deadfish-teams

# Sentinel contracts
cp /tank/dump/DEV/deadfish-cli/.deadf/contracts/sentinel/*.md contracts/sentinel/ 2>/dev/null || echo "no sentinel contracts found"

# Track templates
for f in select-track.md write-spec.md write-plan.md; do
  cp "/tank/dump/DEV/deadfish-cli/.deadf/templates/track/$f" templates/track/ 2>/dev/null
done

# Task templates
for f in generate-packet.md implement.md; do
  cp "/tank/dump/DEV/deadfish-cli/.deadf/templates/task/$f" templates/task/ 2>/dev/null
done

# Verify templates
for f in verify-criterion.md reflect.md qa-review.md; do
  cp "/tank/dump/DEV/deadfish-cli/.deadf/templates/verify/$f" templates/verify/ 2>/dev/null
done

# Bootstrap templates (brainstorm)
cp /tank/dump/DEV/deadfish-cli/.deadf/templates/bootstrap/*.md templates/bootstrap/ 2>/dev/null

# Repair templates
for f in format-repair.md auto-diagnose.md; do
  cp "/tank/dump/DEV/deadfish-cli/.deadf/templates/repair/$f" templates/repair/ 2>/dev/null
done

git add templates/ contracts/
git commit -m "feat: copy templates + sentinel contracts from v1"
```

## Acceptance Criteria
- DET: templates/track/write-plan.md exists
- DET: templates/bootstrap/ has at least 1 file
- DET: templates/verify/qa-review.md exists
- DET: git commit created
