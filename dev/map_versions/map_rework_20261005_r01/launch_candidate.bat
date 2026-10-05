@echo off
setlocal
set "GODOT_EXE=C:\1\Godot_v4.7.1-stable_win64_console.exe"
"%GODOT_EXE%" --path "C:\游戏" res://dev/map_versions/map_rework_20261005_r01/review.tscn %*
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" pause
exit /b %EXIT_CODE%
