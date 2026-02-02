# Worktree Management

A workflow for managing multiple repositories with git worktrees.

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](SETUP.md) | Step-by-step installation guide |
| [COMMANDS.md](COMMANDS.md) | Complete command reference |
| [README.md](README.md) | This file - overview and quick start |

## Quick Start

### For Git Bash

Add this line to your `~/.bashrc`:

```bash
source "C:/worktrees-SeekOut/worktree_management/scripts/wt-profile.sh"
```

Then reload: `source ~/.bashrc`

### For Windows Command Prompt

1. Add to PATH: `C:\worktrees-SeekOut\worktree_management\bin`
2. Run setup once:
```cmd
C:\worktrees-SeekOut\worktree_management\bin\setup.cmd
```

### Initialize a repository

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
# Based on develop

# When done:
wt-hotfix-done critical-bug
```

### Check status across all repos

```bash
wt-status
```

### Remove a worktree when done

```bash
wt-remove AI-1234-new-feature
```

## Navigation Shortcuts

| Command | Description |
|---------|-------------|
| `wtgo` | Jump to worktree root |
| `wtr <repo>` | Jump to repo (tab completion) |
| `wtd [repo]` | Jump to develop worktree |
| `wtm [repo]` | Jump to main worktree |
| `wtl` | List worktrees in current repo |
| `wt-remove <name>` | Remove a worktree |

## Directory Structure

```
C:/worktrees-SeekOut/
├── worktree_management/    # This management repo
│   ├── bin/                # Windows cmd wrappers
│   ├── scripts/            # Bash scripts
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

## Migrating Repositories

The `wt-migrate` script handles both fresh clones and existing local repos.

### From GitHub URL (recommended)

```bash
# Basic usage
wt-migrate --from-url https://github.com/Zipstorm/backend.git

# With custom name
wt-migrate --from-url https://github.com/Zipstorm/backend.git my-backend
```

### From Existing Local Directory

```bash
# Migrate from existing clone (fetches fresh from remote)
wt-migrate --from-dir "C:/Seekout/backend"

# With custom name
wt-migrate --from-dir "C:/Seekout/AI-1099" AI-1099
```

### What Migration Does

1. Clones the repo as a bare repository (`repo.git/`)
2. Configures proper remote tracking
3. Creates `main/` and `develop/` worktrees (if branches exist)
4. Creates `_feature/`, `_review/`, `_hotfix/` directories

Your original repos remain untouched - this creates a parallel structure.

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
wt-remove my-feature    # Remove a specific worktree
wt-cleanup              # Remove stale worktrees
wt-cleanup --dry-run    # Preview without changes
```
