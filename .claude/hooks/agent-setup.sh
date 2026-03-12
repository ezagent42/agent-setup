#!/usr/bin/env bash
# SessionStart hook — reads AGENT_SETUP.md, ensures skills, tools, and packages are installed.
# Idempotent: re-running on already-installed items simply overwrites them.
# Uses hash-based change detection to skip install when AGENT_SETUP.md is unchanged.
set -euo pipefail

SETUP_FILE="${CLAUDE_PROJECT_DIR}/AGENT_SETUP.md"
HASH_FILE="${CLAUDE_PROJECT_DIR}/.agents/.last-setup-hash"
PKG_HASH_FILE="${CLAUDE_PROJECT_DIR}/.agents/.last-package-hash"
VERSION_FILE="${CLAUDE_PROJECT_DIR}/.claude/.template-version"
TEMPLATE_REPO="https://github.com/ezagent42/agent-setup.git"
TEMPLATE_RAW_URL="https://raw.githubusercontent.com/ezagent42/agent-setup/main/AGENT_SETUP.md"
WARNINGS=""

escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

# --- merge_section: additive-only merge of template section into local file ---
# Appends any "- xxx" lines from the template section that are missing in the local section.
# Never removes user lines. Creates the section if it doesn't exist locally.
merge_section() {
  local section="$1"
  local template_file="$2"
  local local_file="$3"

  # Extract "- " lines from template section
  local tpl_items
  tpl_items=$(awk -v sec="## $section" '$0==sec{f=1;next} /^## /{f=0} f && /^- /{print}' "$template_file")
  [ -z "$tpl_items" ] && return 0

  # Extract "- " lines from local section (if it exists)
  local loc_items=""
  if grep -q "^## ${section}$" "$local_file"; then
    loc_items=$(awk -v sec="## $section" '$0==sec{f=1;next} /^## /{f=0} f && /^- /{print}' "$local_file")
  fi

  # Find lines present in template but missing from local
  local missing=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [ -z "$loc_items" ] || ! printf '%s\n' "$loc_items" | grep -qxF -- "$line"; then
      missing="${missing}${line}"$'\n'
    fi
  done <<< "$tpl_items"
  [ -z "$missing" ] && return 0

  local tmp
  tmp=$(mktemp)

  if ! grep -q "^## ${section}$" "$local_file"; then
    # Section doesn't exist — insert before ## Project Skills or append at EOF
    if grep -q "^## Project Skills$" "$local_file"; then
      export _MERGE_ITEMS="$missing"
      awk -v sec="## $section" '
        /^## Project Skills$/ {
          print sec
          print ""
          printf "%s", ENVIRON["_MERGE_ITEMS"]
          print ""
        }
        { print }
      ' "$local_file" > "$tmp"
      unset _MERGE_ITEMS
    else
      cp "$local_file" "$tmp"
      printf '\n## %s\n\n%s' "$section" "$missing" >> "$tmp"
    fi
  else
    # Section exists — append missing lines at end of section
    export _MERGE_ITEMS="$missing"
    awk -v sec="## $section" '
      BEGIN { in_sec=0; done_ins=0 }
      {
        if (/^## /) {
          if (in_sec && !done_ins) {
            printf "%s", ENVIRON["_MERGE_ITEMS"]
            done_ins=1
          }
          in_sec = ($0 == sec) ? 1 : 0
        }
        print
      }
      END {
        if (in_sec && !done_ins) printf "%s", ENVIRON["_MERGE_ITEMS"]
      }
    ' "$local_file" > "$tmp"
    unset _MERGE_ITEMS
  fi

  mv "$tmp" "$local_file"
}

# --- 1. Check AGENT_SETUP.md exists ---
if [ ! -f "$SETUP_FILE" ]; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "WARNING: AGENT_SETUP.md not found at project root. Skills and tools will not be managed. Create one from the template: https://github.com/ezagent42/agent-setup"
  }
}
EOF
  exit 0
fi

# --- 1.5. Auto-update infrastructure + merge AGENT_SETUP.md ---
# When the template repo has new commits:
#   a) Run update-from-template.sh to update hooks/scripts (so this file self-updates)
#   b) Additively merge new Skills/Tools/Packages entries into local AGENT_SETUP.md
if [ -f "$VERSION_FILE" ]; then
  LOCAL_SHA=$(cat "$VERSION_FILE")
  REMOTE_SHA=$(git ls-remote "$TEMPLATE_REPO" refs/heads/main 2>/dev/null | cut -f1 || true)
  if [ -n "$REMOTE_SHA" ] && [ "$REMOTE_SHA" != "$LOCAL_SHA" ]; then
    # a) Update infrastructure (hooks, scripts, bundled skills)
    UPDATER="${CLAUDE_PROJECT_DIR}/update-from-template.sh"
    if [ -x "$UPDATER" ]; then
      "$UPDATER" >/dev/null 2>&1 || true
    fi

    # b) Merge AGENT_SETUP.md entries (additive only)
    TPL_TMP=$(mktemp)
    if curl -sfL "$TEMPLATE_RAW_URL" -o "$TPL_TMP" 2>/dev/null; then
      merge_section "Skills" "$TPL_TMP" "$SETUP_FILE"
      merge_section "Tools" "$TPL_TMP" "$SETUP_FILE"
      merge_section "Packages" "$TPL_TMP" "$SETUP_FILE"
    else
      WARNINGS="${WARNINGS}\nTemplate merge: could not fetch remote AGENT_SETUP.md"
    fi
    rm -f "$TPL_TMP"

    # update-from-template.sh already saves .template-version,
    # but write it again in case the updater was missing or failed
    echo "$REMOTE_SHA" > "$VERSION_FILE"
  fi
