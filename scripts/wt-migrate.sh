#!/bin/bash
# wt-migrate.sh - Migrate existing repo OR clone fresh to worktree structure
#
# Usage:
#   wt-migrate --from-dir <local_path> [repo_name]
#   wt-migrate --from-url <github_url> [repo_name]
#
# Examples:
#   wt-migrate --from-dir "C:/Seekout/backend"
#   wt-migrate --from-dir "C:/Seekout/AI-1099" AI-1099
#   wt-migrate --from-url https://github.com/Zipstorm/backend.git
#   wt-migrate --from-url https://github.com/Zipstorm/backend.git backend

set -e

WORKTREE_ROOT="${WORKTREE_ROOT:-C:/worktrees-SeekOut}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

show_usage() {
    cat << EOF
Usage: wt-migrate <mode> <source> [repo_name]

Modes:
  --from-dir <path>    Migrate from existing local git repository
  --from-url <url>     Clone fresh from GitHub URL

Arguments:
  source               Local path or GitHub HTTPS URL
  repo_name            Optional: Override the repository name

Examples:
  wt-migrate --from-dir "C:/Seekout/backend"
  wt-migrate --from-dir "C:/Seekout/AI-1099" AI-1099
  wt-migrate --from-url https://github.com/Zipstorm/backend.git
  wt-migrate --from-url https://github.com/Zipstorm/backend.git my-backend

Environment:
  WORKTREE_ROOT        Target directory (default: C:/worktrees-SeekOut)
EOF
}

# Detect default branch from remote
detect_default_branch() {
    local default_branch
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if [ -z "$default_branch" ]; then
        # Fallback: check for main or master
        if git show-ref --verify --quiet "refs/remotes/origin/main"; then
            default_branch="main"
        elif git show-ref --verify --quiet "refs/remotes/origin/master"; then
            default_branch="master"
        fi
    fi
    echo "$default_branch"
}

# Create standard worktrees
create_worktrees() {
    local bare_repo=$1
    cd "$bare_repo"

    local default_branch=$(detect_default_branch)

    # Create main/master worktree
    print_step "Creating main worktree..."
    if git show-ref --verify --quiet "refs/remotes/origin/main"; then
        git worktree add main origin/main
        print_success "Created main/ worktree"
    elif git show-ref --verify --quiet "refs/remotes/origin/master"; then
        git worktree add main origin/master
        print_success "Created main/ worktree (from master)"
    else
        print_warning "No main/master branch found"
    fi

    # Create develop worktree if exists
    if git show-ref --verify --quiet "refs/remotes/origin/develop"; then
        print_step "Creating develop worktree..."
        git worktree add develop origin/develop
        print_success "Created develop/ worktree"
    else
        print_warning "No develop branch found (skipping)"
    fi

    # Create placeholder directories
    mkdir -p _feature _review _hotfix

    print_success "Created _feature/, _review/, _hotfix/ directories"
}

# Migrate from existing local directory
migrate_from_dir() {
    local source_dir=$1
    local repo_name=$2

    # Validate source exists
    if [ ! -d "$source_dir" ]; then
        print_error "Source directory not found: $source_dir"
        exit 1
    fi

    # Validate it's a git repo
    if [ ! -d "$source_dir/.git" ]; then
        print_error "Not a git repository: $source_dir"
        exit 1
    fi

    # Auto-detect repo name if not provided
    if [ -z "$repo_name" ]; then
        repo_name=$(basename "$source_dir")
    fi

    local bare_repo="${WORKTREE_ROOT}/${repo_name}.git"

    echo ""
    echo "=========================================="
    echo " Migrating: $repo_name"
    echo "=========================================="
    echo ""
    echo "Source:      $source_dir"
    echo "Destination: $bare_repo"
    echo ""

    # Check if destination already exists
    if [ -d "$bare_repo" ]; then
        print_error "Destination already exists: $bare_repo"
        echo "Remove it first or choose a different name."
        exit 1
    fi

    # Get the remote URL from existing repo
    print_step "Reading remote URL from existing repo..."
    local remote_url
    remote_url=$(cd "$source_dir" && git remote get-url origin 2>/dev/null)

    if [ -z "$remote_url" ]; then
        print_error "No 'origin' remote found in source repo"
        exit 1
    fi
    print_success "Remote URL: $remote_url"

    # Ensure worktree root exists
    mkdir -p "$WORKTREE_ROOT"

    # Clone as bare repo (fresh from remote)
    print_step "Cloning bare repository from remote..."
    git clone --bare "$remote_url" "$bare_repo"
    print_success "Created bare repository"

    # Configure remote tracking
    print_step "Configuring remote tracking..."
    cd "$bare_repo"
    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    git fetch origin
    print_success "Configured fetch refspec"

    # Create worktrees
    create_worktrees "$bare_repo"

    # Summary
    echo ""
    echo "=========================================="
    echo " Migration Complete!"
    echo "=========================================="
    echo ""
    echo "New structure:"
    git worktree list
    echo ""
    echo "Your original repo at '$source_dir' is unchanged."
    echo "You can remove it once you verify everything works."
    echo ""
    echo "Next steps:"
    echo "  cd '$bare_repo/develop'   # or /main"
    echo "  wt-feature 'your-feature'"
    echo ""
}

# Clone fresh from URL
migrate_from_url() {
    local url=$1
    local repo_name=$2

    # Validate URL format
    if [[ ! "$url" =~ ^https://.*\.git$ ]] && [[ ! "$url" =~ ^git@.*\.git$ ]]; then
        print_warning "URL doesn't end with .git - appending..."
        url="${url}.git"
    fi

    # Auto-detect repo name if not provided
    if [ -z "$repo_name" ]; then
        repo_name=$(basename "$url" .git)
    fi

    local bare_repo="${WORKTREE_ROOT}/${repo_name}.git"

    echo ""
    echo "=========================================="
    echo " Setting up: $repo_name"
    echo "=========================================="
    echo ""
    echo "URL:         $url"
    echo "Destination: $bare_repo"
    echo ""

    # Check if destination already exists
    if [ -d "$bare_repo" ]; then
        print_error "Destination already exists: $bare_repo"
        echo "Remove it first or choose a different name."
        exit 1
    fi

    # Ensure worktree root exists
    mkdir -p "$WORKTREE_ROOT"

    # Clone as bare repo
    print_step "Cloning bare repository..."
    git clone --bare "$url" "$bare_repo"
    print_success "Created bare repository"

    # Configure remote tracking
    print_step "Configuring remote tracking..."
    cd "$bare_repo"
    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    git fetch origin
    print_success "Configured fetch refspec"

    # Create worktrees
    create_worktrees "$bare_repo"

    # Summary
    echo ""
    echo "=========================================="
    echo " Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Structure:"
    git worktree list
    echo ""
    echo "Next steps:"
    echo "  cd '$bare_repo/develop'   # or /main"
    echo "  wt-feature 'your-feature'"
    echo ""
}

# Main
main() {
    if [ $# -lt 2 ]; then
        show_usage
        exit 1
    fi

    local mode=$1
    local source=$2
    local repo_name=${3:-""}

    case "$mode" in
        --from-dir|-d)
            migrate_from_dir "$source" "$repo_name"
            ;;
        --from-url|-u)
            migrate_from_url "$source" "$repo_name"
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown mode: $mode"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
