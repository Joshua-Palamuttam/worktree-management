#!/bin/bash
# wt-profile.sh - Source this in your .bashrc or .zshrc
# Add this line to your shell profile:
#   source "C:/worktrees-SeekOut/worktree_management/scripts/wt-profile.sh"

export WORKTREE_ROOT="C:/worktrees-SeekOut"
export WORKTREE_SCRIPTS="$WORKTREE_ROOT/worktree_management/scripts"

# ============================================================
# Core Worktree Functions
# ============================================================

# Initialize a new repo for worktree workflow
wt-init() {
    bash "$WORKTREE_SCRIPTS/wt-init.sh" "$@"
}

# Create a feature worktree
wt-feature() {
    bash "$WORKTREE_SCRIPTS/wt-feature.sh" "$@"
    # Auto-cd to the new worktree
    if [ $? -eq 0 ] && [ -n "$1" ]; then
        local repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir)
        local dir_name=$(echo "$1" | sed 's|.*/||')
        cd "$repo_root/_feature/$dir_name" 2>/dev/null || true
    fi
}

# Quick PR review
wt-review() {
    bash "$WORKTREE_SCRIPTS/wt-review.sh" "$@"
    # Auto-cd to review worktree
    if [ $? -eq 0 ]; then
        local repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir)
        cd "$repo_root/_review/current" 2>/dev/null || true
    fi
}

# Done with review
wt-review-done() {
    bash "$WORKTREE_SCRIPTS/wt-review-done.sh" "$@"
}

# Status across all repos
wt-status() {
    bash "$WORKTREE_SCRIPTS/wt-status.sh" "$@"
}

# Cleanup stale worktrees
wt-cleanup() {
    bash "$WORKTREE_SCRIPTS/wt-cleanup.sh" "$@"
}

# Migrate existing repo or clone from URL to worktree structure
wt-migrate() {
    bash "$WORKTREE_SCRIPTS/wt-migrate.sh" "$@"
}

# ============================================================
# Quick Navigation
# ============================================================

# Jump to worktree root
wt() {
    cd "$WORKTREE_ROOT"
}

# Jump to a specific repo
wtr() {
    local repo=$1
    if [ -z "$repo" ]; then
        echo "Available repos:"
        ls -1 "$WORKTREE_ROOT" | grep '\.git$' | sed 's/\.git$//'
        return
    fi
    cd "$WORKTREE_ROOT/${repo}.git"
}

# Jump to develop worktree of current or specified repo
wtd() {
    local repo=$1
    if [ -z "$repo" ]; then
        # Try to detect from current location
        local repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null)
        if [ -n "$repo_root" ]; then
            cd "$repo_root/develop" 2>/dev/null || echo "No develop worktree"
            return
        fi
    fi
    cd "$WORKTREE_ROOT/${repo}.git/develop" 2>/dev/null || echo "No develop worktree for $repo"
}

# Jump to main worktree
wtm() {
    local repo=$1
    if [ -z "$repo" ]; then
        local repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null)
        if [ -n "$repo_root" ]; then
            cd "$repo_root/main" 2>/dev/null || echo "No main worktree"
            return
        fi
    fi
    cd "$WORKTREE_ROOT/${repo}.git/main" 2>/dev/null || echo "No main worktree for $repo"
}

# List worktrees in current repo
wtl() {
    git worktree list
}

# ============================================================
# Hotfix Workflow
# ============================================================

wt-hotfix() {
    local branch_name=$1
    if [ -z "$branch_name" ]; then
        echo "Usage: wt-hotfix <branch_name>"
        return 1
    fi

    local repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir)
    cd "$repo_root"

    echo "🚨 Creating hotfix worktree from main..."
    git fetch origin
    git worktree add -b "hotfix/$branch_name" "_hotfix/$branch_name" origin/main

    cd "_hotfix/$branch_name"
    echo "✅ Hotfix worktree ready at: $(pwd)"
}

wt-hotfix-done() {
    local branch_name=$1
    if [ -z "$branch_name" ]; then
        echo "Usage: wt-hotfix-done <branch_name>"
        return 1
    fi

    local repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir)
    cd "$repo_root"

    git worktree remove "_hotfix/$branch_name" --force
    git worktree prune
    echo "✅ Hotfix worktree removed"
}

# ============================================================
# Tab Completion (Bash)
# ============================================================

_wtr_completions() {
    local repos=$(ls -1 "$WORKTREE_ROOT" 2>/dev/null | grep '\.git$' | sed 's/\.git$//')
    COMPREPLY=($(compgen -W "$repos" -- "${COMP_WORDS[1]}"))
}

if [ -n "$BASH_VERSION" ]; then
    complete -F _wtr_completions wtr
    complete -F _wtr_completions wtd
    complete -F _wtr_completions wtm
fi

# ============================================================
# Prompt Enhancement (Optional)
# ============================================================

# Uncomment to show worktree info in prompt
# wt_prompt_info() {
#     local wt_name=$(basename "$(pwd)")
#     local repo_name=$(basename "$(git rev-parse --git-common-dir 2>/dev/null)" .git)
#     if [ -n "$repo_name" ]; then
#         echo "[${repo_name}:${wt_name}]"
#     fi
# }

echo "✅ Worktree functions loaded. Type 'wt-status' to see all repos."
