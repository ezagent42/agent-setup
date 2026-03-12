#!/usr/bin/env bash
# Installs a multi-artifact package from a GitHub repo.
# Usage: install-package.sh <owner/repo> <project_dir>
# Scans for: skills/, agents/, commands/, hooks/
set -euo pipefail

REPO="$1"
PROJECT_DIR="$2"
REPO_NAME=$(basename "$REPO")

AGENTS_DIR="${PROJECT_DIR}/.claude/agents"
COMMANDS_DIR="${PROJECT_DIR}/.claude/commands"
PKG_HOOKS_DIR="${PROJECT_DIR}/.agents/package-hooks/${REPO_NAME}"
MANIFEST_DIR="${PROJECT_DIR}/.agents/packages"
SETTINGS_FILE="${PROJECT_DIR}/.claude/settings.json"

# Clone to temp dir
CLONE_DIR=$(mktemp -d)
trap 'rm -rf "$CLONE_DIR"' EXIT

if ! git clone --depth 1 "https://github.com/${REPO}.git" "$CLONE_DIR" 2>/dev/null; then
  echo "Failed to clone ${REPO}" >&2
  exit 1
fi

# Track installed artifacts as newline-separated strings
INSTALLED_SKILLS=""
INSTALLED_AGENTS=""
INSTALLED_COMMANDS=""
INSTALLED_HOOKS=""

# --- Skills (delegate to skills CLI) ---
SKILL_DIR=""
[ -d "$CLONE_DIR/skill" ] && SKILL_DIR="$CLONE_DIR/skill"
[ -d "$CLONE_DIR/skills" ] && SKILL_DIR="$CLONE_DIR/skills"

if [ -n "$SKILL_DIR" ]; then
  if pnpm dlx skills add "$REPO" --agent claude-code -y </dev/null >/dev/null 2>&1; then
    INSTALLED_SKILLS="$REPO"
  fi
fi

# --- Agents ---
AGENT_DIR=""
[ -d "$CLONE_DIR/agent" ] && AGENT_DIR="$CLONE_DIR/agent"
[ -d "$CLONE_DIR/agents" ] && AGENT_DIR="$CLONE_DIR/agents"

if [ -n "$AGENT_DIR" ]; then
  mkdir -p "$AGENTS_DIR"
  for f in "$AGENT_DIR"/*.md; do
    [ -f "$f" ] || continue
    cp "$f" "$AGENTS_DIR/"
    INSTALLED_AGENTS="${INSTALLED_AGENTS}$(basename "$f")"$'\n'
  done
fi

# --- Commands ---
CMD_DIR=""
[ -d "$CLONE_DIR/command" ] && CMD_DIR="$CLONE_DIR/command"
[ -d "$CLONE_DIR/commands" ] && CMD_DIR="$CLONE_DIR/commands"

if [ -n "$CMD_DIR" ]; then
  mkdir -p "$COMMANDS_DIR"
  for f in "$CMD_DIR"/*.md; do
    [ -f "$f" ] || continue
    cp "$f" "$COMMANDS_DIR/"
    INSTALLED_COMMANDS="${INSTALLED_COMMANDS}$(basename "$f")"$'\n'
  done
fi

# --- Hooks ---
if [ -d "$CLONE_DIR/hooks" ]; then
  mkdir -p "$PKG_HOOKS_DIR"
  for f in "$CLONE_DIR/hooks"/*.sh; do
    [ -f "$f" ] || continue
    cp "$f" "$PKG_HOOKS_DIR/"
    chmod +x "$PKG_HOOKS_DIR/$(basename "$f")"
    INSTALLED_HOOKS="${INSTALLED_HOOKS}$(basename "$f")"$'\n'

    # Register in settings.json (SessionStart) with dedup
    if command -v jq &>/dev/null && [ -f "$SETTINGS_FILE" ]; then
      hook_file="$(basename "$f")"
      HOOK_CMD='"$CLAUDE_PROJECT_DIR"/.agents/package-hooks/'"${REPO_NAME}"'/'"${hook_file}"
      UPDATED=$(jq --arg cmd "$HOOK_CMD" '
        .hooks.SessionStart += [{
          "hooks": [{"type": "command", "command": $cmd}]
        }]
        | .hooks.SessionStart |= unique_by(.hooks[0].command)
      ' "$SETTINGS_FILE")
      printf '%s\n' "$UPDATED" > "$SETTINGS_FILE"
    fi
  done
fi

# --- Write manifest ---
# Helper: convert newline-separated string to JSON array
to_json_array() {
  local items="$1"
  if [ -z "$items" ]; then echo "[]"; return; fi
  local result="["
  local first=true
  while IFS= read -r item; do
    [ -z "$item" ] && continue
    if [ "$first" = true ]; then first=false; else result+=", "; fi
    result+="\"${item}\""
  done <<< "$items"
  result+="]"
  echo "$result"
}

mkdir -p "$MANIFEST_DIR"
cat > "${MANIFEST_DIR}/${REPO_NAME}.json" <<MANIFEST
{
  "repo": "${REPO}",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "artifacts": {
    "skills": $(to_json_array "$INSTALLED_SKILLS"),
    "agents": $(to_json_array "$INSTALLED_AGENTS"),
    "commands": $(to_json_array "$INSTALLED_COMMANDS"),
    "hooks": $(to_json_array "$INSTALLED_HOOKS")
  }
}
MANIFEST

exit 0
