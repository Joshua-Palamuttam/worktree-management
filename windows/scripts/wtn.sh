#!/bin/bash
# wtn.sh - Interactive worktree navigation
#
# Smart flow:
#   - If in a repo: show worktree selection
#   - If not in a repo: show repo selection first, then worktree
#
# Options:
#   --code, -c    Launch Claude Code after navigating
#
# Supports partial input filtering (type text to filter, number to select)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to load config, or compute defaults
if [ -f "$SCRIPT_DIR/wt-config.sh" ]; then
    source "$SCRIPT_DIR/wt-config.sh"
else
    export WORKTREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# Parse arguments
LAUNCH_CODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --code|-c)
            LAUNCH_CODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: wtn [options]"
            echo ""
            echo "Interactive worktree navigation."
            echo ""
            echo "Options:"
            echo "  --code, -c    Launch Claude Code after navigating"
            echo "  --help, -h    Show this help message"
            return 0 2>/dev/null || exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# Function to display menu and get selection
# Usage: select_from_menu "prompt" item1 item2 item3 ...
# Returns selected item in $SELECTED
select_from_menu() {
    local prompt="$1"
    shift
    local items=("$@")
    local filtered=("${items[@]}")

    while true; do
        echo ""
        echo "$prompt"
        echo ""

        # Display numbered list
        local i=1
        for item in "${filtered[@]}"; do
            echo "  $i) $item"
            ((i++))
        done
        echo ""

        # Get input
        read -p "Choice (number or text to filter): " input

        # Empty input - cancel
        if [ -z "$input" ]; then
            SELECTED=""
            return 1
        fi

        # Check if input is a number
        if [[ "$input" =~ ^[0-9]+$ ]]; then
            local idx=$((input - 1))
            if [ $idx -ge 0 ] && [ $idx -lt ${#filtered[@]} ]; then
                SELECTED="${filtered[$idx]}"
                return 0
            else
                echo "Invalid selection"
                continue
            fi
        fi

        # Filter by partial match (case insensitive)
        filtered=()
        for item in "${items[@]}"; do
            if [[ "${item,,}" == *"${input,,}"* ]]; then
                filtered+=("$item")
            fi
        done

        # If only one match, select it
        if [ ${#filtered[@]} -eq 1 ]; then
            SELECTED="${filtered[0]}"
            return 0
        elif [ ${#filtered[@]} -eq 0 ]; then
            echo "No matches for '$input'"
            filtered=("${items[@]}")
        fi
    done
}

# Get list of repos
get_repos() {
    ls -1 "$WORKTREE_ROOT" 2>/dev/null | grep '\.git$' | sed 's/\.git$//'
}

# Get list of worktrees for a repo
get_worktrees() {
    local repo_path="$1"
    local worktrees=()

    # Main branches
    [ -d "$repo_path/main" ] && worktrees+=("main")
    [ -d "$repo_path/develop" ] && worktrees+=("develop")

    # Feature worktrees
    if [ -d "$repo_path/_feature" ]; then
        for d in "$repo_path/_feature"/*/; do
            [ -d "$d" ] && worktrees+=("$(basename "$d") (feature)")
        done
    fi

    # Hotfix worktrees
    if [ -d "$repo_path/_hotfix" ]; then
        for d in "$repo_path/_hotfix"/*/; do
            [ -d "$d" ] && worktrees+=("$(basename "$d") (hotfix)")
        done
    fi

    # Review worktrees
    if [ -d "$repo_path/_review" ]; then
        for d in "$repo_path/_review"/*/; do
            [ -d "$d" ] && worktrees+=("$(basename "$d") (review)")
        done
    fi

    printf '%s\n' "${worktrees[@]}"
}

# Navigate to worktree
navigate_to_worktree() {
    local repo_path="$1"
    local selection="$2"

    # Extract name (remove type suffix like " (feature)")
    local name=$(echo "$selection" | sed 's/ ([^)]*)$//')

    # Find the worktree path
    if [ -d "$repo_path/$name" ]; then
        cd "$repo_path/$name"
    elif [ -d "$repo_path/_feature/$name" ]; then
        cd "$repo_path/_feature/$name"
    elif [ -d "$repo_path/_hotfix/$name" ]; then
        cd "$repo_path/_hotfix/$name"
    elif [ -d "$repo_path/_review/$name" ]; then
        cd "$repo_path/_review/$name"
    else
        echo "Could not find worktree: $name"
        return 1
    fi

    echo "📂 $(pwd)"

    # Launch Claude Code if requested
    if [ "$LAUNCH_CODE" = true ]; then
        echo ""
        echo "🚀 Launching Claude Code..."
        claude
    fi
}

# Main logic
main() {
    local repo_path=""

    # Check if we're already in a repo
    local git_dir=$(git rev-parse --git-common-dir 2>/dev/null)
    if [ -n "$git_dir" ] && [ "$git_dir" != "." ]; then
        repo_path=$(cd "$git_dir" && pwd)
        local repo_name=$(basename "$repo_path" .git)
        echo "📁 In repo: $repo_name"
    elif [ -n "$git_dir" ] && [ "$git_dir" == "." ]; then
        repo_path=$(pwd)
        local repo_name=$(basename "$repo_path" .git)
        echo "📁 In repo: $repo_name"
    fi

    # If not in a repo, select one
    if [ -z "$repo_path" ]; then
        local repos=($(get_repos))
        if [ ${#repos[@]} -eq 0 ]; then
            echo "No repositories found in $WORKTREE_ROOT"
            return 1
        fi

        select_from_menu "Select repository:" "${repos[@]}"
        if [ -z "$SELECTED" ]; then
            echo "Cancelled"
            return 1
        fi

        repo_path="$WORKTREE_ROOT/${SELECTED}.git"
    fi

    # Select worktree
    local worktrees=($(get_worktrees "$repo_path"))
    if [ ${#worktrees[@]} -eq 0 ]; then
        echo "No worktrees found"
        return 1
    fi

    # Read worktrees into array properly (handle spaces in names)
    IFS=$'\n' read -d '' -r -a worktrees < <(get_worktrees "$repo_path" && printf '\0')

    select_from_menu "Select worktree:" "${worktrees[@]}"
    if [ -z "$SELECTED" ]; then
        echo "Cancelled"
        return 1
    fi

    navigate_to_worktree "$repo_path" "$SELECTED"
}

main
