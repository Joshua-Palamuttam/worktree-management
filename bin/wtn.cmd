@echo off
setlocal enabledelayedexpansion
call "%~dp0wt-config.cmd"

set "REPO_PATH="
set "REPO_NAME="

REM Check if we're in a repo already
for /f "delims=" %%R in ('git rev-parse --git-common-dir 2^>nul') do set "GIT_DIR=%%R"
if defined GIT_DIR (
    if "!GIT_DIR!"=="." (
        set "REPO_PATH=%CD%"
    ) else (
        pushd "!GIT_DIR!" 2>nul && set "REPO_PATH=!CD!" && popd
    )
)

if defined REPO_PATH (
    for %%I in ("!REPO_PATH!") do set "REPO_NAME=%%~nxI"
    set "REPO_NAME=!REPO_NAME:.git=!"
    echo. & echo In repo: !REPO_NAME!
    goto :select_worktree
)

:select_repo
echo.
echo Select repository:
echo.

set "COUNT=0"
for /d %%D in ("%WORKTREE_ROOT%\*.git") do (
    set /a COUNT+=1
    set "REPO_!COUNT!=%%~nD"
    for %%N in ("%%~nD") do set "NAME=%%~N"
    set "NAME=!NAME:.git=!"
    echo   !COUNT!^) !NAME!
)

if !COUNT!==0 (
    echo No repositories found.
    goto :eof
)

echo.
set /p "INPUT=Choice (number or text to filter): "

if "!INPUT!"=="" goto :eof

REM Check if number
set "ISNUM=1"
for /f "delims=0123456789" %%A in ("!INPUT!") do set "ISNUM=0"

if !ISNUM!==1 (
    if !INPUT! GEQ 1 if !INPUT! LEQ !COUNT! (
        set "SELECTED=!REPO_%INPUT%!"
        set "REPO_PATH=%WORKTREE_ROOT%\!SELECTED!.git"
        goto :select_worktree
    )
    echo Invalid selection
    goto :select_repo
)

REM Filter by partial match
set "MATCHES=0"
set "LAST_MATCH="
for /L %%I in (1,1,!COUNT!) do (
    set "ITEM=!REPO_%%I!"
    echo !ITEM! | findstr /i "!INPUT!" >nul
    if !errorlevel!==0 (
        set /a MATCHES+=1
        set "LAST_MATCH=!ITEM!"
    )
)

if !MATCHES!==1 (
    set "REPO_PATH=%WORKTREE_ROOT%\!LAST_MATCH!.git"
    goto :select_worktree
)

if !MATCHES!==0 (
    echo No matches for '!INPUT!'
)
goto :select_repo

:select_worktree
echo.
echo Select worktree:
echo.

set "COUNT=0"
set "WT_PATH="

REM Main branches
if exist "!REPO_PATH!\main" (
    set /a COUNT+=1
    set "WT_!COUNT!=main"
    set "WT_PATH_!COUNT!=!REPO_PATH!\main"
    echo   !COUNT!^) main
)
if exist "!REPO_PATH!\develop" (
    set /a COUNT+=1
    set "WT_!COUNT!=develop"
    set "WT_PATH_!COUNT!=!REPO_PATH!\develop"
    echo   !COUNT!^) develop
)

REM Feature worktrees
if exist "!REPO_PATH!\_feature" (
    for /d %%D in ("!REPO_PATH!\_feature\*") do (
        set /a COUNT+=1
        set "WT_!COUNT!=%%~nxD"
        set "WT_PATH_!COUNT!=%%D"
        echo   !COUNT!^) %%~nxD ^(feature^)
    )
)

REM Hotfix worktrees
if exist "!REPO_PATH!\_hotfix" (
    for /d %%D in ("!REPO_PATH!\_hotfix\*") do (
        set /a COUNT+=1
        set "WT_!COUNT!=%%~nxD"
        set "WT_PATH_!COUNT!=%%D"
        echo   !COUNT!^) %%~nxD ^(hotfix^)
    )
)

REM Review worktrees
if exist "!REPO_PATH!\_review" (
    for /d %%D in ("!REPO_PATH!\_review\*") do (
        set /a COUNT+=1
        set "WT_!COUNT!=%%~nxD"
        set "WT_PATH_!COUNT!=%%D"
        echo   !COUNT!^) %%~nxD ^(review^)
    )
)

if !COUNT!==0 (
    echo No worktrees found.
    goto :eof
)

echo.
set /p "INPUT=Choice (number or text to filter): "

if "!INPUT!"=="" goto :eof

REM Check if number
set "ISNUM=1"
for /f "delims=0123456789" %%A in ("!INPUT!") do set "ISNUM=0"

if !ISNUM!==1 (
    if !INPUT! GEQ 1 if !INPUT! LEQ !COUNT! (
        set "DEST=!WT_PATH_%INPUT%!"
        goto :navigate
    )
    echo Invalid selection
    goto :select_worktree
)

REM Filter by partial match
set "MATCHES=0"
set "LAST_MATCH="
for /L %%I in (1,1,!COUNT!) do (
    set "ITEM=!WT_%%I!"
    echo !ITEM! | findstr /i "!INPUT!" >nul
    if !errorlevel!==0 (
        set /a MATCHES+=1
        set "LAST_MATCH=!WT_PATH_%%I!"
    )
)

if !MATCHES!==1 (
    set "DEST=!LAST_MATCH!"
    goto :navigate
)

if !MATCHES!==0 (
    echo No matches for '!INPUT!'
)
goto :select_worktree

:navigate
endlocal & cd /d "%DEST%"
echo.
echo %CD%
