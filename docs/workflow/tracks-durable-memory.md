# Tracks As Durable Memory

## Canonical Track Layout

```text
tracks/<YYYY-MM-DD>-<slug>/
  index.md
  spec.md
  plan.md
  notes.md
  task-packets/
    index.md
    <track>-P<phase>-T<nn>.md
  verdicts/
  snapshots/
```

Canonical files:
- `spec.md`: scope + acceptance criteria
- `plan.md`: ordered tasks and packet paths
- `task-packets/*.md`: per-task execution packets
- `verdicts/*`: QA and boundary artifacts
- `notes.md`: human rationale and resume breadcrumbs

## Start A New Track

1. `python3 bin/new-track.py --slug <track-slug> --track-name "<Track Name>"`
2. Fill `spec.md` with one `deadfish:SPEC` block.
3. Fill `plan.md` with one `deadfish:PLAN` block.
4. Mirror plan into packets:
   `python3 bin/plan-to-packets.py tracks/<YYYY-MM-DD>-<track-slug>/plan.md`
5. For each packet, generate task prompt:
   `python3 bin/packet-to-task.py <packet_path>`

## Rehydrate After `/resume`

Use `templates/rehydrate.md` as the operational checklist.

Fast path:
1. Find latest track directory by date prefix.
2. Reopen canonical files (`index.md`, `spec.md`, `plan.md`, `notes.md`).
3. Recreate teammates from `CLAUDE.md` kickoff contract.
4. Reconcile `plan.md` checkboxes against Claude task statuses.
5. If packet files are missing or stale, rerun:
   `python3 bin/plan-to-packets.py <track_plan_path> --overwrite`

## Out-Of-Sync Handling

- `verify.sh` PASS but plan checkbox unchecked: check it and log evidence in `notes.md`.
- Task marked complete but `verify.sh` FAIL: reopen task and append failure evidence.
- Packet drift from plan intent: update `plan.md` first, then remirror packets.
- 2+ failed attempts on one task: request conductor boundary decision.
