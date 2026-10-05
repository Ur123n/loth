@echo off
chcp 65001 >nul
rem Godot map editor launcher (local assets + built-in TileMap editor)
rem Pipeline doc: docs/world/map_pipeline.md
cd /d "%~dp0"
set "PROJ="
if exist "%~dp0project.godot" set "PROJ=%~dp0"
for /d %%d in ("%~dp0*") do if exist "%%d\project.godot" set "PROJ=%%d"
if not defined PROJ (
    echo Cannot find project folder with project.godot
    pause
    exit /b 1
)
echo Opening Godot editor...
echo   1. open maps/godot/scenes/dark48_map_template.tscn (Save As your own map first)
echo   2. paint tiles, place markers under "标记", Ctrl+S
echo   3. check with: tests/map/test_godot_map_pipeline.gd
echo.
start "" "C:\1\Godot_v4.7.1-stable_win64.exe" --path "%PROJ%" --editor
