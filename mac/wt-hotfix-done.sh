#!/bin/bash
# wt-hotfix-done.sh - Remove a hotfix worktree (macOS)
# Usage: wt-hotfix-done <name>

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wt-lib.sh"

name="$1"
[[ -z "$name" ]] && { echo "Usage: wt-hotfix-done <name>"; exit 1; }

repo_root=$(get_repo_root)
cd "$repo_root"

if [[ -d "_hotfix/$name" ]]; then
    git worktree remove "_hotfix/$name" --force
    git worktree prune
    success "Hotfix removed: _hotfix/$name"
else
    err "Not found: _hotfix/$name"
    exit 1
fi
