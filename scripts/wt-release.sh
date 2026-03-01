#!/bin/bash
# wt-release.sh - Create a release branch and push it to origin
# Usage: wt-release [prefix] [--source <branch>] [--date <date>] [--repo <repo>] [--dry-run]
#
# Auto-discovers release branch naming conventions from existing branches.
# Works across repos with different patterns:
#   backend:     release/pubapi/03-01-26  (sub-prefix + MM-DD-YY)
#   AI-1099:     release/2026.02.23       (YYYY.MM.DD, with .N patch suffix)
#   recruit-api: release/2026.03.03       (YYYY.MM.DD)

set -e

# Parse arguments
prefix=""
source_branch=""
custom_date=""
repo_name=""
dry_run=false
workdir=""

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
        --workdir)
            workdir="$2"
            shift 2
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
            echo "  --help, -h             Show this help message"
            echo ""
            echo "Examples:"
            echo "  wt-release                           # Interactive (auto-detect everything)"
            echo "  wt-release pubapi                    # Backend: release/pubapi/MM-DD-YY"
            echo "  wt-release runtime                   # Backend: release/runtime/MM-DD-YY"
            echo "  wt-release --repo AI-1099            # AI-1099: release/YYYY.MM.DD"
            echo "  wt-release --repo recruit-api        # recruit-api: release/YYYY.MM.DD"
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

# Change to workdir if provided
if [ -n "$workdir" ]; then
    cd "$workdir"
fi

# If --repo specified, navigate to that repo
if [ -n "$repo_name" ]; then
    repo_root="${WORKTREE_ROOT:-C:/worktrees-SeekOut}/${repo_name}.git"
    if [ ! -d "$repo_root" ]; then
        echo "❌ Repository not found: ${repo_root}"
        exit 1
    fi
    cd "$repo_root"
else
    # Get repo root from current directory
    repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null)
    if [ -z "$repo_root" ] || [ "$repo_root" = ".git" ]; then
        echo "❌ Not in a git repository. Use --repo <name> or navigate to a repo first."
        exit 1
    fi
    cd "$repo_root"
fi

# Get repo display name
repo_display=$(basename "$(pwd)" .git)

# Fetch latest
echo "📥 Fetching latest from origin..."
git fetch origin < /dev/null

# Determine source branch
if [ -z "$source_branch" ]; then
    if git show-ref --verify --quiet refs/remotes/origin/develop; then
        source_branch="develop"
    elif git show-ref --verify --quiet refs/remotes/origin/main; then
        source_branch="main"
    else
        echo "❌ Could not determine source branch. Use --source <branch>."
        exit 1
    fi
fi

# Validate source branch exists
if ! git show-ref --verify --quiet "refs/remotes/origin/${source_branch}"; then
    echo "❌ Source branch 'origin/${source_branch}' not found."
    exit 1
fi

# Scan release branches (sorted by most recent first)
release_branches=$(git branch -r --list 'origin/release/*' --sort=-committerdate | sed 's|^ *origin/||')

if [ -z "$release_branches" ]; then
    echo "❌ No existing release branches found (origin/release/*)."
    echo "   Cannot auto-detect naming convention."
    echo ""
    echo "   To create the first release branch manually:"
    echo "   git branch release/<your-pattern> origin/${source_branch} && git push origin release/<your-pattern>"
    exit 1
fi

# Parse prefixes and date formats
# Group branches by their sub-prefix
# Use _FLAT_ sentinel for repos with no sub-prefix (e.g., release/2026.03.01)
_FLAT_="_FLAT_"
declare -A prefix_latest   # prefix -> most recent date part
declare -A prefix_count    # prefix -> count of branches
declare -a prefix_order    # ordered list of unique prefixes (first-seen order = most recent)

