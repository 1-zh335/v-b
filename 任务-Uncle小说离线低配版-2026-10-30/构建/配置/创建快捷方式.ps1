param(
    [Parameter(Mandatory=$true)][string]$InstallDir
)
$ErrorActionPreference = 'Stop'
$exe = Join-Path $InstallDir 'Uncle小说.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    Write-Host '[X] 找不到主程序 Uncle小说.exe'
    exit 1
}
$javaw = Join-Path $InstallDir 'runtime\bin\javaw.exe'
if (-not (Test-Path -LiteralPath $javaw)) {
    Write-Host '[X] 找不到 runtime\bin\javaw.exe'
    exit 1
}
$ws = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
$programs = [Environment]::GetFolderPath('Programs')
# 低配目标机运行参数：小堆 + 串行 GC + JavaFX 软件渲染 + 目标档离线提示
$quickArgs = @(
    '--module-path', ('"' + (Join-Path $InstallDir 'runtime\modules') + '"'),
    '--add-modules', 'ALL-SYSTEM',
    '--add-exports=javafx.graphics/com.sun.javafx.css=com.unclezs.novel.app.framework',
    '--add-exports=javafx.graphics/com.sun.javafx.stage=com.unclezs.novel.app.main,com.jfoenix',
    '--add-exports=javafx.graphics/com.sun.javafx.scene=com.jfoenix',
    '--add-exports=javafx.base/com.sun.javafx.binding=com.jfoenix',
    '--add-exports=javafx.base/com.sun.javafx.event=com.jfoenix',
    '--add-exports=javafx.controls/com.sun.javafx.scene.control.behavior=com.jfoenix',
    '--add-exports=javafx.controls/com.sun.javafx.scene.control=com.jfoenix',
    '--add-exports=javafx.controls/com.sun.javafx.scene.control.skin=com.unclezs.novel.app.main',
    '--add-opens=com.jfoenix/com.jfoenix.controls=com.unclezs.novel.app.framework',
    '-Dfile.encoding=UTF-8',
    '-Djava.util.logging.config.file=conf/jul.properties',
    '-Dprism.order=sw',
    '-Dprism.forceGPU=false',
    '-Dprism.lcdtext=false',
    '-Duncle.target.profile=true',
    '-Duncle.analytics.disabled=true',
    '-Duncle.update.check=false',
    '-Xms64m',
    '-Xmx448m',
    '-XX:MaxMetaspaceSize=192m',
    '-XX:+UseSerialGC',
    '-m', 'com.unclezs.novel.app.main/com.unclezs.novel.app.main.QuickApp'
) -join ' '

$made = 0
foreach ($dir in @($desktop, $programs)) {
    if (-not $dir) { continue }
    # 完整版快捷方式
    $lnkPath = Join-Path $dir 'Uncle小说.lnk'
    $lnk = $ws.CreateShortcut($lnkPath)
    $lnk.TargetPath = $exe
    $lnk.WorkingDirectory = $InstallDir
    $lnk.IconLocation = (Join-Path $InstallDir 'favicon.ico')
    $lnk.Description = 'Uncle小说 离线低配版 v5.0.44（完整功能）'
    $lnk.Save()
    Write-Host "[OK] 完整版快捷方式: $lnkPath"
    $made++
    # 本地 TXT 快速阅读快捷方式（不带参数启动时弹出文件选择框）
    $quickPath = Join-Path $dir 'Uncle小说 · 本地TXT快速阅读.lnk'
    $q = $ws.CreateShortcut($quickPath)
    $q.TargetPath = $javaw
    $q.Arguments = $quickArgs
    $q.WorkingDirectory = $InstallDir
    $q.IconLocation = (Join-Path $InstallDir 'favicon.ico')
    $q.Description = 'Uncle小说 本地 TXT 快速阅读（离线可用 / 老板键 Alt+U）'
    $q.Save()
    Write-Host "[OK] 本地TXT快速阅读快捷方式: $quickPath"
    $made++
}
# 发送到菜单：右键 TXT → 发送到 → Uncle小说快速阅读
$sendTo = Join-Path $env:APPDATA 'Microsoft\Windows\SendTo'
if (Test-Path -LiteralPath $sendTo) {
    $sendLnk = Join-Path $sendTo 'Uncle小说快速阅读.lnk'
    $s = $ws.CreateShortcut($sendLnk)
    $s.TargetPath = (Join-Path $InstallDir '本地TXT快速阅读.bat')
    $s.WorkingDirectory = $InstallDir
    $s.IconLocation = (Join-Path $InstallDir 'favicon.ico')
    $s.Description = '用 Uncle小说 快速阅读此 TXT（离线可用）'
    $s.Save()
    Write-Host "[OK] 已加入右键『发送到』菜单: $sendLnk"
    $made++
}
if ($made -eq 0) { Write-Host '[X] 未创建任何快捷方式'; exit 1 }
exit 0
