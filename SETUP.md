# Worktree Management Setup Guide

This guide walks you through setting up the git worktree workflow from scratch.

## Prerequisites

- **Git for Windows** installed (includes Git Bash)
- **Windows Terminal** (optional, but recommended)

---

## Step 1: Clone the Management Repository

If you're setting this up fresh, clone or copy the `worktree_management` folder to:

```
C:\worktrees-SeekOut\worktree_management\
```

The structure should look like:
```
C:\worktrees-SeekOut\
└── worktree_management\
    ├── bin\           # Windows cmd wrappers
    ├── scripts\       # Bash scripts
    ├── templates\     # Claude/VSCode configs
    ├── config.yaml    # Repo registry
    └── README.md
```

---

## Step 2: Configure Your Shell

### For Git Bash

Add this line to your `~/.bashrc` file:

```bash
source "C:/worktrees-SeekOut/worktree_management/scripts/wt-profile.sh"
```

**To add it via command line:**
```bash
echo 'source "C:/worktrees-SeekOut/worktree_management/scripts/wt-profile.sh"' >> ~/.bashrc
source ~/.bashrc
```

You should see: `✅ Worktree functions loaded. Type 'wt-status' to see all repos.`

### For Windows Command Prompt

**Step 1: Add the `bin` directory to your PATH**

*Option A: Via PowerShell (run once)*
```powershell
[Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'User') + ';C:\worktrees-SeekOut\worktree_management\bin', 'User')
```

*Option B: Via System Settings*
1. Press `Win + R`, type `sysdm.cpl`, press Enter
2. Click "Advanced" tab → "Environment Variables"
3. Under "User variables", select `Path` → Edit
4. Add new entry: `C:\worktrees-SeekOut\worktree_management\bin`
5. Click OK and restart your terminal

**Step 2: Run setup to configure Git Bash path**

```cmd
C:\worktrees-SeekOut\worktree_management\bin\setup.cmd
```

This creates `wt-config.cmd` with your machine-specific paths. You only need to run this once.

**Step 3: Verify it works**
```cmd
wt-status
```

> **Note:** The setup script finds Git Bash automatically. This is required because Windows may have WSL's bash which uses different paths.

---

## Step 3: Migrate Your First Repository

Take any GitHub repository and convert it to the worktree structure.

### From a GitHub URL

```cmd
wt-migrate --from-url https://github.com/YourOrg/your-repo.git
```

**Example:**
```cmd
wt-migrate --from-url https://github.com/Zipstorm/AI-1099.git
```

This creates:
```
C:\worktrees-SeekOut\
└── AI-1099.git\          # Bare repository (git database)
    ├── main\             # Worktree: main branch
    ├── develop\          # Worktree: develop branch (if exists)
    ├── _feature\         # Your feature branches go here
    ├── _review\          # PR review worktrees
    └── _hotfix\          # Emergency hotfixes
```

### With a Custom Name

```cmd
wt-migrate --from-url https://github.com/Zipstorm/backend.git my-backend
```

### From an Existing Local Clone

If you already have a repo cloned locally:

```cmd
wt-migrate --from-dir "C:\path\to\existing\repo"
```

This fetches fresh from the remote and creates the worktree structure.

---

## Step 4: Start Working

### Navigate to your repo
```cmd
wtr AI-1099
```

### Jump to the develop branch
```cmd
wtd
```

### Create a feature branch
```cmd
wt-feature my-new-feature
```

This creates: `AI-1099.git\_feature\my-new-feature\`

### Review a PR
```cmd
wt-review 123
```

This checks out PR #123 into `AI-1099.git\_review\current\`

### When done reviewing
```cmd
wt-review-done
```

---

## Command Reference

### Navigation

| Command | Description |
|---------|-------------|
| `wtgo` | Jump to `C:\worktrees-SeekOut\` |
| `wtr <repo>` | Jump to a repo's bare directory |
| `wtr` | List all available repos |
| `wtd [repo]` | Jump to develop worktree |
| `wtm [repo]` | Jump to main worktree |
| `wtl` | List worktrees in current repo |

### Workflow

| Command | Description |
|---------|-------------|
| `wt-migrate --from-url <url>` | Clone repo to worktree structure |
| `wt-migrate --from-dir <path>` | Migrate existing local repo |
| `wt-feature <name>` | Create feature worktree from develop |
| `wt-review <pr#>` | Checkout PR for review |
| `wt-review-done` | Clean up review worktree |
| `wt-hotfix <name>` | Create hotfix from develop |
| `wt-remove <name>` | Remove a worktree when done |
| `wt-status` | Show status across all repos |
| `wt-cleanup` | Remove stale worktrees |

---

## Example: Full Migration Workflow

Let's say you want to migrate 3 repos:

```cmd
REM Migrate repos
wt-migrate --from-url https://github.com/Zipstorm/backend.git
wt-migrate --from-url https://github.com/Zipstorm/integrations.git
wt-migrate --from-url https://github.com/Zipstorm/recruit-api.git

REM Verify
wt-status

REM Start working on backend
wtr backend
wtd
wt-feature AI-1234-new-feature

REM Quick PR review without losing your work
wt-review 567

REM Done reviewing, back to feature
wt-review-done
cd ..\develop\_feature\AI-1234-new-feature

REM When feature is complete and merged, clean up
wt-remove AI-1234-new-feature
```

---

## Directory Structure Explained

```
C:\worktrees-SeekOut\
│
├── worktree_management\     # Management tools (this repo)
│   ├── bin\                 # .cmd files for Windows Command Prompt
│   ├── scripts\             # .sh files for Git Bash
│   └── templates\           # Shared configs
│
├── backend.git\             # Bare repo (no working files, just git data)
│   ├── main\                # Permanent worktree - clean main branch
│   ├── develop\             # Permanent worktree - integration branch
│   ├── _feature\            # Your feature worktrees
│   │   ├── AI-1234-thing\
│   │   └── AI-5678-other\
│   ├── _review\             # Ephemeral review worktrees
│   │   └── current\
│   └── _hotfix\             # Emergency hotfix worktrees
│
└── integrations.git\        # Another bare repo
    └── ...
```

**Why bare repos?**
- Single git database shared across all worktrees
- No duplicate `.git` directories
- Faster operations, less disk space
- Clean separation of concerns

---

## Troubleshooting

### "No such file or directory" when running wt-* commands
Run `setup.cmd` first to configure Git Bash:
```cmd
C:\worktrees-SeekOut\worktree_management\bin\setup.cmd
```
This is required because Windows may use WSL's bash (which uses `/mnt/c/` paths) instead of Git Bash (which uses `/c/` paths).

### "bash: command not found" in Command Prompt
Make sure Git for Windows is installed and `git` is in your PATH.

### Commands not found after adding to PATH
Close and reopen your terminal. PATH changes require a new session.

### Worktree shows "(detached HEAD)"
This is normal for worktrees created from remote branches. You can work normally - commits will still be on the correct branch.

### ".bashrc: command not found" errors
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
