#!/bin/bash
# wt-lib.sh - Shared functions for worktree management scripts
# Source this file: source "$(dirname "$0")/wt-lib.sh"

# sync_config_to_worktree <repo_root> <dest_worktree_path> [invoking_worktree_path]
#
# Copies untracked config directories (.claude, .agent) into a new worktree.
# Uses cp -rn (no-clobber) to add missing files without overwriting git-tracked ones.
#
# Source priority:
#   1. invoking_worktree_path (if provided and contains config dirs - has freshest permissions)
#   2. First of main/develop/master that exists in repo_root
#
# Resolves file/directory type conflicts before copying (e.g. git tracks .claude/skills
# as a file but the source worktree has it as a directory with subdirs).
sync_config_to_worktree() {
    local repo_root="$1"
    local dest="$2"
    local invoking_wt="$3"

    # Build ordered list of source worktrees to try
    local sources=()
    if [ -n "$invoking_wt" ] && [ -d "$invoking_wt" ]; then
        sources+=("$invoking_wt")
    fi
    sources+=("$repo_root/main" "$repo_root/develop" "$repo_root/master")

    for source_wt in "${sources[@]}"; do
        if [ -d "$source_wt" ]; then
            for config_dir in .claude .agent; do
                if [ -d "$source_wt/$config_dir" ]; then
                    # Resolve type conflicts at one level deep
                    if [ -d "$dest/$config_dir" ]; then
                        for item in "$source_wt/$config_dir"/*; do
                            [ -e "$item" ] || continue
                            name=$(basename "$item")
                            target="$dest/$config_dir/$name"
                            if [ -e "$target" ]; then
                                if [ -d "$item" ] && [ ! -d "$target" ]; then
                                    rm -f "$target"
                                elif [ ! -d "$item" ] && [ -d "$target" ]; then
                                    rm -rf "$target"
                                fi
                            fi
                        done
                    fi
                    cp -rn "$source_wt/$config_dir" "$dest/" 2>/dev/null || true
                    echo "   Synced $config_dir/ from $(basename "$source_wt")"
                fi
            done
            break
        fi
    done
}
