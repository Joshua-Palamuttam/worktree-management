# Worktree Commands Reference

All commands work in both **Git Bash** and **Windows Command Prompt**.

---

## Navigation Commands

### `wtn`
Interactive worktree navigation with smart flow and partial matching.

```cmd
wtn              # Navigate to a worktree
wtn --code       # Navigate and launch Claude Code
wtn -c           # Short form
```

**Options:**
- `--code`, `-c` - Launch Claude Code after navigating to the worktree

**Smart flow:**
- If already in a repo: skips repo selection, shows worktree menu
- If not in a repo: shows repo selection first, then worktree menu

**Example session:**
```
$ wtn

Select repository:

  1) AI-1099
  2) backend
  3) integrations

Choice (number or text to filter): AI

In repo: AI-1099

Select worktree:

  1) main
  2) develop
  3) my-feature (feature)
  4) critical-fix (hotfix)

Choice (number or text to filter): feat

C:\worktrees-SeekOut\AI-1099.git\_feature\my-feature
```

**Features:**
- Type a number to select directly
- Type text to filter the list (case insensitive)
- If filter matches exactly one item, it's selected automatically
- Press Enter with no input to cancel

---

### `wtgo`
Jump to the worktrees root directory.

```cmd
wtgo
```
**Result:** Changes directory to `C:\worktrees-SeekOut\`

---

### `wtr [repo]`
Jump to a repository's bare directory, or list available repos.

```cmd
# List all available repos
wtr

# Jump to a specific repo
wtr backend
wtr AI-1099
```
**Result:** Changes directory to `C:\worktrees-SeekOut\<repo>.git\`

---

### `wtd [repo]`
Jump to the develop worktree.

```cmd
# From anywhere in a repo, jump to its develop worktree
wtd

# Jump to a specific repo's develop worktree
wtd backend
```
**Result:** Changes directory to `<repo>.git\develop\`

---

### `wtm [repo]`
Jump to the main worktree.

```cmd
# From anywhere in a repo, jump to its main worktree
wtm

# Jump to a specific repo's main worktree
wtm backend
```
**Result:** Changes directory to `<repo>.git\main\`

---

### `wtl`
List all worktrees in the current repository.

```cmd
wtl
```
**Example output:**
```
C:/worktrees-SeekOut/AI-1099.git          (bare)
C:/worktrees-SeekOut/AI-1099.git/develop  4bd11bde (detached HEAD)
C:/worktrees-SeekOut/AI-1099.git/main     9733532f (detached HEAD)
```

---

## Repository Setup Commands

### `wt-migrate`
Migrate a repository to the worktree structure.

**From GitHub URL (recommended):**
```cmd
wt-migrate --from-url https://github.com/Org/repo.git

# With custom name
wt-migrate --from-url https://github.com/Org/repo.git my-custom-name
```

**From existing local directory:**
```cmd
wt-migrate --from-dir "C:\path\to\existing\repo"

