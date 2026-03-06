@echo off
call "%~dp0wt-config.cmd"
if "%~1"=="" (
    if exist "main" ( cd /d "main" ) else ( echo No main worktree found )
) else (
    cd /d "%WORKTREE_ROOT%\%~1.git\main"
)
