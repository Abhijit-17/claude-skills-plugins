# Install REA on a Mac

REA (Reverse Engineer Anything, [github.com/morluto/rea](https://github.com/morluto/rea), MIT) is a local MCP server. This guide installs REA 6.5.0 for **Claude Desktop** and **Claude Code** with `install-rea-mac.sh` (build 2026-10-16.1). Written in ASD-STE100.

## Before you start

| Item | Requirement |
|---|---|
| Mac | Intel or Apple silicon (M1 to M5). |
| Rights | No admin rights. No sudo. No Homebrew. |
| Network | Access to `nodejs.org`, `registry.npmjs.org` and `raw.githubusercontent.com`. On a company network, a proxy can block them. |
| Time | 2 to 5 minutes. |
| Disk | About 200 MB (Node 22 and the REA package). |

The script downloads the official Node 22 build into `~/.local/share/rea-node` and checks its SHA-256. Your default `node` (for example Node 18) does not change.

## Steps

1. Quit Claude Desktop fully with **Cmd+Q**. Closing the window is not sufficient.
2. Close all Claude Code sessions.
3. Open Terminal and get the script. Use one of these:
   - With the repo: `cd ~/Downloads/WORKSPACE/SkillsPlugins && git pull`
   - Without the repo:
     ```bash
     mkdir -p ~/Downloads/rea-install && cd ~/Downloads/rea-install
     curl -fsSLO https://raw.githubusercontent.com/Abhijit-17/claude-skills-plugins/main/install-rea-mac.sh
     ```
4. Optional: look at the plan first. This changes nothing:
   ```bash
   bash install-rea-mac.sh --dry-run
   ```
5. Install:
   ```bash
   bash install-rea-mac.sh
   ```
6. When REA shows its plan for Claude Code and Claude Desktop, approve it. If REA asks to install Hopper, you can say **No**. Hopper is necessary only for native binary analysis.
7. At the end, the script runs `REA doctor` for both clients. Read the result.
8. Start Claude Desktop again. In a new chat, ask: **"List the REA tools that you have."**
9. Upload `skills/reverse-engineer-anything.zip` in claude.ai (**Customize > Skills**), if you did not do it before.

Each step prints a time stamp. If one step takes more than 10 minutes, stop the script with **Ctrl+C** and send the last 20 lines of the Terminal output.

## Other commands

| Command | What it does |
|---|---|
| `bash install-rea-mac.sh --doctor` | Runs only the REA health checks. |
| `bash install-rea-mac.sh --dry-run` | Shows the REA setup plan. Changes nothing. |
| `REA_VERSION=6.6.0 bash install-rea-mac.sh` | Installs or updates to a different REA version. |

## What the script changes

| Place | Change |
|---|---|
| `~/.local/share/rea-node/` | Node 22 (official build), only if no Node 22.19+ is found. |
| `~/Library/Application Support/Claude/claude_desktop_config.json` | REA setup adds `mcpServers.rea`. The script then sets its command to the full Node 22 `npx` path. A backup is made first (`*.bak-rea-<time>`). |
| `~/.claude.json` | The same for Claude Code. |
| npm cache (`~/.npm`) | The REA package. |

Why the full path: Claude Desktop starts MCP servers with a short PATH. Without the full path, it can find your old Node, or no Node, and REA does not start.

## Problems

| Symptom | Cause and fix |
|---|---|
| `STOP: cannot reach nodejs.org` | Network or proxy. Try a different network, or ask IT to allow `nodejs.org` and `registry.npmjs.org`. |
| `STOP: Claude Desktop is running` | Quit it with Cmd+Q, then run again. |
| REA tools do not show in Claude Desktop | Run `bash install-rea-mac.sh --doctor`. On a company-managed Mac, a policy can reset the Claude Desktop config. |
| The script ran for a long time without output (build 2026-10-15.1) | That build used Homebrew, which can compile Node from source on Intel Macs. Use this build. |

## Remove REA

1. Quit Claude Desktop (Cmd+Q).
2. Remove the `rea` entry from `mcpServers` in both config files above, or restore a `*.bak-rea-*` backup.
3. Optional: `rm -rf ~/.local/share/rea-node`.
