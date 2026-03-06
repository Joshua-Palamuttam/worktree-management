@echo off
setlocal enabledelayedexpansion
call "%~dp0wt-config.cmd"
set "ORIG_DIR=%CD%"
set "ORIG_DIR=!ORIG_DIR:\=/!"
set "ORIG_DIR=!ORIG_DIR:C:/=/c/!"
set "ORIG_DIR=!ORIG_DIR:D:/=/d/!"

REM Run the review script
"%GIT_BASH%" "%SCRIPTS_PATH%/wt-review.sh" %* --workdir "!ORIG_DIR!"
if errorlevel 1 goto :eof

REM Find repo root and cd to the review worktree
for /f "delims=" %%R in ('git rev-parse --git-common-dir 2^>nul') do set "REPO_ROOT=%%R"
if "!REPO_ROOT!"=="." set "REPO_ROOT=%CD%"

endlocal & cd /d "%REPO_ROOT%\_review\current"
