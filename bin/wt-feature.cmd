@echo off
setlocal enabledelayedexpansion
call "%~dp0wt-config.cmd"
set "ORIG_DIR=%CD%"
set "ORIG_DIR=!ORIG_DIR:\=/!"
set "ORIG_DIR=!ORIG_DIR:C:/=/c/!"
set "ORIG_DIR=!ORIG_DIR:D:/=/d/!"

REM Get the branch name (first non-flag argument)
set "BRANCH_NAME=%~1"

REM Run the feature script
"%GIT_BASH%" "%SCRIPTS_PATH%/wt-feature.sh" %* --workdir "!ORIG_DIR!"
if errorlevel 1 goto :eof

REM Extract directory name from branch (remove prefix like joshua/)
for %%I in ("%BRANCH_NAME%") do set "DIR_NAME=%%~nxI"
for /f "tokens=* delims=/" %%A in ("%DIR_NAME%") do set "DIR_NAME=%%A"

REM Find repo root and cd to the new worktree
for /f "delims=" %%R in ('git rev-parse --git-common-dir 2^>nul') do set "REPO_ROOT=%%R"
if "!REPO_ROOT!"=="." set "REPO_ROOT=%CD%"

endlocal & cd /d "%REPO_ROOT%\_feature\%DIR_NAME%"
