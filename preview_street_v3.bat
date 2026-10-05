@echo off
set "GODOT_EXE=C:\1\Godot_v4.7.1-stable_win64_console.exe"
if not exist "%GODOT_EXE%" exit /b 1
"%GODOT_EXE%" --path "%~dp0." --rendering-method gl_compatibility --resolution 1280x900 maps/leyton/street_sample_v3/review.tscn
