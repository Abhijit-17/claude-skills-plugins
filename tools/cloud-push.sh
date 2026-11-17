#!/usr/bin/env bash
# cloud-push.sh: push commits from AB's Mac to GitHub through the cloud
# session (the desktop VM has no internet). Build 2026-11-17.1. ASD-STE100.
#
# Steps for Claude:
#   1. In the VM: tools/git-agent.sh bundle <repo> <repo>/old-builds/push.bundle
#   2. Stage the bundle file into the cloud session (device_stage_files).
#   3. In the cloud session, with the repo attached for push (add_repo):
#        cloud-push.sh <clone-dir> <staged-bundle> [branch]
#   4. Delete the bundle file in the VM.
# It pushes only a fast-forward. It never force-pushes.
set -euo pipefail
clone=$1; bundle=$2; branch=${3:-main}
cd "$clone"
git fetch -q --depth=50 origin "$branch"
git fetch -q "$bundle" "$branch:refs/remotes/bundle/$branch"
if ! git merge-base --is-ancestor "origin/$branch" "bundle/$branch"; then
  echo "cloud-push: origin/$branch is not an ancestor of the bundle head. Stop: rebase on the Mac first." >&2; exit 1
fi
[ "$(git rev-parse "origin/$branch")" = "$(git rev-parse "bundle/$branch")" ] && { echo "cloud-push: nothing to push"; exit 0; }
git -c push.negotiate=true push origin "refs/remotes/bundle/$branch:refs/heads/$branch"
echo "cloud-push: origin/$branch is now $(git ls-remote origin "refs/heads/$branch" | cut -c1-7)"
