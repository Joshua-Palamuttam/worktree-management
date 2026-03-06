#!/bin/bash
# wt-remove.sh - Remove a worktree interactively or by name (macOS)
# Usage: wt-remove [name] [-d|--delete-branch] [-k|--keep-branch] [-f|--force]

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wt-lib.sh"

worktree_name=""
force_flag=""
delete_branch="" # empty=prompt, yes, no

while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f) force_flag="--force"; shift ;;
        --delete-branch|-d) delete_branch="yes"; shift ;;
        --keep-branch|-k) delete_branch="no"; shift ;;
        *) [[ -z "$worktree_name" ]] && worktree_name="$1"; shift ;;
    esac
done

repo_root=$(get_repo_root)
cd "$repo_root"

# Interactive selection if no name given
if [[ -z "$worktree_name" ]]; then
    selected=$(list_removable_worktrees "$repo_root" | fzf_select "Remove worktree") || { echo "Cancelled"; exit 0; }
    worktree_name="${selected%% \[*\]}"
fi

# Find the worktree path
worktree_path=""
for candidate in "_feature/$worktree_name" "_hotfix/$worktree_name" "_review/$worktree_name" "$worktree_name"; do
    [[ -d "$candidate" ]] && { worktree_path="$candidate"; break; }
done

[[ -z "$worktree_path" ]] && { err "Not found: $worktree_name"; git worktree list; exit 1; }

# Get branch name before removing
branch_name=$(cd "$worktree_path" && git branch --show-current 2>/dev/null) || true

info "Removing: $worktree_path"

if ! git worktree remove "$worktree_path" $force_flag 2>/dev/null; then
    warn "Has modified/untracked files. Force remove?"
    read -p "[y/N] " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] || { echo "Cancelled"; exit 1; }
    git worktree remove "$worktree_path" --force
fi

git worktree prune
success "Worktree removed: $worktree_path"

# Handle branch deletion
if [[ -n "$branch_name" && "$branch_name" != "main" && "$branch_name" != "master" && "$branch_name" != "develop" ]]; then
    if [[ "$delete_branch" == "yes" ]]; then
        git branch -D "$branch_name" 2>/dev/null && success "Branch deleted: $branch_name"
    elif [[ "$delete_branch" != "no" ]]; then
        read -p "Delete local branch '$branch_name'? [y/N] " -n 1 -r; echo
        [[ $REPLY =~ ^[Yy]$ ]] && git branch -D "$branch_name" 2>/dev/null && success "Branch deleted: $branch_name"
    fi
fi
