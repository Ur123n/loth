@echo off
rem Battle test demo launcher (encoding-safe)
cd /d "%~dp0"
set "PROJ="
if exist "%~dp0project.godot" set "PROJ=%~dp0"
for /d %%d in ("%~dp0*") do if exist "%%d\project.godot" set "PROJ=%%d"
if not defined PROJ (
    echo Cannot find project folder with project.godot
    pause
    exit /b 1
)
"C:\1\Godot_v4.7.1-stable_win64_console.exe" --path "%PROJ%" res://demo/BattleTestDemo.tscn
pause