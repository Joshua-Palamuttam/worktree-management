# Worktree Management Setup Guide

This guide walks you through setting up the git worktree workflow on macOS or Windows.

---

## macOS Setup

### Prerequisites

- **Homebrew** installed
- **fzf** installed (`brew install fzf`)
- **GitHub CLI** installed (`brew install gh`) - for PR-related commands

### Step 1: Clone the Management Repository

```bash
cd ~/Developer
git clone https://github.com/YourOrg/worktree-management.git
```

### Step 2: Configure Your Shell

Add this line to your `~/.zshrc`:

```zsh
source ~/Developer/worktree-management/mac/wt-profile.zsh
```

Then reload:
```bash
source ~/.zshrc
```

This loads all `wt-*` commands and navigation functions (`wtgo`, `wtr`, `wtd`, `wtm`, `wtl`, `wtn`) into your shell, with zsh tab completion.

### Step 3: Migrate Your First Repository

```bash
wt-migrate --from-url https://github.com/YourOrg/your-repo.git
```

This creates:
```
~/Developer/worktrees/
└── your-repo.git/
    ├── main/
    ├── develop/        (if exists)
    ├── _feature/
    ├── _review/
    └── _hotfix/
```

### Step 4: Start Working

```bash
wtr your-repo            # Jump to repo
wtd                      # Jump to develop
wt-feature my-feature    # Create feature worktree
```

---

## Windows Setup

### Prerequisites

- **Git for Windows** installed (includes Git Bash)
- **Windows Terminal** (optional, but recommended)
- **GitHub CLI** installed - for PR-related commands

### Step 1: Clone the Management Repository

Clone or copy the repo to your worktree root:

```
C:\worktrees-SeekOut\worktree_management\
```

The structure should look like:
```
C:\worktrees-SeekOut\
└── worktree_management\
    ├── windows\
    │   ├── bin\       # Windows cmd wrappers
    │   └── scripts\   # Bash scripts
    ├── mac\           # macOS scripts (not used on Windows)
    ├── templates\
    ├── config.yaml
    └── README.md
```

### Step 2: Configure Your Shell

#### For Git Bash

Add this line to your `~/.bashrc` file:

```bash
source "C:/worktrees-SeekOut/worktree_management/windows/scripts/wt-profile.sh"
```

**To add it via command line:**
```bash
echo 'source "C:/worktrees-SeekOut/worktree_management/windows/scripts/wt-profile.sh"' >> ~/.bashrc
source ~/.bashrc
```

You should see: `Worktree functions loaded. Type 'wt-status' to see all repos.`

#### For Windows Command Prompt

**Step 1: Add the `bin` directory to your PATH**

*Option A: Via PowerShell (run once)*
```powershell
[Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'User') + ';C:\worktrees-SeekOut\worktree_management\windows\bin', 'User')
```

*Option B: Via System Settings*
1. Press `Win + R`, type `sysdm.cpl`, press Enter
2. Click "Advanced" tab -> "Environment Variables"
3. Under "User variables", select `Path` -> Edit
4. Add new entry: `C:\worktrees-SeekOut\worktree_management\windows\bin`
5. Click OK and restart your terminal

**Step 2: Run setup to configure Git Bash path**

```cmd
C:\worktrees-SeekOut\worktree_management\windows\bin\setup.cmd
```

This creates `wt-config.cmd` with your machine-specific paths. You only need to run this once.

**Step 3: Verify it works**
```cmd
wt-status
```

### Step 3: Migrate Your First Repository

```cmd
wt-migrate --from-url https://github.com/YourOrg/your-repo.git
```

### Step 4: Start Working

```cmd
wtr your-repo
wtd
wt-feature my-feature
```

---

## Migrating from Previous Directory Structure

If you're upgrading from the old structure where `scripts/` and `bin/` were at the repo root, you need to update your paths after pulling the latest changes.

### Windows Migration Steps

After `git pull`:

