#!/usr/bin/env bash
# Signal-only: log task completion event
mkdir -p "$(dirname "$0")/../../.signals"
touch "$(dirname "$0")/../../.signals/task-completed"
echo "[$(date -Iseconds)] task-completed" >> "$(dirname "$0")/../../.signals/events.log"
