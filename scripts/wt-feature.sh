#!/bin/bash
# wt-feature.sh - Create a feature worktree
# Usage: wt-feature <branch_name> [base_branch]

set -e

branch_name=$1
base_branch=${2:-develop}

if [ -z "$branch_name" ]; then
    echo "Usage: wt-feature <branch_name> [base_branch]"
    echo "Example: wt-feature AI-1234-new-feature develop"
    exit 1
fi

# Get the bare repo root (find .git directory or bare repo)
repo_root=$(git rev-parse --git-dir 2>/dev/null)
if [[ "$repo_root" == "." ]]; then
    # Already in bare repo
    repo_root=$(pwd)
elif [[ "$repo_root" == *.git ]]; then
    repo_root=$(cd "$repo_root" && pwd)
else
    # In a worktree, find the main repo
    repo_root=$(git rev-parse --git-common-dir 2>/dev/null)
    repo_root=$(cd "$repo_root" && pwd)
fi

cd "$repo_root"

# Clean branch name for directory (remove prefix like joshua/)
dir_name=$(echo "$branch_name" | sed 's|.*/||')
worktree_path="_feature/${dir_name}"

echo "🌿 Creating feature worktree..."
echo "   Branch: ${branch_name}"
echo "   Base: ${base_branch}"
echo "   Path: ${worktree_path}"

# Fetch latest
git fetch origin

# Determine the base ref
if git show-ref --verify --quiet "refs/remotes/origin/${base_branch}"; then
    base_ref="origin/${base_branch}"
elif git show-ref --verify --quiet "refs/heads/${base_branch}"; then
    base_ref="${base_branch}"
else
    echo "❌ Base branch '${base_branch}' not found"
    exit 1
fi

# Create the worktree with new branch
git worktree add -b "$branch_name" "$worktree_path" "$base_ref"

# Set upstream tracking
cd "$worktree_path"
git branch --set-upstream-to="origin/${base_branch}" "$branch_name" 2>/dev/null || true

echo ""
echo "✅ Feature worktree created!"
echo ""
echo "Location: ${repo_root}/${worktree_path}"
echo ""
echo "To start working:"
echo "  cd '${repo_root}/${worktree_path}'"
