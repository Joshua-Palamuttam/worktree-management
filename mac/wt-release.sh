#!/bin/bash
# wt-release.sh - Create a release branch and push it to origin (macOS)
# Usage: wt-release [prefix] [--source <branch>] [--date <date>] [--repo <repo>] [--dry-run]
#
# Auto-discovers release branch naming conventions from existing branches.

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wt-lib.sh"

# Parse arguments
prefix=""
source_branch=""
custom_date=""
repo_name=""
dry_run=false
auto_yes=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --source)
            source_branch="$2"
            shift 2
            ;;
        --date)
            custom_date="$2"
            shift 2
            ;;
        --repo)
            repo_name="$2"
            shift 2
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        --yes|-y)
            auto_yes=true
            shift
            ;;
        --help|-h)
            echo "Usage: wt-release [prefix] [options]"
            echo ""
            echo "Create a release branch from the source branch and push it to origin."
            echo "Auto-discovers naming conventions from existing release branches."
            echo ""
            echo "Arguments:"
            echo "  prefix                 Release prefix (e.g., pubapi, runtime, cf)"
            echo "                         Only needed for repos with sub-prefixes (like backend)"
            echo "                         Omit for repos with flat release branches (like AI-1099)"
            echo ""
            echo "Options:"
            echo "  --source <branch>      Source branch (default: develop or main)"
            echo "  --date <date>          Override today's date (must match repo's format)"
            echo "  --repo <name>          Target a specific repo (default: current repo)"
            echo "  --dry-run              Show what would happen without making changes"
            echo "  --yes, -y              Skip confirmation prompt (for automation)"
            echo "  --help, -h             Show this help message"
            echo ""
            echo "Examples:"
            echo "  wt-release                           # Interactive (auto-detect everything)"
            echo "  wt-release pubapi                    # Backend: release/pubapi/MM-DD-YY"
            echo "  wt-release --repo AI-1099            # AI-1099: release/YYYY.MM.DD"
            echo "  wt-release pubapi --source main      # Release from main instead of develop"
            echo "  wt-release pubapi --date 03-05-26    # Override the date"
            echo "  wt-release --dry-run                 # Preview only"
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            if [ -z "$prefix" ]; then
                prefix="$1"
            fi
            shift
            ;;
    esac
done

# Navigate to repo
if [ -n "$repo_name" ]; then
    repo_root="${WORKTREE_ROOT:-$HOME/Developer/worktrees}/${repo_name}.git"
    if [ ! -d "$repo_root" ]; then
        err "Repository not found: ${repo_root}"
        exit 1
    fi
    cd "$repo_root"
else
    repo_root=$(get_repo_root) || {
        err "Not in a git repository. Use --repo <name> or navigate to a repo first."
        exit 1
    }
    cd "$repo_root"
fi

repo_display=$(basename "$(pwd)" .git)

# Fetch latest
info "Fetching latest from origin..."
git fetch origin < /dev/null

# Determine source branch
if [ -z "$source_branch" ]; then
    if git show-ref --verify --quiet refs/remotes/origin/develop; then
        source_branch="develop"
    elif git show-ref --verify --quiet refs/remotes/origin/main; then
        source_branch="main"
    else
        err "Could not determine source branch. Use --source <branch>."
        exit 1
    fi
fi

if ! git show-ref --verify --quiet "refs/remotes/origin/${source_branch}"; then
    err "Source branch 'origin/${source_branch}' not found."
    exit 1
fi

# Scan release branches
release_branches=$(git branch -r --list 'origin/release/*' --sort=-committerdate | sed 's|^ *origin/||')

if [ -z "$release_branches" ]; then
    err "No existing release branches found (origin/release/*)."
    echo "   Cannot auto-detect naming convention."
    exit 1
fi

# Parse prefixes and date formats using parallel arrays (bash 3 compatible)
_FLAT_="_FLAT_"
prefix_order=()
prefix_latest=()
prefix_count=()

_find_prefix_idx() {
    local needle="$1" i
    for i in "${!prefix_order[@]}"; do
        [[ "${prefix_order[$i]}" == "$needle" ]] && echo "$i" && return 0
    done
    return 1
}

