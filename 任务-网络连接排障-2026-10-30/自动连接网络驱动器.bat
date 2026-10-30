chcp 936 >nul
@echo off
title 网络驱动器自动映射
setlocal EnableDelayedExpansion

REM ============================================================
REM 自动映射网络驱动器（修正版）
REM 保存要求：ANSI/GBK 编码 + CRLF 换行，不要保存成 UTF-8
REM 旧版问题：文件是 UTF-8 带 BOM + chcp 65001，老系统 cmd
REM           无法向控制台输出中文，会刷屏报
REM           "The system cannot write to the specified device."
REM 本版：改成 GBK + chcp 936，并把 net use 的真实错误显示出来
REM ============================================================

set "SHARE_PATH=\\DTPC1154\Users\D40427\Documents\IPQC\A271 DH A栋一楼 自动线"
set "DRIVE_LETTER=Z:"
set "RETRY_INTERVAL=30"

set "ATTEMPT_COUNT=0"
echo 开始自动映射网络驱动器...
echo 目标路径: %SHARE_PATH%
echo 盘符: %DRIVE_LETTER%
echo.

:retry_loop
set /a ATTEMPT_COUNT+=1
cls
echo 尝试次数: !ATTEMPT_COUNT!
echo 目标路径: %SHARE_PATH%
echo 盘符: %DRIVE_LETTER%
echo.

REM 清理旧映射
net use %DRIVE_LETTER% /delete /y >nul 2>&1

REM 尝试映射（使用本机已保存的 Windows 凭据）
net use %DRIVE_LETTER% "%SHARE_PATH%" /persistent:no >"%TEMP%\netuse_err.log" 2>&1
set "NET_RC=!errorlevel!"
if "!NET_RC!"=="0" goto success

echo 映射失败，net use 返回码: !NET_RC!
echo net 返回的原始错误:
type "%TEMP%\netuse_err.log"
echo.
echo 排查建议:
echo   1) ping DTPC1154            检查网络是否连通
echo   2) net view \\DTPC1154     检查共享是否可见
echo   3) 控制面板 - 凭据管理器   添加或更新 Windows 凭据
echo.
echo !RETRY_INTERVAL! 秒后自动重试，按 Ctrl+C 可终止...
timeout /t %RETRY_INTERVAL% /nobreak >nul 2>&1
goto retry_loop

:success
echo [OK] 已成功映射 %DRIVE_LETTER% 驱动器
echo 路径: %SHARE_PATH%
echo.
echo 操作完成，3 秒后关闭窗口...
timeout /t 3 /nobreak >nul 2>&1
exit /b 0
