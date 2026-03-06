#!/bin/bash
# wt-migrate.sh - Clone or migrate a repo into bare-repo + worktree structure (macOS)
#
# Usage:
#   wt-migrate --from-url <github_url> [name]
#   wt-migrate --from-dir <local_path> [name]

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wt-lib.sh"

WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/Developer/worktrees}"

show_usage() {
    cat <<EOF
Usage: wt-migrate <mode> <source> [repo_name]

Modes:
  --from-url, -u <url>     Clone from GitHub URL
  --from-dir, -d <path>    Migrate from existing local repo

Examples:
  wt-migrate -u https://github.com/org/repo.git
  wt-migrate -d ~/code/my-repo my-repo
EOF
}

create_worktrees() {
    local bare_repo="$1"
    cd "$bare_repo"

    # Main worktree
    info "Creating main worktree..."
    if git show-ref --verify --quiet "refs/remotes/origin/main"; then
        git show-ref --verify --quiet "refs/heads/main" \
            && git worktree add main main \
            || git worktree add --track -b main main origin/main
        success "main/ (tracking origin/main)"
    elif git show-ref --verify --quiet "refs/remotes/origin/master"; then
        git show-ref --verify --quiet "refs/heads/main" \
            && git worktree add main main \
            || git worktree add --track -b main main origin/master
        success "main/ (tracking origin/master)"
    else
        warn "No main/master branch found"
    fi

    # Develop worktree
    if git show-ref --verify --quiet "refs/remotes/origin/develop"; then
        info "Creating develop worktree..."
        git show-ref --verify --quiet "refs/heads/develop" \
            && git worktree add develop develop \
            || git worktree add --track -b develop develop origin/develop
        success "develop/ (tracking origin/develop)"
    fi

    mkdir -p _feature _review _hotfix
    success "Created _feature/, _review/, _hotfix/"
}

convert_to_ssh() {
    local url="$1"
    if [[ "$url" =~ ^https://github\.com/(.+)$ ]]; then
        echo "git@github.com:${BASH_REMATCH[1]}"
    else
        echo "$url"
    fi
}

migrate_from_url() {
    local url="$1" repo_name="$2"
    [[ ! "$url" =~ \.git$ ]] && url="${url}.git"
    url=$(convert_to_ssh "$url")
    [[ -z "$repo_name" ]] && repo_name=$(basename "$url" .git)

    local bare_repo="${WORKTREE_ROOT}/${repo_name}.git"

    echo ""
    echo "  Setting up: $repo_name"
    echo "  URL:         $url"
    echo "  Destination: $bare_repo"
    echo ""

    [[ -d "$bare_repo" ]] && { err "Already exists: $bare_repo"; exit 1; }

    mkdir -p "$WORKTREE_ROOT"

    info "Cloning bare repository..."
    git clone --bare "$url" "$bare_repo"
    success "Bare repo created"

    info "Configuring remote tracking..."
    cd "$bare_repo"
    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    git fetch origin
    success "Fetch refspec configured"

    create_worktrees "$bare_repo"

    echo ""
    echo "  Structure:"
    git worktree list
    echo ""
    echo "  Next: cd '$bare_repo/main' or '$bare_repo/develop'"
    echo ""
}

migrate_from_dir() {
    local source_dir="$1" repo_name="$2"

    [[ ! -d "$source_dir" ]] && { err "Not found: $source_dir"; exit 1; }
    [[ ! -d "$source_dir/.git" ]] && { err "Not a git repo: $source_dir"; exit 1; }

    [[ -z "$repo_name" ]] && repo_name=$(basename "$source_dir")

    local remote_url
    remote_url=$(cd "$source_dir" && git remote get-url origin 2>/dev/null)
    [[ -z "$remote_url" ]] && { err "No 'origin' remote in source repo"; exit 1; }

    echo ""
    echo "  Migrating: $repo_name"
    echo "  Source:      $source_dir"
    echo "  Remote:      $remote_url"
    echo ""

    migrate_from_url "$remote_url" "$repo_name"

    echo "  Original repo at '$source_dir' is unchanged."
    echo ""
}

# Main
[[ $# -lt 2 ]] && { show_usage; exit 1; }

mode="$1"; shift
source_arg="$1"; shift
name_arg="${1:-}"

case "$mode" in
    --from-url|-u) migrate_from_url "$source_arg" "$name_arg" ;;
    --from-dir|-d) migrate_from_dir "$source_arg" "$name_arg" ;;
    --help|-h) show_usage ;;
    *) err "Unknown mode: $mode"; show_usage; exit 1 ;;
esac
