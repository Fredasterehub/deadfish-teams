# Task 01: Copy bin/ artifacts from deadfish-cli v1

Copy deterministic tools from `/tank/dump/DEV/deadfish-cli/.deadf/bin/` to `/tank/dump/DEV/deadfish-teams/bin/`. These are proven scripts — copy verbatim, do not modify.

## Commands

```bash
cd /tank/dump/DEV/deadfish-teams

cp /tank/dump/DEV/deadfish-cli/.deadf/bin/verify.sh bin/verify.sh
cp /tank/dump/DEV/deadfish-cli/.deadf/bin/parse-blocks.py bin/parse-blocks.py
cp /tank/dump/DEV/deadfish-cli/.deadf/bin/build-verdict.py bin/build-verdict.py
cp /tank/dump/DEV/deadfish-cli/.deadf/bin/lint-templates.py bin/lint-templates.py
chmod +x bin/*.sh bin/*.py

git add bin/
git commit -m "feat: copy deterministic tools from deadfish-cli v1

verify.sh, parse-blocks.py, build-verdict.py, lint-templates.py"
```

## Acceptance Criteria
- DET: bin/verify.sh exists and is executable
- DET: bin/parse-blocks.py exists and is executable
- DET: bin/build-verdict.py exists
- DET: bin/lint-templates.py exists
- DET: git commit created
