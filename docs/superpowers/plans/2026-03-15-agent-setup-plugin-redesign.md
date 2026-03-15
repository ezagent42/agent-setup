# Agent Setup Plugin Redesign — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert agent-setup from a template repository into a self-contained Claude Code plugin with its own marketplace.

**Architecture:** The repo becomes a Claude Code plugin (`agent-setup@agent-setup`) with hooks, commands, skills, and a marketplace manifest. Legacy infrastructure (AGENT_SETUP.md, update-from-template.sh, pnpm-based skill installation, hash tracking) is removed entirely. Plugin installation and project bootstrapping flow through `claude plugin install` and the `/agent-setup:init` command.

**Tech Stack:** Bash (hooks), Markdown (commands/skills), JSON (plugin metadata)

**Spec:** `docs/superpowers/specs/2026-03-15-agent-setup-plugin-redesign.md`

---

## Chunk 1: Cleanup & Plugin Foundation

### Task 1: Delete legacy infrastructure files

Remove all files that belong to the old template-based system. These are replaced by the plugin mechanism.

**Files:**
- Delete: `AGENT_SETUP.md`
- Delete: `update-from-template.sh`
- Delete: `skills-lock.json`
- Delete: `.mcp.env.example`
- Delete: `.claude/hooks/agent-setup.sh`
- Delete: `.claude/hooks/install-package.sh`
- Delete: `.claude/hooks/inject-superpowers.sh`
- Delete: `.claude/hooks/learning-output-style.sh`
- Delete: `.claude/hooks/enforce-tools.sh`
- Delete: `.claude/hooks/rtk-rewrite.sh`
- Delete: `.claude/commands/brainstorm.md`
- Delete: `.claude/commands/write-plan.md`
- Delete: `.claude/commands/execute-plan.md`
- Delete: `.claude/commands/commit.md`
- Delete: `.claude/commands/commit-push-pr.md`
- Delete: `.claude/commands/clean_gone.md`
- Delete: `.claude/commands/revise-claude-md.md`
- Delete: `.claude/agents/code-reviewer.md`
- Delete: `.claude/.template-checksums`
- Delete: `.claude/.template-version`

**Do NOT delete:**
- `.claude/settings.json` (will be updated in Task 3)
- `.claude/mcp.json` (MCP config, still needed for development)
- `.claude/RTK.md` (RTK documentation, still needed)
- `.claude/skills/` (83 skill directories — these are from external sources installed by pnpm. Delete the entire directory, as these skills will be re-installed as plugins)
- `claude.sh` (kept as-is for this repo; also used as template source in Task 11)
- `docs/` (keep specs and plans)
- `.gitignore` (will be updated in Task 13)

- [ ] **Step 1: Delete top-level legacy files**

```bash
cd /Users/h2oslabs/Workspace/ezagent42/agent-setup
rm -f AGENT_SETUP.md update-from-template.sh skills-lock.json .mcp.env.example
```

- [ ] **Step 2: Delete legacy hooks**

```bash
rm -f .claude/hooks/agent-setup.sh .claude/hooks/install-package.sh
rm -f .claude/hooks/inject-superpowers.sh .claude/hooks/learning-output-style.sh
rm -f .claude/hooks/enforce-tools.sh .claude/hooks/rtk-rewrite.sh
```

- [ ] **Step 3: Delete legacy commands and agents**

```bash
rm -f .claude/commands/brainstorm.md .claude/commands/write-plan.md .claude/commands/execute-plan.md
rm -f .claude/commands/commit.md .claude/commands/commit-push-pr.md .claude/commands/clean_gone.md
rm -f .claude/commands/revise-claude-md.md
rm -f .claude/agents/code-reviewer.md
```

- [ ] **Step 4: Delete template state files**

```bash
rm -f .claude/.template-checksums .claude/.template-version
```

- [ ] **Step 5: Delete externally-installed skills**

All 83 skill directories under `.claude/skills/` were installed from external sources (obra/superpowers, impeccable, etc.) via `pnpm dlx skills add`. In the new system, these are installed as plugins. Delete them all.

```bash
rm -rf .claude/skills/
```

- [ ] **Step 6: Clean empty directories**

```bash
rmdir .claude/hooks 2>/dev/null || true
rmdir .claude/commands 2>/dev/null || true
rmdir .claude/agents 2>/dev/null || true
```

- [ ] **Step 7: Verify cleanup**

```bash
ls -la .claude/
```

Expected: only `settings.json`, `mcp.json`, `RTK.md` remain.

- [ ] **Step 8: Verify only intended deletions are staged**

```bash
git status
```

Review the output. All changes should be deletions of the files listed above. No unintended files should be staged.

- [ ] **Step 9: Commit**

```bash
git add AGENT_SETUP.md update-from-template.sh skills-lock.json .mcp.env.example
git add .claude/hooks/ .claude/commands/ .claude/agents/
git add .claude/.template-checksums .claude/.template-version
git add .claude/skills/
git commit -m "chore: remove legacy template infrastructure

Delete AGENT_SETUP.md, update-from-template.sh, all legacy hooks,
externally-installed skills/commands/agents, and template state files.
These are replaced by the plugin mechanism in the next commits."
```

---

### Task 2: Create plugin metadata

