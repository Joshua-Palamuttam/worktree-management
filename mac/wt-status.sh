#!/bin/bash
# wt-status.sh - Show status of all worktrees across repos (macOS)
# Usage: wt-status [repo_name]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/wt-lib.sh"

WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/Developer/worktrees}"
repo_filter="$1"

cd "$WORKTREE_ROOT"

echo ""
echo "Worktree Status"
echo "==============="
echo ""

for repo in *.git/; do
    [[ -d "$repo" ]] || continue
    repo_name="${repo%.git/}"
    [[ -n "$repo_filter" && "$repo_name" != "$repo_filter" ]] && continue

    echo "$repo_name"
    echo "$(printf '%0.s-' $(seq 1 ${#repo_name}))"

    cd "$WORKTREE_ROOT/$repo"

    git worktree list --porcelain | while read -r line; do
        if [[ "$line" == worktree* ]]; then
            wt_path="${line#worktree }"
            wt_name=$(basename "$wt_path")
        elif [[ "$line" == branch* ]]; then
            branch="${line#branch refs/heads/}"

            if [[ -d "$wt_path" ]]; then
                changes=$(cd "$wt_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
                if [[ "$changes" -gt 0 ]]; then
                    status="${YELLOW}${changes} changes${NC}"
                else
                    status="${GREEN}clean${NC}"
                fi

                ahead_behind=$(cd "$wt_path" && git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null || echo "0 0")
                ahead=$(echo "$ahead_behind" | awk '{print $1}')
                behind=$(echo "$ahead_behind" | awk '{print $2}')

                sync=""
                [[ "$ahead" -gt 0 ]] && sync+=" ${GREEN}+${ahead}${NC}"
                [[ "$behind" -gt 0 ]] && sync+=" ${RED}-${behind}${NC}"

                printf "  %-20s %-30s %b%b\n" "$wt_name" "$branch" "$status" "$sync"
            fi
        fi
    done

    echo ""
    cd "$WORKTREE_ROOT"
done