while IFS= read -r branch; do
    # Strip "release/" prefix
    remainder="${branch#release/}"

    # Check if there's a sub-prefix (has a / in the remainder)
    if [[ "$remainder" == */* ]]; then
        p="${remainder%%/*}"
        date_part="${remainder#*/}"
    else
        p="$_FLAT_"
        date_part="$remainder"
    fi

    # Skip non-date entries (e.g., release/PORT/jcw-bugfix)
    # A valid date part should start with a digit
    if [[ ! "$date_part" =~ ^[0-9] ]]; then
        continue
    fi

    # Track this prefix (first occurrence = most recent due to sort order)
    if [ -z "${prefix_count[$p]+x}" ]; then
        prefix_count["$p"]=0
        prefix_order+=("$p")
        prefix_latest["$p"]="$date_part"
    fi
    prefix_count["$p"]=$(( ${prefix_count["$p"]} + 1 ))
done <<< "$release_branches"

if [ ${#prefix_order[@]} -eq 0 ]; then
    echo "❌ No valid release branches found (no date-based branches)."
    exit 1
fi

# Determine which prefix to use
selected_prefix=""

if [ -n "$prefix" ]; then
    # User specified a prefix - validate it
    found=false
    for p in "${prefix_order[@]}"; do
        if [ "$p" = "$prefix" ]; then
            found=true
            break
        fi
    done
    if [ "$found" = false ]; then
        echo "❌ Release prefix '${prefix}' not found."
        echo ""
        echo "Available prefixes:"
        for p in "${prefix_order[@]}"; do
            if [ "$p" = "$_FLAT_" ]; then
                echo "   (none) - e.g., release/${prefix_latest[$p]}"
            else
                echo "   ${p} - e.g., release/${p}/${prefix_latest[$p]}"
            fi
        done
        exit 1
    fi
    selected_prefix="$prefix"
elif [ ${#prefix_order[@]} -eq 1 ]; then
    # Only one prefix - auto-select
    selected_prefix="${prefix_order[0]}"
    if [ "$selected_prefix" != "$_FLAT_" ]; then
        echo "📦 Auto-selected prefix: ${selected_prefix}"
    fi
else
    # Multiple prefixes - prompt user
    echo ""
    echo "📦 Release prefixes for ${repo_display}:"
    echo ""
    i=1
    for p in "${prefix_order[@]}"; do
        if [ "$p" = "$_FLAT_" ]; then
            echo "  ${i}) (flat) - e.g., release/${prefix_latest[$p]}  (${prefix_count[$p]} branches)"
        else
            echo "  ${i}) ${p} - e.g., release/${p}/${prefix_latest[$p]}  (${prefix_count[$p]} branches)"
        fi
        i=$((i + 1))
    done
    echo ""
    read -p "Select prefix (number or name): " selection < /dev/tty

    if [ -z "$selection" ]; then
        echo "Cancelled."
        exit 1
    fi

    if [[ "$selection" =~ ^[0-9]+$ ]]; then
        idx=$((selection - 1))
        if [ $idx -ge 0 ] && [ $idx -lt ${#prefix_order[@]} ]; then
            selected_prefix="${prefix_order[$idx]}"
        else
            echo "Invalid selection."
            exit 1
        fi
    else
        # Match by name
        found=false
        for p in "${prefix_order[@]}"; do
            if [ "$p" = "$selection" ]; then
                selected_prefix="$p"
                found=true
                break
            fi
        done
        if [ "$found" = false ]; then
            echo "❌ Prefix '${selection}' not found."
            exit 1
        fi
    fi
fi

# Get the most recent date for this prefix to detect format
latest_date="${prefix_latest[$selected_prefix]}"

# Detect date format from an example date string
detect_date_format() {
    local d="$1"

    # YYYY.MM.DD or YYYY.MM.DD.N (patch suffix)
    if [[ "$d" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}(\.[0-9]+)?$ ]]; then
        echo "YYYY.MM.DD"
        return
    fi

    # YYYY-MM-DD
    if [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "YYYY-MM-DD"
        return
    fi

    # MM-DD-YY
    if [[ "$d" =~ ^[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "MM-DD-YY"
        return
    fi

    # MM-DD-YYYY
    if [[ "$d" =~ ^[0-9]{2}-[0-9]{2}-[0-9]{4}$ ]]; then
        echo "MM-DD-YYYY"
        return
    fi

    echo "unknown"
}

date_format=$(detect_date_format "$latest_date")

if [ "$date_format" = "unknown" ]; then
    echo "⚠️  Could not detect date format from latest branch: release/.../${latest_date}"
    echo "   Please specify the date manually with --date <date>"
    exit 1
fi

# Generate today's date in the detected format
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

# Build the full branch name
if [ "$selected_prefix" != "$_FLAT_" ]; then
    release_name="release/${selected_prefix}/${today_date}"
else
    release_name="release/${today_date}"
fi

# Check for collisions and auto-increment patch suffix if needed
if git show-ref --verify --quiet "refs/remotes/origin/${release_name}"; then
    if [ "$date_format" = "YYYY.MM.DD" ]; then
        # This format supports patch suffixes (.1, .2, etc.)
        patch=1
        while git show-ref --verify --quiet "refs/remotes/origin/${release_name}.${patch}"; do
            patch=$((patch + 1))
        done
        release_name="${release_name}.${patch}"
        echo "⚠️  Branch for today already exists, using: ${release_name}"
    else
        echo "❌ Release branch '${release_name}' already exists on remote."
        echo "   Use --date to specify a different date."
        exit 1
    fi
fi

# Show summary
source_sha=$(git rev-parse --short "origin/${source_branch}")

echo ""
echo "🚀 Ready to create release branch:"
echo ""
echo "   Repo:     ${repo_display}"
echo "   Branch:   ${release_name}"
echo "   Source:   origin/${source_branch} (${source_sha})"
echo "   Format:   ${date_format}"
echo ""

# Dry run exits here
if [ "$dry_run" = true ]; then
    echo "   (dry run - no changes made)"
    exit 0
fi

read -p "Proceed? [Y/n] " proceed < /dev/tty
case "$proceed" in
    ""|[Yy]|[Yy]es) ;;
    *)
        echo "Cancelled."
        exit 1
        ;;
esac

# Create and push
echo ""
echo "📤 Creating and pushing release branch..."
git branch "$release_name" "origin/${source_branch}"
git push origin "$release_name"

echo ""
echo "✅ Release branch created and pushed!"
echo ""
echo "   ${release_name}"
echo ""
