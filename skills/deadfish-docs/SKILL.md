---
name: deadfish-docs
description: Living docs format, budgets, significance gate.
---

# deadfish-docs — Living Documentation

## 7 Living Docs (in `docs/living/`)

| Doc | Budget (chars) | Content |
|-----|---------------|---------|
| TECH_STACK.md | 3200 | Languages, frameworks, deps, versions |
| PATTERNS.md | 3200 | Architecture patterns, conventions, idioms |
| PITFALLS.md | 2800 | Known gotchas, footguns, anti-patterns |
| RISKS.md | 2000 | Security, operational, business risks |
| PRODUCT.md | 2800 | Features, API surface, user-facing behavior |
| WORKFLOW.md | 2800 | CI/CD, scripts, deployment, dev workflow |
| GLOSSARY.md | 2000 | Domain terms, abbreviations, naming |
| **Total** | **~18800** | |

## Scratch Buffer
`docs/living/.scratch.yaml` — observations not yet significant enough for a doc update:
```yaml
- task: auth-P1-T02
  doc: PATTERNS
  entry: "JWT uses RS256 with rotating keys"
  timestamp: 2026-02-06T10:30:00Z
```

## Significance Triggers
Only update docs when:
- manifest/lockfile changed
- diff_lines ≥ 120
- New CLI/script/CI artifact
- retry_count > 0 (unexpected complexity)
- Scope drift detected
- New architectural pattern
- Breaking change

## Actions
- **NOP**: No new information
- **BUFFER**: Minor observation → scratch buffer
- **UPDATE**: Significant → edit doc
- **FLUSH**: Track-end → flush buffer + reconcile all 7 docs

## Docsync Sentinel

    ```deadfish:DOCSYNC
    action: UPDATE
    touched_docs:
      - docs/living/PATTERNS.md
    summary: "Added JWT RS256 pattern with key rotation notes"
    ```

## Budget Enforcement
If doc exceeds 80% of budget → compress before commit. Prefer edits over expansion.
