# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository provides cross-platform git worktree management scripts. All commands work in both Windows Command Prompt and Unix shells (bash/zsh).

## Architecture

```
bin/           # Windows .cmd wrappers (call Git Bash to run .sh scripts)
scripts/       # Unix .sh implementations (source of truth)
```

The `.cmd` files are thin wrappers that invoke the corresponding `.sh` scripts via Git Bash, ensuring identical behavior across platforms.

## Script Parity Requirement

**Critical:** This repository maintains cross-platform parity between `.cmd` and `.sh` scripts.

When creating or modifying scripts:
1. Every `.sh` script in `scripts/` must have a corresponding `.cmd` wrapper in `bin/`
2. Every `.cmd` script in `bin/` must have a corresponding `.sh` script in `scripts/`
3. Behavior changes must be applied to both versions

### .cmd Wrapper Pattern

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

Navigation scripts (`wtgo`, `wtr`, `wtd`, `wtm`, `wtl`) change the current directory:
- `.cmd` files have inline implementation (subprocess can't change parent's directory)
- `.sh` files must be **sourced** (`. script.sh`) to affect the calling shell
- Also defined as functions in `wt-profile.sh` for interactive use

### Auto-Generated Config Files (Do Not Commit)

- `bin/wt-config.cmd` - created by `setup.cmd`
- `scripts/wt-config.sh` - created by `setup.sh`

## Documentation Requirements

When creating a new command, update `COMMANDS.md` with:
1. Command name and description
2. Usage examples
3. Step-by-step explanation of what it does
4. Add to the Quick Reference Table

### New Command Checklist

- [ ] `scripts/<command>.sh` - Implementation
- [ ] `bin/<command>.cmd` - Windows wrapper
- [ ] `scripts/wt-profile.sh` - Add function (if needed for interactive shell)
- [ ] `COMMANDS.md` - Documentation