while IFS= read -r branch; do
    remainder="${branch#release/}"
    if [[ "$remainder" == */* ]]; then
        p="${remainder%%/*}"
        date_part="${remainder#*/}"
    else
        p="$_FLAT_"
        date_part="$remainder"
    fi

    [[ ! "$date_part" =~ ^[0-9] ]] && continue

    idx=$(_find_prefix_idx "$p") || {
        prefix_order+=("$p")
        prefix_latest+=("$date_part")
        prefix_count+=(1)
        continue
    }
    prefix_count[$idx]=$(( ${prefix_count[$idx]} + 1 ))
done <<< "$release_branches"

if [ ${#prefix_order[@]} -eq 0 ]; then
    err "No valid release branches found (no date-based branches)."
    exit 1
fi

# Determine which prefix to use
selected_prefix=""
selected_idx=""

if [ -n "$prefix" ]; then
    idx=$(_find_prefix_idx "$prefix") || {
        err "Release prefix '${prefix}' not found."
        echo ""
        echo "Available prefixes:"
        for i in "${!prefix_order[@]}"; do
            p="${prefix_order[$i]}"
            if [ "$p" = "$_FLAT_" ]; then
                echo "   (none) - e.g., release/${prefix_latest[$i]}"
            else
                echo "   ${p} - e.g., release/${p}/${prefix_latest[$i]}"
            fi
        done
        exit 1
    }
    selected_prefix="$prefix"
    selected_idx="$idx"
elif [ ${#prefix_order[@]} -eq 1 ]; then
    selected_prefix="${prefix_order[0]}"
    selected_idx=0
    if [ "$selected_prefix" != "$_FLAT_" ]; then
        info "Auto-selected prefix: ${selected_prefix}"
    fi
else
    # Multiple prefixes - use fzf for selection
    choices=""
    for i in "${!prefix_order[@]}"; do
        p="${prefix_order[$i]}"
        if [ "$p" = "$_FLAT_" ]; then
            choices+="(flat) - e.g., release/${prefix_latest[$i]}  (${prefix_count[$i]} branches)\n"
        else
            choices+="${p} - e.g., release/${p}/${prefix_latest[$i]}  (${prefix_count[$i]} branches)\n"
        fi
    done

    selected=$(echo -e "$choices" | sed '/^$/d' | fzf_select "Release prefix")
    [[ -z "$selected" ]] && { echo "Cancelled."; exit 1; }

    # Extract prefix name from selection
    sel_name="${selected%% -*}"
    sel_name="${sel_name## }"
    if [ "$sel_name" = "(flat)" ]; then
        selected_prefix="$_FLAT_"
    else
        selected_prefix="$sel_name"
    fi
    selected_idx=$(_find_prefix_idx "$selected_prefix")
fi

latest_date="${prefix_latest[$selected_idx]}"

# Detect date format
detect_date_format() {
    local d="$1"
    if [[ "$d" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}(\.[0-9]+)?$ ]]; then
        echo "YYYY.MM.DD"; return
    fi
    if [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "YYYY-MM-DD"; return
    fi
    if [[ "$d" =~ ^[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "MM-DD-YY"; return
    fi
    if [[ "$d" =~ ^[0-9]{2}-[0-9]{2}-[0-9]{4}$ ]]; then
        echo "MM-DD-YYYY"; return
    fi
    echo "unknown"
}

date_format=$(detect_date_format "$latest_date")

if [ "$date_format" = "unknown" ]; then
    warn "Could not detect date format from latest branch: release/.../${latest_date}"
    echo "   Please specify the date manually with --date <date>"
    exit 1
fi

# Generate today's date
generate_date() {
    local fmt="$1"
    case "$fmt" in
        "YYYY.MM.DD") date +"%Y.%m.%d" ;;
        "YYYY-MM-DD") date +"%Y-%m-%d" ;;
        "MM-DD-YY")   date +"%m-%d-%y" ;;
        "MM-DD-YYYY") date +"%m-%d-%Y" ;;
    esac
}

if [ -n "$custom_date" ]; then
    today_date="$custom_date"
else
    today_date=$(generate_date "$date_format")
fi

# Build full branch name
if [ "$selected_prefix" != "$_FLAT_" ]; then
    release_name="release/${selected_prefix}/${today_date}"
else
    release_name="release/${today_date}"
fi

# Auto-increment patch suffix on collision
if git show-ref --verify --quiet "refs/remotes/origin/${release_name}"; then
    if [ "$date_format" = "YYYY.MM.DD" ]; then
        patch=1
        while git show-ref --verify --quiet "refs/remotes/origin/${release_name}.${patch}"; do
            patch=$((patch + 1))
        done
        release_name="${release_name}.${patch}"
        warn "Branch for today already exists, using: ${release_name}"
    else
        err "Release branch '${release_name}' already exists on remote."
        echo "   Use --date to specify a different date."
        exit 1
    fi
fi

# Show summary
source_sha=$(git rev-parse --short "origin/${source_branch}")

echo ""
echo "Ready to create release branch:"
echo ""
echo "   Repo:     ${repo_display}"
echo "   Branch:   ${release_name}"
echo "   Source:   origin/${source_branch} (${source_sha})"
echo "   Format:   ${date_format}"
echo ""

if [ "$dry_run" = true ]; then
    echo "   (dry run - no changes made)"
    exit 0
fi

if [ "$auto_yes" = true ]; then
    echo "   (auto-confirmed via --yes)"
else
    read -p "Proceed? [Y/n] " proceed < /dev/tty
    case "$proceed" in
        ""|[Yy]|[Yy]es) ;;
        *)
            echo "Cancelled."
            exit 1
            ;;
    esac
fi

echo ""
info "Creating and pushing release branch..."
git branch "$release_name" "origin/${source_branch}"
git push origin "$release_name"

echo ""
success "Release branch created and pushed!"
echo ""
echo "   ${release_name}"
echo ""
