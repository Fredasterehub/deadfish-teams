# Task 02: Copy Surviving Artifacts from deadfish-cli v1

Copy files from `/tank/dump/DEV/deadfish-cli/` to `/tank/dump/DEV/deadfish-teams/`. These files are proven and must NOT be modified — copy them exactly.

## bin/ scripts (copy verbatim)

```bash
cp /tank/dump/DEV/deadfish-cli/.deadf/bin/verify.sh /tank/dump/DEV/deadfish-teams/bin/verify.sh
cp /tank/dump/DEV/deadfish-cli/.deadf/bin/parse-blocks.py /tank/dump/DEV/deadfish-teams/bin/parse-blocks.py
cp /tank/dump/DEV/deadfish-cli/.deadf/bin/build-verdict.py /tank/dump/DEV/deadfish-teams/bin/build-verdict.py
cp /tank/dump/DEV/deadfish-cli/.deadf/bin/lint-templates.py /tank/dump/DEV/deadfish-teams/bin/lint-templates.py
chmod +x /tank/dump/DEV/deadfish-teams/bin/*.sh /tank/dump/DEV/deadfish-teams/bin/*.py
```

## contracts/sentinel/ (copy verbatim)

```bash
cp /tank/dump/DEV/deadfish-cli/.deadf/contracts/sentinel/*.md /tank/dump/DEV/deadfish-teams/contracts/sentinel/
```

## templates/ (copy verbatim, preserve structure)

```bash
# Track templates
cp /tank/dump/DEV/deadfish-cli/.deadf/templates/track/select-track.md /tank/dump/DEV/deadfish-teams/templates/track/
cp /tank/dump/DEV/deadfish-cli/.deadf/templates/track/write-spec.md /tank/dump/DEV/deadfish-teams/templates/track/
cp /tank/dump/DEV/deadfish-cli/.deadf/templates/track/write-plan.md /tank/dump/DEV/deadfish-teams/templates/track/

# Task templates
cp /tank/dump/DEV/deadfish-cli/.deadf/templates/task/generate-packet.md /tank/dump/DEV/deadfish-teams/templates/task/
cp /tank/dump/DEV/deadfish-cli/.deadf/templates/task/implement.md /tank/dump/DEV/deadfish-teams/templates/task/

# Verify templates
cp /tank/dump/DEV/deadfish-cli/.deadf/templates/verify/verify-criterion.md /tank/dump/DEV/deadfish-teams/templates/verify/
cp /tank/dump/DEV/deadfish-cli/.deadf/templates/verify/reflect.md /tank/dump/DEV/deadfish-teams/templates/verify/
cp /tank/dump/DEV/deadfish-cli/.deadf/templates/verify/qa-review.md /tank/dump/DEV/deadfish-teams/templates/verify/

# Bootstrap templates (brainstorm)
for f in /tank/dump/DEV/deadfish-cli/.deadf/templates/bootstrap/*.md; do
  cp "$f" /tank/dump/DEV/deadfish-teams/templates/bootstrap/
done

# Repair templates
cp /tank/dump/DEV/deadfish-cli/.deadf/templates/repair/format-repair.md /tank/dump/DEV/deadfish-teams/templates/repair/
cp /tank/dump/DEV/deadfish-cli/.deadf/templates/repair/auto-diagnose.md /tank/dump/DEV/deadfish-teams/templates/repair/
```

## Commit

```bash
cd /tank/dump/DEV/deadfish-teams
git add -A
git commit -m "feat: copy surviving artifacts from deadfish-cli v1

bin/: verify.sh, parse-blocks.py, build-verdict.py, lint-templates.py
contracts/: all sentinel format definitions
templates/: all 27 templates (bootstrap, track, task, verify, repair)"
```

## Acceptance Criteria
- DET: `bin/verify.sh` exists and is executable
- DET: `bin/parse-blocks.py` exists and is executable
- DET: `bin/build-verdict.py` exists
- DET: `contracts/sentinel/plan.v1.md` exists
- DET: `templates/track/write-plan.md` exists
- DET: `templates/bootstrap/seed-project-docs.md` exists
- DET: `templates/verify/qa-review.md` exists
- DET: All files are exact copies (diff shows no changes)
