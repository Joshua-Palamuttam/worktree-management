@echo off
setlocal enabledelayedexpansion
call "%~dp0wt-config.cmd"
set "ORIG_DIR=%CD%"
set "ORIG_DIR=!ORIG_DIR:\=/!"
set "ORIG_DIR=!ORIG_DIR:C:/=/c/!"
set "ORIG_DIR=!ORIG_DIR:D:/=/d/!"

REM Get the PR number (first argument)
set "PR_NUMBER=%~1"

REM Run the hotfix-pr script
"%GIT_BASH%" "%SCRIPTS_PATH%/wt-hotfix-pr.sh" %* --workdir "!ORIG_DIR!"
if errorlevel 1 goto :eof

REM Find repo root and cd to the new worktree
for /f "delims=" %%R in ('git rev-parse --git-common-dir 2^>nul') do set "REPO_ROOT=%%R"
if "!REPO_ROOT!"=="." set "REPO_ROOT=%CD%"

endlocal & cd /d "%REPO_ROOT%\_hotfix\hotfix-pr-%PR_NUMBER%"
