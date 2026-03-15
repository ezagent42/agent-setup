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
