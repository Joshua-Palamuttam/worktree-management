#!/bin/bash
# wt-sync.sh - Sync a branch with develop (or another branch)
# Usage: wt-sync [branch-to-sync] [target-branch] [--merge|--rebase]
#
# Interactive mode (no arguments):
#   - If not in a repo: select repo first
#   - Then select which branch to sync
#   - Syncs with develop by default
#
# Examples:
#   wt-sync                    # Interactive: select branch, rebase onto develop
#   wt-sync --merge            # Interactive: select branch, merge develop
#   wt-sync my-feature         # Sync specific branch with develop
#   wt-sync my-feature main    # Sync specific branch with main

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to load config, or compute defaults
if [ -f "$SCRIPT_DIR/wt-config.sh" ]; then
    source "$SCRIPT_DIR/wt-config.sh"
else
    # Compute WORKTREE_ROOT from script location (scripts is inside worktree_management which is inside WORKTREE_ROOT)
    export WORKTREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

show_help() {
    echo "Usage: wt-sync [branch-to-sync] [target-branch] [options]"
    echo ""
    echo "Sync a branch with develop (or another branch)."
    echo ""
    echo "Interactive mode (no branch specified):"
    echo "  - If not in a repo: select repo first"
    echo "  - Then select which branch to sync"
    echo ""
    echo "Options:"
    echo "  --rebase    Rebase branch onto target (default)"
    echo "  --merge     Merge target branch into branch"
    echo "  --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  wt-sync                    # Interactive selection"
    echo "  wt-sync --merge            # Interactive, use merge"
    echo "  wt-sync my-feature         # Sync my-feature with develop"
    echo "  wt-sync my-feature main    # Sync my-feature with main"
    exit 0
}

