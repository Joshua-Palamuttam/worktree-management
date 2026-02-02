# Worktree Commands Reference

All commands work in both **Git Bash** and **Windows Command Prompt**.

---

## Navigation Commands

### `wt`
Jump to the worktrees root directory.

```cmd
wt
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
Create a new feature worktree from develop.

```cmd
wt-feature my-feature-name
wt-feature AI-1234-add-login
wt-feature joshua/experimental-thing
```

**What it does:**
1. Fetches latest from origin
2. Creates new branch from `origin/develop`
3. Creates worktree at `_feature/<name>/`
4. Sets up upstream tracking

**Result:** New worktree at `<repo>.git\_feature\<name>\`

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

**Note:** Your current feature work is completely untouched!

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
| `wt` | Go to worktrees root | `wt` |
| `wtr` | List repos | `wtr` |
| `wtr <repo>` | Go to repo | `wtr backend` |
| `wtd` | Go to develop | `wtd` |
| `wtm` | Go to main | `wtm` |
| `wtl` | List worktrees | `wtl` |
| `wt-migrate --from-url <url>` | Setup repo from GitHub | `wt-migrate --from-url https://github.com/Org/repo.git` |
| `wt-migrate --from-dir <path>` | Setup repo from local | `wt-migrate --from-dir "C:\code\repo"` |
| `wt-feature <name>` | New feature branch | `wt-feature AI-1234-thing` |
| `wt-hotfix <name>` | New hotfix branch | `wt-hotfix urgent-fix` |
| `wt-review <pr#>` | Review a PR | `wt-review 123` |
| `wt-review-done` | Done reviewing | `wt-review-done` |
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

### Morning Status Check
```cmd
wt-status                # See all repos at a glance
wt-cleanup --dry-run     # See what can be cleaned up
```
