# Claude Code Guidelines for worktree_management

## Script Parity Requirement

This repository maintains **cross-platform parity** between Windows (.cmd) and Unix (.sh) scripts.

### Directory Structure

```
bin/           # Windows .cmd files (wrappers that call Git Bash)
scripts/       # Unix .sh files (actual implementations)
```

### When Creating or Editing Scripts

**Always maintain parity:**

1. **If you create a new `.sh` script in `scripts/`**, you must also create a corresponding `.cmd` wrapper in `bin/`
2. **If you create a new `.cmd` script in `bin/`**, you must also create a corresponding `.sh` script in `scripts/`
3. **If you modify a script's behavior**, ensure both versions are updated to match

### .cmd Wrapper Pattern

The `.cmd` files in `bin/` are thin wrappers that call the `.sh` scripts via Git Bash:

```cmd
@echo off
setlocal enabledelayedexpansion
call "%~dp0wt-config.cmd"
set "ORIG_DIR=%CD%"
set "ORIG_DIR=!ORIG_DIR:\=/!"
set "ORIG_DIR=!ORIG_DIR:C:/=/c/!"
set "ORIG_DIR=!ORIG_DIR:D:/=/d/!"
"%GIT_BASH%" "%SCRIPTS_PATH%/script-name.sh" %* --workdir "!ORIG_DIR!"
endlocal
```

### Navigation Scripts (Special Case)

Navigation scripts (`wtgo`, `wtr`, `wtd`, `wtm`, `wtl`) change the current directory. These require:
- `.cmd` files with inline implementation (can't delegate to subprocess for `cd`)
- `.sh` files that must be **sourced** (`. script.sh`) to affect the calling shell
- Functions in `wt-profile.sh` for interactive shell use

### Auto-Generated Config Files

These are created by `setup.cmd`/`setup.sh` and should NOT be committed:
- `bin/wt-config.cmd`
- `scripts/wt-config.sh`

Both are listed in `.gitignore`.

## Updating Documentation

### When Creating a New Command

You **must** update `COMMANDS.md` with:
1. Command name and description
2. Usage examples
3. What the command does (step by step)
4. Expected result/output
5. Add to the Quick Reference Table

### File Checklist for New Commands

- [ ] `scripts/<command>.sh` - Implementation
- [ ] `bin/<command>.cmd` - Windows wrapper
- [ ] `scripts/wt-profile.sh` - Add function (if interactive shell use needed)
- [ ] `COMMANDS.md` - Documentation
