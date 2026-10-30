chcp 936 >nul
@echo off
setlocal
set "SRC=%~dp0uncle-novel"
set "DEST=%LOCALAPPDATA%\Programs\UncleNovel"
echo ==================================================
echo   Uncle小说 离线低配版 v5.0.44  安装程序
echo   （目标机：Win10 LTSC / Celeron J4005 / 4GB / 软件渲染）
echo ==================================================
if not exist "%SRC%\Uncle小说.exe" (
  echo [X] 未找到 uncle-novel 文件夹，请确认压缩包已完整解压
  pause
  exit /b 1
)
if not exist "%LOCALAPPDATA%\Programs" mkdir "%LOCALAPPDATA%\Programs" >nul 2>nul
if exist "%DEST%\Uncle小说.exe" (
  echo [!] 检测到已安装: %DEST%
  choice /c YN /m "是否覆盖安装（保留书架数据 conf\core.db 与设置 conf\conf.json）"
  if errorlevel 2 (
    echo 已取消安装。
    pause
    exit /b 0
  )
  robocopy "%SRC%" "%DEST%" /E /XF core.db conf.json /NFL /NDL /NJH /NJS /NP >nul
) else (
  robocopy "%SRC%" "%DEST%" /E /NFL /NDL /NJH /NJS /NP >nul
)
if errorlevel 8 (
  echo [X] 文件复制失败，请检查磁盘空间或权限
  pause
  exit /b 1
)
echo [OK] 程序文件已复制到: %DEST%
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0初始化配置.ps1" -InstallDir "%DEST%"
if errorlevel 1 echo [!] 调优配置生成失败，可稍后在软件设置中手动调整
copy /y "%~dp0初始化配置.ps1" "%DEST%\初始化配置.ps1" >nul 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0创建快捷方式.ps1" -InstallDir "%DEST%"
if errorlevel 1 (
  echo [X] 快捷方式创建失败
  pause
  exit /b 1
)
copy /y "%~dp0卸载.bat" "%DEST%\卸载.bat" >nul 2>nul
copy /y "%~dp0使用说明-离线版.txt" "%DEST%\使用说明-离线版.txt" >nul 2>nul
copy /y "%~dp0目标机环境自检.ps1" "%DEST%\目标机环境自检.ps1" >nul 2>nul
copy /y "%~dp0benchmark.ps1" "%DEST%\benchmark.ps1" >nul 2>nul
echo [OK] 目标机环境自检脚本已放入安装目录
echo [OK] 离线/老板键说明已放入安装目录
echo [OK] 卸载脚本与使用说明已放入安装目录
echo.
echo 安装完成！看到 [OK] 提示且桌面出现 "Uncle小说" 图标即为成功。
echo 提示：老板键 Alt+U 可随时隐藏/恢复窗口（完整版与本地TXT快速阅读均可用）。
echo 首次启动会自动生成 conf\conf.json 等数据文件；离线时联网功能会显示离线提示。
echo 建议先运行安装目录下的 目标机环境自检.ps1 检查目标机环境。
pause
