chcp 936 >nul
@echo off
rem 本地 TXT 快速阅读启动器（离线低配版：可把 TXT 直接拖到本文件上；不带参数则弹出文件选择框）
setlocal
set "APP_DIR=%~dp0"
cd /d "%APP_DIR%"
set "JAVAW=%APP_DIR%runtime\bin\javaw.exe"
if not exist "%JAVAW%" (
  echo [X] 未找到 runtime\bin\javaw.exe，请确认本文件位于 Uncle小说 安装目录
  pause
  exit /b 1
)
start "" "%JAVAW%" ^
 --module-path "%APP_DIR%runtime\modules" ^
 --add-modules ALL-SYSTEM ^
 --add-exports=javafx.graphics/com.sun.javafx.css=com.unclezs.novel.app.framework ^
 --add-exports=javafx.graphics/com.sun.javafx.stage=com.unclezs.novel.app.main,com.jfoenix ^
 --add-exports=javafx.graphics/com.sun.javafx.scene=com.jfoenix ^
 --add-exports=javafx.base/com.sun.javafx.binding=com.jfoenix ^
 --add-exports=javafx.base/com.sun.javafx.event=com.jfoenix ^
 --add-exports=javafx.controls/com.sun.javafx.scene.control.behavior=com.jfoenix ^
 --add-exports=javafx.controls/com.sun.javafx.scene.control=com.jfoenix ^
 --add-exports=javafx.controls/com.sun.javafx.scene.control.skin=com.unclezs.novel.app.main ^
 --add-opens=com.jfoenix/com.jfoenix.controls=com.unclezs.novel.app.framework ^
 -Dfile.encoding=UTF-8 ^
 -Djava.util.logging.config.file=conf/jul.properties ^
 -Dprism.order=sw ^
 -Dprism.forceGPU=false ^
 -Dprism.lcdtext=false ^
 -Duncle.target.profile=true ^
 -Duncle.analytics.disabled=true ^
 -Duncle.update.check=false ^
 -Xms64m ^
 -Xmx448m ^
 -XX:MaxMetaspaceSize=192m ^
 -XX:+UseSerialGC ^
 -m com.unclezs.novel.app.main/com.unclezs.novel.app.main.QuickApp %*
exit /b 0
