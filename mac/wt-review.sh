#!/bin/bash
# wt-review.sh - Create a review worktree for a PR or branch (macOS)
# Usage: wt-review <pr_number_or_branch>

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wt-lib.sh"

pr_input="$1"
[[ -z "$pr_input" ]] && { echo "Usage: wt-review <pr_number_or_branch>"; exit 1; }

invoking_wt=$(git rev-parse --show-toplevel 2>/dev/null) || true
repo_root=$(get_repo_root)
cd "$repo_root"

review_dir="_review/current"

# Clean up existing review
if git worktree list | grep -q "_review/current"; then
    info "Cleaning up previous review..."
    git worktree remove "$review_dir" --force 2>/dev/null || rm -rf "$review_dir"
    git worktree prune
fi

git fetch origin

if [[ "$pr_input" =~ ^[0-9]+$ ]]; then
    info "Fetching PR #${pr_input}..."
    branch_name="pr-${pr_input}"

    if command -v gh &>/dev/null; then
        pr_branch=$(gh pr view "$pr_input" --json headRefName -q '.headRefName' 2>/dev/null || echo "")
        if [[ -n "$pr_branch" ]]; then
            git fetch origin "${pr_branch}:${branch_name}"
        else
            git fetch origin "pull/${pr_input}/head:${branch_name}"
        fi
    else
        git fetch origin "pull/${pr_input}/head:${branch_name}"
    fi
else
    branch_name="$pr_input"
    if git show-ref --verify --quiet "refs/remotes/origin/${branch_name}"; then
        git fetch origin "${branch_name}"
        git branch -f "$branch_name" "origin/${branch_name}" 2>/dev/null || true
    else
        err "Branch '${branch_name}' not found on remote"
        exit 1
    fi
fi

mkdir -p "_review"
git worktree add "$review_dir" "$branch_name"

sync_config_to_worktree "$repo_root" "$review_dir" "$invoking_wt"

echo ""
success "Review worktree ready"
echo "  $repo_root/$review_dir ($branch_name)"
echo ""
echo "  When done: wt-review-done"
