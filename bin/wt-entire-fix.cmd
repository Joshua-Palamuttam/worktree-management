@echo off
setlocal enabledelayedexpansion
call "%~dp0wt-config.cmd"
"%GIT_BASH%" "%SCRIPTS_PATH%/wt-entire-fix.sh" %*
