#!/bin/bash
# wt-remove.sh - Remove a worktree
# Usage: wt-remove <worktree_name> [--force] [--delete-branch | --keep-branch]

set -e

worktree_name=""
force_flag=""
workdir=""
delete_branch=""  # empty = prompt, "yes" = delete, "no" = keep

while [[ $# -gt 0 ]]; do
    case $1 in
        --workdir)
            workdir="$2"
            shift 2
            ;;
        --force|-f)
            force_flag="--force"
            shift
            ;;
        --delete-branch|-d)
            delete_branch="yes"
            shift
            ;;
        --keep-branch|-k)
            delete_branch="no"
            shift
            ;;
        *)
            if [ -z "$worktree_name" ]; then
                worktree_name="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$worktree_name" ]; then
    echo "Usage: wt-remove <worktree_name> [--force] [--delete-branch | --keep-branch]"
    echo ""
    echo "Options:"
    echo "  --force, -f          Force remove even with uncommitted changes"
    echo "  --delete-branch, -d  Also delete the local branch"
    echo "  --keep-branch, -k    Keep the local branch (no prompt)"
    echo ""
    echo "Examples:"
    echo "  wt-remove AI-1234-feature           # Remove and prompt about branch"
    echo "  wt-remove AI-1234-feature -d        # Remove worktree and delete branch"
    echo "  wt-remove AI-1234-feature -k        # Remove worktree, keep branch"
    echo "  wt-remove my-branch --force         # Force remove with uncommitted changes"
    echo ""
    echo "Current worktrees:"
    git worktree list
    exit 1
fi

# Change to workdir if provided
if [ -n "$workdir" ]; then
    cd "$workdir"
fi

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

# Find the worktree path
worktree_path=""
branch_name=""

# Check common locations
if [ -d "_feature/$worktree_name" ]; then
    worktree_path="_feature/$worktree_name"
elif [ -d "_hotfix/$worktree_name" ]; then
    worktree_path="_hotfix/$worktree_name"
elif [ -d "_review/$worktree_name" ]; then
    worktree_path="_review/$worktree_name"
elif [ -d "$worktree_name" ]; then
    worktree_path="$worktree_name"
else
    echo "❌ Worktree not found: $worktree_name"
    echo ""
    echo "Available worktrees:"
    git worktree list
    exit 1
fi

# Get the branch name before removing
branch_name=$(cd "$worktree_path" && git branch --show-current 2>/dev/null) || true

echo "🗑️  Removing worktree: $worktree_path"

# Remove the worktree
git worktree remove "$worktree_path" $force_flag

# Clean up
git worktree prune

echo "✅ Worktree removed: $worktree_path"

# Handle branch deletion
if [ -n "$branch_name" ] && [ "$branch_name" != "main" ] && [ "$branch_name" != "master" ] && [ "$branch_name" != "develop" ]; then
    if [ "$delete_branch" = "yes" ]; then
        # Delete branch automatically
        echo "🗑️  Deleting branch: $branch_name"
        git branch -D "$branch_name" 2>/dev/null || echo "⚠️  Could not delete branch (may not exist locally)"
    elif [ "$delete_branch" = "no" ]; then
        # Keep branch, no prompt
        echo "📌 Keeping local branch: $branch_name"
    else
        # Interactive prompt
        echo ""
        echo "The local branch '$branch_name' still exists."
        read -p "Delete the branch? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git branch -D "$branch_name" 2>/dev/null && echo "✅ Branch deleted: $branch_name" || echo "⚠️  Could not delete branch"
        else
            echo "📌 Keeping branch: $branch_name"
        fi
    fi
fi
