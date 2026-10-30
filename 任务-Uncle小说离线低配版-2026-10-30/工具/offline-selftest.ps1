param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\UncleNovel'),
    [string]$InputFile = '',
    [string]$OutDir = '',
    [switch]$ForceOffline,
    [switch]$ForceOnline,
    [switch]$NoAudio,
    [switch]$TargetProfile,
    [switch]$TestBossKey,
    [int]$WaitSeconds = 12
)
$ErrorActionPreference = 'Stop'
if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '..\截图\自动测试' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -ReferencedAssemblies @('System.Drawing') -TypeDefinition @"
using System;
using System.Text;
using System.Drawing;
using System.Runtime.InteropServices;
public class WinProbe {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    public static void Aware() { try { SetThreadDpiAwarenessContext(new IntPtr(-4)); } catch { } }
    public static IntPtr FindByPid(int pid) {
        Aware();
        IntPtr best = IntPtr.Zero; long area = 0;
        EnumWindows((h, l) => {
            uint p; GetWindowThreadProcessId(h, out p);
            if ((int)p == pid) {
                var cn = new StringBuilder(256); GetClassName(h, cn, 256);
                RECT r; GetWindowRect(h, out r);
                long a = (long)(r.R - r.L) * (r.B - r.T);
                if (a > area) { area = a; best = h; }
            }
            return true;
        }, IntPtr.Zero);
        return best;
    }
    public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
    public static void PressAltU() {
        keybd_event(0x12, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(80);
        keybd_event(0x55, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(80);
        keybd_event(0x55, 0, 2, UIntPtr.Zero);
        System.Threading.Thread.Sleep(80);
        keybd_event(0x12, 0, 2, UIntPtr.Zero);
    }
    public static Bitmap Capture(IntPtr h) {
        Aware();
        RECT r; GetWindowRect(h, out r);
        int w = r.R - r.L, hh = r.B - r.T;
        if (w <= 0 || hh <= 0) { return null; }
        var bmp = new Bitmap(w, hh);
        using (var g = Graphics.FromImage(bmp)) {
            IntPtr hdc = g.GetHdc();
            bool ok = PrintWindow(h, hdc, 2);
            g.ReleaseHdc(hdc);
            if (!ok) { return null; }
        }
        return bmp;
    }
}
"@
function Save-Shot([IntPtr]$hwnd, [string]$path) {
    $bmp = [WinProbe]::Capture($hwnd)
    if ($bmp) {
        $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        return $true
    }
    return $false
}
function Get-UiTitle([int]$targetPid) {
    try {
        $uia = [System.Windows.Automation.AutomationElement]::RootElement
        $cond = New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::ProcessIdProperty), $targetPid
        $win = $uia.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
        if ($win) { return $win.Current.Name }
    } catch { }
    return ''
}
$javaw = Join-Path $InstallDir 'runtime\bin\javaw.exe'
if (-not (Test-Path $javaw)) { throw "javaw not found: $javaw" }
if (-not $InputFile) {
    $InputFile = Get-ChildItem 'C:\Users\31384\Documents\trae_projects\v b\素材' -Filter '*.txt' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $InputFile -or -not (Test-Path $InputFile)) { throw 'no input txt found' }
Get-Process javaw -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process 'Uncle小说' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
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
    '-Xms64m', '-Xmx448m', '-XX:MaxMetaspaceSize=192m', '-XX:+UseSerialGC',
    '-m', 'com.unclezs.novel.app.main/com.unclezs.novel.app.main.QuickApp', $InputFile
)
if ($ForceOffline) { $args = @('-Duncle.network.force=offline') + $args }
if ($ForceOnline) { $args = @('-Duncle.network.force=online') + $args }
if ($NoAudio) { $args = @('-Duncle.audio.force=unavailable') + $args }
if ($TargetProfile) { $args = @('-Duncle.target.profile=true', '-Duncle.analytics.disabled=true', '-Duncle.update.check=false') + $args }
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $javaw
$psi.Arguments = ($args | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
$psi.WorkingDirectory = $InstallDir
$psi.UseShellExecute = $false
$proc = [System.Diagnostics.Process]::Start($psi)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$hwnd = [IntPtr]::Zero
while ($sw.Elapsed.TotalSeconds -lt $WaitSeconds) {
    Start-Sleep -Milliseconds 500
    $hwnd = [WinProbe]::FindByPid($proc.Id)
    if ($hwnd -ne [IntPtr]::Zero -and [WinProbe]::IsWindowVisible($hwnd)) { break }
}
Start-Sleep -Seconds 4
$hwnd = [WinProbe]::FindByPid($proc.Id)
$windowTitle = [WinProbe]::Title($hwnd)
$uiTitle = Get-UiTitle $proc.Id
$visibleBefore = [WinProbe]::IsWindowVisible($hwnd)
$shotBefore = Save-Shot $hwnd (Join-Path $OutDir '01-启动后.png')
$visibleAfterHide = $null
$visibleAfterRestore = $null
$shotHidden = $false
$shotRestored = $false
if ($TestBossKey) {
    [WinProbe]::PressAltU()
    Start-Sleep -Seconds 2
    $visibleAfterHide = [WinProbe]::IsWindowVisible($hwnd)
    $shotHidden = Save-Shot $hwnd (Join-Path $OutDir '02-老板键隐藏后.png')
    [WinProbe]::PressAltU()
    Start-Sleep -Seconds 2
    $visibleAfterRestore = [WinProbe]::IsWindowVisible($hwnd)
    $shotRestored = Save-Shot $hwnd (Join-Path $OutDir '03-老板键恢复后.png')
}
$logFile = Join-Path $InstallDir 'logs\log-system.log'
$logs = @()
if (Test-Path $logFile) { $logs = Get-Content $logFile -Encoding UTF8 -Tail 40 }
$result = [ordered]@{
    pid = $proc.Id
    hwnd = $hwnd.ToInt64()
    windowTitle = $windowTitle
    uiTitle = $uiTitle
    titleHasOffline = ($windowTitle -match '离线') -or ($uiTitle -match '离线')
    visibleBefore = $visibleBefore
    visibleAfterHide = $visibleAfterHide
    visibleAfterRestore = $visibleAfterRestore
    shotBefore = $shotBefore
    shotHidden = $shotHidden
    shotRestored = $shotRestored
    logHasOfflineGuard = (($logs -join "`n") -match '离线守卫已启动')
    logHasBossKey = (($logs -join "`n") -match '老板键已注册')
    logOfflineState = (($logs -join "`n") -match 'CHECKING -> OFFLINE')
    logTail = ($logs | Select-Object -Last 12)
    outDir = $OutDir
}
Get-Process -Id $proc.Id -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$result | ConvertTo-Json -Depth 4
