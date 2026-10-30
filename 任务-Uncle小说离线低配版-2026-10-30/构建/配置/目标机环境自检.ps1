param(
    [string]$OutFile = ''
)
$ErrorActionPreference = 'Continue'
if (-not $OutFile) {
    $OutFile = Join-Path $PSScriptRoot '目标机自检报告.txt'
}
$lines = New-Object System.Collections.Generic.List[string]
$fail = 0
$warn = 0
function Add-Line([string]$text) {
    $lines.Add($text)
    Write-Host $text
}
function Check([string]$name, [bool]$ok, [string]$detail, [bool]$isWarn = $false) {
    if ($ok) {
        Add-Line ("[OK]   {0}: {1}" -f $name, $detail)
    } elseif ($isWarn) {
        $script:warn++
        Add-Line ("[WARN] {0}: {1}" -f $name, $detail)
    } else {
        $script:fail++
        Add-Line ("[FAIL] {0}: {1}" -f $name, $detail)
    }
}
Add-Line '=================================================='
Add-Line '  Uncle小说 离线低配版 · 目标机环境自检'
Add-Line ('  生成时间: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Add-Line ('  计算机名: ' + $env:COMPUTERNAME)
Add-Line '=================================================='
try {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $video = @(Get-CimInstance Win32_VideoController)
    $sound = @(Get-CimInstance Win32_SoundDevice)
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $net = @(Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.NetEnabled -eq $true })
} catch {
    Add-Line ('[FAIL] 无法通过 WMI 读取系统信息: ' + $_.Exception.Message)
    $lines | Set-Content -Path $OutFile -Encoding UTF8
    exit 1
}
Add-Line ''
Add-Line '---- 系统 ----'
Add-Line ("操作系统: " + $os.Caption + " / 版本 " + $os.Version + " / Build " + $os.BuildNumber)
Add-Line ("系统型号: " + $cs.Manufacturer + " " + $cs.Model)
Add-Line ("处理器: " + $cpu.Name + " / " + $cpu.NumberOfCores + " 核 " + $cpu.NumberOfLogicalProcessors + " 线程")
Add-Line ("物理内存: " + [math]::Round($cs.TotalPhysicalMemory / 1GB, 2) + " GB")
foreach ($v in $video) {
    Add-Line ("显示适配器: " + $v.Name + " / 驱动 " + $v.DriverVersion + " / 显存 " + [math]::Round($v.AdapterRAM / 1MB, 0) + " MB")
}
if ($sound.Count -eq 0) {
    Add-Line '音频设备: 未检测到（Windows 未安装声卡驱动）'
} else {
    foreach ($s in $sound) { Add-Line ("音频设备: " + $s.Name + " [" + $s.Status + "]") }
}
Add-Line ("C 盘剩余: " + [math]::Round($disk.FreeSpace / 1GB, 2) + " GB / 总 " + [math]::Round($disk.Size / 1GB, 2) + " GB")
$primaryVideo = Get-CimInstance Win32_VideoController | Where-Object { $_.CurrentHorizontalResolution -gt 0 } | Select-Object -First 1
if ($primaryVideo) {
    Add-Line ("屏幕: " + $primaryVideo.CurrentHorizontalResolution + "x" + $primaryVideo.CurrentVerticalResolution)
} else {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $screenBounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        Add-Line ("屏幕: " + $screenBounds.Width + "x" + $screenBounds.Height)
    } catch { Add-Line '屏幕: 未知' }
}
$netNames = @($net | ForEach-Object { $_.Name })
if ($netNames.Count -gt 0) {
    Add-Line ("网络适配器(已启用): " + ($netNames -join '; '))
} else {
    Add-Line '网络适配器(已启用): 无'
}
Add-Line ''
Add-Line '---- 适配检查 ----'
Check '操作系统' ($os.Version -like '10.*') ($os.Caption + ' Build ' + $os.BuildNumber)
Check 'CPU 核心数' ($cpu.NumberOfLogicalProcessors -ge 2) ($cpu.NumberOfCores.ToString() + 'C/' + $cpu.NumberOfLogicalProcessors.ToString() + 'T')
Check '物理内存' ($cs.TotalPhysicalMemory -ge 3.5GB) ([math]::Round($cs.TotalPhysicalMemory / 1GB, 2).ToString() + ' GB（建议 4GB）')
$basicDisplay = @($video | Where-Object { $_.Name -match '基本显示适配器|Basic Display' }).Count -gt 0
Check '显示适配器' $true ($(if ($basicDisplay) { '基本显示适配器（已启用 JavaFX 软件渲染，正常）' } else { ($video | Select-Object -First 1).Name + '（有硬件驱动，软件渲染参数仍可兼容）' })) $false
Check '音频设备' ($sound.Count -gt 0) ($(if ($sound.Count -gt 0) { '检测到音频设备' } else { '未检测到声卡驱动（朗读/有声播放将提示音频不可用，本地阅读不受影响）' })) $true
Check '磁盘空间' ($disk.FreeSpace -gt 10GB) ([math]::Round($disk.FreeSpace / 1GB, 2).ToString() + ' GB 可用（需 ≥10GB）')
$netUp = $netNames.Count -gt 0
if ($netUp) {
    Add-Line '[OK]   网络: 已启用的网络适配器存在（本机为间歇联网环境，离线时联网功能会显示提示）'
} else {
    Add-Line '[WARN] 网络: 当前没有已启用的网络适配器（离线模式正常：本地 TXT 快速阅读可用）'
    $script:warn++
}
Add-Line ''
Add-Line '---- 结论 ----'
if ($fail -eq 0) {
    Add-Line '[OK]   全部关键项通过：本机满足 Uncle小说 离线低配版运行条件'
} else {
    Add-Line ('[FAIL] 存在 ' + $fail + ' 个不满足项，请按上方提示处理后再启动软件')
}
if ($warn -gt 0) {
    Add-Line ('[WARN] 有 ' + $warn + ' 个提醒项（不影响本地阅读）')
}
Add-Line ''
Add-Line ('报告已保存: ' + $OutFile)
$lines | Set-Content -Path $OutFile -Encoding UTF8
if ($fail -gt 0) { exit 2 }
exit 0
