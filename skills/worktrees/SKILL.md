---
name: worktrees
description: >
  Show git worktree status across all managed repos or a specific repo. Use when user asks about worktree status, active branches, or wants to see what's checked out.
argument-hint: "[repo-name]"
---

# Show Worktree Status

Display the status of all git worktrees managed under `C:/worktrees-SeekOut/`.

## Arguments

`$ARGUMENTS` may contain an optional repo name to filter to a single repo (e.g., `backend`, `agents`).

## Process

1. **Parse arguments**: If `$ARGUMENTS` is non-empty, treat it as a repo name filter.
2. **Run the status script**:
   ```
   bash C:/worktrees-SeekOut/worktree_management/scripts/wt-status.sh $ARGUMENTS
   ```
3. **Present the output directly** — the script already produces well-formatted output with repo names, branch info, change status, and ahead/behind indicators.

## Notes

- This skill does NOT need repo auto-detection — `wt-status.sh` handles iteration over all repos internally.
- If a specific repo name is given and doesn't match any `*.git/` directory, the script will report no results.
