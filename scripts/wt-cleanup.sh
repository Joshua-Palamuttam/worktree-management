#!/bin/bash
# wt-cleanup.sh - Clean up stale worktrees and prune across all repos
# Usage: wt-cleanup [--dry-run]

WORKTREE_ROOT="${WORKTREE_ROOT:-C:/worktrees-SeekOut}"

dry_run=false
if [ "$1" == "--dry-run" ]; then
    dry_run=true
    echo "🔍 DRY RUN - No changes will be made"
    echo ""
fi

cd "$WORKTREE_ROOT"

echo "🧹 Cleaning up worktrees..."
echo ""

for repo in *.git/; do
    repo_name="${repo%.git/}"

    echo "📁 ${repo_name}"

    cd "$WORKTREE_ROOT/$repo"

    # Check for stale worktrees
    stale=$(git worktree list --porcelain | grep -c "prunable" || echo "0")

    if [ "$stale" -gt 0 ]; then
        echo "   Found ${stale} stale worktree(s)"
        if [ "$dry_run" = false ]; then
            git worktree prune
            echo "   ✓ Pruned"
        fi
    else
        echo "   ✓ No stale worktrees"
    fi

    # Check for merged feature branches that can be cleaned up
    if [ -d "_feature" ]; then
        for feature_dir in _feature/*/; do
            if [ -d "$feature_dir" ]; then
                feature_name=$(basename "$feature_dir")
                branch=$(cd "$feature_dir" && git branch --show-current 2>/dev/null)

                if [ -n "$branch" ]; then
                    # Check if merged into develop or main
                    merged_develop=$(git branch --merged origin/develop 2>/dev/null | grep -c "^\s*${branch}$" || echo "0")
                    merged_main=$(git branch --merged origin/main 2>/dev/null | grep -c "^\s*${branch}$" || echo "0")

                    if [ "$merged_develop" -gt 0 ] || [ "$merged_main" -gt 0 ]; then
                        echo "   ⚠️  Feature '${feature_name}' appears merged (consider removing)"
                    fi
                fi
            fi
        done
    fi

    echo ""
    cd "$WORKTREE_ROOT"
done

echo "✅ Cleanup complete!"
