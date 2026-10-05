@echo off
cd /d "%~dp0"
"C:\1\Godot_v4.7.1-stable_win64_console.exe" --path "%~dp0." res://dev/hall_art_v1/hall_art_v1.tscn %*
set "launch_result=%errorlevel%"
if not "%launch_result%"=="0" pause
exit /b %launch_result%
