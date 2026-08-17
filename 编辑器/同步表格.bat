@echo off
cd /d "%~dp0"
set "PYEXE=C:\Users\njw\AppData\Local\Programs\Python\Python311\python.exe"
if not exist "%PYEXE%" set "PYEXE=python"
"%PYEXE%" "%~dp0sync_tables.py"
pause
