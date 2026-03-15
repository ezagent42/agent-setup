# agent-setup

Claude Code plugin that bootstraps project environments with curated hooks, commands, skills, and a plugin marketplace.

## Quick Start

将以下 prompt 复制给你的 Claude Code，它会自动完成安装和配置：

```
请帮我安装 agent-setup 插件：
1. 注册 marketplace：claude plugin marketplace add https://github.com/ezagent42/agent-setup
2. 安装插件：claude plugin install agent-setup@agent-setup --scope project
3. 执行 /agent-setup:init 完成项目配置
```

如果你更喜欢手动操作，参考下面的安装方式。

### 方式 A — 直接安装插件

```bash
# 1. 注册 agent-setup marketplace（每台机器只需一次）
claude plugin marketplace add https://github.com/ezagent42/agent-setup

# 2. 安装核心插件
claude plugin install agent-setup@agent-setup --scope project

# 3. 在 Claude 会话中运行交互式配置
#    /agent-setup:init
```

`/agent-setup:init` 引导你选择额外插件（superpowers、impeccable 等），生成 `claude.sh` 启动脚本，并更新 `.gitignore`。

### 方式 B — 通过 `claude.sh` 启动

将 `claude.sh` 下载到项目根目录：

```bash
# 下载 claude.sh
curl -fsSL https://raw.githubusercontent.com/ezagent42/agent-setup/main/templates/claude.sh.tpl -o claude.sh
chmod +x claude.sh

# 启动 — 首次运行自动安装 agent-setup 插件
./claude.sh
```

`claude.sh` 首次运行时检测到 agent-setup 未安装，自动执行 `claude plugin install agent-setup@agent-setup --scope project`，然后启动 Claude 会话。进入会话后运行 `/agent-setup:init` 完成配置。

团队成员只需将 `claude.sh` 放入项目目录，运行即可——插件会自动安装。

## What's Included

### Hooks

| Hook | Event | Description |
|---|---|---|
| `session-start.sh` | SessionStart | Health check — verifies plugin integrity on each session |
| `enforce-tools.sh` | PreToolUse:Bash | Blocks `pip`/`npm`/`npx`, suggests `uv`/`pnpm` instead |
| `rtk-rewrite.sh` | PreToolUse:Bash | Delegates commands to [RTK](https://github.com/nicholasgasior/rtk) for token savings (skips silently if RTK not installed) |

### Commands

| Command | Description |
|---|---|
| `/agent-setup:init` | Interactive setup — select plugins, generate `claude.sh`, update `.gitignore` |
| `/agent-setup:reset` | Clean up, uninstall plugins, or re-initialize project configuration |

### Skills

| Skill | Description |
|---|---|
| `agent-setup` | Usage guide for plugin management, hooks, MCP, and environment configuration |

## Marketplace Plugins

The agent-setup marketplace provides curated plugins you can install via `/agent-setup:init` or manually:

| Plugin | Source | Description |
|---|---|---|
| `agent-setup` | local | Core plugin (this repo) |
| `superpowers` | [obra/superpowers](https://github.com/obra/superpowers) | Brainstorming, planning, TDD, debugging skills |
| `impeccable` | [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | Design quality skills for frontend |
| `product-manager-skills` | [deanpeters/Product-Manager-Skills](https://github.com/deanpeters/Product-Manager-Skills) | Product management skills (wrapper) |
| `agent-browser` | [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) | Browser automation for AI agents |

Install individually:

```bash
claude plugin install superpowers@agent-setup --scope project
```

## Adding to the Marketplace

To add a new plugin to the agent-setup marketplace:

1. If the repo has native `.claude-plugin` support → add a `source: url` entry to `.claude-plugin/marketplace.json`
2. If the repo lacks `.claude-plugin` support → create a wrapper in `wrappers/` with plugin metadata
3. Submit a PR

## Repo Structure

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
│   ├── enforce-tools.sh       # PreToolUse — block pip/npm
│   └── rtk-rewrite.sh         # PreToolUse — RTK delegation
├── skills/
│   └── agent-setup/SKILL.md   # Usage guide
├── templates/
│   ├── claude.sh.tpl          # Project launcher template
│   └── gitignore-entries.txt  # Entries to append to .gitignore
├── wrappers/
│   └── product-manager-skills/  # Wrapper for repos without .claude-plugin
└── README.md
```

## License

MIT
