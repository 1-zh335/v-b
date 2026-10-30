param(
    [Parameter(Mandatory=$true)][string]$File,
    [string]$Tag = '',
    [string]$OutDir = '',
    [int]$TimeoutSec = 90,
    [switch]$KeepRunning,
    [switch]$TestToc,
    [switch]$RepeatWarm
)
$ErrorActionPreference = 'Continue'
$install = Join-Path $env:LOCALAPPDATA 'Programs\UncleNovel'
$root = 'C:\Users\31384\Documents\trae_projects\v b\任务-uncle-novel优化-2026-10-25'
if (-not $OutDir) { $OutDir = Join-Path $root '测试结果' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
if (-not $Tag) { $Tag = [System.IO.Path]::GetFileNameWithoutExtension($File) }

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class QW3 {
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr c);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    public static void DpiAware() { try { SetProcessDpiAwarenessContext(new IntPtr(-4)); } catch {} try { SetProcessDPIAware(); } catch {} }
    public static IntPtr FindMainWindow(int pid) {
        IntPtr best = IntPtr.Zero; long bestArea = 0;
        EnumWindows((h, l) => {
            uint p; GetWindowThreadProcessId(h, out p);
            if ((int)p == pid && IsWindowVisible(h)) {
                var c = new StringBuilder(256); GetClassName(h, c, 256);
                if (c.ToString().StartsWith("GlassWndClass")) {
                    RECT r; GetWindowRect(h, out r);
                    long area = (long)(r.R - r.L) * (r.B - r.T);
                    if (area > bestArea) { bestArea = area; best = h; }
                }
            }
            return true;
        }, IntPtr.Zero);
        return best;
    }
    public static void Key(IntPtr h, int vk) {
        PostMessage(h, 0x0100, (IntPtr)vk, IntPtr.Zero);
        System.Threading.Thread.Sleep(60);
        PostMessage(h, 0x0101, (IntPtr)vk, IntPtr.Zero);
    }
    public static void Click(int x, int y) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(150);
        mouse_event(0x0002, 0, 0, 0, IntPtr.Zero);
        System.Threading.Thread.Sleep(60);
        mouse_event(0x0004, 0, 0, 0, IntPtr.Zero);
    }
}
"@
[QW3]::DpiAware()

function Get-AppWindows([int]$procId) {
    $uia = [System.Windows.Automation.AutomationElement]::RootElement
    $cond = New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::ProcessIdProperty), $procId
    $wins = $uia.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
    $res = @()
    foreach ($w in $wins) {
        $r = $w.Current.BoundingRectangle
        if ($r.Width -gt 300 -and $r.Height -gt 200) { $res += $w }
    }
    return $res
}
function Get-ReaderTexts($win) {
    $cond = New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::ControlTypeProperty), ([System.Windows.Automation.ControlType]::Text)
    $els = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
    $res = @()
    foreach ($e in $els) { $res += [string]$e.Current.Name }
    return $res
}
function Get-LongestText($texts) {
    $best = ''
    foreach ($t in $texts) { if ($t.Length -gt $best.Length) { $best = $t } }
    return $best
}
function Save-WindowShot($win, [string]$path) {
    $r = $win.Current.BoundingRectangle
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $x1 = [math]::Max(0, [int]$r.X); $y1 = [math]::Max(0, [int]$r.Y)
    $x2 = [math]::Min($screen.Width, [int]($r.X + $r.Width)); $y2 = [math]::Min($screen.Height, [int]($r.Y + $r.Height))
    $w = $x2 - $x1; $h = $y2 - $y1
    if ($w -le 0 -or $h -le 0) { return $false }
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($x1, $y1, 0, 0, (New-Object System.Drawing.Size $w, $h))
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    return $true
}

