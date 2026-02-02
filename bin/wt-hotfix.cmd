@echo off
setlocal enabledelayedexpansion
call "%~dp0wt-config.cmd"
set "ORIG_DIR=%CD%"
set "ORIG_DIR=!ORIG_DIR:\=/!"
set "ORIG_DIR=!ORIG_DIR:C:/=/c/!"
set "ORIG_DIR=!ORIG_DIR:D:/=/d/!"
if "%~1"=="" (
    echo Usage: wt-hotfix ^<branch-name^>
    exit /b 1
)
cd /d "!ORIG_DIR!"
git fetch origin
git worktree add -b "hotfix/%~1" "_hotfix/%~1" origin/develop
cd /d "_hotfix\%~1"
echo Hotfix worktree ready at: %CD%
endlocal
