# Decisions Ledger

This file is the canonical decision index. Keep one row per `decision_id`.

Use either:
- repo root: `decisions.md`
- track-local: `tracks/<track_id>/decisions.md`

If both exist, the track-local file is authoritative for that track.

## Rules
- A `decision_id` appears exactly once in this ledger.
- Every ADR file updates this ledger in the same commit.
- Supersessions must be bidirectional:
  - new ADR row fills `supersedes`
  - old ADR row fills `superseded_by` and status becomes `superseded`

## Index
| decision_id | status | adr_path | supersedes | superseded_by | date | summary |
|---|---|---|---|---|---|---|
| ADR-0001 | accepted | tracks/auth/decisions/ADR-0001.md | - | ADR-0003 | 2026-02-09 | Introduced task-packet contract for auth track |
| ADR-0003 | proposed | tracks/auth/decisions/ADR-0003.md | ADR-0001 | - | 2026-02-10 | Replaced packet naming to support retries |
