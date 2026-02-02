#!/bin/bash
# wt-review-done.sh - Clean up review worktree after completing review
# Usage: wt-review-done

set -e

# Get the bare repo root
repo_root=$(git rev-parse --git-dir 2>/dev/null)
if [[ "$repo_root" == "." ]]; then
    repo_root=$(pwd)
elif [[ "$repo_root" == *.git ]]; then
    repo_root=$(cd "$repo_root" && pwd)
else
    repo_root=$(git rev-parse --git-common-dir 2>/dev/null)
    repo_root=$(cd "$repo_root" && pwd)
fi

cd "$repo_root"

review_dir="_review/current"

if git worktree list | grep -q "_review/current"; then
    echo "🧹 Cleaning up review worktree..."

    # Get the branch name before removing
    branch_name=$(cd "$review_dir" && git branch --show-current)

    # Remove the worktree
    git worktree remove "$review_dir" --force
    git worktree prune

    # Delete the local PR branch if it was a PR
    if [[ "$branch_name" == pr-* ]]; then
        git branch -D "$branch_name" 2>/dev/null || true
    fi

    echo "✅ Review worktree cleaned up!"
else
    echo "ℹ️  No active review worktree found"
fi
