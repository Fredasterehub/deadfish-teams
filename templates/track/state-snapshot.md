# Deadfish State Snapshot Template

Use this structure for compaction snapshots written before context compaction:

```markdown
# Deadfish State Snapshot
timestamp_utc: 2026-02-09T12:34:56Z
task_list_id: deadfish-20260209
project_root: /path/to/project
track_id: auth

## Current Goal
Implement token issuance and validation primitives for authenticated routes.

## Current Task
auth-P1-T02

## Key Decisions
- ADR-0007
- ADR-0008

## Open Risks
- Token refresh semantics are still unresolved.
- Existing middleware error shape may require compatibility glue.

## Next Actions
- Implement refresh expiry handling in auth middleware.
- Add deterministic tests for revoked token path.
```

Notes:
- Keep it concise. Prefer short bullets over long prose.
- Include ADR IDs when available.
- If a section has no data, write `- none recorded`.
