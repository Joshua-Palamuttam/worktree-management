---
name: cut-release
description: >
  Create a release branch in a managed repo. Use when user wants to cut a release, create a release branch, or start a release process.
argument-hint: "[prefix] [--repo name] [--source branch] [--date date] [--dry-run]"
---

# Cut a Release Branch

Create and push a release branch in a managed repo under `C:/worktrees-SeekOut/`.

## Arguments

`$ARGUMENTS` may contain:
- **prefix** (optional, positional) — release sub-prefix like `pubapi`, `runtime`. Omit for flat release branches.
- **--repo name** — target repo by name, skipping auto-detection
- **--source branch** — override the source branch (default: `develop` or `main`)
- **--date date** — override today's date for the release branch name
- **--dry-run** — preview what would be created without making changes

## Process

### Step 1: Parse Arguments

Extract flags (`--repo`, `--source`, `--date`, `--dry-run`) and any remaining positional argument as the prefix from `$ARGUMENTS`.

### Step 2: Detect Repo

If `--repo` was provided, use that repo name directly. Otherwise, auto-detect:

1. Run `git rev-parse --git-common-dir 2>/dev/null` to get the bare repo path.
2. Check if the path is under `C:/worktrees-SeekOut/`. If NOT, go to step 4.
3. Extract repo name: `C:/worktrees-SeekOut/<name>.git/...` -> `<name>`. Done.
4. Read `C:/worktrees-SeekOut/worktree_management/config.yaml` for repo list. Ask via AskUserQuestion which repo to use.

### Step 3: Discover Release Prefixes (if no prefix given)

If no prefix was provided as a positional argument:

1. `cd` into the repo's bare dir and run:
   ```bash
   git fetch origin --quiet 2>/dev/null
   git branch -r --list 'origin/release/*' --sort=-committerdate | head -30
   ```
2. Parse the output to identify prefix groups. Examples:
   - `origin/release/pubapi/2026.03.01` -> prefix: `pubapi`
   - `origin/release/runtime/2026.03.01` -> prefix: `runtime`
   - `origin/release/2026.03.01` -> no prefix (flat)
3. If there are **multiple distinct prefixes**, ask via AskUserQuestion which prefix to use. Include a "(flat / no prefix)" option if flat branches also exist.
4. If there is only **one prefix** (or all are flat), proceed without asking.

### Step 4: Run the Script

```bash
cd "C:/worktrees-SeekOut/<repo>.git" && echo "y" | bash C:/worktrees-SeekOut/worktree_management/scripts/wt-release.sh [prefix] --repo <repo> [--source <branch>] [--date <date>] [--dry-run]
```

The `echo "y" |` pipes confirmation to the "Proceed? [Y/n]" prompt. The skill invocation itself serves as the user's intent to proceed.

### Step 5: Report Results

From the script output, report:
- **Branch name** created (e.g., `release/pubapi/03-02-26`)
- **Source commit** it was branched from
- **Whether it was pushed** to origin
- On `--dry-run`: clearly state this was a preview and no changes were made

If the script reports a collision (date already exists), report the patch suffix that was used (e.g., `.1`).

## Notes

- The script auto-detects date format from existing release branches in the repo.
- If the repo has never had release branches, the script will prompt for format — in that case, show the script output directly and let the user respond.
- Always `cd` into the repo's bare dir before running the script to ensure correct git context.
