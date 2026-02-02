@echo off
call "%~dp0wt-config.cmd"
if "%~1"=="" (
    if exist "develop" ( cd /d "develop" ) else ( echo No develop worktree found )
) else (
    cd /d "%WORKTREE_ROOT%\%~1.git\develop"
)
