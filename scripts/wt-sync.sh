#!/bin/bash
# wt-sync.sh - Sync current branch with develop (or another branch)
# Usage: wt-sync [target-branch] [--merge|--rebase]
#
# Examples:
#   wt-sync                    # Rebase current branch onto origin/develop
#   wt-sync --merge            # Merge origin/develop into current branch
#   wt-sync main               # Rebase current branch onto origin/main
#   wt-sync main --merge       # Merge origin/main into current branch

set -e

show_help() {
    echo "Usage: wt-sync [target-branch] [options]"
    echo ""
    echo "Sync current branch with develop (or another branch)."
    echo ""
    echo "Options:"
    echo "  --rebase    Rebase current branch onto target (default)"
    echo "  --merge     Merge target branch into current branch"
    echo "  --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  wt-sync                 # Rebase onto origin/develop"
    echo "  wt-sync --merge         # Merge origin/develop into current"
    echo "  wt-sync main            # Rebase onto origin/main"
    echo "  wt-sync main --merge    # Merge origin/main into current"
    exit 0
}

# Parse arguments
target_branch="develop"
strategy="rebase"
workdir=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            ;;
        --merge)
            strategy="merge"
            shift
            ;;
        --rebase)
            strategy="rebase"
            shift
            ;;
        --workdir)
            workdir="$2"
            shift 2
            ;;
        *)
            target_branch="$1"
            shift
            ;;
    esac
done

# Change to workdir if provided
if [ -n "$workdir" ]; then
    cd "$workdir"
fi

# Ensure we're in a git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Get current branch name
current_branch=$(git rev-parse --abbrev-ref HEAD)

if [ "$current_branch" = "HEAD" ]; then
    echo "Error: HEAD is detached. Please checkout a branch first."
    exit 1
fi

# Check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Warning: You have uncommitted changes."
    echo ""
    read -p "Stash changes and continue? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git stash push -m "wt-sync: auto-stash before sync"
        stashed=true
    else
        echo "Aborted. Commit or stash your changes first."
        exit 1
    fi
fi

echo ""
echo "Syncing '$current_branch' with '$target_branch'..."
echo ""

# Fetch latest
echo "Fetching latest from origin..."
git fetch origin

# Check if target branch exists
if ! git show-ref --verify --quiet "refs/remotes/origin/${target_branch}"; then
    echo "Error: Remote branch 'origin/${target_branch}' not found"
    exit 1
fi

# If we're on the target branch, just pull
if [ "$current_branch" = "$target_branch" ]; then
    echo "On '$target_branch' branch, pulling latest..."
    git pull origin "$target_branch"
    echo ""
    echo "Synced '$target_branch' to latest."
    exit 0
fi

# Sync based on strategy
if [ "$strategy" = "rebase" ]; then
    echo "Rebasing '$current_branch' onto 'origin/${target_branch}'..."
    if git rebase "origin/${target_branch}"; then
        echo ""
        echo "Successfully rebased '$current_branch' onto 'origin/${target_branch}'"
    else
        echo ""
        echo "Rebase has conflicts. Resolve them, then run:"
        echo "  git rebase --continue"
        echo ""
        echo "Or abort with:"
        echo "  git rebase --abort"
        exit 1
    fi
else
    echo "Merging 'origin/${target_branch}' into '$current_branch'..."
    if git merge "origin/${target_branch}" -m "Merge ${target_branch} into ${current_branch}"; then
        echo ""
        echo "Successfully merged 'origin/${target_branch}' into '$current_branch'"
    else
        echo ""
        echo "Merge has conflicts. Resolve them, then run:"
        echo "  git commit"
        echo ""
        echo "Or abort with:"
        echo "  git merge --abort"
        exit 1
    fi
fi

# Restore stashed changes if we stashed earlier
if [ "$stashed" = true ]; then
    echo ""
    echo "Restoring stashed changes..."
    git stash pop
fi

echo ""
echo "Sync complete!"