# With custom name
wt-migrate --from-dir "C:\Seekout\backend" backend
```

**What it does:**
1. Clones the repository as a bare repo (`repo.git/`)
2. Configures remote tracking for all branches
3. Creates `main/` worktree (from main or master branch)
4. Creates `develop/` worktree (if develop branch exists)
5. Creates `_feature/`, `_review/`, `_hotfix/` directories

---

### `wt-init`
Initialize a new repository for worktree workflow (alternative to wt-migrate).

```cmd
wt-init https://github.com/Org/repo.git
```

**Note:** `wt-migrate` is preferred as it has more options.

---

## Feature Development Commands

### `wt-feature`
Create a new feature worktree from develop, or use an existing branch.

```cmd
wt-feature my-feature-name
wt-feature AI-1234-add-login
wt-feature joshua/experimental-thing
```

**What it does:**
1. Fetches latest from origin
2. Checks if branch already exists (locally or remotely)
   - If exists: creates worktree from the existing branch
   - If new: creates new branch from `origin/develop`
3. Creates worktree at `_feature/<name>/`
4. Sets up upstream tracking

**Result:** New worktree at `<repo>.git\_feature\<name>\`

**Notes:**
- If the branch already exists, the command will use it instead of failing
- Automatically changes to the new worktree directory after creation

---

### `wt-hotfix`
Create a hotfix worktree from develop for urgent fixes.

```cmd
wt-hotfix critical-bug-fix
wt-hotfix payment-issue
```

**What it does:**
1. Fetches latest from origin
2. Creates new branch `hotfix/<name>` from `origin/develop`
3. Creates worktree at `_hotfix/<name>/`

**Result:** New worktree at `<repo>.git\_hotfix\<name>\`

**Note:** Automatically changes to the new worktree directory after creation.

---

### `wt-hotfix-done`
Clean up a hotfix worktree after merging.

```cmd
wt-hotfix-done critical-bug-fix
wt-hotfix-done payment-issue
```

**What it does:**
1. Removes the `_hotfix/<name>/` worktree
2. Prunes git worktree references

---

### `wt-hotfix-pr`
Cherry-pick a merged develop PR onto the latest release branch, with Jira tracking and postmortem.

```cmd
# Cherry-pick PR #456 to latest release branch (prompts for Jira ticket)
wt-hotfix-pr 456

# With Jira ticket specified upfront
wt-hotfix-pr 456 --ticket AI-1234

# Target a specific release branch
wt-hotfix-pr 456 --ticket AI-1234 --release release/2026-02-04

