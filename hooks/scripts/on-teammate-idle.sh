#!/usr/bin/env bash
# Signal-only: log teammate idle event
mkdir -p "$(dirname "$0")/../../.signals"
touch "$(dirname "$0")/../../.signals/teammate-idle"
echo "[$(date -Iseconds)] teammate-idle" >> "$(dirname "$0")/../../.signals/events.log"
