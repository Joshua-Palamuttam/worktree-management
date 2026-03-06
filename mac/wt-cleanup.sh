#!/bin/bash
# wt-cleanup.sh - Clean up stale worktrees across repos (macOS)
# Usage: wt-cleanup [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wt-lib.sh"

WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/Developer/worktrees}"

dry_run=false
[[ "$1" == "--dry-run" ]] && { dry_run=true; echo "DRY RUN - no changes"; echo ""; }

cd "$WORKTREE_ROOT"

for repo in *.git/; do
    [[ -d "$repo" ]] || continue
    repo_name="${repo%.git/}"
    echo "$repo_name"

    cd "$WORKTREE_ROOT/$repo"

    stale=$(git worktree list --porcelain | grep -c "prunable" 2>/dev/null || echo "0")
    if [[ "$stale" -gt 0 ]]; then
        echo "  $stale stale worktree(s)"
        [[ "$dry_run" == false ]] && git worktree prune && success "  Pruned"
    else
        echo "  clean"
    fi

    # Check for merged feature branches
    if [[ -d "_feature" ]]; then
        for d in _feature/*/; do
            [[ -d "$d" ]] || continue
            name=$(basename "$d")
            branch=$(cd "$d" && git branch --show-current 2>/dev/null) || continue
            [[ -z "$branch" ]] && continue

            merged=false
            git branch --merged origin/develop 2>/dev/null | grep -q "^\s*${branch}$" && merged=true
            git branch --merged origin/main 2>/dev/null | grep -q "^\s*${branch}$" && merged=true

            [[ "$merged" == true ]] && warn "  '$name' appears merged (consider: wt-remove $name)"
        done
    fi

    echo ""
    cd "$WORKTREE_ROOT"
done

success "Cleanup complete"
