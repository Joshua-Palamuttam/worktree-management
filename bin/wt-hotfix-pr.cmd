@echo off
setlocal enabledelayedexpansion
call "%~dp0wt-config.cmd"
set "ORIG_DIR=%CD%"
set "ORIG_DIR=!ORIG_DIR:\=/!"
set "ORIG_DIR=!ORIG_DIR:C:/=/c/!"
set "ORIG_DIR=!ORIG_DIR:D:/=/d/!"

REM Run the hotfix-pr script
"%GIT_BASH%" "%SCRIPTS_PATH%/wt-hotfix-pr.sh" %* --workdir "!ORIG_DIR!"
if errorlevel 1 goto :eof

REM Find repo root
for /f "delims=" %%R in ('git rev-parse --git-common-dir 2^>nul') do set "REPO_ROOT=%%R"
if "!REPO_ROOT!"=="." set "REPO_ROOT=%CD%"

REM Read worktree dir from temp file written by the script
set "WT_DIR="
set "TMPFILE=%TEMP%\.wt-hotfix-pr-last-dir"
if exist "%TMPFILE%" (
    for /f "usebackq delims=" %%D in ("%TMPFILE%") do set "WT_DIR=%%D"
    del "%TMPFILE%" >nul 2>&1
)

if defined WT_DIR (
    endlocal & cd /d "%REPO_ROOT%\%WT_DIR%"
) else (
    endlocal
)
