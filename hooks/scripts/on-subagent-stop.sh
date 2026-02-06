#!/usr/bin/env bash
# Signal-only: log subagent stop event
mkdir -p "$(dirname "$0")/../../.signals"
touch "$(dirname "$0")/../../.signals/subagent-stop"
echo "[$(date -Iseconds)] subagent-stop" >> "$(dirname "$0")/../../.signals/events.log"
