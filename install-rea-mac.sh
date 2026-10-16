#!/usr/bin/env bash
# install-rea-mac.sh  (build 2026-10-16.4)
#
# Installs REA (Reverse Engineer Anything, github.com/morluto/rea, MIT) on a Mac
# for Claude Desktop and Claude Code. No sudo, no Homebrew, no compile.
# Works on Intel and Apple silicon (M1..M5).
#
#   bash install-rea-mac.sh             install, or update to the pinned version
#   bash install-rea-mac.sh --doctor    only run the REA health checks
#   bash install-rea-mac.sh --dry-run   show the REA setup plan; change nothing
#   bash install-rea-mac.sh --fix-paths only do step 3 (full Node 22 path) and step 4
#
# Steps:
#   1. Node 22: uses a Node 22.19+ that is already here (this script's own copy,
#      or Homebrew node@22 if it is complete). Else it downloads the official
#      Node 22 build from nodejs.org into ~/.local/share/rea-node, checks its
#      SHA-256, and unpacks it. Your default "node" (for example Node 18) does
#      not change. (Build 2026-10-15.1 used "brew install node@22". On some
#      Intel Macs Homebrew compiles Node from source, which takes hours.)
#   2. REA setup for Claude Code and Claude Desktop, chosen with --client
#      flags (no menu). REA shows its plan; you approve it. If REA offers to
#      install Hopper, you can say No: it is not needed for JavaScript, .NET,
#      APK or web targets.
#   3. Changes the "rea" entry in claude_desktop_config.json and ~/.claude.json
#      to the full path of this Node 22's npx, plus a PATH that starts with
#      Node 22. Reason: the apps start MCP servers with a short PATH. A backup
#      of each changed file is made first.
#   4. REA doctor for both clients.
#
# Claude Code is optional. If the "claude" command is not found (and there is
# no ~/.claude.json), the script sets up Claude Desktop only. To choose, use
# REA_CLIENTS="claude_desktop" or REA_CLIENTS="claude_code claude_desktop".
#
# Before you start: QUIT Claude Desktop fully (Cmd+Q) and close all Claude Code
# sessions. They can write their config files again from memory.
# Needs internet access to nodejs.org and registry.npmjs.org.

set -euo pipefail
REA_VERSION="${REA_VERSION:-6.5.0}"
NODE_MAJOR=22
NODE_HOME_BASE="${REA_NODE_DIR:-$HOME/.local/share/rea-node}"
T0=$(date +%s)
say()  { printf '\n[%s +%ss] == %s\n' "$(date +%H:%M:%S)" "$(( $(date +%s) - T0 ))" "$*"; }
info() { printf '   %s\n' "$*"; }
stop() { printf '\nSTOP: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || stop "this script is for macOS."
case "$(uname -m)" in
  arm64)  ARCH=arm64 ;;
  x86_64) ARCH=x64
          # Rosetta check: an Intel shell on Apple silicon still needs arm64 Node.
          if [ "$(sysctl -in sysctl.proc_translated 2>/dev/null || echo 0)" = 1 ]; then ARCH=arm64; fi ;;
  *) stop "unknown CPU: $(uname -m)" ;;
esac
command -v curl >/dev/null || stop "curl not found."

node_ok() {  # node_ok <dir-with-node>  -> true if node there is 22.19+
  [ -x "$1/node" ] && "$1/node" -e 'const [a,b]=process.versions.node.split(".").map(Number);process.exit(a>22||(a===22&&b>=19)?0:1)' 2>/dev/null
}

# ---- 1. Node 22 -------------------------------------------------------------
say "1. Node $NODE_MAJOR (your default node stays: $(command -v node || echo none) $(node -v 2>/dev/null || true))"
N22=""
for d in "$NODE_HOME_BASE"/current/bin /opt/homebrew/opt/node@22/bin /usr/local/opt/node@22/bin; do
  if node_ok "$d"; then N22="$d"; break; fi
done
if [ -z "$N22" ]; then
  BASE="https://nodejs.org/dist/latest-v${NODE_MAJOR}.x"
  info "Downloading the Node $NODE_MAJOR file list from $BASE ..."
  SUMS="$(curl -fsSL --connect-timeout 15 -m 60 "$BASE/SHASUMS256.txt")" \
    || stop "cannot reach nodejs.org. Check the network or proxy, then run again."
  FILE="$(printf '%s\n' "$SUMS" | awk '{print $2}' | grep -E "^node-v${NODE_MAJOR}\.[0-9]+\.[0-9]+-darwin-${ARCH}\.tar\.gz$" | head -1)"
  [ -n "$FILE" ] || stop "no darwin-$ARCH build found in $BASE"
  WANT="$(printf '%s\n' "$SUMS" | awk -v f="$FILE" '$2==f{print $1}')"
  mkdir -p "$NODE_HOME_BASE"
  info "Downloading $FILE (about 50 MB) ..."
  curl -fL --connect-timeout 15 -m 900 --progress-bar -o "$NODE_HOME_BASE/$FILE.part" "$BASE/$FILE" \
    || stop "download failed: $BASE/$FILE"
  GOT="$(shasum -a 256 "$NODE_HOME_BASE/$FILE.part" | cut -d' ' -f1)"
  [ "$GOT" = "$WANT" ] || { rm -f "$NODE_HOME_BASE/$FILE.part"; stop "SHA-256 mismatch for $FILE (got $GOT)."; }
  info "SHA-256 OK."
  tar -xzf "$NODE_HOME_BASE/$FILE.part" -C "$NODE_HOME_BASE"
  rm -f "$NODE_HOME_BASE/$FILE.part"
  ln -sfn "$NODE_HOME_BASE/${FILE%.tar.gz}" "$NODE_HOME_BASE/current"
  N22="$NODE_HOME_BASE/current/bin"
  node_ok "$N22" || stop "the downloaded Node does not run."
