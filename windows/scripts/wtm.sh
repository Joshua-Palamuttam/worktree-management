#!/bin/bash
# wtm.sh - Jump to main worktree of current or specified repo
#
# Usage: source wtm.sh [repo-name]
#
# NOTE: To change directories, this script must be sourced:
#   source wtm.sh
#   . wtm.sh repo-name
#
# Or use the function from wt-profile.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wt-config.sh" 2>/dev/null || {
    echo "Run setup.sh first to configure paths"
    return 1 2>/dev/null || exit 1
}

repo=$1
if [ -z "$repo" ]; then
    # Try to detect from current location
    repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null)
    if [ -n "$repo_root" ]; then
        cd "$repo_root/main" 2>/dev/null || echo "No main worktree"
        return 0 2>/dev/null || exit 0
    fi
fi

cd "$WORKTREE_ROOT/${repo}.git/main" 2>/dev/null || echo "No main worktree for $repo"
