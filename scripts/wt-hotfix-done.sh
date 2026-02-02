#!/bin/bash
# wt-hotfix-done.sh - Remove a hotfix worktree after merging
# Usage: wt-hotfix-done.sh <branch-name> [--workdir <path>]

set -e

branch_name=""
workdir=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --workdir)
            workdir="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            branch_name="$1"
            shift
            ;;
    esac
done

if [ -z "$branch_name" ]; then
    echo "Usage: wt-hotfix-done <branch-name>"
    exit 1
fi

# Change to workdir if specified (used by .cmd wrapper)
if [ -n "$workdir" ]; then
    cd "$workdir"
fi

# Get repo root
repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir)
cd "$repo_root"

echo "Removing hotfix worktree..."
git worktree remove "_hotfix/$branch_name" --force
git worktree prune

echo "Hotfix worktree removed"
