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

# Get repo root
repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir)
cd "$repo_root"

echo "Creating hotfix worktree from develop..."
git fetch origin
git worktree add -b "hotfix/$branch_name" "_hotfix/$branch_name" origin/develop

# Copy untracked config directories (.claude, .agent) from an existing worktree
# Uses cp -rn (no-clobber) to add missing files without overwriting git-tracked ones
for source_wt in "$repo_root/main" "$repo_root/develop" "$repo_root/master"; do
    if [ -d "$source_wt" ]; then
        for config_dir in .claude .agent; do
            if [ -d "$source_wt/$config_dir" ]; then
                cp -rn "$source_wt/$config_dir" "_hotfix/$branch_name/" 2>/dev/null || true
                echo "   Synced $config_dir/ from $(basename "$source_wt")"
            fi
        done
        break
    fi
done

echo "Hotfix worktree ready at: $repo_root/_hotfix/$branch_name"
