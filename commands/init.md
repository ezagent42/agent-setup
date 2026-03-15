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
