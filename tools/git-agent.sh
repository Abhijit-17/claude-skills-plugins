#!/usr/bin/env bash
# git-agent.sh: git helper for Claude sessions that work on AB's Mac
# through the desktop VM (device shell). Build 2026-11-17.1. ASD-STE100.
#
# Why: in the VM, git can delete its own lock and temp files only when
# AB gave delete permission for the folder in this session. Without it,
# commits leave .lock files that stop the next git command. This script
# commits, then removes (or renames) what git left.
#
# Usage:
#   git-agent.sh commit <repo-dir> "<message>" [path ...]
#        Add the paths (or all changes), commit, clean the locks.
#   git-agent.sh clean  <repo-dir>
#        Remove left lock and temp files; rename them if a delete fails.
#   git-agent.sh bundle <repo-dir> <out-file> [base-ref]
#        Write a bundle of the commits after base-ref (default:
#        origin/main) for a push from the cloud session (cloud-push.sh).
#   git-agent.sh check  <repo-dir>
#        Show the branch, the last commit, the changes and left locks.
#
# Rules: run it only when no other git command runs in that repo.
# It never pushes, never rewrites history, never removes a work file.
set -euo pipefail

die() { echo "git-agent: $*" >&2; exit 1; }
[ $# -ge 2 ] || die "usage: git-agent.sh commit|clean|bundle|check <repo-dir> ..."
cmd=$1; repo=$2; shift 2
[ -d "$repo/.git" ] || die "not a git repo: $repo"
cd "$repo"
g() { git --no-optional-locks "$@"; }
stamp=$(date -u +%Y%m%d%H%M%S)

clean() {
  local n=0 f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if rm -f "$f" 2>/dev/null && [ ! -e "$f" ]; then n=$((n+1)); else
      mv "$f" ".git/stale-$(basename "$f")-$stamp" 2>/dev/null && n=$((n+1)) || echo "git-agent: cannot move $f" >&2
    fi
  done < <(find .git \( -name '*.lock' -o -name 'tmp_obj_*' \) -not -path '.git/stale-*' 2>/dev/null)
  local left; left=$(find .git -name '*.lock' 2>/dev/null | wc -l | tr -d ' ')
  echo "clean: handled $n file(s); lock files left: $left"
  ls .git/stale-* >/dev/null 2>&1 && echo "note: renamed files .git/stale-* remain; delete them when deletion is allowed" || true
}

ident() {
  local args=()
  git config user.name >/dev/null || args+=(-c "user.name=Abhijit Bhadoria")
  git config user.email >/dev/null || args+=(-c "user.email=37837579+Abhijit-17@users.noreply.github.com")
  if [ ${#args[@]} -gt 0 ]; then printf '%s\n' "${args[@]}"; fi
}

case "$cmd" in
  commit)
    [ $# -ge 1 ] || die "commit needs a message"
    msg=$1; shift
    clean >/dev/null
    if [ $# -gt 0 ]; then git add -- "$@" 2>/dev/null || git add -- "$@"; else git add -A 2>/dev/null || git add -A; fi
    if git diff --cached --quiet; then echo "commit: nothing to commit"; clean; exit 0; fi
    mapfile -t extra < <(ident)
    git "${extra[@]+"${extra[@]}"}" commit -q -m "$msg" 2>/dev/null || git "${extra[@]+"${extra[@]}"}" commit -q -m "$msg"
    echo "commit: $(g log --oneline -1)"
    clean ;;
  clean) clean ;;
  bundle)
    [ $# -ge 1 ] || die "bundle needs an out-file"
    out=$1; base=${2:-origin/main}
    g rev-parse --verify -q "$base" >/dev/null || die "unknown base ref: $base"
    n=$(g rev-list --count "$base"..HEAD)
    [ "$n" -gt 0 ] || { echo "bundle: no commits after $base"; exit 0; }
    br=$(g rev-parse --abbrev-ref HEAD)
    g bundle create "$out" "$base..$br" >/dev/null 2>&1
    echo "bundle: $out ($n commit(s) after $base, branch $br, head $(g rev-parse --short HEAD))" ;;
  check)
    echo "branch: $(g rev-parse --abbrev-ref HEAD)  head: $(g log --oneline -1)"
    g status --short | head -20
    echo "lock files: $(find .git -name '*.lock' | wc -l | tr -d ' ')" ;;
  *) die "unknown command: $cmd" ;;
esac
