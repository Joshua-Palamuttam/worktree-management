@echo off
if "%~1"=="" (
    echo Available repos:
    dir /b "C:\worktrees-SeekOut\*.git" 2>nul | findstr /r "\.git$"
    exit /b
)
cd /d "C:\worktrees-SeekOut\%~1.git"
