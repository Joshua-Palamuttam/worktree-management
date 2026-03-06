#!/bin/bash
# wt-hotfix.sh - Create a hotfix worktree from develop (macOS)
# Usage: wt-hotfix <name>

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wt-lib.sh"

branch_name="$1"
[[ -z "$branch_name" ]] && { echo "Usage: wt-hotfix <name>"; exit 1; }

invoking_wt=$(git rev-parse --show-toplevel 2>/dev/null) || true
repo_root=$(get_repo_root)
cd "$repo_root"

git fetch origin
git worktree add -b "hotfix/$branch_name" "_hotfix/$branch_name" origin/develop

sync_config_to_worktree "$repo_root" "_hotfix/$branch_name" "$invoking_wt"

echo ""
success "Hotfix worktree created"
echo "  $repo_root/_hotfix/$branch_name"
