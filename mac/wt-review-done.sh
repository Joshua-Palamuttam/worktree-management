#!/bin/bash
# wt-review-done.sh - Clean up review worktree (macOS)

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wt-lib.sh"

repo_root=$(get_repo_root)
cd "$repo_root"

review_dir="_review/current"

if git worktree list | grep -q "_review/current"; then
    branch_name=$(cd "$review_dir" && git branch --show-current 2>/dev/null) || true
    git worktree remove "$review_dir" --force
    git worktree prune
    [[ "$branch_name" == pr-* ]] && git branch -D "$branch_name" 2>/dev/null || true
    success "Review cleaned up"
else
    echo "No active review worktree"
fi
