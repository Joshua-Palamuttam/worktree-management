#!/bin/bash
# wt-init.sh - Initialize a repository for worktree workflow
# Usage: wt-init <repo_url> [repo_name]

set -e

WORKTREE_ROOT="${WORKTREE_ROOT:-C:/worktrees-SeekOut}"

repo_url=$1
repo_name=${2:-$(basename "$repo_url" .git)}

if [ -z "$repo_url" ]; then
    echo "Usage: wt-init <repo_url> [repo_name]"
    echo "Example: wt-init https://github.com/Zipstorm/backend.git"
    exit 1
fi

echo "🔧 Initializing ${repo_name} for worktree workflow..."

cd "$WORKTREE_ROOT"

# Clone as bare repository
echo "📦 Cloning bare repository..."
git clone --bare "$repo_url" "${repo_name}.git"

cd "${repo_name}.git"

# Fix fetch refspec (critical for bare repos to track remotes properly)
echo "⚙️  Configuring remote tracking..."
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git fetch origin

# Detect default branch
default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
echo "📌 Default branch detected: ${default_branch}"

# Create main/master worktree (with local branch tracking remote)
echo "🌳 Creating main worktree..."
if git show-ref --verify --quiet "refs/remotes/origin/main"; then
    git worktree add --track -b main main origin/main
elif git show-ref --verify --quiet "refs/remotes/origin/master"; then
    git worktree add --track -b main main origin/master
fi

# Create develop worktree if it exists (with local branch tracking remote)
if git show-ref --verify --quiet "refs/remotes/origin/develop"; then
    echo "🌳 Creating develop worktree..."
    git worktree add --track -b develop develop origin/develop
fi

# Create empty directories for feature and review worktrees
mkdir -p _feature _review _hotfix

echo ""
echo "✅ Successfully initialized ${repo_name}"
echo ""
echo "Structure:"
git worktree list
echo ""
echo "Next steps:"
echo "  cd ${WORKTREE_ROOT}/${repo_name}.git/develop"
echo "  wt-feature 'your-feature-name'"
