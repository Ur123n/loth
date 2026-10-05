@echo off
cd /d "%~dp0"
"C:\1\Godot_v4.7.1-stable_win64_console.exe" --path "%~dp0." res://dev/map_workflow_lab/map_workflow_lab.tscn %*
set "launch_result=%errorlevel%"
if not "%launch_result%"=="0" pause
exit /b %launch_result%
