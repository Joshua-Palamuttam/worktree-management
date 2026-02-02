@echo off
REM Jump to main worktree
if "%~1"=="" (
    REM Try to find main in current repo structure
    if exist "main" (
        cd /d "main"
    ) else if exist "..\main" (
        cd /d "..\main"
    ) else (
        echo No main worktree found. Specify repo: wtm repo-name
    )
) else (
    cd /d "C:\worktrees-SeekOut\%~1.git\main"
)