fi
info "Using Node $("$N22/node" -v) at $N22"
export PATH="$N22:$PATH"
NPX="$N22/npx"
REA=( "$NPX" -y "rea-agents@$REA_VERSION" )

if [ -z "${REA_CLIENTS:-}" ]; then
  if command -v claude >/dev/null 2>&1 || [ -f "$HOME/.claude.json" ]; then
    REA_CLIENTS="claude_code claude_desktop"
  else
    REA_CLIENTS="claude_desktop"
  fi
fi
CLIENT_FLAGS=(); for c in $REA_CLIENTS; do CLIENT_FLAGS+=( --client "$c" ); done
info "Clients: $REA_CLIENTS"

doctor() {
  say "REA doctor (it shows all clients that REA knows)"
  "${REA[@]}" doctor "${CLIENT_FLAGS[@]:0:2}" 2>&1 || true
  info "Read only the lines of: $REA_CLIENTS. 'missing' for other clients (copilot_cli, vscode) is"
  info "correct: this script does not set up those clients. 'stale' is expected after step 3:"
  info "the probable cause is that the entry is not the same as what 'rea setup' writes. Do not run"
  info "'rea setup' again for this reason. The real test: the REA tools show in a new chat."
}
need_quit() {
  if pgrep -x Claude >/dev/null 2>&1; then
    stop "Claude Desktop is running. Quit it fully (Cmd+Q), then run this script again."
  fi
}
fix_paths() {
say "3. Use the full Node $NODE_MAJOR path in the client configs"
"$N22/node" - "$NPX" "$N22" <<'JS'
const fs = require('fs'), path = require('path'), os = require('os');
const [npx, n22] = process.argv.slice(2);
const files = [path.join(os.homedir(), 'Library/Application Support/Claude/claude_desktop_config.json'),
               path.join(os.homedir(), '.claude.json')];
const stamp = new Date().toISOString().replace(/[-:]/g, '').slice(0, 15);
for (const f of files) {
  if (!fs.existsSync(f)) { console.log('   skip (not found):', f); continue; }
  let d;
  try { d = JSON.parse(fs.readFileSync(f, 'utf8')); }
  catch (e) { console.log('   skip (not plain JSON, REA setup may use comments):', f); continue; }
  const hits = [];
  const fix = (servers, where) => {
    const e = servers && servers.rea;
    if (!e || typeof e !== 'object') return;
    if (path.basename(String(e.command || '')).replace(/\.cmd$/, '') === 'npx' && e.command !== npx) {
      e.command = npx;
      e.env = Object.assign({}, e.env, { PATH: n22 + ':/usr/bin:/bin:/usr/sbin:/sbin' });
      hits.push(where);
    }
  };
  fix(d.mcpServers, 'mcpServers');
  for (const [p, cfg] of Object.entries(d.projects || {})) if (cfg && typeof cfg === 'object') fix(cfg.mcpServers, `projects[${p}]`);
  if (hits.length) {
    fs.copyFileSync(f, `${f}.bak-rea-${stamp}`);
    fs.writeFileSync(f, JSON.stringify(d, null, 2) + '\n');
    console.log(`   updated ${f} (${hits.join(', ')}). Backup: ${f}.bak-rea-${stamp}`);
  } else console.log('   no change needed in', f);
}
JS
  say "Check: the rea command in each config file"
  "$N22/node" -e '
    const fs=require("fs"),path=require("path"),os=require("os");
    const want=process.argv[1]||"";
    const all={claude_desktop:path.join(os.homedir(),"Library/Application Support/Claude/claude_desktop_config.json"), claude_code:path.join(os.homedir(),".claude.json")};
    for (const f of Object.keys(all).filter(k=>want.split(" ").includes(k)).map(k=>all[k])) {
      let c="(no file)"; try { const d=JSON.parse(fs.readFileSync(f,"utf8")); c=(d.mcpServers&&d.mcpServers.rea&&d.mcpServers.rea.command)||"(no rea entry)"; } catch(e) { c="(cannot read: "+e.message+")"; }
      console.log("   "+(c.startsWith("/")?"OK  ":"FAIL")+" "+c+"   <- "+f);
    }' "$REA_CLIENTS"
}
case "${1:-}" in
  --doctor)  doctor; exit 0 ;;
  --dry-run) say "2. REA setup plan (dry run, no changes)"
             "${REA[@]}" setup "${CLIENT_FLAGS[@]}" --dry-run; exit 0 ;;
  --fix-paths) need_quit; fix_paths; doctor; exit 0 ;;
esac

need_quit

say "2. REA $REA_VERSION setup for: $REA_CLIENTS"
info "The first run downloads REA from npm (one or two minutes). Then REA shows its plan."
info "Approve the plan. You can say No to Hopper."
set +e
"${REA[@]}" setup "${CLIENT_FLAGS[@]}"
RC=$?
set -e
[ "$RC" -eq 0 ] || info "REA setup ended with exit code $RC. The script continues with step 3."

fix_paths

doctor
say "Done in $(( $(date +%s) - T0 )) s. Start Claude Desktop again. In a new chat, ask: 'List the REA tools that you have.'"
