# Agent Setup Plugin Redesign

## Problem

Agent-setup currently operates as a **template repository** with shell scripts that manage skills, tools, plugins, and packages through multiple mechanisms (`pnpm dlx skills add`, `claude plugin install`, custom `install-package.sh`). This creates complexity:

- Three distinct installation mechanisms with separate hash tracking
- A `merge_section()` function to additively sync template updates
- `update-from-template.sh` (510 lines) for infrastructure self-updates
- `AGENT_SETUP.md` as a declarative config that overlaps with the plugin system's own tracking

Claude Code has a native plugin/marketplace system that can replace all of this. The redesign converts agent-setup from a template repo into a **self-contained Claude Code plugin with its own marketplace**.

## Design

### Architecture

Agent-setup becomes a single Claude Code plugin (`agent-setup@agent-setup`) that:

1. Hosts a marketplace for wrapper plugins (repos without native `.claude-plugin` support)
2. Provides `/agent-setup:init` and `/agent-setup:reset` commands
3. Ships three hooks: `session-start.sh`, `enforce-tools.sh`, `rtk-rewrite.sh`
4. Ships one skill: `skills/agent-setup/SKILL.md` (renamed from `env-setup`)

### Repo Structure

```
agent-setup/
├── .claude-plugin/
│   ├── plugin.json            # Plugin metadata
│   └── marketplace.json       # Marketplace manifest
├── commands/
│   ├── init.md                # /agent-setup:init
│   └── reset.md               # /agent-setup:reset
├── hooks/
│   ├── hooks.json             # Hook registration
│   ├── session-start.sh       # SessionStart health check
│   ├── enforce-tools.sh       # PreToolUse:Bash — block pip/npm, suggest uv/pnpm
│   └── rtk-rewrite.sh         # PreToolUse:Bash — delegate to rtk rewrite
├── skills/
│   └── agent-setup/SKILL.md   # Usage guide for the plugin
├── templates/
│   ├── claude.sh.tpl          # Project launcher template
│   └── gitignore-entries.txt  # Entries to append to .gitignore
├── wrappers/
│   └── product-manager-skills/  # Wrapper plugin for deanpeters/Product-Manager-Skills
│       ├── .claude-plugin/
│       │   └── plugin.json
│       └── skills/
│           └── ... (symlinks or copies)
└── README.md
```

### Marketplace Manifest

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
      "description": "Wrapper for obra/superpowers skills",
      "source": { "source": "url", "url": "https://github.com/obra/superpowers" }
    },
    {
      "name": "impeccable",
      "description": "Wrapper for pbakaus/impeccable skills",
      "source": { "source": "url", "url": "https://github.com/pbakaus/impeccable" }
    },
    {
      "name": "product-manager-skills",
      "description": "Wrapper for deanpeters/Product-Manager-Skills",
      "source": "./wrappers/product-manager-skills"
    },
    {
      "name": "agent-browser",
      "description": "Browser automation for AI agents",
      "source": { "source": "url", "url": "https://github.com/vercel-labs/agent-browser" }
    }
  ]
}
```

**Source format** follows Claude Code's marketplace schema:
- `"source": "./"` — plugin lives in this repo (string shorthand for local path)
- `"source": {"source": "url", "url": "..."}` — plugin lives at a remote URL (object with `source` discriminator)
- Both formats are valid per Claude Code's plugin system; local wrappers use the string form, remote repos use the object form.

**Routing rules:**
- Repos that already have `.claude-plugin` format (superpowers, impeccable) use `source: url` — Claude fetches directly from the upstream repo.
- Repos without `.claude-plugin` support (Product-Manager-Skills) get a local wrapper in `wrappers/` with the necessary plugin metadata.
- Official plugins (hookify, playground, skill-creator, etc.) are installed from `claude-plugins-official` marketplace — not wrapped here.

### Hooks

All hooks use `${CLAUDE_PLUGIN_ROOT}` for portable paths in `hooks/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh",
        "timeout": 30
      }]
    }],
    "PreToolUse": [{
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
    }]
  }
}
```

**Tool checks are internal to hooks:**
- `rtk-rewrite.sh` checks if `rtk` is in PATH itself; skips silently if missing
- `enforce-tools.sh` checks for `uv`/`pnpm` availability itself

### Bootstrapping Paths

Two complementary paths to install agent-setup:

```
Path A: Marketplace first
  claude plugin install agent-setup@agent-setup
  → /agent-setup:init
  → generates claude.sh + project config files

