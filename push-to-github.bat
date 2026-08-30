chcp 936 >nul
@echo off
:: ========================================
:: v b 工作区 -> GitHub 一键上传（入口）
:: 调用 push-to-github.ps1，完成建仓+推送
:: ========================================

setlocal

pushd "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0push-to-github.ps1"
set ERR=%errorlevel%
if not "%ERR%"=="0" (
    echo.
    echo [提示] 上传脚本异常退出（退出码 %ERR%）。
)

echo.
pause

popd
endlocal
