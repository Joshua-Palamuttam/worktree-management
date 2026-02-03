#!/bin/bash
# wt-remove.sh - Remove a worktree
# Usage: wt-remove [worktree_name] [--force] [--delete-branch | --keep-branch]

worktree_name=""
force_flag=""
workdir=""
delete_branch=""  # empty = prompt, "yes" = delete, "no" = keep

while [[ $# -gt 0 ]]; do
    case $1 in
        --workdir)
            workdir="$2"
            shift 2
            ;;
        --force|-f)
            force_flag="--force"
            shift
            ;;
        --delete-branch|-d)
            delete_branch="yes"
            shift
            ;;
        --keep-branch|-k)
            delete_branch="no"
            shift
            ;;
        *)
            if [ -z "$worktree_name" ]; then
                worktree_name="$1"
            fi
            shift
            ;;
    esac
done

# Change to workdir if provided
if [ -n "$workdir" ]; then
    cd "$workdir"
fi

# Get the bare repo root
repo_root=$(git rev-parse --git-dir 2>/dev/null)
if [[ "$repo_root" == "." ]]; then
    repo_root=$(pwd)
elif [[ "$repo_root" == *.git ]]; then
    repo_root=$(cd "$repo_root" && pwd)
else
    repo_root=$(git rev-parse --git-common-dir 2>/dev/null)
    repo_root=$(cd "$repo_root" && pwd)
fi

cd "$repo_root"

