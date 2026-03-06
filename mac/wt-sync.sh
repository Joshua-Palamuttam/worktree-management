#!/bin/bash
# wt-sync.sh - Sync a branch with develop or another target (macOS)
# Usage: wt-sync [branch] [target] [--merge|--rebase]
#        wt-sync              # interactive fzf selection
#        wt-sync --merge      # interactive with merge strategy

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wt-lib.sh"

WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/Developer/worktrees}"

branch_to_sync=""
target_branch="develop"
strategy="rebase"
interactive=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --merge) strategy="merge"; shift ;;
        --rebase) strategy="rebase"; shift ;;
        --help|-h)
            echo "Usage: wt-sync [branch] [target] [--merge|--rebase]"
            exit 0
            ;;
        *)
            if [[ -z "$branch_to_sync" ]]; then
                branch_to_sync="$1"; interactive=false
            else
                target_branch="$1"
            fi
            shift
            ;;
    esac
done

do_sync() {
    local wt_path="$1" target="$2" strat="$3"
    cd "$wt_path"

    local current=$(git rev-parse --abbrev-ref HEAD)
    [[ "$current" == "HEAD" ]] && { err "Detached HEAD"; return 1; }

    local stashed=false
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        warn "Uncommitted changes detected"
        read -p "Stash and continue? [y/N] " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git stash push -m "wt-sync: auto-stash"
            stashed=true
        else
            echo "Aborted"; return 1
        fi
    fi

    info "Syncing '$current' with '$target' ($strat)..."
    git fetch origin

    git show-ref --verify --quiet "refs/remotes/origin/${target}" || { err "origin/${target} not found"; return 1; }

    if [[ "$current" == "$target" ]]; then
        git pull origin "$target"
    elif [[ "$strat" == "rebase" ]]; then
        git rebase "origin/${target}" || { warn "Conflicts - resolve then: git rebase --continue"; return 1; }
    else
        git merge "origin/${target}" -m "Merge ${target} into ${current}" || { warn "Conflicts - resolve then: git commit"; return 1; }
    fi

    [[ "$stashed" == true ]] && { info "Restoring stash..."; git stash pop; }
    success "Sync complete"
}

# Determine repo
repo_path=""
git_dir=$(git rev-parse --git-common-dir 2>/dev/null || true)
if [[ -n "$git_dir" && "$git_dir" != "." ]]; then
    repo_path=$(cd "$git_dir" && pwd)
elif [[ -n "$git_dir" && "$git_dir" == "." ]]; then
    repo_path=$(pwd)
fi

# Interactive: select repo if not in one
if [[ "$interactive" == true && -z "$repo_path" ]]; then
    selected=$(list_repos | fzf_select "Select repo") || { echo "Cancelled"; exit 1; }
    repo_path="$WORKTREE_ROOT/${selected}.git"
fi

[[ -z "$repo_path" ]] && { err "Not in a git repository"; exit 1; }

if [[ "$interactive" == true ]]; then
    echo "Repo: $(basename "$repo_path" .git)"
    selected=$(list_removable_worktrees "$repo_path" | fzf_select "Sync with $target_branch") || { echo "Cancelled"; exit 1; }
    wt_path=$(resolve_worktree_path "$repo_path" "$selected") || { err "Not found: $selected"; exit 1; }
    do_sync "$wt_path" "$target_branch" "$strategy"
elif [[ -n "$branch_to_sync" ]]; then
    wt_path=$(resolve_worktree_path "$repo_path" "$branch_to_sync") || wt_path="$(pwd)"
    do_sync "$wt_path" "$target_branch" "$strategy"
else
    do_sync "$(pwd)" "$target_branch" "$strategy"
fi