Create `.claude-plugin/` directory with `plugin.json` and `marketplace.json`.

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Create plugin.json**

Write `.claude-plugin/plugin.json`:

```json
{
  "name": "agent-setup",
  "description": "Claude Code project bootstrapper — hooks, commands, and a marketplace for curated plugins",
  "author": "ezagent42"
}
```

- [ ] **Step 2: Create marketplace.json**

Write `.claude-plugin/marketplace.json`:

```json
{
  "plugins": [
    {
      "name": "agent-setup",
      "description": "Core plugin — hooks, commands, and project setup",
      "source": "./"
    },
    {
      "name": "superpowers",
      "description": "Skills for brainstorming, planning, TDD, debugging, and more",
      "source": { "source": "url", "url": "https://github.com/obra/superpowers" }
    },
    {
      "name": "impeccable",
      "description": "Design quality skills for frontend interfaces",
      "source": { "source": "url", "url": "https://github.com/pbakaus/impeccable" }
    },
    {
      "name": "product-manager-skills",
      "description": "Product management skills (wrapped from deanpeters/Product-Manager-Skills)",
      "source": "./wrappers/product-manager-skills"
    },
    {
      "name": "agent-browser",
      "description": "Browser automation CLI for AI agents",
      "source": { "source": "url", "url": "https://github.com/vercel-labs/agent-browser" }
    }
  ]
}
```

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/
git commit -m "feat: add plugin metadata and marketplace manifest

agent-setup is now a Claude Code plugin with its own marketplace.
Marketplace hosts: agent-setup (core), superpowers, impeccable,
product-manager-skills (wrapper), agent-browser."
```

---

### Task 3: Update settings.json

Strip old hook registrations from `.claude/settings.json`. Hooks are now registered via `hooks/hooks.json` in the plugin. Keep permissions and enabledPlugins.

**Files:**
- Modify: `.claude/settings.json`

- [ ] **Step 1: Read current settings.json**

Read `.claude/settings.json` to confirm current content.

- [ ] **Step 2: Update settings.json**

Replace the entire file. Remove all `hooks` entries (they're now in the plugin's `hooks/hooks.json`). Keep `permissions`, `enabledPlugins`, and `teammateMode`.

New content:

```json
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  },
  "enabledPlugins": {
    "playground@claude-plugins-official": true,
    "hookify@claude-plugins-official": true,
    "skill-creator@claude-plugins-official": true
  },
  "teammateMode": "auto"
}
```

- [ ] **Step 3: Commit**

```bash
git add .claude/settings.json
git commit -m "chore: remove hook registrations from settings.json

Hooks are now registered via the plugin's hooks/hooks.json.
Settings retains permissions, enabledPlugins, and teammateMode."
```

---

## Chunk 2: Plugin Hooks

### Task 4: Create hooks/hooks.json

Register all three hooks using `${CLAUDE_PLUGIN_ROOT}` for portable paths.

**Files:**
- Create: `hooks/hooks.json`

- [ ] **Step 1: Create hooks directory and hooks.json**

Write `hooks/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/enforce-tools.sh",
            "timeout": 5
          },
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/rtk-rewrite.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add hooks/hooks.json
git commit -m "feat: add plugin hook registration

Registers session-start (SessionStart) and enforce-tools + rtk-rewrite
(PreToolUse:Bash) via plugin's hooks.json."
```

---

### Task 5: Create hooks/session-start.sh

Lightweight health check — verifies the plugin is functional and outputs SessionStart JSON.

**Files:**
- Create: `hooks/session-start.sh`

- [ ] **Step 1: Write session-start.sh**

Write `hooks/session-start.sh`:

```bash
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
```

- [ ] **Step 2: Make executable**

```bash
chmod +x hooks/session-start.sh
```

- [ ] **Step 3: Test locally**

```bash
CLAUDE_PLUGIN_ROOT="$(pwd)" hooks/session-start.sh
```

Expected output:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Agent Setup plugin active"
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add hooks/session-start.sh
git commit -m "feat: add session-start health check hook

~15 lines replacing the previous ~300 line agent-setup.sh.
Verifies plugin integrity, outputs SessionStart JSON."
```

---

### Task 6: Create hooks/enforce-tools.sh

Move enforce-tools from `.claude/hooks/` to `hooks/` at repo root. The script content is identical to the old version — it's a self-contained PreToolUse hook that blocks pip/npm/npx and suggests uv/pnpm alternatives.

**Files:**
- Create: `hooks/enforce-tools.sh`

- [ ] **Step 1: Write enforce-tools.sh**

Write `hooks/enforce-tools.sh` with the exact same content as the old `.claude/hooks/enforce-tools.sh` (87 lines). The script is self-contained — no path changes needed since it reads from stdin and writes to stderr/stdout.

