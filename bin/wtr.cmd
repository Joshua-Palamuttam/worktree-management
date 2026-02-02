@echo off
call "%~dp0wt-config.cmd"
if "%~1"=="" (
    echo Available repos:
    dir /b "%WORKTREE_ROOT%\*.git" 2>nul
    exit /b
)
cd /d "%WORKTREE_ROOT%\%~1.git"