# Function to get removable worktrees (excludes main, develop, master)
get_removable_worktrees() {
    local worktrees=()

    # Feature worktrees
    if [ -d "_feature" ]; then
        for d in "_feature"/*/; do
            [ -d "$d" ] && worktrees+=("$(basename "$d") (feature)")
        done
    fi

    # Hotfix worktrees
    if [ -d "_hotfix" ]; then
        for d in "_hotfix"/*/; do
            [ -d "$d" ] && worktrees+=("$(basename "$d") (hotfix)")
        done
    fi

    # Review worktrees
    if [ -d "_review" ]; then
        for d in "_review"/*/; do
            [ -d "$d" ] && worktrees+=("$(basename "$d") (review)")
        done
    fi

    printf '%s\n' "${worktrees[@]}"
}

# Interactive selection if no worktree specified
if [ -z "$worktree_name" ]; then
    echo ""
    echo "Select worktree to remove:"
    echo ""

    # Build list of removable worktrees
    declare -a worktrees
    declare -a worktree_paths
    count=0

    # Feature worktrees
    if [ -d "_feature" ]; then
        for d in "_feature"/*/; do
            if [ -d "$d" ]; then
                name=$(basename "$d")
                ((count++))
                worktrees[$count]="$name"
                worktree_paths[$count]="_feature/$name"
                echo "  $count) $name (feature)"
            fi
        done
    fi

    # Hotfix worktrees
    if [ -d "_hotfix" ]; then
        for d in "_hotfix"/*/; do
            if [ -d "$d" ]; then
                name=$(basename "$d")
                ((count++))
                worktrees[$count]="$name"
                worktree_paths[$count]="_hotfix/$name"
                echo "  $count) $name (hotfix)"
            fi
        done
    fi

    # Review worktrees
    if [ -d "_review" ]; then
        for d in "_review"/*/; do
            if [ -d "$d" ]; then
                name=$(basename "$d")
                ((count++))
                worktrees[$count]="$name"
                worktree_paths[$count]="_review/$name"
                echo "  $count) $name (review)"
            fi
        done
    fi

    if [ $count -eq 0 ]; then
        echo "  No removable worktrees found (main/develop are protected)"
        exit 0
    fi

    echo ""
    read -p "Choice (number or text to filter): " input

    if [ -z "$input" ]; then
        echo "Cancelled"
        exit 0
    fi

    # Check if number
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        if [ "$input" -ge 1 ] && [ "$input" -le $count ]; then
            worktree_name="${worktrees[$input]}"
            worktree_path="${worktree_paths[$input]}"
        else
            echo "Invalid selection"
            exit 1
        fi
    else
        # Filter by partial match
        matches=0
        match_name=""
        match_path=""
        for i in $(seq 1 $count); do
            if [[ "${worktrees[$i],,}" == *"${input,,}"* ]]; then
                ((matches++))
                match_name="${worktrees[$i]}"
                match_path="${worktree_paths[$i]}"
            fi
        done

        if [ $matches -eq 1 ]; then
            worktree_name="$match_name"
            worktree_path="$match_path"
        elif [ $matches -eq 0 ]; then
            echo "No matches for '$input'"
            exit 1
        else
            echo "Multiple matches for '$input', please be more specific"
            exit 1
        fi
    fi
else
    # Find the worktree path from name
    worktree_path=""

    # Check common locations
    if [ -d "_feature/$worktree_name" ]; then
        worktree_path="_feature/$worktree_name"
    elif [ -d "_hotfix/$worktree_name" ]; then
        worktree_path="_hotfix/$worktree_name"
    elif [ -d "_review/$worktree_name" ]; then
        worktree_path="_review/$worktree_name"
    elif [ -d "$worktree_name" ]; then
        worktree_path="$worktree_name"
    else
        echo "❌ Worktree not found: $worktree_name"
        echo ""
        echo "Available worktrees:"
        git worktree list
        exit 1
    fi
fi

# Get the branch name before removing
branch_name=$(cd "$worktree_path" && git branch --show-current 2>/dev/null) || true

echo "🗑️  Removing worktree: $worktree_path"

# Try to remove the worktree
remove_worktree() {
    git worktree remove "$worktree_path" $force_flag 2>&1
    return $?
}

# Attempt removal with retry logic for file locking
max_attempts=3
attempt=1

while [ $attempt -le $max_attempts ]; do
    output=$(remove_worktree 2>&1)
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        break
    fi

    # Check if it's a file locking issue
    if echo "$output" | grep -qi "failed\|locked\|denied\|in use"; then
        echo ""
        echo "⚠️  Directory appears to be locked. Common causes:"
        echo "   - VS Code or IDE has this folder open"
        echo "   - A terminal is cd'd into this directory"
        echo "   - Windows Search indexer or antivirus"
        echo ""

        if [ $attempt -lt $max_attempts ]; then
            read -p "Close any programs using this folder and press Enter to retry (or 'q' to quit): " retry
            if [ "$retry" = "q" ] || [ "$retry" = "Q" ]; then
                echo "Cancelled"
                exit 1
            fi
            ((attempt++))
        else
            echo ""
            echo "❌ Could not remove worktree after $max_attempts attempts."
            echo ""
            echo "Manual removal:"
            echo "  1. Close all programs using: $repo_root/$worktree_path"
            echo "  2. Run: rd /s /q \"$repo_root/$worktree_path\""
            echo "  3. Run: git worktree prune"
            exit 1
        fi
    else
        # Some other error
        echo "$output"
        exit 1
    fi
done

# Clean up
git worktree prune

echo "✅ Worktree removed: $worktree_path"

# Handle branch deletion
if [ -n "$branch_name" ] && [ "$branch_name" != "main" ] && [ "$branch_name" != "master" ] && [ "$branch_name" != "develop" ]; then
    if [ "$delete_branch" = "yes" ]; then
        # Delete branch automatically
        echo "🗑️  Deleting branch: $branch_name"
        git branch -D "$branch_name" 2>/dev/null || echo "⚠️  Could not delete branch (may not exist locally)"
    elif [ "$delete_branch" = "no" ]; then
        # Keep branch, no prompt
        echo "📌 Keeping local branch: $branch_name"
    else
        # Interactive prompt
        echo ""
        echo "The local branch '$branch_name' still exists."
        read -p "Delete the branch? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git branch -D "$branch_name" 2>/dev/null && echo "✅ Branch deleted: $branch_name" || echo "⚠️  Could not delete branch"
        else
            echo "📌 Keeping branch: $branch_name"
        fi
    fi
fi
