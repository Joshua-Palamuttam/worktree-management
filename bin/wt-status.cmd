@echo off
call "%~dp0wt-config.cmd"
"%GIT_BASH%" "%SCRIPTS_PATH%/wt-status.sh" %*