```bash
#!/usr/bin/env bash
# enforce-tools.sh — Block forbidden package managers, suggest alternatives.
# Configured as a PreToolUse hook for the Bash tool.

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[ -z "$COMMAND" ] && exit 0

# --- Python: pip → uv ---
# Match pip/pip3 only at command position (start of line or after shell operator)
if echo "$COMMAND" | grep -qE '(^|[;&|])[[:space:]]*(pip|pip3)([[:space:]]|$)'; then
  cat >&2 <<'MSG'
BLOCKED: pip is not allowed. Use uv instead.

  pip install foo       → uv pip install foo
  pip uninstall foo     → uv pip uninstall foo
  pip freeze            → uv pip freeze
  pip install -r req.txt → uv pip install -r req.txt

See CONTRIBUTING.md for details.
MSG
  exit 2
fi

if echo "$COMMAND" | grep -qE '(^|[;&|])[[:space:]]*(python|python3)[[:space:]]+-m[[:space:]]+pip([[:space:]]|$)'; then
  echo "BLOCKED: python -m pip is not allowed. Use 'uv pip' instead. See CONTRIBUTING.md." >&2
  exit 2
fi

# --- Python: python/python3 → uv run ---
# Block bare python/python3 invocations (allow inside uv run / uvx / curl pipes)
if echo "$COMMAND" | grep -qE '(^|[;&|])[[:space:]]*(python|python3)([[:space:]]|$)' \
   && ! echo "$COMMAND" | grep -qE '(uv run|uvx)'; then
  cat >&2 <<'MSG'
BLOCKED: Direct python/python3 is not allowed. Use uv run instead.

  python script.py        → uv run python script.py
  python -m pytest        → uv run pytest
  python3 -m pytest       → uv run pytest
  python3 -c "..."        → uv run python3 -c "..."

See CONTRIBUTING.md for details.
MSG
  exit 2
fi

# --- Python: .venv/bin/* → uv run ---
# Block direct .venv/bin/ invocations (should use uv run instead)
if echo "$COMMAND" | grep -qE '(^|[;&|])[[:space:]]*\.?/?\.venv/bin/'; then
  cat >&2 <<'MSG'
BLOCKED: Direct .venv/bin/ invocations are not allowed. Use uv run instead.

  .venv/bin/pytest        → uv run pytest
  .venv/bin/zchat         → uv run zchat
  .venv/bin/python        → uv run python

See CONTRIBUTING.md for details.
MSG
  exit 2
fi

# --- JavaScript: npm/npx → pnpm ---
if echo "$COMMAND" | grep -qE '(^|[;&|])[[:space:]]*npm([[:space:]]|$)'; then
  cat >&2 <<'MSG'
BLOCKED: npm is not allowed. Use pnpm instead.

  npm install           → pnpm install
  npm install foo       → pnpm add foo
  npm run dev           → pnpm run dev
  npm init              → pnpm create
  npm exec foo          → pnpm exec foo
  npm ci                → pnpm install --frozen-lockfile

See CONTRIBUTING.md for details.
MSG
  exit 2
fi

if echo "$COMMAND" | grep -qE '(^|[;&|])[[:space:]]*npx([[:space:]]|$)'; then
  echo "BLOCKED: npx is not allowed. Use 'pnpm dlx' (one-off) or 'pnpm exec' (local) instead. See CONTRIBUTING.md." >&2
  exit 2
fi

exit 0
```

- [ ] **Step 2: Make executable**

```bash
chmod +x hooks/enforce-tools.sh
```

- [ ] **Step 3: Test with a blocked command**

```bash
echo '{"tool_input":{"command":"pip install requests"}}' | hooks/enforce-tools.sh
echo "Exit code: $?"
```

Expected: stderr shows "BLOCKED: pip is not allowed", exit code 2.

- [ ] **Step 4: Test with an allowed command**

```bash
echo '{"tool_input":{"command":"uv pip install requests"}}' | hooks/enforce-tools.sh
echo "Exit code: $?"
```

Expected: no output, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add hooks/enforce-tools.sh
git commit -m "feat: add enforce-tools PreToolUse hook

Blocks pip/npm/npx/python, suggests uv/pnpm alternatives.
Moved from .claude/hooks/ to plugin's hooks/ directory."
```

---

### Task 7: Create hooks/rtk-rewrite.sh

Move rtk-rewrite from `.claude/hooks/` to `hooks/` at repo root. Self-contained — checks for rtk/jq availability internally.

**Files:**
- Create: `hooks/rtk-rewrite.sh`

- [ ] **Step 1: Write rtk-rewrite.sh**

Write `hooks/rtk-rewrite.sh` with the exact same content as the old `.claude/hooks/rtk-rewrite.sh` (62 lines). Self-contained, no path changes needed.

```bash
#!/usr/bin/env bash
# rtk-hook-version: 2
# RTK Claude Code hook — rewrites commands to use rtk for token savings.
# Requires: rtk >= 0.23.0, jq
#
# This is a thin delegating hook: all rewrite logic lives in `rtk rewrite`,
# which is the single source of truth (src/discover/registry.rs).
# To add or change rewrite rules, edit the Rust registry — not this file.

if ! command -v jq &>/dev/null; then
  echo "[rtk] WARNING: jq is not installed. Hook cannot rewrite commands. Install jq: https://jqlang.github.io/jq/download/" >&2
  exit 0
fi

if ! command -v rtk &>/dev/null; then
  echo "[rtk] WARNING: rtk is not installed or not in PATH. Hook cannot rewrite commands. Install: https://github.com/rtk-ai/rtk#installation" >&2
  exit 0
fi

