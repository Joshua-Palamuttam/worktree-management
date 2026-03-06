# Worktree Management

A workflow for managing multiple repositories with git worktrees. Supports both Windows and macOS with platform-native implementations.

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](SETUP.md) | Step-by-step installation guide |
| [COMMANDS.md](COMMANDS.md) | Complete command reference |
| [README.md](README.md) | This file - overview and quick start |

## Quick Start

### macOS

Add this line to your `~/.zshrc`:

```zsh
source ~/Developer/worktree-management/mac/wt-profile.zsh
```

Then reload: `source ~/.zshrc`

### Windows (Git Bash)

Add this line to your `~/.bashrc`:

```bash
source "C:/worktrees-SeekOut/worktree_management/windows/scripts/wt-profile.sh"
```

Then reload: `source ~/.bashrc`

### Windows (Command Prompt)

1. Add to PATH: `C:\worktrees-SeekOut\worktree_management\windows\bin`
2. Run setup once:
```cmd
C:\worktrees-SeekOut\worktree_management\windows\bin\setup.cmd
```

### Initialize a repository

```bash
wt-migrate --from-url https://github.com/YourOrg/backend.git
```

This creates:
```
~/Developer/worktrees/          # macOS
C:/worktrees-SeekOut/           # Windows

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

# When done:
wt-hotfix-done critical-bug
```

### Cutting a release

```bash
wt-release pubapi         # Backend: release/pubapi/MM-DD-YY
wt-release --repo AI-1099 # AI-1099: release/YYYY.MM.DD
```

### Cherry-pick a PR to release

```bash
wt-hotfix-pr 456 --ticket AI-1234
# Creates worktree, cherry-picks, creates PR with postmortem
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
| `wtn` | Interactive navigation (fzf on Mac, menus on Windows) |
| `wtgo` | Jump to worktree root |
| `wtr <repo>` | Jump to repo (tab completion) |
| `wtd [repo]` | Jump to develop worktree |
| `wtm [repo]` | Jump to main worktree |
| `wtl` | List worktrees in current repo |
| `wt-remove <name>` | Remove a worktree |

## Directory Structure

```
worktree-management/            # This management repo
├── mac/                        # macOS scripts (bash + zsh profile)
│   ├── wt-profile.zsh          # Source from ~/.zshrc
│   ├── wt-lib.sh               # Shared helpers
│   └── wt-*.sh                 # Command scripts
├── windows/                    # Windows scripts
│   ├── bin/                    # .cmd wrappers for Command Prompt
│   └── scripts/                # .sh scripts for Git Bash
├── skills/                     # Claude Code skills (shared)
├── templates/                  # Config templates (shared)
└── config.yaml                 # Repo registry (shared)

~/Developer/worktrees/          # Managed repos (macOS)
C:\worktrees-SeekOut\           # Managed repos (Windows)
├── backend.git/
│   ├── main/
│   ├── develop/
│   ├── _feature/
│   │   └── AI-1234-thing/
│   ├── _review/
│   │   └── current/
│   └── _hotfix/
├── AI-1099.git/
│   └── ...
└── integrations.git/
    └── ...
```

## Platform Differences

| Aspect | macOS | Windows |
|--------|-------|---------|
| Shell profile | `wt-profile.zsh` (zsh) | `wt-profile.sh` (bash) |
| Interactive selection | fzf | Numbered menus |
| Tab completion | zsh `compdef` | bash `complete -F` |
| Default worktree root | `~/Developer/worktrees` | `C:/worktrees-SeekOut` |
| CMD support | N/A | `.cmd` wrappers in `windows/bin/` |

## Benefits

1. **Zero stashing** - Never lose context when switching tasks
2. **Instant PR reviews** - `wt-review 123` and you're reviewing
3. **Parallel AI agents** - Run Claude Code in separate worktrees
4. **Clean builds** - `main/` worktree is always pristine
5. **Muscle memory** - Same structure across all repos

## Tips

### IDE Setup
- Open each worktree as a separate project/window
- VS Code: Install the "Git Worktrees" extension for easy switching
- Each worktree is independent - you can have multiple IDEs open

### Claude Code
- Each worktree gets its own Claude context
- Run parallel agents on different features
- Use `_review/` worktree in read-only mode for code reviews

### Cleanup
```bash
wt-remove my-feature    # Remove a specific worktree
wt-cleanup              # Remove stale worktrees
wt-cleanup --dry-run    # Preview without changes
```
