@echo off
chcp 65001 >nul
title 网络驱动器自动映射

setlocal enabledelayedexpansion

set SHARE_PATH=\\DTPC1154\Users\D40427\Documents\IPQC\A271 DH A栋一楼 自动线
set DRIVE_LETTER=Z:
set RETRY_INTERVAL=30
set ATTEMPT_COUNT=0

echo 开始自动映射网络驱动器...
echo.

:retry_loop
set /a ATTEMPT_COUNT+=1
cls
echo 尝试次数: !ATTEMPT_COUNT!
echo 目标: %SHARE_PATH%
echo 驱动器: %DRIVE_LETTER%
echo.

REM 清理旧映射
net use %DRIVE_LETTER% /delete /y >nul 2>&1

REM 尝试映射
net use %DRIVE_LETTER% "%SHARE_PATH%" /persistent:no >nul 2>&1
if %errorlevel% equ 0 goto success

REM 如果失败，尝试使用guest账户
net use %DRIVE_LETTER% "%SHARE_PATH%" /persistent:no /user:guest "" >nul 2>&1
if %errorlevel% equ 0 goto success

echo 映射失败，%RETRY_INTERVAL%秒后重试...
echo 按 Ctrl+C 终止
timeout /t %RETRY_INTERVAL% /nobreak >nul
goto retry_loop

:success
echo ✓ 成功映射 %DRIVE_LETTER% 驱动器
echo 路径: %SHARE_PATH%
echo.
echo 操作完成，即将退出...
timeout /t 2 /nobreak >nul
exit