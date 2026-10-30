param(
    [ValidateSet('launch','shot','ui','invoke','kill','info')]
    [string]$Action = 'launch',
    [string]$AppDir = '',
    [string]$OutDir = '',
    [int]$TimeoutSec = 90,
    [int]$TargetPid = -1,
    [string]$ButtonName = '',
    [switch]$KeepRunning,
    [switch]$ListAll
)

$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class W3 {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr ctx);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
    public static void MakeDpiAware() {
        try { SetProcessDpiAwarenessContext(new IntPtr(-4)); } catch { }
        try { SetProcessDPIAware(); } catch { }
    }
}
"@
[W3]::MakeDpiAware()

# Chinese strings without non-ASCII source (avoid encoding pitfalls)
function U([int[]]$codes) { -join ($codes | ForEach-Object { [char]$_ }) }
$UI_BOOKSHELF = U @(0x5C0F,0x8BF4,0x4E66,0x67B6)      # 小说书架
$UI_SEARCH    = U @(0x641C,0x7D22,0x5C0F,0x8BF4)      # 搜索小说
$DISMISS      = @((U @(0x4E86,0x89E3,0x4E86)), (U @(0x786E,0x5B9A)), (U @(0x5173,0x95ED)))  # 了解了 / 确定 / 关闭
$UI_PREFIX    = 'GlassWndClass'

function Get-TreePids([int]$RootPid) {
    $all = Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId -ErrorAction SilentlyContinue
    $set = New-Object 'System.Collections.Generic.HashSet[int]'
    [void]$set.Add($RootPid)
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($proc in $all) {
            if ($set.Contains([int]$proc.ParentProcessId) -and -not $set.Contains([int]$proc.ProcessId)) {
                [void]$set.Add([int]$proc.ProcessId); $changed = $true
            }
        }
    }
    return @($set)
}

function Find-AppWindows([int]$RootPid) {
    $tree = Get-TreePids $RootPid
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $wins = $root.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
    $res = New-Object System.Collections.ArrayList
    foreach ($w in $wins) {
        if ($tree -contains [int]$w.Current.ProcessId -and $w.Current.ClassName -like ($UI_PREFIX + '*')) {
            [void]$res.Add($w)
        }
    }
    return @($res)
}

function Get-WindowShotPath([string]$Dir) {
    if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Force -Path $Dir | Out-Null }
    return (Join-Path $Dir ("shot-" + (Get-Date -Format 'HHmmss') + ".png"))
}

function Save-WindowShot($Win, [string]$Path) {
    $r = $Win.Current.BoundingRectangle
    $sb = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $x1 = [math]::Max(0, [int]$r.X); $y1 = [math]::Max(0, [int]$r.Y)
    $x2 = [math]::Min($sb.Width, [int]($r.X + $r.Width)); $y2 = [math]::Min($sb.Height, [int]($r.Y + $r.Height))
    $w = $x2 - $x1; $h = $y2 - $y1
    if ($w -le 0 -or $h -le 0) { Write-Host "CAPTURE_FAIL: bad rect"; return }
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($x1, $y1, 0, 0, (New-Object System.Drawing.Size $w, $h))
    $g.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "SCREENSHOT: $Path ($w x $h)"
}

function Dismiss-Dialogs($Win) {
    $invoked = 0
    foreach ($name in $DISMISS) {
        $cond = New-Object System.Windows.Automation.AndCondition(
            (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)),
            (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $name)))
        $btns = $Win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
        foreach ($b in $btns) {
            try {
                $pat = $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                $pat.Invoke(); $invoked++
                Write-Host "DISMISSED: $name"
                Start-Sleep -Milliseconds 700
            } catch { }
        }
    }
    return $invoked
}

function Invoke-AppButton($Win, [string]$Name) {
    $cond = New-Object System.Windows.Automation.AndCondition(
        (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)),
        (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $Name)))
    $b = $Win.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
    if (-not $b) { Write-Host "BUTTON_NOT_FOUND: $Name"; return $false }
    try {
        $pat = $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
        $pat.Invoke()
        Write-Host "INVOKED: $Name"
        return $true
    } catch { Write-Host "INVOKE_FAIL: $($_.Exception.Message)"; return $false }
}

function Show-Metrics([int]$RootPid) {
    $tree = Get-TreePids $RootPid
    $procs = Get-CimInstance Win32_Process -Property ProcessId, Name, WorkingSetSize, KernelModeTime, UserModeTime -ErrorAction SilentlyContinue | Where-Object { $tree -contains [int]$_.ProcessId }
    $rss = 0; $cpu = 0.0
    foreach ($pr in $procs) {
        $rss += $pr.WorkingSetSize
        $cpu += ($pr.KernelModeTime + $pr.UserModeTime) / 10000000
    }
    "RSS_MB: {0:N1}" -f ($rss / 1MB)
    "CPU_SEC: {0:N2}" -f $cpu
    "PROC_COUNT: $($procs.Count)"
    return @{ Pids = $tree }
}

if ($Action -eq 'kill') {
    $pids = if ($TargetPid -gt 0) { @($TargetPid) } else { Get-CimInstance Win32_Process | Where-Object { $_.Name -like '*Uncle*' -or ($_.CommandLine -ne $null -and $_.CommandLine -match 'uncle-novel') } | Select-Object -ExpandProperty ProcessId }
    write-host "KILLING: $($pids -join ',')"
    foreach ($procId in $pids) { try { Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue } catch {} }
    Start-Sleep -Seconds 2
    $left = Get-CimInstance Win32_Process | Where-Object { $_.Name -like '*Uncle*' }
    if ($left) { "STILL_RUNNING: $($left.ProcessId -join ',')" } else { "ALL_KILLED" }
    exit 0
}

