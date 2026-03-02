---
name: hotfix
description: >
  Cherry-pick a merged PR into a release branch as a hotfix. Use when user needs to hotfix, cherry-pick a PR to release, or backport a fix.
argument-hint: "<PR#> [--ticket JIRA-ID] [--release branch] [--dry-run]"
---

# Hotfix a Merged PR to Release

Cherry-pick a merged pull request into a release branch, creating a hotfix worktree and a new PR.

## Arguments

`$ARGUMENTS` may contain:
- **PR#** (required, positional) — the pull request number to cherry-pick
- **--ticket JIRA-ID** — Jira ticket ID (e.g., `AI-1234`). If not provided, will attempt to extract from PR title/branch.
- **--release branch** — target release branch (e.g., `release/pubapi/2026.03.01`). If not provided, will show recent releases and ask.
- **--dry-run** — preview the cherry-pick plan without making changes

## Process

### Step 1: Parse Arguments

Extract the PR number and flags (`--ticket`, `--release`, `--dry-run`) from `$ARGUMENTS`. If no PR number is found, ask via AskUserQuestion: "Which PR number should be cherry-picked?"

### Step 2: Detect Repo

Auto-detect which repo the user is in:

1. Run `git rev-parse --git-common-dir 2>/dev/null` to get the bare repo path.
2. Check if the path is under `C:/worktrees-SeekOut/`. If NOT, go to step 4.
3. Extract repo name: `C:/worktrees-SeekOut/<name>.git/...` -> `<name>`. Done.
4. Read `C:/worktrees-SeekOut/worktree_management/config.yaml` for repo list. Ask via AskUserQuestion which repo to use.

### Step 3: Pre-flight PR Check

Run from the repo's bare dir:
```bash
cd "C:/worktrees-SeekOut/<repo>.git" && gh pr view <PR#> --json state,title,mergeCommit,headRefName
```

- If the PR is **not merged**, report this and stop — cherry-picking an unmerged PR doesn't work.
- Show the PR title for user confirmation/context.

### Step 4: Determine Release Branch

If `--release` was not provided:

1. List recent release branches:
   ```bash
   git branch -r --list 'origin/release/*' --sort=-committerdate | head -10
   ```
2. Ask via AskUserQuestion which release branch to target. Show the top 3-4 as options.

### Step 5: Determine Jira Ticket

If `--ticket` was not provided:

1. Try to extract a Jira ticket pattern from the PR title or branch name. Match patterns like `AI-1234`, `SPOT-567`, `REC-890` (uppercase letters + hyphen + digits).
2. If found, use it automatically and mention what was detected.
3. If not found, ask via AskUserQuestion: "What Jira ticket is this hotfix for? (or 'none' to skip)"

### Step 6: Run the Script

Always use `--quick` to skip the script's interactive postmortem Q&A (it doesn't work well non-interactively). Build the command:

```bash
cd "C:/worktrees-SeekOut/<repo>.git" && echo "y" | bash C:/worktrees-SeekOut/worktree_management/scripts/wt-hotfix-pr.sh <PR#> --ticket <ticket> --release <branch> --quick [--dry-run]
```

If no ticket was determined, omit `--ticket` and pass `--quick` (which skips the Jira prompt).

### Step 7: Handle Conflicts

Check the script output for conflict indicators (lines containing `CONFLICT`, `cherry-pick failed`, or `fix conflicts`).

If conflicts occurred:
1. List the conflicting files from the output
2. Show the worktree path where conflicts need resolution
3. Provide instructions:
   ```
   To resolve:
   1. cd <worktree-path>
   2. Edit the conflicting files
   3. git add <resolved-files>
   4. git cherry-pick --continue
   5. git push origin <branch>
   6. Create the PR manually: gh pr create --base <release-branch> --title "hotfix: <PR-title>"
   ```

### Step 8: Report Results

On success, report:
- **PR URL** — the newly created hotfix PR
- **Worktree location** — where the hotfix branch lives
- **Cleanup command** — `wt-hotfix-done <worktree-dir-name>` to clean up after merge

On `--dry-run`, clearly state this was a preview.

## Notes

- Always pass `--quick` to the script. The postmortem Q&A uses terminal-style piped stdin that doesn't work non-interactively. If the user wants a postmortem, they can ask Claude to generate one separately using the PR context.
- The script auto-detects merge strategy (merge commit vs squash vs rebase) for correct cherry-pick behavior.
- Worktrees are created under `_hotfix/` in the repo's bare dir.
