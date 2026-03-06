#!/bin/zsh
# wt-profile.zsh - Worktree management for macOS/zsh
# Add to ~/.zshrc:  source ~/Developer/worktree-management/mac/wt-profile.zsh

export WORKTREE_ROOT="$HOME/Developer/worktrees"
export WORKTREE_SCRIPTS="$(cd "$(dirname "${(%):-%x}")" && pwd)"

# ============================================================
# Core Commands (delegate to scripts)
# ============================================================

wt-migrate()  { bash "$WORKTREE_SCRIPTS/wt-migrate.sh" "$@"; }
wt-status()   { bash "$WORKTREE_SCRIPTS/wt-status.sh" "$@"; }
wt-cleanup()  { bash "$WORKTREE_SCRIPTS/wt-cleanup.sh" "$@"; }

wt-feature() {
    bash "$WORKTREE_SCRIPTS/wt-feature.sh" "$@"
    if [[ $? -eq 0 && -n "$1" ]]; then
        local repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null)
        local dir_name="${1##*/}"
        [[ -d "$repo_root/_feature/$dir_name" ]] && cd "$repo_root/_feature/$dir_name"
    fi
}

wt-review() {
    bash "$WORKTREE_SCRIPTS/wt-review.sh" "$@"
    if [[ $? -eq 0 ]]; then
        local repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null)
        [[ -d "$repo_root/_review/current" ]] && cd "$repo_root/_review/current"
    fi
}

wt-review-done() { bash "$WORKTREE_SCRIPTS/wt-review-done.sh" "$@"; }

wt-hotfix() {
    bash "$WORKTREE_SCRIPTS/wt-hotfix.sh" "$@"
    if [[ $? -eq 0 && -n "$1" ]]; then
        local repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null)
        [[ -d "$repo_root/_hotfix/$1" ]] && cd "$repo_root/_hotfix/$1"
    fi
}

wt-hotfix-done() { bash "$WORKTREE_SCRIPTS/wt-hotfix-done.sh" "$@"; }

wt-remove() {
    bash "$WORKTREE_SCRIPTS/wt-remove.sh" "$@"
    # cd to repo root if current dir was deleted
    [[ ! -d "$(pwd)" ]] && cd "$(git rev-parse --git-common-dir 2>/dev/null || echo "$WORKTREE_ROOT")"
}

wt-sync() { bash "$WORKTREE_SCRIPTS/wt-sync.sh" "$@"; }

wt-release() { bash "$WORKTREE_SCRIPTS/wt-release.sh" "$@"; }

wt-hotfix-pr() {
    bash "$WORKTREE_SCRIPTS/wt-hotfix-pr.sh" "$@"
    if [[ $? -eq 0 && -f /tmp/.wt-hotfix-pr-last-dir ]]; then
        local repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null)
        local wt_dir=$(cat /tmp/.wt-hotfix-pr-last-dir)
        rm -f /tmp/.wt-hotfix-pr-last-dir
        [[ -d "$repo_root/$wt_dir" ]] && cd "$repo_root/$wt_dir"
    fi
}

wt-sync-permissions() { bash "$WORKTREE_SCRIPTS/wt-sync-permissions.sh" "$@"; }

# ============================================================
# Navigation
# ============================================================

# Jump to worktree root
wtgo() { cd "$WORKTREE_ROOT"; }

# Jump to / list repos
wtr() {
    if [[ -z "$1" ]]; then
        ls -1 "$WORKTREE_ROOT" 2>/dev/null | grep '\.git$' | sed 's/\.git$//'
        return
    fi
    cd "$WORKTREE_ROOT/${1}.git"
}

# Jump to develop worktree
wtd() {
    if [[ -n "$1" ]]; then
        cd "$WORKTREE_ROOT/${1}.git/develop" 2>/dev/null || echo "No develop worktree for $1"
        return
    fi
    local root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null)
    [[ -n "$root" ]] && cd "$root/develop" 2>/dev/null || echo "No develop worktree"
}

# Jump to main worktree
wtm() {
    if [[ -n "$1" ]]; then
        cd "$WORKTREE_ROOT/${1}.git/main" 2>/dev/null || echo "No main worktree for $1"
        return
    fi
    local root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null)
    [[ -n "$root" ]] && cd "$root/main" 2>/dev/null || echo "No main worktree"
}

# List worktrees in current repo
wtl() { git worktree list; }

# ============================================================
# Interactive Navigation (fzf-powered)
# ============================================================

wtn() {
    local launch_claude=false
    [[ "$1" == "--code" || "$1" == "-c" ]] && launch_claude=true

    local repo_path=""
    local git_dir=$(git rev-parse --git-common-dir 2>/dev/null)

    if [[ -n "$git_dir" && "$git_dir" != "." ]]; then
        repo_path=$(cd "$git_dir" && pwd)
    elif [[ -n "$git_dir" && "$git_dir" == "." ]]; then
        repo_path=$(pwd)
    fi

    # Select repo if not in one
    if [[ -z "$repo_path" ]]; then
        local repos=$(ls -1 "$WORKTREE_ROOT" 2>/dev/null | grep '\.git$' | sed 's/\.git$//')
        [[ -z "$repos" ]] && { echo "No repos in $WORKTREE_ROOT"; return 1; }

        local selected=$(echo "$repos" | fzf --prompt="repo: " --height=~40% --reverse --border)
        [[ -z "$selected" ]] && return 0
        repo_path="$WORKTREE_ROOT/${selected}.git"
    fi

    local repo_name=$(basename "$repo_path" .git)

    # Build worktree list
    local worktrees=""
    [[ -d "$repo_path/main" ]] && worktrees+="main\n"
    [[ -d "$repo_path/develop" ]] && worktrees+="develop\n"
    for kind in _feature _hotfix _review; do
        [[ -d "$repo_path/$kind" ]] || continue
        local label="${kind#_}"
        for d in "$repo_path/$kind"/*(N/); do
            worktrees+="$(basename "$d") [$label]\n"
        done
    done

    [[ -z "$worktrees" ]] && { echo "No worktrees in $repo_name"; return 1; }

    local selected=$(echo -e "$worktrees" | sed '/^$/d' | fzf --prompt="$repo_name> " --height=~40% --reverse --border)
    [[ -z "$selected" ]] && return 0

    # Extract name (strip label)
    local name="${selected%% \[*\]}"

    # Find and cd to path
    for candidate in "$repo_path/$name" "$repo_path/_feature/$name" "$repo_path/_hotfix/$name" "$repo_path/_review/$name"; do
        if [[ -d "$candidate" ]]; then
            cd "$candidate"
            echo "$(pwd)"
            [[ "$launch_claude" == true ]] && claude
            return 0
        fi
    done

    echo "Not found: $name"
    return 1
}

# ============================================================
# Zsh Completions
# ============================================================

_wt_repos() {
    local repos=(${(f)"$(ls -1 "$WORKTREE_ROOT" 2>/dev/null | grep '\.git$' | sed 's/\.git$//')"})
    compadd -a repos
}

compdef _wt_repos wtr wtd wtm wt-status

_wt_worktrees() {
    local repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null)
    [[ -z "$repo_root" ]] && return
    local names=()
    for kind in _feature _hotfix _review; do
        [[ -d "$repo_root/$kind" ]] || continue
        for d in "$repo_root/$kind"/*/; do
            [[ -d "$d" ]] && names+=($(basename "$d"))
        done
    done
    compadd -a names
}

compdef _wt_worktrees wt-remove wt-hotfix-done

# Silenced to avoid p10k instant prompt warning
# To check: run `wt-status` or `wtr` to list repos
