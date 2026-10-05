@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo === 剧情数据检查 ===
C:\Users\njw\AppData\Local\Programs\Python\Python311\python.exe "编辑器\剧情检查.py" %*
if errorlevel 1 (
  echo.
  echo 存在剧情数据问题，请按上面提示修正后再运行。
  pause
) else (
  echo.
  echo 剧情数据全部通过。
  pause
)
