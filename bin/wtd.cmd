@echo off
REM Jump to develop worktree
if "%~1"=="" (
    REM Try to find develop in current repo structure
    if exist "develop" (
        cd /d "develop"
    ) else if exist "..\develop" (
        cd /d "..\develop"
    ) else (
        echo No develop worktree found. Specify repo: wtd repo-name
    )
) else (
    cd /d "C:\worktrees-SeekOut\%~1.git\develop"
)
