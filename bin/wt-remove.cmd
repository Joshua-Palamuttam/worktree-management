@echo off
setlocal enabledelayedexpansion
call "%~dp0wt-config.cmd"
set "ORIG_DIR=%CD%"
set "ORIG_DIR=!ORIG_DIR:\=/!"
set "ORIG_DIR=!ORIG_DIR:C:/=/c/!"
set "ORIG_DIR=!ORIG_DIR:D:/=/d/!"

REM Get repo root before running (in case we're inside a worktree being deleted)
for /f "delims=" %%R in ('git rev-parse --git-common-dir 2^>nul') do set "REPO_ROOT=%%R"
if "!REPO_ROOT!"=="" set "REPO_ROOT=%CD%"
if "!REPO_ROOT!"=="." set "REPO_ROOT=%CD%"

REM Convert to Windows path
set "REPO_ROOT=!REPO_ROOT:/=\!"
set "REPO_ROOT=!REPO_ROOT:\c\=C:\!"
set "REPO_ROOT=!REPO_ROOT:\d\=D:\!"

REM Run the remove script
"%GIT_BASH%" "%SCRIPTS_PATH%/wt-remove.sh" %* --workdir "!ORIG_DIR!"

REM Move to repo root after removal (so user isn't stuck in deleted directory)
endlocal & cd /d "%REPO_ROOT%"