Path B: claude.sh first
  Copy/download claude.sh to project
  → First run: claude.sh detects agent-setup not installed
    (checks: claude plugin list --json | grep agent-setup)
  → Runs: claude plugin install agent-setup@agent-setup --scope project
  → Starts claude session
  → Prompts user to run /agent-setup:init (or session-start.sh triggers prompt)
```

**`claude.sh` bootstrap detection:** The script checks whether agent-setup is already installed by inspecting `claude plugin list` output before launching the interactive session. This ensures the install step runs non-interactively before `claude` takes over the terminal.

### `/agent-setup:init` Command

Interactive setup that installs plugins and generates project config.

**Flow:**

1. **Detect project state** — check for existing `.claude/` config, old `AGENT_SETUP.md`, etc.
2. **If migrating from old system** — parse existing `AGENT_SETUP.md`, map entries to new plugins (see Migration section)
3. **Select plugins** (multi-select):
   - Core hooks (enforce-tools, rtk-rewrite) — default on
   - Superpowers skills (obra/superpowers) — default on
   - Product Manager skills (wrapper)
   - Impeccable (pbakaus/impeccable)
   - Agent Browser (vercel-labs/agent-browser)
   - Official plugins: hookify, playground, skill-creator, claude-md-improver, claude-automation-recommender, learning-output-style
4. **Generate files:**
   - `claude.sh` (if not present)
   - `.gitignore` entries
5. **Execute installation** — `claude plugin install` for each selected plugin
6. **Output summary**

**Idempotent:** Re-running only adds missing items, does not break existing config.

### `/agent-setup:reset` Command

Cleanup and re-initialization.

**Flow:**

1. **Scan project** — detect all agent-setup-managed files and installed plugins
2. **Show current state** — list installed plugins and config files
3. **Select operation** (single-select):
   - **Force health re-check** — clear cached state, session-start.sh re-validates on next launch
   - **Uninstall all plugins** — `claude plugin uninstall` for each
   - **Full cleanup** — remove all generated files + uninstall plugins
   - **Re-init** — full cleanup then auto-run `/agent-setup:init`
4. **Execute and summarize**

**Safety:** Does not delete user-created `.claude/` content. Prompts for confirmation before deleting files with potential user customizations.

### `session-start.sh` Logic

Lightweight health check on each session start. No longer parses a config file or installs plugins.

**Responsibilities:**
- Verify agent-setup plugin is functional (check `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json` exists)
- Output JSON status in SessionStart hook format

**Pseudocode:**
```bash
#!/usr/bin/env bash
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

**What it does NOT do (compared to current system):**
- No `AGENT_SETUP.md` parsing
- No `pnpm dlx skills add`
- No `claude plugin install` (that's `/init`'s job)
- No `merge_section()` template merging
- No `git ls-remote` version checking
- No multi-hash tracking

**~20 lines of bash** vs current ~300 lines.

### AGENT_SETUP.md — Abolished

The current `AGENT_SETUP.md` declarative config file is removed entirely. Rationale:

- `## Skills` → replaced by plugin installation
- `## Plugins` → `claude plugin install` manages this natively
- `## Packages` → wrapper plugins replace this
- `## Tools` → each hook checks its own dependencies internally
- `## Project Skills` → Claude Code auto-discovers `.claude/skills/`

**Git is the declarative config.** When `/init` installs plugins with `--scope project`, the resulting files (hooks, commands, skills) are written to `.claude/` in the project directory and committed to git. New team members get them automatically on clone.

### Migration Path

For existing projects using the template-based system:

1. **Install agent-setup plugin** (via `claude.sh` or manual)
2. **Run `/agent-setup:init`** — detects existing `AGENT_SETUP.md`, maps entries:

| Old Entry | New Plugin |
|-----------|-----------|
| `obra/superpowers` (Skills) | `superpowers@agent-setup` |
| `deanpeters/Product-Manager-Skills` (Skills) | `product-manager-skills@agent-setup` |
| `pbakaus/impeccable` (Skills) | `impeccable@agent-setup` |
| `vercel-labs/agent-browser` (Skills) | `agent-browser@agent-setup` (wrapper or `source: url` if repo has `.claude-plugin`) |
| `anthropics/claude-plugins-official -s claude-md-improver` (Skills) | `claude-md-improver@claude-plugins-official` (native plugin) |
| `anthropics/claude-plugins-official -s claude-automation-recommender` (Skills) | `claude-automation-recommender@claude-plugins-official` (native plugin) |
| `learning-output-style.sh` (Hook) | `learning-output-style@claude-plugins-official` (native plugin) |
| `hookify@claude-plugins-official` (Plugins) | unchanged |
| `skill-creator@claude-plugins-official` (Plugins) | unchanged |
| `playground@claude-plugins-official` (Plugins) | unchanged |

