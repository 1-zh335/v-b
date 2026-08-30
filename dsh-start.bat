chcp 936 >nul
@echo off
:: ========================================
:: DSH (DeepSeek Harness) Web UI 启动脚本
:: ========================================
:: 修复(2026-08-30): 端口 3080 已被占用时不再闪退
::   - DSH 已在运行: 直接打开浏览器并退出
::   - 未运行:      正常启动, dsh 启动后自动打开浏览器

setlocal

pushd "%~dp0"

:: 检查 dsh 是否已安装
where dsh >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 dsh 命令, 请先安装:
    echo   npm install -g @deepseek-ai/dsh
    pause
    exit /b 1
)

:: 端口（如需修改请改此处）
set PORT=3080

:: 1) DSH 已在运行: 直接打开浏览器（避免 EADDRINUSE 闪退）
netstat -ano | findstr ":3080" | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo [信息] DSH 已在运行, 正在打开 http://127.0.0.1:%PORT%
    start "" "http://127.0.0.1:%PORT%"
    exit /b 0
)

:: 2) 未运行: 启动 Web 服务（dsh 启动后会自动打开浏览器）
echo [信息] 正在启动 DSH Web UI...
echo [信息] 访问地址: http://127.0.0.1:%PORT%
echo.
dsh web --host 127.0.0.1 --port %PORT%
set ERR=%errorlevel%
if not "%ERR%"=="0" (
    echo.
    echo [提示] DSH 进程已结束（退出码 %ERR%）。
    pause
)

popd
endlocal