# Version guard: rtk rewrite was added in 0.23.0.
# Older binaries: warn once and exit cleanly (no silent failure).
RTK_VERSION=$(rtk --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [ -n "$RTK_VERSION" ]; then
  MAJOR=$(echo "$RTK_VERSION" | cut -d. -f1)
  MINOR=$(echo "$RTK_VERSION" | cut -d. -f2)
  # Require >= 0.23.0
  if [ "$MAJOR" -eq 0 ] && [ "$MINOR" -lt 23 ]; then
    echo "[rtk] WARNING: rtk $RTK_VERSION is too old (need >= 0.23.0). Upgrade: cargo install rtk" >&2
    exit 0
  fi
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$CMD" ]; then
  exit 0
fi

# Delegate all rewrite logic to the Rust binary.
# rtk rewrite exits 1 when there's no rewrite — hook passes through silently.
REWRITTEN=$(rtk rewrite "$CMD" 2>/dev/null) || exit 0

# No change — nothing to do.
if [ "$CMD" = "$REWRITTEN" ]; then
  exit 0
fi

ORIGINAL_INPUT=$(echo "$INPUT" | jq -c '.tool_input')
UPDATED_INPUT=$(echo "$ORIGINAL_INPUT" | jq --arg cmd "$REWRITTEN" '.command = $cmd')

jq -n \
  --argjson updated "$UPDATED_INPUT" \
  '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "allow",
      "permissionDecisionReason": "RTK auto-rewrite",
      "updatedInput": $updated
    }
  }'
```

- [ ] **Step 2: Make executable**

```bash
chmod +x hooks/rtk-rewrite.sh
```

- [ ] **Step 3: Test (rtk not installed case)**

If `rtk` is not installed on the test machine:

```bash
echo '{"tool_input":{"command":"git status"}}' | hooks/rtk-rewrite.sh
echo "Exit code: $?"
```

Expected: stderr warning about rtk not installed, exit code 0 (graceful skip).

- [ ] **Step 4: Commit**

```bash
git add hooks/rtk-rewrite.sh
git commit -m "feat: add rtk-rewrite PreToolUse hook

Delegates command rewriting to rtk for token savings.
Checks rtk/jq availability internally; skips gracefully if missing.
Moved from .claude/hooks/ to plugin's hooks/ directory."
```

---

## Chunk 3: Commands

### Task 8: Create commands/init.md

The `/agent-setup:init` command — interactive project setup. This is a Claude Code command file (instructions for Claude, not an executable script).

**Files:**
- Create: `commands/init.md`

- [ ] **Step 1: Write init.md**

Write `commands/init.md`:

```markdown
---
description: Initialize or update agent-setup configuration for this project
argument-hint: Optional — "migrate" to auto-detect and migrate from old template system
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "AskUserQuestion", "Agent"]
---

# /agent-setup:init — Project Setup

Set up Claude Code plugins, hooks, and project launcher for this project.

## Step 1: Detect Project State

Check the current project for:
1. Existing `AGENT_SETUP.md` at project root → **migration mode**
2. Existing `claude.sh` at project root → **already bootstrapped**
3. Neither → **fresh setup**

```bash
ls -la "$CLAUDE_PROJECT_DIR/AGENT_SETUP.md" "$CLAUDE_PROJECT_DIR/claude.sh" 2>/dev/null || echo "Fresh project"
```

## Step 2: Migration (if AGENT_SETUP.md exists)

If `AGENT_SETUP.md` is found, parse it and map old entries to new plugins:

| Old Entry (Skills section) | New Plugin |
|---|---|
| `obra/superpowers` | `superpowers@agent-setup` |
| `deanpeters/Product-Manager-Skills` | `product-manager-skills@agent-setup` |
| `pbakaus/impeccable` | `impeccable@agent-setup` |
| `vercel-labs/agent-browser` | `agent-browser@agent-setup` |
| `anthropics/claude-plugins-official -s claude-md-improver` | `claude-md-improver@claude-plugins-official` |
| `anthropics/claude-plugins-official -s claude-automation-recommender` | `claude-automation-recommender@claude-plugins-official` |

| Old Entry (Plugins section) | New Plugin |
|---|---|
| `hookify@claude-plugins-official` | unchanged |
| `skill-creator@claude-plugins-official` | unchanged |
| `playground@claude-plugins-official` | unchanged |

| Old Hook | New Plugin |
|---|---|
| `learning-output-style.sh` | `learning-output-style@claude-plugins-official` |

Pre-select these plugins in the multi-select below. Inform the user about the migration.

## Step 3: Plugin Selection

Use AskUserQuestion with multi-select to let the user choose which plugins to install:

**agent-setup marketplace plugins:**
- `superpowers@agent-setup` — Brainstorming, planning, TDD, debugging skills (default: on)
- `product-manager-skills@agent-setup` — Product management skills
- `impeccable@agent-setup` — Design quality skills
- `agent-browser@agent-setup` — Browser automation for AI agents

**Official marketplace plugins (claude-plugins-official):**
- `hookify@claude-plugins-official` — User-configurable hooks from rule files
- `playground@claude-plugins-official` — Interactive playground
- `skill-creator@claude-plugins-official` — Create and manage skills
- `claude-md-improver@claude-plugins-official` — Audit and improve CLAUDE.md files
- `claude-automation-recommender@claude-plugins-official` — Recommend automations
- `learning-output-style@claude-plugins-official` — Educational output style

