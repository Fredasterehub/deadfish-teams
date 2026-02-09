# Track Structure and Rehydration

Deadfish keeps execution state in track artifacts, then uses compaction hooks to preserve a concise snapshot when context is compacted.

## Track layout

Typical track directory:

```text
tracks/<track_id>/
├── SPEC.md
├── PLAN.md
├── RISKS.md
├── NEXT_ACTIONS.md
├── DECISIONS.md
├── TASKS/
│   └── <track_id>-P1-TNN.md
└── STATE_SNAPSHOT.md    # written by PreCompact hook when track is known
```

If no active track can be resolved, snapshot fallback is:

```text
.deadfish/session/<task_list_id>/STATE_SNAPSHOT.md
```

If project fallback cannot be written, hooks fall back to plugin signals:

```text
<plugin_root>/.signals/<task_list_id>/STATE_SNAPSHOT.md
```

## Hook flow

1. `PreCompact` runs `hooks/scripts/on-pre-compact.sh`.
2. Script writes a concise state snapshot with required fields:
   - current goal
   - current task
   - key decisions (ADR IDs when present)
   - open risks
   - next actions
3. Script records snapshot path to:
   - `<plugin_root>/.signals/<task_list_id>/latest-snapshot-path.txt`
4. `SessionStart` runs `hooks/scripts/on-session-start.sh`.
5. Script prints the latest snapshot into session output for immediate rehydration context.

Snapshot format reference: `templates/track/state-snapshot.md`.
