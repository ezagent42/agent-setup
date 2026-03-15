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
