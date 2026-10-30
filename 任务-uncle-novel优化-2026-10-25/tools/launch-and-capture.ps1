param(
    [Parameter(Mandatory=$true)][string]$AppDir,
    [Parameter(Mandatory=$true)][string]$OutDir,
    [int]$TimeoutSec = 120,
    [int]$ExtraWaitSec = 5,
    [switch]$NoKill
)

$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class W32 {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lp);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

function Get-WindowList {
    $list = New-Object System.Collections.ArrayList
    $cb = {
        param($hWnd, $lParam)
        if ([W32]::IsWindowVisible($hWnd)) {
            $len = [W32]::GetWindowTextLength($hWnd)
            if ($len -gt 0) {
                $sb = New-Object System.Text.StringBuilder ($len + 2)
                [void][W32]::GetWindowText($hWnd, $sb, $sb.Capacity)
                $title = $sb.ToString()
                $wpid = 0
                [void][W32]::GetWindowThreadProcessId($hWnd, [ref]$wpid)
                $r = New-Object W32+RECT
                [void][W32]::GetWindowRect($hWnd, [ref]$r)
                $w = $r.Right - $r.Left
                $h = $r.Bottom - $r.Top
                [void]$list.Add([pscustomobject]@{ Hwnd=$hWnd; Pid=$wpid; Title=$title; Left=$r.Left; Top=$r.Top; Width=$w; Height=$h })
            }
        }
        return $true
    }
    [void][W32]::EnumWindows($cb, [IntPtr]::Zero)
    return $list
}

function Get-DescendantPids([int]$RootPid) {
    $all = Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId, Name, CommandLine -ErrorAction SilentlyContinue
    $set = New-Object 'System.Collections.Generic.HashSet[int]'
    [void]$set.Add($RootPid)
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($p in $all) {
            if ($set.Contains([int]$p.ParentProcessId) -and -not $set.Contains([int]$p.ProcessId)) {
                [void]$set.Add([int]$p.ProcessId); $changed = $true
            }
        }
    }
    return @($set)
}

$exe = Get-ChildItem -LiteralPath $AppDir -Filter *.exe -File | Where-Object { $_.Name -notmatch '^(kindlegen|java|javaw)' } | Select-Object -First 1
if (-not $exe) { throw "No exe found in $AppDir" }
Write-Host "EXE: $($exe.FullName)"

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$p = Start-Process -FilePath $exe.FullName -WorkingDirectory $AppDir -PassThru
Write-Host "STARTED PID: $($p.Id)"
$rootPid = $p.Id

$mainWin = $null
$firstSeen = $null
$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 250
    $tree = Get-DescendantPids $rootPid
    $wins = Get-WindowList
    $cand = $wins | Where-Object { $tree -contains [int]$_.Pid -and $_.Width -gt 200 -and $_.Height -gt 100 } |
            Sort-Object { $_.Width * $_.Height } -Descending | Select-Object -First 1
    if ($cand) {
        if (-not $mainWin) {
            $mainWin = $cand
            $firstSeen = $sw.Elapsed.TotalSeconds
            Write-Host ("WINDOW_APPEARED_SEC: {0:N2}" -f $firstSeen)
            Write-Host "WINDOW: [$($cand.Title)] $($cand.Width)x$($cand.Height) hwnd=$($cand.Hwnd)"
            break
        }
    }
}
if (-not $mainWin) {
    Write-Host "WINDOW_APPEARED_SEC: TIMEOUT"
} else {
    Start-Sleep -Seconds $ExtraWaitSec
    $mainWin = Get-WindowList | Where-Object { $_.Hwnd -eq $mainWin.Hwnd } | Select-Object -First 1
    if (-not $mainWin) {
        Write-Host "WINDOW: lost before capture"
    } else {
        [void][W32]::ShowWindow($mainWin.Hwnd, 9)
        [void][W32]::SetWindowPos($mainWin.Hwnd, [IntPtr](-1), $mainWin.Left, $mainWin.Top, $mainWin.Width, $mainWin.Height, 0x0040)
        [void][W32]::SetForegroundWindow($mainWin.Hwnd)
        Start-Sleep -Milliseconds 1200
        $w = $mainWin.Width; $h = $mainWin.Height
        $x = [math]::Max(0, $mainWin.Left); $y = [math]::Max(0, $mainWin.Top)
        $bmp = New-Object System.Drawing.Bitmap $w, $h
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size $w, $h))
        $g.Dispose()
        $png = Join-Path $OutDir ("window-" + (Get-Date -Format 'HHmmss') + ".png")
        $bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        Write-Host "SCREENSHOT: $png"
    }
}

Start-Sleep -Seconds 2
$tree = Get-DescendantPids $rootPid
"---PROCESSES---"
Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId, Name, WorkingSetSize -ErrorAction SilentlyContinue |
    Where-Object { $tree -contains [int]$_.ProcessId } |
    ForEach-Object { "{0,6} parent={1,6} {2,-22} {3,8:N1} MB" -f $_.ProcessId, $_.ParentProcessId, $_.Name, ($_.WorkingSetSize/1MB) }
$totalCpu = 0.0
$procs = Get-CimInstance Win32_Process -Property ProcessId, KernelModeTime, UserModeTime -ErrorAction SilentlyContinue | Where-Object { $tree -contains [int]$_.ProcessId }
foreach ($pr in $procs) { $totalCpu += ($pr.KernelModeTime + $pr.UserModeTime) / 10000000 }
"CPU_SEC_TOTAL: {0:N2}" -f $totalCpu
"---CONFIG---"
$cfg = Get-ChildItem -LiteralPath $AppDir -Recurse -Filter *.vmoptions -ErrorAction SilentlyContinue
foreach ($c in $cfg) { Write-Host "VMOPTIONS $($c.FullName):"; Get-Content -LiteralPath $c.FullName -Encoding UTF8 }
$logDir = Join-Path $AppDir 'logs'
if (Test-Path $logDir) {
    "---LOGS---"
    Get-ChildItem $logDir -File | ForEach-Object { "== $($_.Name) ($($_.Length) bytes) =="; Get-Content -LiteralPath $_.FullName -Tail 40 -Encoding UTF8 }
} else { "NO logs dir at $logDir" }

if (-not $NoKill) {
    "---KILL---"
    foreach ($procId in $tree) {
        try { Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue } catch {}
    }
    Start-Sleep -Seconds 2
    $left = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $tree -contains [int]$_.ProcessId }
    if ($left) { "STILL_RUNNING: $($left.ProcessId -join ',')" } else { "ALL_KILLED" }
}
