# Install REA on a Mac

REA (Reverse Engineer Anything, [github.com/morluto/rea](https://github.com/morluto/rea), MIT) is a local MCP server. This guide installs REA 6.5.0 for **Claude Desktop** and **Claude Code** with `install-rea-mac.sh` (build 2026-10-16.4). Written in ASD-STE100.

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
2. If Claude Code is installed, close all Claude Code sessions. If Claude Code is not installed, the script sets up Claude Desktop only.
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
6. REA shows its plan for Claude Desktop (and Claude Code, if it is installed). The script selects the clients with `--client` flags, thus REA can apply the plan without a yes/no question. The only question that you see can be about Hopper. You can say **No** to Hopper. Hopper is necessary only for native binary analysis. To make sure that REA set up the clients, do the checks in [Check the installation](#check-the-installation).
7. At the end, the script runs `REA doctor` for both clients. Read the result.
8. Start Claude Desktop again. In a new chat, ask: **"List the REA tools that you have."**
9. Upload `skills/reverse-engineer-anything.zip` in claude.ai (**Customize > Skills**), if you did not do it before.
10. Do the checks in [Check the installation](#check-the-installation).

Each step prints a time stamp. If one step takes more than 10 minutes, stop the script with **Ctrl+C** and send the last 20 lines of the Terminal output.

## Check the installation

Do all 5 checks. If a check fails, see [Problems](#problems).

| # | Check | Command or action | Correct result |
|---|---|---|---|
| 1 | REA health | `bash install-rea-mac.sh --doctor` | `claude_code` and `claude_desktop` each show a `command` that starts with the full Node 22 path. `state: stale` is expected (see the note below this table). `missing` for `copilot_cli` and `vscode` is correct. |
| 2 | Config files | `grep -c '"rea"' ~/.claude.json "$HOME/Library/Application Support/Claude/claude_desktop_config.json"` | A number of 1 or more for each file. |
| 3 | Node path in config | `grep -A2 '"rea"' "$HOME/Library/Application Support/Claude/claude_desktop_config.json"` | `"command"` shows the full path that ends in `rea-node/current/bin/npx` (or a different Node 22 `npx`). It is not only `npx`. |
| 4 | Claude Code (skip if Claude Code is not installed) | In Terminal: `claude mcp list`. Then in a Claude Code session: `/mcp`. | `rea` shows `✓ Connected` (`/mcp` shows `connected`). The command starts with the full Node 22 path, for example `/Users/<you>/.local/share/rea-node/current/bin/npx`. If it starts with only `npx`, see the note below this table. |
| 5 | Claude Desktop | Start Claude Desktop. Open **Settings > Developer**. Then, in a new chat, ask: **"Use REA to open ~/Downloads/WORKSPACE/SkillsPlugins/pr.zip and inspect it."** | **Settings > Developer** shows `rea` as `running`. Claude calls `open_binary` and `inspect_artifact`, and shows 5 entries in the archive. |

About `state: stale` in check 1: `rea setup` writes only `npx`. Step 3 of the script changes it to the full Node 22 path and adds a `PATH`. The probable cause of `stale` is that the entry is now not the same as the entry that `rea setup` writes. If checks 4 and 5 are correct, `stale` is not a problem. Do not run `rea setup` again for this reason: it can set the command back to only `npx`. If you do run it, run `bash install-rea-mac.sh --fix-paths` after it.

Check 5 is the full test. It makes sure that REA starts, reads a local file, and sends a result. Checks 1 to 4 only make sure that the setup is correct.

If check 3 or check 4 shows only `npx` (not a full path), step 3 of the script did not run. (Build 2026-10-16.1 stopped after `REA setup` if REA ended with an error code.) REA can work in this condition, but it uses your default Node, and that can change (for example, with `nvm`). To fix it, quit Claude Desktop (Cmd+Q), close all Claude Code sessions, and run:

```bash
bash install-rea-mac.sh --fix-paths
```

This does only step 3 and REA doctor. At the end, it shows `OK` or `FAIL` for the `rea` command in each config file. Both lines must show `OK`.

If check 4 does not show `rea`, the REA setup did not add Claude Code. Close all Claude Code sessions, quit Claude Desktop (Cmd+Q), and run the script again. It is safe to run again: it uses the Node 22 that it installed before, and it sets the full Node path in the 2 config files again.

```bash
bash install-rea-mac.sh
```

## Other commands

| Command | What it does |
|---|---|
| `bash install-rea-mac.sh --doctor` | Runs only the REA health checks. |
| `bash install-rea-mac.sh --dry-run` | Shows the REA setup plan. Changes nothing. |
| `bash install-rea-mac.sh --fix-paths` | Sets the full Node 22 path in the 2 config files, then runs REA doctor. Does not run REA setup again. |
| `REA_VERSION=6.6.0 bash install-rea-mac.sh` | Installs or updates to a different REA version. |
| `REA_CLIENTS=claude_desktop bash install-rea-mac.sh` | Sets up only the clients that you name. Default: Claude Desktop, plus Claude Code if it is installed. |

## What the script changes

| Place | Change |
|---|---|
| `~/.local/share/rea-node/` | Node 22 (official build), only if no Node 22.19+ is found. |
| `~/Library/Application Support/Claude/claude_desktop_config.json` | REA setup adds `mcpServers.rea`. The script then sets its command to the full Node 22 `npx` path. A backup is made first (`*.bak-rea-<time>`). |
| `~/.claude.json` | The same for Claude Code. Only if Claude Code is installed (the `claude` command or `~/.claude.json` is found). |
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
