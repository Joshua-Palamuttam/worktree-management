@echo off
REM setup-skills.cmd — Windows wrapper for setup-skills.sh
REM Creates symlinks from ~/.claude/skills/ to worktree_management/skills/
REM
REM Usage: setup-skills.cmd [--remove]

setlocal
set "SCRIPT_DIR=%~dp0"
set "BASH_SCRIPT=%SCRIPT_DIR%..\scripts\setup-skills.sh"

where bash >nul 2>&1
if errorlevel 1 (
    echo ERROR: bash not found. Install Git for Windows or WSL.
    exit /b 1
)

bash "%BASH_SCRIPT%" %*
