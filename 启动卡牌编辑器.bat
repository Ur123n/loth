@echo off
rem Card editor launcher: double-click to start (does not require Godot)
cd /d "%~dp0"
set "EDITOR_DIR="
for /d %%d in ("%~dp0*") do if exist "%%d\CardEditor\card_editor.py" set "EDITOR_DIR=%%d"
if not defined EDITOR_DIR (
    echo Cannot find CardEditor folder
    pause
    exit /b 1
)
set "PYEXE=C:\Users\njw\AppData\Local\Programs\Python\Python311\pythonw.exe"
if not exist "%PYEXE%" set "PYEXE=pythonw"
"%PYEXE%" "%EDITOR_DIR%\CardEditor\card_editor.py"
