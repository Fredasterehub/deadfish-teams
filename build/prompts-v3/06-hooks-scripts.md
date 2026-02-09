# Task 06: Hooks + signal scripts

Create hooks configuration and signal-only scripts. Hooks nudge the pipeline forward. They are NOT the scheduler. Don't let hooks become Ralph.

## File 1: `hooks/hooks.json`

```json
{
  "hooks": {
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "touch /tank/dump/DEV/deadfish-teams/.signals/task-completed"
          }
        ]
      }
    ],
    "TeammateIdle": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "touch /tank/dump/DEV/deadfish-teams/.signals/teammate-idle"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "touch /tank/dump/DEV/deadfish-teams/.signals/subagent-stop"
          }
        ]
      }
    ]
  }
}
```

## File 2: `hooks/scripts/on-task-completed.sh`

```bash
#!/usr/bin/env bash
# Signal-only: log task completion event
mkdir -p "$(dirname "$0")/../../.signals"
touch "$(dirname "$0")/../../.signals/task-completed"
echo "[$(date -Iseconds)] task-completed" >> "$(dirname "$0")/../../.signals/events.log"
```

## File 3: `hooks/scripts/on-teammate-idle.sh`

```bash
#!/usr/bin/env bash
# Signal-only: log teammate idle event
mkdir -p "$(dirname "$0")/../../.signals"
touch "$(dirname "$0")/../../.signals/teammate-idle"
echo "[$(date -Iseconds)] teammate-idle" >> "$(dirname "$0")/../../.signals/events.log"
```

## File 4: `hooks/scripts/on-subagent-stop.sh`

```bash
#!/usr/bin/env bash
# Signal-only: log subagent stop event
mkdir -p "$(dirname "$0")/../../.signals"
touch "$(dirname "$0")/../../.signals/subagent-stop"
echo "[$(date -Iseconds)] subagent-stop" >> "$(dirname "$0")/../../.signals/events.log"
```

## Setup

```bash
cd /tank/dump/DEV/deadfish-teams
mkdir -p hooks/scripts .signals
# (write files above)
chmod +x hooks/scripts/*.sh
echo '.signals/' >> .gitignore

git add hooks/ .gitignore
git commit -m "feat: signal-only hooks (TaskCompleted, TeammateIdle, SubagentStop)

Hooks touch signal files and append to events.log.
They do NOT schedule work — Lead reads signals."
```

## Acceptance Criteria
- DET: hooks/hooks.json exists and is valid JSON
- DET: hooks/scripts/ contains 3 .sh files, all executable
- DET: .gitignore contains .signals/
- DET: .signals/ directory exists
- DET: git commit created
