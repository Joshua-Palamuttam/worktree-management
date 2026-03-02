---
name: feature-worktree-create
description: >
  Create a new feature worktree in a managed repo. Use when user wants to start work on a new feature branch with a dedicated worktree.
argument-hint: "<branch-name> [base-branch] [--repo name]"
---

# Create a Feature Worktree

Create a new git worktree for feature development in a managed repo under `C:/worktrees-SeekOut/`.

## Arguments

`$ARGUMENTS` may contain:
- **branch-name** (required) — the feature branch name (e.g., `AI-1234-my-feature`)
- **base-branch** (optional) — branch to base off of (default: `develop`, falls back to `main`)
- **--repo name** (optional) — target repo by name, skipping auto-detection

## Process

### Step 1: Parse Arguments

Extract the branch name, optional base branch, and optional `--repo` flag from `$ARGUMENTS`. If no branch name is provided, ask via AskUserQuestion: "What branch name should the feature worktree use?"

### Step 2: Detect Repo

If `--repo` was provided, use that repo name directly. Otherwise, auto-detect:

1. Run `git rev-parse --git-common-dir 2>/dev/null` to get the bare repo path.
2. Check if the path is under `C:/worktrees-SeekOut/`. If NOT (e.g., user is in an unrelated git repo or no git repo at all), go to step 4.
3. Extract repo name from the path: `C:/worktrees-SeekOut/<name>.git/...` -> `<name>`. Done.
4. Read `C:/worktrees-SeekOut/worktree_management/config.yaml` to get the list of repos. Ask the user via AskUserQuestion which repo to use (list repo names as options, max 4 most common + Other).

### Step 3: Run the Script

```bash
cd "C:/worktrees-SeekOut/<repo>.git" && bash C:/worktrees-SeekOut/worktree_management/scripts/wt-feature.sh <branch-name> [base-branch]
```

### Step 4: Report Results

From the script output, report:
- Worktree path (the `Location:` line)
- Branch name
- Base branch used
- Whether `.claude/` config was synced from another worktree

## Notes

- The script has no interactive prompts — it runs to completion.
- If the branch already exists (local or remote), the script creates a worktree from the existing branch rather than creating a new one.
- The script automatically copies `.claude/` and `.agent/` directories from `main`, `develop`, or `master` worktrees if they exist.
