param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\UncleNovel'),
    [string]$InputFile = '',
    [int]$WaitSeconds = 40
)
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
if (-not $InputFile) {
    $InputFile = Get-ChildItem 'C:\Users\31384\Documents\trae_projects\v b\素材' -Filter '*.txt' -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $InputFile -or -not (Test-Path $InputFile)) {
    Write-Host '[X] 未找到测试 TXT，可传 -InputFile 指定'
    exit 1
}
Get-Process javaw -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
$javaw = Join-Path $InstallDir 'runtime\bin\javaw.exe'
$args = @(
    '--module-path', (Join-Path $InstallDir 'runtime\modules'), '--add-modules', 'ALL-SYSTEM',
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
    '-Dprism.order=sw', '-Dprism.forceGPU=false', '-Dprism.lcdtext=false',
    '-Duncle.target.profile=true', '-Duncle.analytics.disabled=true', '-Duncle.update.check=false',
    '-Xms64m', '-Xmx448m', '-XX:MaxMetaspaceSize=192m', '-XX:+UseSerialGC',
    '-m', 'com.unclezs.novel.app.main/com.unclezs.novel.app.main.QuickApp', $InputFile
)
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $javaw
$psi.Arguments = ($args | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
$psi.WorkingDirectory = $InstallDir
$psi.UseShellExecute = $false
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$proc = [System.Diagnostics.Process]::Start($psi)
$uia = [System.Windows.Automation.AutomationElement]::RootElement
$windowReady = -1
$readerReady = -1
while ($sw.Elapsed.TotalSeconds -lt $WaitSeconds) {
    Start-Sleep -Milliseconds 400
    try {
        $proc.Refresh()
        $cond = New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::ProcessIdProperty), $proc.Id
        $win = $uia.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
        if ($win) {
            if ($windowReady -lt 0) { $windowReady = $sw.Elapsed.TotalSeconds }
            $texts = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants,
                (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty), [System.Windows.Automation.ControlType]::Text))
            $longest = 0
            foreach ($t in $texts) { if ($t.Current.Name.Length -gt $longest) { $longest = $t.Current.Name.Length } }
            if ($longest -gt 120) { $readerReady = $sw.Elapsed.TotalSeconds; break }
        }
    } catch { }
}
$proc.Refresh()
$rss = [math]::Round($proc.WorkingSet64 / 1MB, 1)
$logFile = Join-Path $InstallDir 'logs\log-system.log'
$indexLine = ''
if (Test-Path $logFile) {
    $indexLine = (Get-Content $logFile -Encoding UTF8 | Select-String '章节索引完成' | Select-Object -Last 1).Line
}
Get-Process -Id $proc.Id -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$result = [ordered]@{
    input = $InputFile
    windowReadySec = [math]::Round($windowReady, 2)
    readerReadySec = [math]::Round($readerReady, 2)
    rssMB = $rss
    indexLog = $indexLine
}
$result | ConvertTo-Json -Depth 3
Write-Host ''
Write-Host '提示：本脚本用于目标机低配参数下的启动耗时/内存采样，结果仅作量级参考。'
