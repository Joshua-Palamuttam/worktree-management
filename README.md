# Worktree Management

A Principal Engineer's workflow for managing multiple repositories with git worktrees.

## Quick Start

### 1. Add to your shell profile

Add this line to your `~/.bashrc` or `~/.zshrc`:

```bash
source "C:/worktrees-SeekOut/worktree_management/scripts/wt-profile.sh"
```

Then reload:
```bash
source ~/.bashrc  # or source ~/.zshrc
```

### 2. Initialize a repository

```bash
wt-init https://github.com/Zipstorm/backend.git
```

This creates:
```
C:/worktrees-SeekOut/
└── backend.git/
    ├── main/           # Clean main branch
    ├── develop/        # Integration branch
    ├── _feature/       # Your feature worktrees go here
    ├── _review/        # PR review worktrees
    └── _hotfix/        # Emergency hotfixes
```

## Daily Workflow

### Starting a new feature

```bash
wtr backend              # Jump to backend repo
wt-feature AI-1234-new-feature
# Now in: backend.git/_feature/AI-1234-new-feature/
```

### Reviewing a PR (instant context switch)

```bash
wt-review 4521
# Now in: backend.git/_review/current/
# Your feature work is untouched!

# When done:
wt-review-done
```

### Emergency hotfix

```bash
wt-hotfix critical-bug
# Now in: backend.git/_hotfix/critical-bug/
# Based on main, not develop

# When done:
wt-hotfix-done critical-bug
```

### Check status across all repos

```bash
wt-status
```

## Navigation Shortcuts

| Command | Description |
|---------|-------------|
| `wt` | Jump to worktree root |
| `wtr <repo>` | Jump to repo (tab completion) |
| `wtd [repo]` | Jump to develop worktree |
| `wtm [repo]` | Jump to main worktree |
| `wtl` | List worktrees in current repo |

## Directory Structure

```
C:/worktrees-SeekOut/
├── worktree_management/    # This management repo
│   ├── scripts/            # Shell functions
│   ├── templates/          # Claude/VSCode configs
│   └── config.yaml         # Repo registry
│
├── backend.git/            # Bare repo
│   ├── main/
│   ├── develop/
│   ├── _feature/
│   │   └── AI-1234-thing/
│   ├── _review/
│   │   └── current/
│   └── _hotfix/
│
├── AI-1099.git/
│   └── ...
│
└── integrations.git/
    └── ...
```

## Benefits

1. **Zero stashing** - Never lose context when switching tasks
2. **Instant PR reviews** - `wt-review 123` and you're reviewing
3. **Parallel AI agents** - Run Claude Code in separate worktrees
4. **Clean builds** - `main/` worktree is always pristine
5. **Muscle memory** - Same structure across all repos

## Migrating Existing Repos

Your old repos in `C:/Seekout/` remain untouched. This is a parallel structure.

To migrate a repo:
```bash
wt-init https://github.com/Zipstorm/repo-name.git
```

## Tips

### IDE Setup
- Open each worktree as a separate project/window
- Use VS Code's Git Worktree extension for easy switching
- Symlink shared configs from `templates/` if needed

### Claude Code
- Each worktree gets its own Claude context
- Run parallel agents on different features
- Use `_review/` worktree in read-only mode

### Cleanup
```bash
wt-cleanup           # See what can be cleaned
wt-cleanup --dry-run # Preview without changes
```
