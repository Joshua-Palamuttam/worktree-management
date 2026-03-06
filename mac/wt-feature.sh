#!/bin/bash
# wt-feature.sh - Create a feature worktree (macOS)
# Usage: wt-feature <branch_name> [base_branch]

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wt-lib.sh"

branch_name=""
base_branch=""
base_explicit=false

while [[ $# -gt 0 ]]; do
    case $1 in
        *) [[ -z "$branch_name" ]] && branch_name="$1" || { base_branch="$1"; base_explicit=true; } ;;
    esac
    shift
done

[[ -z "$branch_name" ]] && { echo "Usage: wt-feature <branch_name> [base_branch]"; exit 1; }

invoking_wt=$(git rev-parse --show-toplevel 2>/dev/null) || true
repo_root=$(get_repo_root)
cd "$repo_root"

dir_name="${branch_name##*/}"
worktree_path="_feature/${dir_name}"

git fetch origin

[[ -d "$worktree_path" ]] && { warn "Already exists: $worktree_path"; echo "  cd '$repo_root/$worktree_path'"; exit 1; }

# Check if branch exists
if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
    info "Branch '${branch_name}' exists locally, creating worktree..."
    git worktree add "$worktree_path" "$branch_name"
elif git show-ref --verify --quiet "refs/remotes/origin/${branch_name}"; then
    info "Branch '${branch_name}' exists on remote, creating worktree..."
    git worktree add --track -b "$branch_name" "$worktree_path" "origin/${branch_name}"
else
    # New branch - determine base
    if [[ "$base_explicit" == false ]]; then
        if git show-ref --verify --quiet "refs/remotes/origin/develop"; then
            base_branch="develop"
        else
            base_branch=$(detect_default_branch)
            [[ -z "$base_branch" ]] && { err "No develop/main/master found. Specify a base branch."; exit 1; }
        fi
    fi

    local_or_remote="origin/${base_branch}"
    git show-ref --verify --quiet "refs/remotes/${local_or_remote}" || local_or_remote="${base_branch}"

    info "Creating '${branch_name}' from ${base_branch}..."
    git worktree add -b "$branch_name" "$worktree_path" "$local_or_remote"
fi

sync_config_to_worktree "$repo_root" "$worktree_path" "$invoking_wt"

cd "$worktree_path"
git branch --set-upstream-to="origin/${base_branch:-$(detect_default_branch)}" "$branch_name" 2>/dev/null || true

echo ""
success "Feature worktree created"
echo "  $repo_root/$worktree_path"
