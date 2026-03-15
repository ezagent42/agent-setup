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