**Other recommended plugins (not managed by agent-setup, but shown for discoverability):**
- `commit-commands@claude-plugins-official` — Git commit/push/PR commands
- `claude-md-management@claude-plugins-official` — CLAUDE.md management

## Step 4: Generate claude.sh

If `claude.sh` does not exist at the project root, generate it from the template.

Read the template from `${CLAUDE_PLUGIN_ROOT}/templates/claude.sh.tpl` and write it to `$CLAUDE_PROJECT_DIR/claude.sh`. Make it executable.

If `claude.sh` already exists, skip this step and inform the user.

## Step 5: Update .gitignore

Read `${CLAUDE_PLUGIN_ROOT}/templates/gitignore-entries.txt`. For each line, check if it already exists in `.gitignore`. Append any missing entries.

## Step 6: Install Selected Plugins

For each selected plugin, run:

```bash
claude plugin install <name>@<marketplace> --scope project
```

Track successes and failures. If any installation fails, report it but continue with the rest.

**IMPORTANT:** Do NOT clean up old files until all plugins are confirmed installed.

## Step 7: Clean Up Old Files (Migration Only)

If migrating from the old system AND all plugins installed successfully:

Ask the user for confirmation, then delete:
- `AGENT_SETUP.md`
- `.agents/` directory
- `update-from-template.sh`
- `.claude/hooks/agent-setup.sh`
- `.claude/hooks/install-package.sh`
- `.claude/hooks/inject-superpowers.sh`
- `.claude/hooks/learning-output-style.sh`
- `skills-lock.json`
- `.claude/.template-checksums`
- `.claude/.template-version`

Also remove old hook entries from `.claude/settings.json` if present (entries referencing the deleted hook files).

Print a notice about renamed commands:
- `brainstorm.md` → use `brainstorming` skill
- `write-plan.md` → use `writing-plans` skill
- `execute-plan.md` → use `executing-plans` skill

## Step 8: Output Summary

Print a summary of what was done:
- Plugins installed (with names)
- Files generated (claude.sh, .gitignore updates)
- Old files cleaned up (if migration)
- Any failures or warnings

Remind: "Run `./claude.sh` to start a new session with all plugins active."

## If $ARGUMENTS is "migrate"

Skip the plugin selection step and auto-select all plugins found in the existing AGENT_SETUP.md. Proceed directly to installation and cleanup.
```

- [ ] **Step 2: Commit**

```bash
git add commands/init.md
git commit -m "feat: add /agent-setup:init command

Interactive project setup: detects project state, offers plugin selection
(multi-select), generates claude.sh, installs plugins, handles migration
from the old template system with safe cleanup."
```

---

### Task 9: Create commands/reset.md

The `/agent-setup:reset` command — cleanup and re-initialization.

**Files:**
- Create: `commands/reset.md`

- [ ] **Step 1: Write reset.md**

Write `commands/reset.md`:

```markdown
---
description: Reset or clean up agent-setup configuration for this project
argument-hint: Optional — "full" for full cleanup, "re-init" for cleanup + re-init
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "AskUserQuestion", "Skill"]
---

# /agent-setup:reset — Reset Project Configuration

Clean up agent-setup managed files and optionally re-initialize.

## Step 1: Scan Project State

Detect all agent-setup related artifacts:

1. **Installed plugins** — run `claude plugin list` and identify plugins from agent-setup marketplace or claude-plugins-official
2. **Generated files** — check for:
   - `claude.sh` at project root
   - `.gitignore` entries added by agent-setup
3. **Legacy files** (from old template system) — check for:
   - `AGENT_SETUP.md`
   - `.agents/` directory
   - `update-from-template.sh`
   - Old hooks in `.claude/hooks/` (agent-setup.sh, install-package.sh, inject-superpowers.sh, learning-output-style.sh)
   - `skills-lock.json`
   - `.claude/.template-checksums`, `.claude/.template-version`

## Step 2: Present Current State

Show the user what was found: installed plugins, generated files, and any legacy files.

## Step 3: Select Operation

If `$ARGUMENTS` is provided, map directly:
- `"full"` → Full cleanup
- `"re-init"` → Re-init (full cleanup then /agent-setup:init)

Otherwise, use AskUserQuestion with single-select:

- **Force health re-check** — Clear any cached plugin state. The session-start hook will re-validate on next launch.
- **Uninstall all managed plugins** — Run `claude plugin uninstall` for each agent-setup managed plugin. Does not delete generated files.
- **Full cleanup** — Uninstall all plugins + delete generated files (claude.sh, .gitignore entries). Returns project to pre-init state.
- **Re-init** — Full cleanup followed by automatic `/agent-setup:init`.

## Step 4: Execute

Based on selection:

### Force health re-check
No destructive action. Inform the user that the next session start will re-validate plugin health.

### Uninstall all managed plugins
For each managed plugin found in Step 1:
```bash
claude plugin uninstall <name>@<marketplace> --scope project
```
Report results.

### Full cleanup
1. Uninstall all managed plugins (as above)
2. Delete generated files:
   - `claude.sh` (ask confirmation — user may have customized it)
   - Legacy files listed in Step 1
3. Remove old hook entries from `.claude/settings.json` if any remain
4. Do NOT delete `.claude/settings.json`, `.claude/mcp.json`, or user-created `.claude/` content

