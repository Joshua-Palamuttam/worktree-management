#!/bin/bash
# wtr.sh - Jump to a specific repo
#
# Usage: source wtr.sh [repo-name]
#
# NOTE: To change directories, this script must be sourced:
#   source wtr.sh repo-name
#   . wtr.sh repo-name
#
# Or use the function from wt-profile.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wt-config.sh" 2>/dev/null || {
    echo "Run setup.sh first to configure paths"
    return 1 2>/dev/null || exit 1
}

repo=$1
if [ -z "$repo" ]; then
    echo "Available repos:"
    ls -1 "$WORKTREE_ROOT" | grep '\.git$' | sed 's/\.git$//'
    return 0 2>/dev/null || exit 0
fi

cd "$WORKTREE_ROOT/${repo}.git"