fi

# --- 2. Parse ## Skills section ---
SKILLS_SECTION=$(awk '/^## Skills$/{found=1;next} /^## /{found=0} found{print}' "$SETUP_FILE")
SKILL_LINES=$(echo "$SKILLS_SECTION" | grep '^- ' | sed 's/^- //' || true)

# --- 3. Parse ## Tools section ---
TOOLS_SECTION=$(awk '/^## Tools$/{found=1;next} /^## /{found=0} found{print}' "$SETUP_FILE")
TOOL_LINES=$(echo "$TOOLS_SECTION" | grep '^- ' | sed 's/^- //' || true)

# --- 3.5. Parse ## Packages section ---
PACKAGES_SECTION=$(awk '/^## Packages$/{found=1;next} /^## /{found=0} found{print}' "$SETUP_FILE")
PACKAGE_LINES=$(echo "$PACKAGES_SECTION" | grep '^- ' | sed 's/^- //' || true)

# --- 4. Hash-based change detection (skills) ---
CURRENT_HASH=$(echo "$SKILL_LINES" | shasum -a 256 | cut -d' ' -f1)
STORED_HASH=""
if [ -f "$HASH_FILE" ]; then
  STORED_HASH=$(cat "$HASH_FILE")
fi

SETUP_CHANGED=false
if [ "$CURRENT_HASH" != "$STORED_HASH" ]; then
  SETUP_CHANGED=true
fi

# --- 4.5. Hash-based change detection (packages) ---
PKG_CURRENT_HASH=$(echo "$PACKAGE_LINES" | shasum -a 256 | cut -d' ' -f1)
PKG_STORED_HASH=""
if [ -f "$PKG_HASH_FILE" ]; then
  PKG_STORED_HASH=$(cat "$PKG_HASH_FILE")
fi

PKG_CHANGED=false
if [ "$PKG_CURRENT_HASH" != "$PKG_STORED_HASH" ]; then
  PKG_CHANGED=true
fi

# --- 5. Install skills if changed ---
INSTALL_ERRORS=""
if [ "$SETUP_CHANGED" = true ] && [ -n "$SKILL_LINES" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    # Each line becomes: pnpm dlx skills add <args> --agent claude-code -y
    # Redirect all output away from stdout to avoid corrupting hook JSON
    if ! pnpm dlx skills add $line --agent claude-code -y </dev/null >/dev/null 2>&1; then
      INSTALL_ERRORS="${INSTALL_ERRORS}\nFailed to install skill: $line"
    fi
  done <<< "$SKILL_LINES"

  # --- 6. Update hash ---
  mkdir -p "$(dirname "$HASH_FILE")"
  echo "$CURRENT_HASH" > "$HASH_FILE"
fi

# --- 7. Check tools ---
if [ -n "$TOOL_LINES" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    TOOL_CMD=$(echo "$line" | cut -d'|' -f1 | xargs)
    TOOL_HINT=$(echo "$line" | cut -d'|' -f2- | xargs)
    if ! command -v "$TOOL_CMD" &>/dev/null; then
      WARNINGS="${WARNINGS}\nMissing tool: ${TOOL_CMD} — Install: ${TOOL_HINT}"
    fi
  done <<< "$TOOL_LINES"
fi

# --- 7.5. Install packages if changed ---
if [ "$PKG_CHANGED" = true ] && [ -n "$PACKAGE_LINES" ]; then
  INSTALLER="${CLAUDE_PROJECT_DIR}/.claude/hooks/install-package.sh"
  if [ -x "$INSTALLER" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      if ! "$INSTALLER" "$line" "$CLAUDE_PROJECT_DIR" 2>/dev/null; then
        INSTALL_ERRORS="${INSTALL_ERRORS}\nFailed to install package: $line"
      fi
    done <<< "$PACKAGE_LINES"
  else
    WARNINGS="${WARNINGS}\nPackage installer not found: .claude/hooks/install-package.sh"
  fi

  # Update package hash
  mkdir -p "$(dirname "$PKG_HASH_FILE")"
  echo "$PKG_CURRENT_HASH" > "$PKG_HASH_FILE"
fi

# --- 8. Output JSON ---
ANYTHING_CHANGED=false
if [ "$SETUP_CHANGED" = true ] && [ -n "$SKILL_LINES" ]; then
  ANYTHING_CHANGED=true
fi
if [ "$PKG_CHANGED" = true ] && [ -n "$PACKAGE_LINES" ]; then
  ANYTHING_CHANGED=true
fi

if [ "$ANYTHING_CHANGED" = true ]; then
  MSG="Agent Setup updated. Please restart Claude Code to load new skills."
  if [ -n "$INSTALL_ERRORS" ]; then
    MSG="${MSG}\\nInstall errors:${INSTALL_ERRORS}"
  fi
  if [ -n "$WARNINGS" ]; then
    MSG="${MSG}\\n${WARNINGS}"
  fi
else
  MSG="All Agent Setup ✓"
  if [ -n "$WARNINGS" ]; then
    MSG="${MSG}\\n${WARNINGS}"
  fi
fi

# Escape for JSON
MSG=$(escape_for_json "$MSG")

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${MSG}"
  }
}
EOF

exit 0