### Re-init
1. Execute full cleanup (as above)
2. Invoke `/agent-setup:init` using the Skill tool

## Step 5: Summary

Print what was done and any remaining manual steps.
```

- [ ] **Step 2: Commit**

```bash
git add commands/reset.md
git commit -m "feat: add /agent-setup:reset command

Cleanup and re-initialization: scans project state, offers four
operations (health re-check, uninstall, full cleanup, re-init).
Safe — never deletes user-created .claude/ content."
```

---

## Chunk 4: Skill, Templates & Wrapper

### Task 10: Create skills/agent-setup/SKILL.md

Renamed from `env-setup`. Updated to reflect the plugin-based system (no more AGENT_SETUP.md, pnpm skills add, etc.).

**Files:**
- Create: `skills/agent-setup/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

Write `skills/agent-setup/SKILL.md`:

```markdown
---
name: agent-setup
description: Guide for managing Claude Code project configuration using the agent-setup plugin. Use when the user asks about adding plugins, configuring hooks, setting up MCP servers, creating slash commands, or asks about claude.sh, project bootstrapping, or "how do I add X to my Claude Code setup".
---

# Agent Setup Guide

This skill helps you manage Claude Code infrastructure in projects that use the `agent-setup` plugin.

## Quick Reference

| What to do | How |
|---|---|
| Bootstrap a new project | `/agent-setup:init` |
| Add a plugin | `claude plugin install <name>@<marketplace> --scope project` |
| Remove a plugin | `claude plugin uninstall <name>@<marketplace> --scope project` |
| Reset/cleanup config | `/agent-setup:reset` |
| Add a project-local skill | Create `.claude/skills/<name>/SKILL.md` |
| Add a hook | Create script + register in `.claude/settings.json` or via hookify plugin |
| Add a subagent | Create `.claude/agents/<name>.md` |
| Add a slash command | Create `.claude/commands/<name>.md` |
| Add an MCP server | Edit `.claude/mcp.json` |
| Set MCP secrets | Edit `.mcp.env` (gitignored, loaded by `claude.sh`) |
| User-local overrides | Edit `claude.local.sh` (gitignored, loaded by `claude.sh`) |

---

## Plugin Management

### Available marketplaces

**agent-setup** — curated plugins for development workflows:
- `superpowers@agent-setup` — brainstorming, planning, TDD, debugging
- `impeccable@agent-setup` — design quality skills
- `product-manager-skills@agent-setup` — product management
- `agent-browser@agent-setup` — browser automation

**claude-plugins-official** — Anthropic's official plugins:
- `hookify` — user-configurable hooks from rule files
- `playground` — interactive playground
- `skill-creator` — create and manage skills
- `claude-md-improver` — audit CLAUDE.md files
- `claude-automation-recommender` — recommend automations
- `learning-output-style` — educational output style
- `commit-commands` — git commit/push/PR commands
- `claude-md-management` — CLAUDE.md management

### Install a plugin

```bash
claude plugin install superpowers@agent-setup --scope project
```

### List installed plugins

```bash
claude plugin list
```

### Update plugins

```bash
claude plugin update <name>@<marketplace>
```

---

## Project-Local Skills

Create a skill directory in `.claude/skills/`:

```
.claude/skills/my-skill/
└── SKILL.md
```

SKILL.md format:
```markdown
---
name: my-skill
description: When to trigger this skill and what it does
---

# My Skill

Instructions for Claude when this skill is invoked...
```

Skills are discovered immediately — no restart needed.

---

## Hooks

Hooks are shell scripts triggered by Claude Code events. Register them in `.claude/settings.json` or use the hookify plugin for rule-based hooks.

### Hook types

| Event | When it fires | Common use |
|---|---|---|
| `SessionStart` | Session begins | Inject context, check tools |
| `PreToolUse` | Before a tool runs | Rewrite commands, block operations |
| `PostToolUse` | After a tool runs | Validate output |
| `Stop` | Session ends | Cleanup |

### Creating a hook

1. Write the script (e.g., `.claude/hooks/my-hook.sh`)
2. Make it executable: `chmod +x .claude/hooks/my-hook.sh`
3. Register in `.claude/settings.json`

For rule-based hooks (simpler, no scripting needed), use the hookify plugin: `/hookify`

---

## MCP Servers

Edit `.claude/mcp.json` to add MCP servers:

```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "@package/mcp-server"],
      "env": { "API_KEY": "" }
    }
  }
}
```

Secrets go in `.mcp.env` (gitignored, auto-exported by `claude.sh`).

---

## Environment Configuration

### `claude.local.sh` (user-specific, gitignored)

```bash
export ALL_PROXY=http://127.0.0.1:7897
export ANTHROPIC_API_KEY=sk-ant-...
```

Sourced by `claude.sh` on every launch.

### `.mcp.env` (MCP secrets, gitignored)

```bash
CONTEXT7_API_KEY=your-key
GITHUB_TOKEN=ghp_...
```

Auto-exported by `claude.sh` before starting Claude.
```

- [ ] **Step 2: Commit**

```bash
git add skills/agent-setup/
git commit -m "feat: add agent-setup skill (renamed from env-setup)

Updated to reflect plugin-based system. Covers plugin management,
project-local skills, hooks, MCP servers, and environment config.
No references to legacy AGENT_SETUP.md or pnpm-based installation."
```

