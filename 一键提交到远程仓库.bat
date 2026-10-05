@echo off
setlocal EnableExtensions DisableDelayedExpansion

pushd "%~dp0"
if errorlevel 1 goto fail

where git >nul 2>&1
if errorlevel 1 (
    echo Git was not found. Install Git for Windows and try again.
    goto fail
)

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo This folder is not a Git repository.
    goto fail
)

git remote get-url origin >nul 2>&1
if errorlevel 1 (
    call :setup_remote
    if errorlevel 1 goto fail
)

echo.
echo Repository: %CD%
echo Remote:
git remote get-url origin
echo.
set "LIST_FILE=%TEMP%\git-upload-list-%RANDOM%-%RANDOM%.txt"
git -c core.quotePath=false status --short --untracked-files=all > "%LIST_FILE%"
if errorlevel 1 goto fail
echo Opening the complete file list in Notepad. Close Notepad to continue.
start /wait "" notepad.exe "%LIST_FILE%"
del /q "%LIST_FILE%" >nul 2>&1
echo.
choice /C YN /N /M "Commit ALL new, changed, and deleted files, then push? [Y/N] "
if errorlevel 2 goto cancelled
if errorlevel 1 goto stage
goto fail

:stage
git add -A
if errorlevel 1 goto fail

git diff --cached --quiet
if errorlevel 1 (
    git commit -m "Update %date% %time:~0,8%"
    if errorlevel 1 goto fail
) else (
    echo No new changes to commit. Checking for commits still needing upload.
)

git push -u origin HEAD
if errorlevel 1 goto fail

echo.
echo Done. Your changes were uploaded.
popd
pause
exit /b 0

:setup_remote
echo No remote repository is configured yet.
echo Paste the HTTPS or SSH URL of your remote Git repository.
set "REMOTE_URL="
set /p "REMOTE_URL=Repository URL: "
if not defined REMOTE_URL exit /b 1
git remote add origin "%REMOTE_URL%"
exit /b %errorlevel%

:cancelled
echo Cancelled. No files were staged or committed by this run.
popd
pause
exit /b 0

:fail
echo.
echo Failed. Read the Git error above. Existing commits and files were not deleted.
popd
pause
exit /b 1
