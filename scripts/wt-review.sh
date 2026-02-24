#!/bin/bash
# wt-review.sh - Create/reuse a review worktree for PR review
# Usage: wt-review <pr_number_or_branch>

set -e

pr_input=$1

if [ -z "$pr_input" ]; then
    echo "Usage: wt-review <pr_number_or_branch>"
    echo "Examples:"
    echo "  wt-review 4521           # Review PR #4521"
    echo "  wt-review feature/xyz    # Review branch directly"
    exit 1
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

review_dir="_review/current"

echo "🔍 Setting up review worktree..."

# Remove existing review worktree if it exists
if git worktree list | grep -q "_review/current"; then
    echo "🧹 Cleaning up previous review worktree..."
    git worktree remove "$review_dir" --force 2>/dev/null || rm -rf "$review_dir"
    git worktree prune
fi

# Fetch latest
git fetch origin

# Determine if input is PR number or branch name
if [[ "$pr_input" =~ ^[0-9]+$ ]]; then
    # It's a PR number - try to fetch using gh CLI first
    echo "📥 Fetching PR #${pr_input}..."

    branch_name="pr-${pr_input}"

    # Try gh CLI first (best experience)
    if command -v gh &> /dev/null; then
        # Get the PR branch name from GitHub
        pr_branch=$(gh pr view "$pr_input" --json headRefName -q '.headRefName' 2>/dev/null || echo "")
        if [ -n "$pr_branch" ]; then
            git fetch origin "${pr_branch}:${branch_name}"
        else
            # Fallback to PR refs
            git fetch origin "pull/${pr_input}/head:${branch_name}"
        fi
    else
        # Fallback to PR refs without gh
        git fetch origin "pull/${pr_input}/head:${branch_name}"
    fi
else
    # It's a branch name
    branch_name="$pr_input"

    if git show-ref --verify --quiet "refs/remotes/origin/${branch_name}"; then
        git fetch origin "${branch_name}"
        # Create local tracking branch
        git branch -f "$branch_name" "origin/${branch_name}" 2>/dev/null || true
    else
        echo "❌ Branch '${branch_name}' not found on remote"
        exit 1
    fi
fi

# Create the review worktree
mkdir -p "_review"
git worktree add "$review_dir" "$branch_name"

# Copy untracked config directories (.claude, .agent) from an existing worktree
# Uses cp -rn (no-clobber) to add missing files without overwriting git-tracked ones
for source_wt in "$repo_root/main" "$repo_root/develop" "$repo_root/master"; do
    if [ -d "$source_wt" ]; then
        for config_dir in .claude .agent; do
            if [ -d "$source_wt/$config_dir" ]; then
                cp -rn "$source_wt/$config_dir" "$review_dir/"
                echo "   Synced $config_dir/ from $(basename "$source_wt")"
            fi
        done
        break
    fi
done

echo ""
echo "✅ Review worktree ready!"
echo ""
echo "Location: ${repo_root}/${review_dir}"
echo "Branch: ${branch_name}"
echo ""
echo "To start reviewing:"
echo "  cd '${repo_root}/${review_dir}'"
echo ""
echo "When done:"
echo "  wt-review-done"
