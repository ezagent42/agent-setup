#!/usr/bin/env bash
# session-start.sh — Lightweight health check for the agent-setup plugin.
# Verifies plugin integrity and outputs SessionStart hook JSON.
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"
MSG="Agent Setup plugin active"
STATUS="ok"

# Basic health check: can we find our own hooks.json?
if [ ! -f "${PLUGIN_ROOT}/hooks/hooks.json" ]; then
  MSG="Agent Setup plugin may be corrupted — hooks.json missing"
  STATUS="warn"
fi

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${MSG}"
  }
}
EOF
