# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository provides cross-platform git worktree management scripts with separate implementations for Windows and macOS.

## Architecture

```
windows/
  bin/           # Windows .cmd wrappers (call Git Bash to run .sh scripts)
  scripts/       # Bash scripts invoked via Git Bash on Windows
mac/             # macOS-native scripts (bash + zsh profile)
skills/          # Shared Claude Code skills
templates/       # Shared config templates
config.yaml      # Shared repo registry
```

### Windows (`windows/`)

The `.cmd` files are thin wrappers that invoke the corresponding `.sh` scripts via Git Bash. The `.sh` scripts contain Windows-specific patterns (e.g., `--workdir` params, `/c/` path conversions, `cygpath` calls).

### macOS (`mac/`)

Standalone bash scripts sourced from `wt-profile.zsh`. Uses fzf for interactive selection, native paths, and Homebrew bash 5+. No `.cmd` wrappers needed.

## Platform-Specific Development

### Windows

When creating or modifying Windows scripts:
1. Every `.sh` script in `windows/scripts/` must have a corresponding `.cmd` wrapper in `windows/bin/`
2. Every `.cmd` script in `windows/bin/` must have a corresponding `.sh` script in `windows/scripts/`
3. Behavior changes must be applied to both versions

#### .cmd Wrapper Pattern

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

#### Navigation Scripts (Special Case)

Navigation scripts (`wtgo`, `wtr`, `wtd`, `wtm`, `wtl`) change the current directory:
- `.cmd` files have inline implementation (subprocess can't change parent's directory)
- `.sh` files must be **sourced** (`. script.sh`) to affect the calling shell
- Also defined as functions in `wt-profile.sh` for interactive use

#### Auto-Generated Config Files (Do Not Commit)

- `windows/bin/wt-config.cmd` - created by `setup.cmd`
- `windows/scripts/wt-config.sh` - created by `setup.sh`

### macOS

When creating or modifying macOS scripts:
1. Add the script to `mac/`
2. Add a wrapper function in `mac/wt-profile.zsh` (for interactive shell use)
3. Source `wt-lib.sh` for shared helpers (colors, `get_repo_root`, `sync_config_to_worktree`, `fzf_select`)

## Documentation Requirements

When creating a new command, update `COMMANDS.md` with:
1. Command name and description
2. Usage examples
3. Step-by-step explanation of what it does
4. Add to the Quick Reference Table

### New Command Checklist (Windows)

- [ ] `windows/scripts/<command>.sh` - Implementation
- [ ] `windows/bin/<command>.cmd` - Windows wrapper
- [ ] `windows/scripts/wt-profile.sh` - Add function (if needed for interactive shell)
- [ ] `COMMANDS.md` - Documentation

### New Command Checklist (macOS)

- [ ] `mac/<command>.sh` - Implementation
- [ ] `mac/wt-profile.zsh` - Add wrapper function
- [ ] `COMMANDS.md` - Documentation
