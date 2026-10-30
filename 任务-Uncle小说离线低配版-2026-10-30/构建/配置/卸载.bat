chcp 936 >nul
@echo off
setlocal
set "DEST=%LOCALAPPDATA%\Programs\UncleNovel"
echo ==================================================
echo   Uncle小说 离线低配版  卸载
echo ==================================================
echo 将删除桌面与开始菜单快捷方式、右键发送到菜单。
echo 注意：安装目录内 conf\core.db（书架/书源）、conf\conf.json（设置）、
echo       downloads\（下载的书）如需要请先备份。
echo.
choice /c YN /m "确认卸载 Uncle小说"
if errorlevel 2 (
  echo 已取消。
  pause
  exit /b 0
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws=New-Object -ComObject WScript.Shell; foreach($d in @([Environment]::GetFolderPath('Desktop'),[Environment]::GetFolderPath('Programs'))){ foreach($n in @('Uncle小说.lnk','Uncle小说 · 本地TXT快速阅读.lnk')){ $p=Join-Path $d $n; if(Test-Path -LiteralPath $p){ Remove-Item -LiteralPath $p -Force; Write-Host ('[OK] 已删除 ' + $p) } } }; $s=Join-Path $env:APPDATA 'Microsoft\Windows\SendTo\Uncle小说快速阅读.lnk'; if(Test-Path -LiteralPath $s){ Remove-Item -LiteralPath $s -Force; Write-Host ('[OK] 已删除 ' + $s) }"
if exist "%DEST%\Uncle小说.exe" (
  choice /c YN /m "是否同时删除安装目录（含书架/设置/下载，不可恢复）"
  if errorlevel 1 (
    rd /s /q "%DEST%" 2>nul
    if exist "%DEST%" (echo [!] 部分文件被占用，请退出 Uncle小说 后手动删除 %DEST%) else (echo [OK] 安装目录已删除)
  )
)
echo.
echo 卸载完成。
pause
