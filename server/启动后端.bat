@echo off
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
  echo 后端依赖未安装，请先按 server\README.md 创建虚拟环境并安装依赖。
  pause
  exit /b 1
)
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
if errorlevel 1 pause
endlocal
