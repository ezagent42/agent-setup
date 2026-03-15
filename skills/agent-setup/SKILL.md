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