# Function to display menu and get selection
select_from_menu() {
    local prompt="$1"
    shift
    local items=("$@")
    local filtered=("${items[@]}")

    while true; do
        echo ""
        echo "$prompt"
        echo ""

        # Display numbered list
        local i=1
        for item in "${filtered[@]}"; do
            echo "  $i) $item"
            ((i++))
        done
        echo ""

        # Get input
        read -p "Choice (number or text to filter): " input

        # Empty input - cancel
        if [ -z "$input" ]; then
            SELECTED=""
            return 1
        fi

        # Check if input is a number
        if [[ "$input" =~ ^[0-9]+$ ]]; then
            local idx=$((input - 1))
            if [ $idx -ge 0 ] && [ $idx -lt ${#filtered[@]} ]; then
                SELECTED="${filtered[$idx]}"
                return 0
            else
                echo "Invalid selection"
                continue
            fi
        fi

        # Filter by partial match (case insensitive)
        filtered=()
        for item in "${items[@]}"; do
            if [[ "${item,,}" == *"${input,,}"* ]]; then
                filtered+=("$item")
            fi
        done

        # If only one match, select it
        if [ ${#filtered[@]} -eq 1 ]; then
            SELECTED="${filtered[0]}"
            return 0
        elif [ ${#filtered[@]} -eq 0 ]; then
            echo "No matches for '$input'"
            filtered=("${items[@]}")
        fi
    done
}

# Get list of repos
get_repos() {
    ls -1 "$WORKTREE_ROOT" 2>/dev/null | grep '\.git$' | sed 's/\.git$//'
}

# Get list of syncable worktrees (feature, hotfix, review - not main/develop)
get_syncable_worktrees() {
    local repo_path="$1"
    local worktrees=()

    # Feature worktrees
    if [ -d "$repo_path/_feature" ]; then
        for d in "$repo_path/_feature"/*/; do
            [ -d "$d" ] && worktrees+=("$(basename "$d") (feature)")
        done
    fi

    # Hotfix worktrees
    if [ -d "$repo_path/_hotfix" ]; then
        for d in "$repo_path/_hotfix"/*/; do
            [ -d "$d" ] && worktrees+=("$(basename "$d") (hotfix)")
        done
    fi

    # Review worktrees
    if [ -d "$repo_path/_review" ]; then
        for d in "$repo_path/_review"/*/; do
            [ -d "$d" ] && worktrees+=("$(basename "$d") (review)")
        done
    fi

    printf '%s\n' "${worktrees[@]}"
}

# Get worktree path from selection
get_worktree_path() {
    local repo_path="$1"
    local selection="$2"

    # Extract name (remove type suffix like " (feature)")
    local name=$(echo "$selection" | sed 's/ ([^)]*)$//')

    # Find the worktree path
    if [ -d "$repo_path/_feature/$name" ]; then
        echo "$repo_path/_feature/$name"
    elif [ -d "$repo_path/_hotfix/$name" ]; then
        echo "$repo_path/_hotfix/$name"
    elif [ -d "$repo_path/_review/$name" ]; then
        echo "$repo_path/_review/$name"
    elif [ -d "$repo_path/$name" ]; then
        echo "$repo_path/$name"
    else
        return 1
    fi
}

# Perform the sync
do_sync() {
    local worktree_path="$1"
    local target_branch="$2"
    local strategy="$3"

    cd "$worktree_path"

    # Get current branch name
    local current_branch=$(git rev-parse --abbrev-ref HEAD)

    if [ "$current_branch" = "HEAD" ]; then
        echo "❌ HEAD is detached. Please checkout a branch first."
        return 1
    fi

    # Check for uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "⚠️  You have uncommitted changes."
        echo ""
        read -p "Stash changes and continue? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git stash push -m "wt-sync: auto-stash before sync"
            stashed=true
        else
            echo "Aborted. Commit or stash your changes first."
            return 1
        fi
    fi

    echo ""
    echo "🔄 Syncing '$current_branch' with '$target_branch'..."
    echo ""

    # Fetch latest
    echo "Fetching latest from origin..."
    git fetch origin

    # Check if target branch exists
    if ! git show-ref --verify --quiet "refs/remotes/origin/${target_branch}"; then
        echo "❌ Remote branch 'origin/${target_branch}' not found"
        return 1
    fi

    # If we're on the target branch, just pull
    if [ "$current_branch" = "$target_branch" ]; then
        echo "On '$target_branch' branch, pulling latest..."
        git pull origin "$target_branch"
        echo ""
        echo "✅ Synced '$target_branch' to latest."
        return 0
    fi

    # Sync based on strategy
    if [ "$strategy" = "rebase" ]; then
        echo "Rebasing '$current_branch' onto 'origin/${target_branch}'..."
        if git rebase "origin/${target_branch}"; then
            echo ""
            echo "✅ Successfully rebased '$current_branch' onto 'origin/${target_branch}'"
        else
            echo ""
            echo "⚠️  Rebase has conflicts. Resolve them, then run:"
            echo "  git rebase --continue"
            echo ""
            echo "Or abort with:"
            echo "  git rebase --abort"
            return 1
        fi
    else
        echo "Merging 'origin/${target_branch}' into '$current_branch'..."
        if git merge "origin/${target_branch}" -m "Merge ${target_branch} into ${current_branch}"; then
            echo ""
            echo "✅ Successfully merged 'origin/${target_branch}' into '$current_branch'"
        else
            echo ""
            echo "⚠️  Merge has conflicts. Resolve them, then run:"
            echo "  git commit"
            echo ""
            echo "Or abort with:"
            echo "  git merge --abort"
            return 1
        fi
    fi

    # Restore stashed changes if we stashed earlier
    if [ "$stashed" = true ]; then
        echo ""
        echo "Restoring stashed changes..."
        git stash pop
    fi

    echo ""
    echo "✅ Sync complete!"
}

# Parse arguments
branch_to_sync=""
target_branch="develop"
strategy="rebase"
workdir=""
interactive=true

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
            if [ -z "$branch_to_sync" ]; then
                branch_to_sync="$1"
                interactive=false
            else
                target_branch="$1"
            fi
            shift
            ;;
    esac
done

# Change to workdir if provided
if [ -n "$workdir" ]; then
    cd "$workdir"
fi

# Determine repo path
repo_path=""
git_dir=$(git rev-parse --git-common-dir 2>/dev/null || true)

if [ -n "$git_dir" ] && [ "$git_dir" != "." ]; then
    repo_path=$(cd "$git_dir" && pwd)
elif [ -n "$git_dir" ] && [ "$git_dir" == "." ]; then
    repo_path=$(pwd)
fi

# If interactive mode and not in a repo, select one
if [ "$interactive" = true ] && [ -z "$repo_path" ]; then
    repos=($(get_repos))
    if [ ${#repos[@]} -eq 0 ]; then
        echo "No repositories found in $WORKTREE_ROOT"
        exit 1
    fi

    select_from_menu "Select repository:" "${repos[@]}"
    if [ -z "$SELECTED" ]; then
        echo "Cancelled"
        exit 1
    fi

    repo_path="$WORKTREE_ROOT/${SELECTED}.git"
fi

# If no repo path at this point, error
if [ -z "$repo_path" ]; then
    echo "❌ Not in a git repository. Run from a worktree or use interactive mode."
    exit 1
fi

repo_name=$(basename "$repo_path" .git)

# Interactive mode: select branch to sync
if [ "$interactive" = true ]; then
    echo "📁 Repo: $repo_name"

    # Read worktrees into array properly
    IFS=$'\n' read -d '' -r -a worktrees < <(get_syncable_worktrees "$repo_path" && printf '\0') || true

    if [ ${#worktrees[@]} -eq 0 ]; then
        echo "No feature/hotfix/review branches to sync."
        echo "Create one with: wt-feature <name>"
        exit 1
    fi

    select_from_menu "Select branch to sync with $target_branch:" "${worktrees[@]}"
    if [ -z "$SELECTED" ]; then
        echo "Cancelled"
        exit 1
    fi

    worktree_path=$(get_worktree_path "$repo_path" "$SELECTED")
    if [ -z "$worktree_path" ]; then
        echo "❌ Could not find worktree: $SELECTED"
        exit 1
    fi

    do_sync "$worktree_path" "$target_branch" "$strategy"
else
    # Non-interactive: sync specified branch or current branch
    if [ -n "$branch_to_sync" ]; then
        # Find the worktree for this branch
        worktree_path=$(get_worktree_path "$repo_path" "$branch_to_sync")
        if [ -z "$worktree_path" ]; then
            # Maybe it's the current directory?
            current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
            if [ "$current_branch" = "$branch_to_sync" ]; then
                worktree_path=$(pwd)
            else
                echo "❌ Could not find worktree for branch: $branch_to_sync"
                exit 1
            fi
        fi
        do_sync "$worktree_path" "$target_branch" "$strategy"
    else
        # Sync current worktree
        if ! git rev-parse --is-inside-work-tree &>/dev/null; then
            echo "❌ Not in a git repository"
            exit 1
        fi
        do_sync "$(pwd)" "$target_branch" "$strategy"
    fi
fi