if ($Action -eq 'launch') {
    if (-not $AppDir) { throw 'AppDir required' }
    $exe = Get-ChildItem -LiteralPath $AppDir -Filter *.exe -File | Where-Object { $_.Name -notmatch '^(kindlegen|java|javaw)' } | Select-Object -First 1
    if (-not $exe) { throw "no exe in $AppDir" }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $p = Start-Process -FilePath $exe.FullName -WorkingDirectory $AppDir -PassThru
    Write-Host "STARTED_PID: $($p.Id)"
    $windowSec = $null; $uiSec = $null; $win = $null
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 200
        $wins = Find-AppWindows $p.Id
        if ($wins.Count -gt 0 -and $null -eq $windowSec) {
            $windowSec = $sw.Elapsed.TotalSeconds
            Write-Host ("WINDOW_SEC: {0:N2}" -f $windowSec)
        }
        foreach ($w in $wins) {
            $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $UI_BOOKSHELF)
            $el = $w.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
            if ($el) {
                $win = $w
                $uiSec = $sw.Elapsed.TotalSeconds
                Write-Host ("UI_READY_SEC: {0:N2}" -f $uiSec)
                break
            }
        }
        if ($uiSec) { break }
    }
    if (-not $win) { Write-Host "WINDOW_SEC: TIMEOUT" }
    if (-not $uiSec) { Write-Host "UI_READY_SEC: TIMEOUT" }
    if ($win) {
        Start-Sleep -Milliseconds 1200
        [void][W3]::ShowWindow([IntPtr]$win.Current.NativeWindowHandle, 9)
        [void][W3]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)
        Start-Sleep -Milliseconds 600
        if (Dismiss-Dialogs $win) { Start-Sleep -Milliseconds 1200 }
        if ($OutDir) { Save-WindowShot $win (Get-WindowShotPath $OutDir) }
    }
    Start-Sleep -Seconds 1
    $m = Show-Metrics $p.Id
    $jcmd = Join-Path $AppDir 'runtime\bin\jcmd.exe'
    if ((Test-Path $jcmd) -and $m.Pids) {
        $javaPid = $m.Pids | Where-Object { (Get-Process -Id $_ -ErrorAction SilentlyContinue).ProcessName -match 'Uncle|java' } | Select-Object -First 1
        Write-Host "--- VM FLAGS ---"
        & $jcmd $javaPid VM.flags 2>&1 | Select-Object -First 4
        Write-Host "--- HEAP INFO ---"
        & $jcmd $javaPid GC.heap_info 2>&1 | Select-Object -First 8
    }
    if (-not $KeepRunning) {
        foreach ($procId in (Get-TreePids $p.Id)) { try { Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue } catch {} }
        Start-Sleep -Seconds 2
        if (Get-Process -Id $p.Id -ErrorAction SilentlyContinue) { "STILL_RUNNING" } else { "ALL_KILLED" }
    }
    exit 0
}

# attach mode for shot/ui/invoke/info
$pids = if ($TargetPid -gt 0) { @($TargetPid) } else { @(Get-CimInstance Win32_Process | Where-Object { $_.Name -like '*Uncle*' -or $_.Name -eq 'java.exe' -or $_.Name -eq 'javaw.exe' } | Select-Object -ExpandProperty ProcessId) }
$win = $null
foreach ($procId in $pids) {
    $w = Find-AppWindows $procId
    if ($w.Count -gt 0) { $win = $w[0]; $rootPid = $procId; break }
}
if (-not $win) { Write-Host "NO_APP_WINDOW (pids: $($pids -join ','))"; exit 1 }
Write-Host "WINDOW_PID: $rootPid"
if ($Action -eq 'info') {
    Show-Metrics $rootPid | Out-Null
    $r = $win.Current.BoundingRectangle
    "WINDOW_RECT: $([int]$r.X),$([int]$r.Y) $([int]$r.Width)x$([int]$r.Height)"
}
if ($Action -eq 'shot') {
    [void][W3]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)
    Start-Sleep -Milliseconds 600
    if (-not $OutDir) { $OutDir = '.' }
    Save-WindowShot $win (Get-WindowShotPath $OutDir)
}
if ($Action -eq 'ui') {
    $all = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    Write-Host "ELEMENT_COUNT: $($all.Count)"
    $i = 0
    foreach ($e in $all) {
        $i++
        if (-not $ListAll -and $i -gt 60) { break }
        $r = $e.Current.BoundingRectangle
        $nm = $e.Current.Name -replace "`r?`n", ' / '
        "$i`t$($e.Current.ControlType.ProgrammaticName)`t[$nm]`t$([int]$r.X),$([int]$r.Y) $([int]$r.Width)x$([int]$r.Height)"
    }
}
if ($Action -eq 'invoke') {
    if (-not $ButtonName) { throw 'ButtonName required' }
    Invoke-AppButton $win $ButtonName | Out-Null
    Start-Sleep -Milliseconds 1200
    if ($OutDir) { Save-WindowShot $win (Get-WindowShotPath $OutDir) }
}