3. **Old files become redundant** — `/init` prompts to clean up:
   - `AGENT_SETUP.md`
   - `.agents/` directory (hashes, packages)
   - `update-from-template.sh`
   - `.claude/hooks/agent-setup.sh` (old version)
   - `.claude/hooks/install-package.sh`
   - `.claude/hooks/inject-superpowers.sh`
   - `.claude/hooks/learning-output-style.sh`

### Self-Cleanup of agent-setup Repo

This is a **developer task** performed as part of the implementation PR, not a runtime operation:

1. **Delete all current Claude Code config** — remove existing `.claude/hooks/`, `AGENT_SETUP.md`, `update-from-template.sh`, `.agents/`, and all legacy infrastructure from the agent-setup repo itself
2. **Rebuild as plugin** — create the new repo structure with `.claude-plugin/`, `commands/`, `hooks/`, `skills/`, `templates/`, `wrappers/`
3. **Require user to restart** — after the PR lands, users of the agent-setup repo must re-launch via `claude.sh` and run `/agent-setup:init` to bootstrap with the new plugin system

### Wrapper Plugin Maintenance

Wrapper plugins in `wrappers/` are snapshots of upstream repos that lack native `.claude-plugin` support. To keep them current:

- Each wrapper's `plugin.json` records the upstream repo URL and the commit SHA it was built from
- Updates are manual: a maintainer periodically checks upstream, updates the wrapper, and commits
- When an upstream repo adds native `.claude-plugin` support, the wrapper is removed and replaced with a `source: url` entry in `marketplace.json`

### Migration Safety

Cleanup of old files (step 3 in Migration Path) only happens **after all new plugins are confirmed installed**. If any plugin installation fails:

- `/init` reports which plugins failed and leaves old files in place
- User can fix the issue and re-run `/init` (idempotent)
- Old system remains functional as a fallback until migration completes

### Deprecated Command Aliases

During migration, `brainstorm.md`, `write-plan.md`, `execute-plan.md` (deprecated aliases from obra/superpowers) are silently removed. These are replaced by `brainstorming`, `writing-plans`, `executing-plans` skills in the superpowers plugin. `/init` prints a notice listing renamed commands.

### Third-Party Plugins Not Managed by agent-setup

Plugins like `commit-commands@claude-plugins-official` and `claude-md-management@claude-plugins-official` are not part of agent-setup's selection menu — they are independent plugins users install separately. `/init` does not install or remove them. Users who had these commands via the old template system should install them directly: `claude plugin install commit-commands@claude-plugins-official`.

## Artifact Source Audit

Original agent-setup content (to be retained in the plugin):
- `enforce-tools.sh` — PreToolUse hook blocking pip/npm/npx
- `rtk-rewrite.sh` — PreToolUse hook delegating to rtk
- `skills/agent-setup/SKILL.md` — setup guidance skill (renamed from env-setup)
- `claude.sh` template — project launcher script

Content from other sources (installed as separate plugins, not bundled):
- `commit.md`, `commit-push-pr.md`, `clean_gone.md` — from `commit-commands@claude-plugins-official`
- `revise-claude-md.md` — from `claude-md-management@claude-plugins-official`
- `code-reviewer.md` — from `obra/superpowers`
- `brainstorm.md`, `write-plan.md`, `execute-plan.md` — from `obra/superpowers` (deprecated aliases)
- `inject-superpowers.sh` — from `obra/superpowers` (plugin handles natively)
- `learning-output-style.sh` — from `learning-output-style@claude-plugins-official`

## Key Design Decisions

1. **Single plugin with marketplace** — one `agent-setup@agent-setup` plugin rather than multiple separate plugins, with `/init` offering interactive selection
2. **Wrapper plugins for non-plugin repos** — repos like Product-Manager-Skills that lack `.claude-plugin` format get a local wrapper in `wrappers/`
3. **Git as source of truth** — no separate config file; plugin files committed to project repo ARE the declarative config
4. **`claude.sh` retained** — plugin mechanism cannot replace a project-level launch script; generated by `/init`
5. **AGENT_SETUP.md abolished** — its responsibilities are fully covered by the plugin system + git
6. **Tool checks moved to hooks** — each hook checks its own dependencies instead of a centralized `## Tools` section
7. **session-start.sh simplified** — from ~300 lines of install logic to ~20 lines of health check
