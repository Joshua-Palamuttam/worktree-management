# Worktree Commands Reference

All commands work in both **Git Bash** and **Windows Command Prompt**.

---

## Navigation Commands

### `wtn`
Interactive worktree navigation with smart flow and partial matching.

```cmd
wtn
```

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

### Morning Status Check
```cmd
wt-status                # See all repos at a glance
wt-cleanup --dry-run     # See what can be cleaned up
```