function Invoke-QuickRun([string]$file, [string]$tag) {
    $javaw = Join-Path $install 'runtime\bin\javaw.exe'
    $opts = @(
     '--module-path', (Join-Path $install 'runtime\modules'),
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
     '-m', 'com.unclezs.novel.app.main/com.unclezs.novel.app.main.QuickApp',
     $file
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $javaw
    $psi.Arguments = ($opts | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $psi.WorkingDirectory = $install
    $psi.UseShellExecute = $false
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $proc = [System.Diagnostics.Process]::Start($psi)
    $res = [ordered]@{ pid = $proc.Id; windowSec = -1; readerSec = -1; chapters = -1; firstTitle = '' }
    $readerWin = $null; $texts = @()
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 300
        if ($proc.HasExited) { break }
        $wins = Get-AppWindows $proc.Id
        if ($wins.Count -gt 0) {
            if ($res.windowSec -lt 0) { $res.windowSec = [math]::Round($sw.Elapsed.TotalSeconds, 2) }
            foreach ($w in $wins) {
                $t = Get-ReaderTexts $w
                if ((Get-LongestText $t).Length -gt 120) {
                    $readerWin = $w; $texts = $t; $res.readerSec = [math]::Round($sw.Elapsed.TotalSeconds, 2)
                    break
                }
            }
        }
        if ($readerWin) { break }
    }
    $log = Join-Path $install 'logs\log-system.log'
    if (Test-Path $log) {
        $hit = (Get-Content $log -Encoding UTF8 -Tail 400) | Select-String '章节索引完成：(\d+) 章' | Select-Object -Last 1
        if ($hit) { $res.chapters = [int]$hit.Matches[0].Groups[1].Value }
    }
    $script:readerWin = $readerWin
    $script:readerTexts = $texts
    $script:proc = $proc
    $script:sw = $sw
    return $res
}

& taskkill /F /IM 'javaw.exe' 2>&1 | Out-Null
& taskkill /F /IM 'Uncle小说.exe' 2>&1 | Out-Null
Start-Sleep -Seconds 1

$result = [ordered]@{ file = $File; tag = $Tag; ok = $false; logError = '' }
$run1 = Invoke-QuickRun $File $Tag
$result.windowSec = $run1.windowSec
$result.readerSec = $run1.readerSec
$result.chapters = $run1.chapters
if ($script:readerWin) {
    Start-Sleep -Milliseconds 800
    $win = $script:readerWin
    $texts = Get-ReaderTexts $win
    $longest = Get-LongestText $texts
    $result.firstPageHead = ($longest -replace "`r?`n", ' ').Substring(0, [Math]::Min(160, $longest.Length))
    # 标题栏（含页码）
    foreach ($t in $texts) {
        if ($t -match '（第\s*\d+/\d+\s*页' -or ($t.Length -lt 80 -and $t -match '第\s*\d+\s*[章节]')) { $result.firstTitle = $t; break }
    }
    $shot1 = Join-Path $OutDir ("{0}-page1.png" -f $Tag)
    if (Save-WindowShot $win $shot1) { $result.screenshot1 = $shot1 }
    # 翻页：单次按键（避免连发导致防抖竞争），失败再单击右侧
    $wsh = New-Object -ComObject WScript.Shell
    $hwnd = [QW3]::FindMainWindow($script:proc.Id)
    [void]$wsh.AppActivate($script:proc.Id)
    [void][QW3]::SetForegroundWindow($hwnd)
    Start-Sleep -Milliseconds 900
    $title1 = ''
    foreach ($t in $texts) { if ($t -match '（第\s*\d+/\d+\s*页') { $title1 = $t; break } }
    $result.title1 = $title1
    [QW3]::Key($hwnd, 0x27)
    Start-Sleep -Seconds 3
    $wins2 = Get-AppWindows $script:proc.Id
    $lg2 = ''; $title2 = ''
    foreach ($w in $wins2) {
        $t2 = Get-ReaderTexts $w
        $cand = Get-LongestText $t2
        if ($cand.Length -gt 120) {
            $win = $w; $lg2 = $cand
            foreach ($t in $t2) { if ($t -match '（第\s*\d+/\d+\s*页') { $title2 = $t; break } }
            break
        }
    }
    if ($title2 -eq '' -or $title2 -eq $title1) {
        [void]$wsh.AppActivate($script:proc.Id)
        Start-Sleep -Milliseconds 400
        $r = $win.Current.BoundingRectangle
        [QW3]::Click([int]($r.X + $r.Width * 0.85), [int]($r.Y + $r.Height * 0.5))
        Start-Sleep -Seconds 3
        $wins3 = Get-AppWindows $script:proc.Id
        foreach ($w in $wins3) {
            $t3 = Get-ReaderTexts $w
            $cand = Get-LongestText $t3
            if ($cand.Length -gt 120) {
                $lg2 = $cand
                foreach ($t in $t3) { if ($t -match '（第\s*\d+/\d+\s*页') { $title2 = $t; break } }
                break
            }
        }
    }
    $result.title2 = $title2
    $result.pageChanged = (($title2 -ne '') -and ($title2 -ne $title1))
    if (-not $result.pageChanged) { $result.pageChanged = ($lg2 -ne $longest -and $lg2.Length -gt 0) }
    $result.page2Head = ($lg2 -replace "`r?`n", ' ').Substring(0, [Math]::Min(160, $lg2.Length))
    $shot2 = Join-Path $OutDir ("{0}-page2.png" -f $Tag)
    if (Save-WindowShot $win $shot2) { $result.screenshot2 = $shot2 }
    if ($TestToc) {
        $hwnd = [QW3]::FindMainWindow($script:proc.Id)
        [void][QW3]::SetForegroundWindow($hwnd)
        $r = $win.Current.BoundingRectangle
        [QW3]::Click([int]($r.X + 18), [int]($r.Y + $r.Height * 0.5))
        Start-Sleep -Seconds 1
        $tocShot = Join-Path $OutDir ("{0}-toc.png" -f $Tag)
        if (Save-WindowShot $win $tocShot) { $result.screenshotToc = $tocShot }
        $textsToc = Get-ReaderTexts $win
        $cnt = 0
        foreach ($t in $textsToc) { if ($t -match '^第\s*\d+\s*章') { $cnt++ } }
        $result.tocCount = $cnt
    }
    $result.ok = ($result.readerSec -gt 0 -and $longest.Length -gt 120 -and $result.pageChanged)
    if (-not $RepeatWarm) { & taskkill /F /PID $script:proc.Id 2>&1 | Out-Null }
}
# 热缓存二次打开耗时
if ($RepeatWarm) {
    & taskkill /F /PID $script:proc.Id 2>&1 | Out-Null
    Start-Sleep -Seconds 1
    $run2 = Invoke-QuickRun $File $Tag
    $result.warmOpenSec = $run2.readerSec
    if ($script:proc) { & taskkill /F /PID $script:proc.Id 2>&1 | Out-Null }
}
if (-not $KeepRunning -and $script:proc) { & taskkill /F /PID $script:proc.Id 2>&1 | Out-Null } else { }
$errLog = Join-Path $install 'logs\log-error.log'
if (Test-Path $errLog) { $result.logError = ((Get-Content $errLog -Encoding UTF8 -Tail 20) -join "`n") }
$jsonPath = Join-Path $OutDir ("{0}-result.json" -f $Tag)
[System.IO.File]::WriteAllText($jsonPath, ($result | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
$result | ConvertTo-Json -Depth 4 -Compress
exit 0
