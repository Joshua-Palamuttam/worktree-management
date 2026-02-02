@echo off
if "%~1"=="" (
    echo Usage: wt-hotfix ^<branch-name^>
    exit /b 1
)
git fetch origin
git worktree add -b "hotfix/%~1" "_hotfix/%~1" origin/develop
cd /d "_hotfix\%~1"
echo Hotfix worktree ready at: %CD%
