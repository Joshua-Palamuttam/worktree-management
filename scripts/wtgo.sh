#!/bin/bash
# wtgo.sh - Jump to worktree root
#
# NOTE: To change directories, this script must be sourced:
#   source wtgo.sh
#   . wtgo.sh
#
# Or use the function from wt-profile.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wt-config.sh" 2>/dev/null || {
    echo "Run setup.sh first to configure paths"
    return 1 2>/dev/null || exit 1
}

cd "$WORKTREE_ROOT"