---

### Task 11: Create templates/

Templates used by `/agent-setup:init` to generate project files.

**Files:**
- Create: `templates/claude.sh.tpl`
- Create: `templates/gitignore-entries.txt`

- [ ] **Step 1: Create claude.sh.tpl**

Copy the current `claude.sh` (361 lines) as `templates/claude.sh.tpl`. Add a bootstrap section that checks for the agent-setup plugin and installs it if missing.

Read the current `claude.sh`, then write `templates/claude.sh.tpl` with one addition. Insert the bootstrap block after the tmux pre-flight check and before the flags section. The surrounding context in `claude.sh`:

```bash
# ... (existing pre-flight checks above)

if ! command -v tmux &> /dev/null; then        # ← line 63
    echo "❌ tmux not found!"                    # ← line 64
    echo ""                                      # ← line 65
    echo "Please install tmux first:"            # ← line 66
    echo "  brew install tmux"                   # ← line 67
    exit 1                                       # ← line 68
fi                                               # ← line 69
                                                 # ← INSERT BOOTSTRAP BLOCK HERE
# ============================================   # ← line 71 (currently)
# Flags per mode                                 # ← line 72
```

The bootstrap block to insert:

```bash
# ============================================
# Agent Setup plugin bootstrap
# ============================================

if ! claude plugin list 2>/dev/null | grep -q "agent-setup@agent-setup"; then
    echo "📦 Installing agent-setup plugin..."
    claude plugin install agent-setup@agent-setup --scope project 2>/dev/null || {
        echo "⚠️  Could not install agent-setup plugin. Run manually:"
        echo "  claude plugin install agent-setup@agent-setup --scope project"
    }
    echo ""
fi
```

- [ ] **Step 2: Make template executable**

```bash
chmod +x templates/claude.sh.tpl
```

- [ ] **Step 3: Create gitignore-entries.txt**

Write `templates/gitignore-entries.txt`:

```
# Agent Setup runtime (gitignored)
.agents/

# User-local launcher overrides
claude.local.sh

# MCP server secrets (API keys, tokens)
.mcp.env
```

- [ ] **Step 4: Commit**

```bash
git add templates/
git commit -m "feat: add templates for project bootstrapping

claude.sh.tpl: launcher with agent-setup plugin auto-bootstrap.
gitignore-entries.txt: standard gitignore entries for agent-setup projects."
```

---

### Task 12: Create wrappers/product-manager-skills/

Wrapper plugin for deanpeters/Product-Manager-Skills which lacks native `.claude-plugin` support.

**Files:**
- Create: `wrappers/product-manager-skills/.claude-plugin/plugin.json`
- Create: `wrappers/product-manager-skills/README.md`

- [ ] **Step 1: Create wrapper plugin.json**

Write `wrappers/product-manager-skills/.claude-plugin/plugin.json`:

```json
{
  "name": "product-manager-skills",
  "description": "Product management skills — wrapped from deanpeters/Product-Manager-Skills",
  "author": "ezagent42 (wrapper), deanpeters (upstream)",
  "upstream": {
    "repo": "https://github.com/deanpeters/Product-Manager-Skills",
    "commit": ""
  }
}
```

Note: `upstream.commit` will be populated when skills are synced from the upstream repo.

- [ ] **Step 2: Create wrapper README**

Write `wrappers/product-manager-skills/README.md`:

```markdown
# product-manager-skills (wrapper)

This is a wrapper plugin for [deanpeters/Product-Manager-Skills](https://github.com/deanpeters/Product-Manager-Skills) which does not yet have native `.claude-plugin` support.

## Maintenance

To update from upstream:
1. Clone or fetch latest from `https://github.com/deanpeters/Product-Manager-Skills`
2. Copy skill files into `skills/` directory here
3. Update `upstream.commit` in `.claude-plugin/plugin.json`
4. Commit and push

When the upstream repo adds native `.claude-plugin` support, this wrapper should be removed and replaced with a `source: url` entry in the marketplace manifest.
```

- [ ] **Step 3: Create skills directory placeholder**

```bash
mkdir -p wrappers/product-manager-skills/skills
touch wrappers/product-manager-skills/skills/.gitkeep
```

The skills content will be populated from the upstream repo as a separate maintenance task (see `wrappers/product-manager-skills/README.md` for instructions). For now, the `.gitkeep` placeholder ensures the directory is tracked.

- [ ] **Step 4: Commit**

```bash
git add wrappers/
git commit -m "feat: add product-manager-skills wrapper plugin

Wrapper for deanpeters/Product-Manager-Skills (no native .claude-plugin).
Skills directory placeholder — content to be synced from upstream."
```

---

## Chunk 5: Finalization

### Task 13: Update .gitignore, CLAUDE.md, README.md

Update project files to reflect the new plugin-based structure.

**Files:**
- Modify: `.gitignore`
- Modify: `CLAUDE.md`
- Modify: `README.md`

- [ ] **Step 1: Update .gitignore**

Read current `.gitignore`, then replace with:

```
# Agent Setup runtime (gitignored)
.agents/

# User-local launcher overrides
claude.local.sh

