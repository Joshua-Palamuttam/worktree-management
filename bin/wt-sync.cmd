@echo off
setlocal enabledelayedexpansion
call "%~dp0wt-config.cmd"
set "ORIG_DIR=%CD%"
set "ORIG_DIR=!ORIG_DIR:\=/!"
set "ORIG_DIR=!ORIG_DIR:C:/=/c/!"
set "ORIG_DIR=!ORIG_DIR:D:/=/d/!"

REM Run the sync script
"%GIT_BASH%" "%SCRIPTS_PATH%/wt-sync.sh" %* --workdir "!ORIG_DIR!"
endlocal
