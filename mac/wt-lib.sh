#!/bin/bash
# wt-lib.sh - Shared functions for worktree management (macOS)
shopt -s nullglob

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m'

info()    { echo -e "${BLUE}>${NC} $1"; }
success() { echo -e "${GREEN}ok${NC} $1"; }
warn()    { echo -e "${YELLOW}!${NC} $1"; }
err()     { echo -e "${RED}x${NC} $1"; }

# Get the bare repo root from anywhere inside a worktree or bare repo
get_repo_root() {
    local git_dir
    git_dir=$(git rev-parse --git-dir 2>/dev/null) || return 1
    if [[ "$git_dir" == "." ]]; then
        pwd
    elif [[ "$git_dir" == *.git ]]; then
        (cd "$git_dir" && pwd)
    else
        local common_dir
        common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || return 1
        (cd "$common_dir" && pwd)
    fi
}

# Detect default branch from remote (main or master)
detect_default_branch() {
    local default_branch
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if [[ -z "$default_branch" ]]; then
        if git show-ref --verify --quiet "refs/remotes/origin/main"; then
            default_branch="main"
        elif git show-ref --verify --quiet "refs/remotes/origin/master"; then
            default_branch="master"
        fi
    fi
    echo "$default_branch"
}

# fzf selection wrapper. Reads items from stdin, returns selected item.
# Usage: echo "a\nb\nc" | fzf_select "Pick one"
fzf_select() {
    local prompt="${1:-Select}"
    fzf --prompt="$prompt: " --height=~40% --reverse --border --no-multi
}

# Sync .claude/ and .agent/ config dirs into a new worktree
# Usage: sync_config_to_worktree <repo_root> <dest_path> [source_worktree]
sync_config_to_worktree() {
    local repo_root="$1" dest="$2" invoking_wt="$3"
    local sources=()
    [[ -n "$invoking_wt" && -d "$invoking_wt" ]] && sources+=("$invoking_wt")
    sources+=("$repo_root/main" "$repo_root/develop" "$repo_root/master")

    for src in "${sources[@]}"; do
        [[ -d "$src" ]] || continue
        for config_dir in .claude .agent; do
            if [[ -d "$src/$config_dir" ]]; then
                # Resolve type conflicts at one level deep
                if [[ -d "$dest/$config_dir" ]]; then
                    for item in "$src/$config_dir"/*; do
                        [[ -e "$item" ]] || continue
                        local name target
                        name=$(basename "$item")
                        target="$dest/$config_dir/$name"
                        if [[ -e "$target" ]]; then
                            [[ -d "$item" && ! -d "$target" ]] && rm -f "$target"
                            [[ ! -d "$item" && -d "$target" ]] && rm -rf "$target"
                        fi
                    done
                fi
                cp -Rn "$src/$config_dir" "$dest/" 2>/dev/null || true
                echo -e "   ${DIM}synced $config_dir/ from $(basename "$src")${NC}"
            fi
        done
        break
    done
}

# List worktrees for a repo, formatted for fzf
# Output: "name [type]" per line
list_worktrees() {
    local repo_path="$1"
    [[ -d "$repo_path/main" ]] && echo "main"
    [[ -d "$repo_path/develop" ]] && echo "develop"
    for kind in _feature _hotfix _review; do
        [[ -d "$repo_path/$kind" ]] || continue
        local label="${kind#_}"
        for d in "$repo_path/$kind"/*/; do
            [[ -d "$d" ]] && echo "$(basename "$d") [$label]"
        done
    done
}

# List only removable worktrees (not main/develop)
list_removable_worktrees() {
    local repo_path="$1"
    for kind in _feature _hotfix _review; do
        [[ -d "$repo_path/$kind" ]] || continue
        local label="${kind#_}"
        for d in "$repo_path/$kind"/*/; do
            [[ -d "$d" ]] && echo "$(basename "$d") [$label]"
        done
    done
}

# Resolve a worktree name to its full path within a repo
# Usage: resolve_worktree_path <repo_root> <name>
resolve_worktree_path() {
    local repo_path="$1" name="$2"
    # Strip fzf label suffix like " [feature]"
    name="${name%% \[*\]}"
    for candidate in "$repo_path/$name" "$repo_path/_feature/$name" "$repo_path/_hotfix/$name" "$repo_path/_review/$name"; do
        [[ -d "$candidate" ]] && echo "$candidate" && return 0
    done
    return 1
}

# List repos under WORKTREE_ROOT
list_repos() {
    ls -1 "$WORKTREE_ROOT" 2>/dev/null | grep '\.git$' | sed 's/\.git$//'
}