1. **Update PATH** - change `bin` to `windows\bin`:
   - Old: `C:\worktrees-SeekOut\worktree_management\bin`
   - New: `C:\worktrees-SeekOut\worktree_management\windows\bin`

2. **Update `.bashrc`** (Git Bash) - change source path:
   ```bash
   # Old:
   # source "C:/worktrees-SeekOut/worktree_management/scripts/wt-profile.sh"

   # New:
   source "C:/worktrees-SeekOut/worktree_management/windows/scripts/wt-profile.sh"
   ```

3. **Re-run setup** to regenerate config files in the new location:
   ```cmd
   C:\worktrees-SeekOut\worktree_management\windows\bin\setup.cmd
   ```

The auto-generated `wt-config.cmd` and `wt-config.sh` files are gitignored and won't be moved automatically. Re-running setup creates them in the correct new location.

### macOS Migration Steps

If you previously had scripts sourced from `scripts/wt-profile.sh`, switch to the mac-native profile:

```zsh
# In ~/.zshrc, replace any old source line with:
source ~/Developer/worktree-management/mac/wt-profile.zsh
```

---

## Example: Full Migration Workflow

### macOS

```bash
# Migrate repos
wt-migrate --from-url https://github.com/YourOrg/backend.git
wt-migrate --from-url https://github.com/YourOrg/integrations.git

# Verify
wt-status

# Start working
wtr backend
wtd
wt-feature AI-1234-new-feature

# Quick PR review
wt-review 567
wt-review-done

# When feature is done
wt-remove AI-1234-new-feature
```

### Windows

```cmd
REM Migrate repos
wt-migrate --from-url https://github.com/YourOrg/backend.git
wt-migrate --from-url https://github.com/YourOrg/integrations.git

REM Verify
wt-status

REM Start working
wtr backend
wtd
wt-feature AI-1234-new-feature

REM Quick PR review
wt-review 567
wt-review-done

REM When feature is done
wt-remove AI-1234-new-feature
```

---

## Troubleshooting

### "No such file or directory" when running wt-* commands (Windows)
Run `setup.cmd` to configure Git Bash:
```cmd
C:\worktrees-SeekOut\worktree_management\windows\bin\setup.cmd
```
This is required because Windows may use WSL's bash (which uses `/mnt/c/` paths) instead of Git Bash (which uses `/c/` paths).

### "command not found" for wt-* commands (macOS)
Make sure you've sourced the profile in `~/.zshrc`:
```zsh
source ~/Developer/worktree-management/mac/wt-profile.zsh
```
Then reload: `source ~/.zshrc`

### fzf not found (macOS)
Install fzf: `brew install fzf`

### "bash: command not found" in Command Prompt (Windows)
Make sure Git for Windows is installed and `git` is in your PATH.

### Commands not found after adding to PATH (Windows)
Close and reopen your terminal. PATH changes require a new session.

### Worktree shows "(detached HEAD)"
This is normal for worktrees created from remote branches. You can work normally - commits will still be on the correct branch.

### ".bashrc: command not found" errors (Windows)
Your `.bashrc` may have encoding issues (UTF-16 BOM). Fix it by saving as UTF-8:
```bash
# In Git Bash:
iconv -f UTF-16LE -t UTF-8 ~/.bashrc > ~/.bashrc.new && mv ~/.bashrc.new ~/.bashrc
```

---

## Tips

### IDE Setup
- Open each worktree folder as a separate project
- VS Code: Install the "Git Worktrees" extension for easy switching
- Each worktree is independent - you can have multiple IDEs open

### Claude Code
- Run separate Claude Code sessions in different worktrees
- Perfect for parallel AI-assisted development
- Use `_review/` in read-only mode for code reviews

### Keep main/develop Clean
- Never commit directly to `main/` or `develop/` worktrees
- Use them as reference points and for clean builds
- All work happens in `_feature/`, `_review/`, or `_hotfix/`
