@echo off
chcp 65001 >nul
rem Building asset pipeline viewer (large buildings on the square overworld grid)
rem Pipeline doc: docs/world/building_pipeline.md
cd /d "%~dp0"
set "PROJ="
if exist "%~dp0project.godot" set "PROJ=%~dp0"
for /d %%d in ("%~dp0*") do if exist "%%d\project.godot" set "PROJ=%%d"
if not defined PROJ (
    echo Cannot find project folder with project.godot
    pause
    exit /b 1
)
echo Opening building viewer...
echo   WASD / arrows = pan, wheel = zoom, R = back to spawn
echo   F = toggle roof layer, Tab = toggle mask debug overlay, Esc = quit
echo   Mouse over a cell shows: building / local cell / occupancy / walkable / door / room
echo.
"C:\1\Godot_v4.7.1-stable_win64_console.exe" --path "%PROJ%" res://world/map/BuildingViewer.tscn
pause
