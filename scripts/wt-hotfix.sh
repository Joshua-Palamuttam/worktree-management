#!/bin/bash
# wt-hotfix.sh - Create a hotfix worktree from develop
# Usage: wt-hotfix.sh <branch-name> [--workdir <path>]

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
    echo "Usage: wt-hotfix <branch-name>"
    exit 1
fi

# Change to workdir if specified (used by .cmd wrapper)
if [ -n "$workdir" ]; then
    cd "$workdir"
fi

# Capture the invoking worktree (has freshest permissions) before cd to repo root
invoking_wt=$(git rev-parse --show-toplevel 2>/dev/null) || true

# Get repo root
repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir)
cd "$repo_root"

echo "Creating hotfix worktree from develop..."
git fetch origin
git worktree add -b "hotfix/$branch_name" "_hotfix/$branch_name" origin/develop

# Copy untracked config directories (.claude, .agent) from an existing worktree
# Prefers invoking worktree (freshest permissions), falls back to main/develop/master
source "$(dirname "$0")/wt-lib.sh"
sync_config_to_worktree "$repo_root" "_hotfix/$branch_name" "$invoking_wt"

echo "Hotfix worktree ready at: $repo_root/_hotfix/$branch_name"
