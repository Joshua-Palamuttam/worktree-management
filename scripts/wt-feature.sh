#!/bin/bash
# wt-feature.sh - Create a feature worktree
# Usage: wt-feature <branch_name> [base_branch]

set -e

# Parse arguments
branch_name=""
base_branch=""
base_branch_explicit=false
workdir=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --workdir)
            workdir="$2"
            shift 2
            ;;
        *)
            if [ -z "$branch_name" ]; then
                branch_name="$1"
            else
                base_branch="$1"
                base_branch_explicit=true
            fi
            shift
            ;;
    esac
done

if [ -z "$branch_name" ]; then
    echo "Usage: wt-feature <branch_name> [base_branch]"
    echo "Example: wt-feature AI-1234-new-feature develop"
    exit 1
fi

# Change to workdir if provided
if [ -n "$workdir" ]; then
    cd "$workdir"
fi

# Get the bare repo root (find .git directory or bare repo)
repo_root=$(git rev-parse --git-dir 2>/dev/null)
if [[ "$repo_root" == "." ]]; then
    # Already in bare repo
    repo_root=$(pwd)
elif [[ "$repo_root" == *.git ]]; then
    repo_root=$(cd "$repo_root" && pwd)
else
    # In a worktree, find the main repo
    repo_root=$(git rev-parse --git-common-dir 2>/dev/null)
    repo_root=$(cd "$repo_root" && pwd)
fi

cd "$repo_root"

# Clean branch name for directory (remove prefix like joshua/)
dir_name=$(echo "$branch_name" | sed 's|.*/||')
worktree_path="_feature/${dir_name}"

# Fetch latest
git fetch origin

# Check if worktree path already exists
if [ -d "$worktree_path" ]; then
    echo "⚠️  Worktree already exists at: ${worktree_path}"
    echo "   Use 'cd ${repo_root}/${worktree_path}' to access it"
    exit 1
fi

# Check if branch already exists (locally or remotely)
branch_exists=""
branch_ref=""

if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
    branch_exists="local"
    branch_ref="${branch_name}"
elif git show-ref --verify --quiet "refs/remotes/origin/${branch_name}"; then
    branch_exists="remote"
    branch_ref="origin/${branch_name}"
fi

if [ -n "$branch_exists" ]; then
    echo "🌿 Branch '${branch_name}' already exists (${branch_exists})"
    echo "   Creating worktree from existing branch..."
    echo "   Path: ${worktree_path}"

    if [ "$branch_exists" = "remote" ]; then
        # Create worktree tracking the remote branch
        git worktree add --track -b "$branch_name" "$worktree_path" "origin/${branch_name}"
    else
        # Create worktree from existing local branch
        git worktree add "$worktree_path" "$branch_name"
    fi
else
    # Determine the base branch
    if [ "$base_branch_explicit" = false ]; then
        # Prefer develop, then fall back to the remote's default branch
        if git show-ref --verify --quiet "refs/remotes/origin/develop" || \
           git show-ref --verify --quiet "refs/heads/develop"; then
            base_branch="develop"
        else
            # Detect the remote's default branch (e.g. main, master)
            default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
            if [ -n "$default_branch" ]; then
                base_branch="$default_branch"
            else
                echo "❌ No 'develop' branch found and could not detect remote default branch"
                echo "   Specify a base branch: wt-feature <branch_name> <base_branch>"
                exit 1
            fi
        fi
    fi

    echo "🌿 Creating feature worktree..."
    echo "   Branch: ${branch_name}"
    echo "   Base: ${base_branch}"
    echo "   Path: ${worktree_path}"

    # Determine the base ref
    if git show-ref --verify --quiet "refs/remotes/origin/${base_branch}"; then
        base_ref="origin/${base_branch}"
    elif git show-ref --verify --quiet "refs/heads/${base_branch}"; then
        base_ref="${base_branch}"
    else
        echo "❌ Base branch '${base_branch}' not found"
        exit 1
    fi

    # Create the worktree with new branch
    git worktree add -b "$branch_name" "$worktree_path" "$base_ref"
fi

# Copy untracked config directories (.claude, .agent) from an existing worktree
# Uses cp -rn (no-clobber) to add missing files without overwriting git-tracked ones
for source_wt in "$repo_root/main" "$repo_root/develop" "$repo_root/master"; do
    if [ -d "$source_wt" ]; then
        for config_dir in .claude .agent; do
            if [ -d "$source_wt/$config_dir" ]; then
                cp -rn "$source_wt/$config_dir" "$worktree_path/"
                echo "   Synced $config_dir/ from $(basename "$source_wt")"
            fi
        done
        break
    fi
done

# Set upstream tracking
cd "$worktree_path"
if [ -n "$base_branch" ]; then
    git branch --set-upstream-to="origin/${base_branch}" "$branch_name" 2>/dev/null || true
fi

echo ""
echo "✅ Feature worktree created!"
echo ""
echo "Location: ${repo_root}/${worktree_path}"
echo ""
echo "To start working:"
echo "  cd '${repo_root}/${worktree_path}'"