# MCP server secrets (API keys, tokens)
.mcp.env
```

Remove legacy entries: `.agents/package-hooks/`, `.agents/packages/`, `.claude/.template-checksums`, `.claude/.template-version` — those are no longer relevant.

- [ ] **Step 2: Update CLAUDE.md**

Read current `CLAUDE.md`, then replace with:

```markdown
# Project

This is the **agent-setup** Claude Code plugin and marketplace.

## Structure

- `.claude-plugin/` — plugin metadata and marketplace manifest
- `commands/` — slash commands (`/agent-setup:init`, `/agent-setup:reset`)
- `hooks/` — SessionStart and PreToolUse hooks
- `skills/agent-setup/` — setup guidance skill
- `templates/` — project bootstrapping templates (claude.sh, gitignore)
- `wrappers/` — wrapper plugins for repos without native `.claude-plugin` support

## Conventions

- Python packages: use `uv`, not `pip`
- JavaScript packages: use `pnpm`, not `npm`/`npx`
- CLI commands are rewritten through RTK for token savings (if installed)

## Development

To work on this plugin locally, install it in project scope:
```bash
claude plugin install agent-setup@agent-setup --scope project
```
```

- [ ] **Step 3: Update README.md**

Write the full `README.md`:

```markdown
# agent-setup

Claude Code plugin and marketplace for project bootstrapping.

## Install

**Option A — from marketplace:**

```bash
claude plugin install agent-setup@agent-setup --scope project
```

Then run `/agent-setup:init` to configure your project.

**Option B — via claude.sh:**

Copy `claude.sh` from a configured project (or download from this repo). On first run, it auto-installs the agent-setup plugin.

## Commands

| Command | Description |
|---|---|
| `/agent-setup:init` | Interactive project setup — select plugins, generate claude.sh |
| `/agent-setup:reset` | Clean up or re-initialize project configuration |

## Marketplace Plugins

**agent-setup marketplace:**

| Plugin | Description |
|---|---|
| `superpowers@agent-setup` | Brainstorming, planning, TDD, debugging skills |
| `impeccable@agent-setup` | Design quality skills |
| `product-manager-skills@agent-setup` | Product management skills |
| `agent-browser@agent-setup` | Browser automation for AI agents |

These are installed via `/agent-setup:init` or manually:

```bash
claude plugin install superpowers@agent-setup --scope project
```

## Adding to the Marketplace

To add a plugin to the agent-setup marketplace:

1. If the repo has native `.claude-plugin` support, add a `source: url` entry to `.claude-plugin/marketplace.json`
2. If the repo lacks `.claude-plugin` support, create a wrapper in `wrappers/` with plugin metadata
3. Submit a PR

## License

MIT
```

- [ ] **Step 4: Commit**

```bash
git add .gitignore CLAUDE.md README.md
git commit -m "docs: update project files for plugin-based architecture

Updated .gitignore (remove template state entries), CLAUDE.md (describe
plugin structure), and README.md (installation and usage guide)."
```

---

### Task 14: Final validation

Verify the complete plugin structure is correct.

**Files:**
- Verify: all files in the new structure

- [ ] **Step 1: Verify directory structure**

```bash
find . -not -path './.git/*' -not -path './.agents/*' -not -path './docs/*' -not -path './.claude/plugins/*' | sort
```

Expected structure:
```
.
./.claude-plugin/marketplace.json
./.claude-plugin/plugin.json
./.claude/mcp.json
./.claude/RTK.md
./.claude/settings.json
./CLAUDE.md
./claude.sh
./commands/init.md
./commands/reset.md
./hooks/enforce-tools.sh
./hooks/hooks.json
./hooks/rtk-rewrite.sh
./hooks/session-start.sh
./README.md
./skills/agent-setup/SKILL.md
./templates/claude.sh.tpl
./templates/gitignore-entries.txt
./wrappers/product-manager-skills/.claude-plugin/plugin.json
./wrappers/product-manager-skills/README.md
./wrappers/product-manager-skills/skills/
./.gitignore
```

- [ ] **Step 2: Verify hooks are executable**

```bash
ls -la hooks/*.sh
```

All `.sh` files should have execute permission.

- [ ] **Step 3: Verify JSON files are valid**

```bash
jq . .claude-plugin/plugin.json && echo "plugin.json: OK"
jq . .claude-plugin/marketplace.json && echo "marketplace.json: OK"
jq . hooks/hooks.json && echo "hooks.json: OK"
jq . .claude/settings.json && echo "settings.json: OK"
```

All should parse without errors.

- [ ] **Step 4: Test session-start hook**

```bash
CLAUDE_PLUGIN_ROOT="$(pwd)" hooks/session-start.sh
```

Expected: valid JSON with "Agent Setup plugin active".

- [ ] **Step 5: Final commit (if any unstaged changes)**

```bash
git status
# If clean, skip. If changes remain:
git add -A
git commit -m "chore: final cleanup for plugin redesign"
```

- [ ] **Step 6: Inform user**

Print:
```
Plugin redesign complete. The agent-setup repo is now a Claude Code plugin.

To activate in this repo:
  1. Restart Claude Code via ./claude.sh
  2. Run /agent-setup:init to re-bootstrap

To install in other projects:
  claude plugin install agent-setup@agent-setup --scope project
```