# Preview what would happen (no changes)
wt-hotfix-pr 456 --dry-run
```

**Options:**
- `--ticket <JIRA-ID>` - Jira ticket ID (prompted interactively if not provided)
- `--release <branch>` - Target a specific release branch instead of auto-detecting
- `--dry-run` - Show summary without making changes

**What it does:**
1. Looks up the PR on GitHub (requires `gh` CLI)
2. Validates the PR is merged and gets merge commit details
3. Auto-detects the merge strategy (squash, merge commit, or rebase)
4. Finds the latest `release/*` branch (or uses `--release`)
5. Prompts for Jira ticket (if not passed via `--ticket`)
6. Confirms the release branch and cherry-pick plan with the user
7. Creates a worktree at `_hotfix/hotfix-pr-<N>/`
8. Cherry-picks using the appropriate strategy:
   - **Squash merge:** `cherry-pick <sha>` (single commit)
   - **Merge commit:** `cherry-pick -m 1 <sha>`
   - **Rebase merge:** `cherry-pick <range>` (all rebased commits)
9. If conflicts occur: lists files, opens editor, waits for resolution
10. Pushes the branch
11. Asks postmortem questions (why needed, business impact, testing, notes)
12. Generates AI-enhanced postmortem via `claude` CLI (falls back to manual template if not installed)
13. Creates a PR with the postmortem in the description

**Merge strategy detection:**
The command automatically detects how the original PR was merged:
- If the merge commit has multiple parents → merge commit
- If the PR had 1 commit → squash/single commit
- If the PR had multiple commits → uses patch-id comparison to distinguish squash vs rebase

**Naming conventions:**
- Hotfix branch: `hotfix/<JIRA-ID>-pr-<N>-to-<date>` (e.g., `hotfix/AI-1234-pr-456-to-2026-02-04`)
- Worktree dir: `_hotfix/hotfix-pr-<N>` (e.g., `_hotfix/hotfix-pr-456`)
- PR title: `[<JIRA-ID>] Cherry-pick PR #<N> to release/<date>`

**Cleanup:** Uses existing `wt-hotfix-done` command:
```cmd
wt-hotfix-done hotfix-pr-456
```

**Note:** Automatically changes to the new worktree directory after creation.

---

### `wt-sync`
Sync a branch with develop (or another target branch). Supports interactive selection.

```cmd
# Interactive mode - select which branch to sync
wt-sync

# Interactive with merge strategy
wt-sync --merge

# Sync a specific branch with develop
wt-sync my-feature

# Sync a specific branch with main
wt-sync my-feature main
```

**Interactive mode:**
```
$ wt-sync

📁 Repo: AI-1099

Select branch to sync with develop:

  1) AI-1234-new-feature (feature)
  2) AI-5678-bugfix (feature)
  3) critical-fix (hotfix)

Choice (number or text to filter): 1
```

**Smart flow:**
- If not in a repo: shows repo selection first
- Then shows list of feature/hotfix/review branches to sync
- Type a number to select, or text to filter

**What it does:**
1. Fetches latest from origin
2. Rebases (default) or merges the target branch into selected branch
3. If you have uncommitted changes, offers to stash them first

**Options:**
- `--rebase` - Rebase onto target (default, cleaner history)
- `--merge` - Merge target into current branch (preserves merge commits)

**Conflict handling:**
If conflicts occur during rebase:
```cmd
# Fix conflicts, then:
git rebase --continue

# Or abort:
git rebase --abort
```

If conflicts occur during merge:
```cmd
# Fix conflicts, then:
git commit

# Or abort:
git merge --abort
```

---

## Code Review Commands

### `wt-review`
Quickly checkout a PR or branch for review.

```cmd
# By PR number (requires gh CLI for best experience)
wt-review 123
wt-review 4567

# By branch name
wt-review feature/someones-feature
wt-review joshua/new-api
```

**What it does:**
1. Removes any existing review worktree
2. Fetches the PR or branch from origin
3. Creates worktree at `_review/current/`

**Result:** Ready to review at `<repo>.git\_review\current\`

**Notes:**
- Your current feature work is completely untouched!
- Automatically changes to the review worktree directory after creation

---

### `wt-review-done`
Clean up the review worktree after completing a review.

```cmd
wt-review-done
```

**What it does:**
1. Removes the `_review/current/` worktree
2. Prunes git worktree references
3. Deletes the local PR branch (if it was a PR)

---

### `wt-remove`
Remove a feature, hotfix, or any worktree when you're done with it.

```cmd
# Interactive mode - select from list
wt-remove

# Remove a specific worktree (prompts about branch deletion)
wt-remove AI-1234-feature

# Remove worktree AND delete the branch
wt-remove AI-1234-feature -d

# Remove worktree but keep the branch (no prompt)
wt-remove AI-1234-feature -k

# Force remove (with uncommitted changes)
wt-remove my-branch --force
```

**Interactive mode:**
```
$ wt-remove

Select worktree to remove:

  1) AI-1234-feature (feature)
  2) critical-fix (hotfix)
  3) current (review)

Choice (number or text to filter): 1
```

**Options:**
- `--force`, `-f` - Force remove even with uncommitted changes
- `--delete-branch`, `-d` - Also delete the local branch (no prompt)
- `--keep-branch`, `-k` - Keep the local branch (no prompt)

**What it does:**
1. If no name given, shows interactive list of removable worktrees
2. Finds the worktree in `_feature/`, `_hotfix/`, or `_review/`
3. Removes the worktree (with retry logic for locked files)
4. Prunes git references
5. Prompts to delete the branch (unless `-d` or `-k` specified)

**File locking:** If the directory is locked (IDE open, terminal inside), you can choose to [R]etry, [F]orce delete, or [Q]uit. Force delete will remove the directory even if locked.

**Note:** Automatically moves you to the repo root after removal (so you're not stuck in a deleted directory).

---

## Maintenance Commands

### `wt-status`
Show status of all worktrees across all repositories.

```cmd
# All repos
wt-status

# Specific repo
wt-status backend
```

**Example output:**
```
📊 Worktree Status Report
=========================

📁 AI-1099
─────────────────────────────
  main                 main                           ✓ clean
  develop              develop                        ✓ clean
  my-feature           feature/my-feature             ⚠️ 3 changes ↑2

📁 backend
─────────────────────────────
  main                 main                           ✓ clean
  develop              develop                        ✓ clean ↓5
```

---

### `wt-cleanup`
Remove stale worktrees and identify merged branches.

```cmd
# Preview what would be cleaned
wt-cleanup --dry-run

# Actually clean up
wt-cleanup
```

**What it does:**
1. Prunes worktrees that no longer exist on disk
2. Identifies feature branches that have been merged
3. Reports what can be safely removed

---

## Quick Reference Table

| Command | Description | Example |
|---------|-------------|---------|
| `wtn` | Interactive navigation (smart flow) | `wtn` |
| `wtn -c` | Navigate + launch Claude Code | `wtn --code` |
| `wtgo` | Go to worktrees root | `wtgo` |
| `wtr` | List repos | `wtr` |
| `wtr <repo>` | Go to repo | `wtr backend` |
| `wtd` | Go to develop | `wtd` |
| `wtm` | Go to main | `wtm` |
| `wtl` | List worktrees | `wtl` |
| `wt-migrate --from-url <url>` | Setup repo from GitHub | `wt-migrate --from-url https://github.com/Org/repo.git` |
| `wt-migrate --from-dir <path>` | Setup repo from local | `wt-migrate --from-dir "C:\code\repo"` |
| `wt-feature <name>` | New feature branch | `wt-feature AI-1234-thing` |
| `wt-hotfix <name>` | New hotfix branch | `wt-hotfix urgent-fix` |
| `wt-hotfix-done <name>` | Remove hotfix worktree | `wt-hotfix-done urgent-fix` |
| `wt-hotfix-pr <pr#>` | Cherry-pick merged PR to release | `wt-hotfix-pr 456 --ticket AI-1234` |
| `wt-sync` | Sync branch with develop | `wt-sync` |
| `wt-sync <branch>` | Sync with specific branch | `wt-sync main --merge` |
| `wt-review <pr#>` | Review a PR | `wt-review 123` |
| `wt-review-done` | Done reviewing | `wt-review-done` |
| `wt-remove` | Interactive worktree removal | `wt-remove` |
| `wt-remove <name>` | Remove specific worktree | `wt-remove AI-1234-thing` |
| `wt-remove <name> -d` | Remove worktree and branch | `wt-remove AI-1234-thing -d` |
| `wt-status` | Status of all repos | `wt-status` |
| `wt-cleanup` | Clean stale worktrees | `wt-cleanup --dry-run` |

---

## Workflow Examples

### Daily Feature Development
```cmd
wtr backend              # Go to backend repo
wtd                      # Go to develop
git pull                 # Get latest
wt-feature AI-1234-new-api
# ... work on feature ...
git add -A && git commit -m "Add new API"
git push -u origin AI-1234-new-api
```

### Quick PR Review (no context switch pain)
```cmd
# You're working on a feature...
wt-review 456            # Checkout PR #456
# ... review code, run tests ...
wt-review-done           # Clean up
# Back to your feature, exactly where you left off
```

### Emergency Hotfix
```cmd
wtr backend
wt-hotfix payment-broken
# ... fix the issue ...
git add -A && git commit -m "Fix payment processing"
git push -u origin hotfix/payment-broken
# Create PR, merge, then cleanup:
cd ..
git worktree remove _hotfix/payment-broken
```

### Hotfix from Develop PR
```cmd
# A PR was merged to develop but also needs to go to the current release
wt-hotfix-pr 456 --ticket AI-1234
# ... resolve conflicts if any ...
# Answer postmortem questions, AI-generated summary added to PR
# PR is automatically created targeting the release branch

# When the hotfix PR is merged, clean up:
wt-hotfix-done hotfix-pr-456
```

### Keeping Feature Branch Up to Date
```cmd
# Working on a feature for a few days? Sync with develop regularly
wt-sync                  # Rebase your feature onto latest develop

# If you prefer merge commits
wt-sync --merge          # Merge develop into your feature
```

### Morning Status Check
```cmd
wt-status                # See all repos at a glance
wt-cleanup --dry-run     # See what can be cleaned up
```
