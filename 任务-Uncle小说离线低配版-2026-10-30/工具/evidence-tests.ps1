param(
    [ValidateSet('offline','audio','recovery','benchmark','all')][string]$Which = 'all',
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\UncleNovel'),
    [string]$OutDir = (Join-Path $PSScriptRoot '..\截图\自动测试')
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies @('System.Drawing') -TypeDefinition @"
using System;
using System.Text;
using System.Drawing;
using System.Runtime.InteropServices;
public class GuiCap {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    public static void Aware() { try { SetThreadDpiAwarenessContext(new IntPtr(-4)); } catch { } }
    public static IntPtr[] Wins(int pid) {
        Aware();
        var list = new System.Collections.Generic.List<IntPtr>();
        EnumWindows((h, l) => {
            uint p; GetWindowThreadProcessId(h, out p);
            if ((int)p == pid && IsWindowVisible(h)) { list.Add(h); }
            return true;
        }, IntPtr.Zero);
        return list.ToArray();
    }
    public static string Cls(IntPtr h) { var sb = new StringBuilder(256); GetClassName(h, sb, 256); return sb.ToString(); }
    public static int[] Size(IntPtr h) {
        RECT r; GetWindowRect(h, out r);
        return new int[] { r.R - r.L, r.B - r.T };
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
$javaw = Join-Path $InstallDir 'runtime\bin\javaw.exe'
$common = @(
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
    '-Xms64m', '-Xmx512m', '-XX:MaxMetaspaceSize=192m', '-XX:+UseSerialGC'
)
function Start-App([string[]]$extraFlags, [string[]]$tailArgs) {
    Get-Process javaw -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    $all = $common + $extraFlags + $tailArgs
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $javaw
    $psi.Arguments = ($all | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $psi.WorkingDirectory = $InstallDir
    $psi.UseShellExecute = $false
    return [System.Diagnostics.Process]::Start($psi)
}
function Stop-App([System.Diagnostics.Process]$proc) {
    try { $proc.Refresh(); $proc.Kill() } catch { }
    Start-Sleep -Milliseconds 500
}
function Capture-All([int]$targetPid, [string]$prefix) {
    $shots = @()
    foreach ($h in [GuiCap]::Wins($targetPid)) {
        if ([GuiCap]::Cls($h) -notlike 'GlassWndClass*') { continue }
        $size = [GuiCap]::Size($h)
        $bmp = [GuiCap]::Capture($h)
        if (-not $bmp) { continue }
        $name = '{0}-{1}x{2}.png' -f $prefix, $size[0], $size[1]
        $path = Join-Path $OutDir $name
        $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        $shots += $path
    }
    return $shots
}
function Log-Tail([int]$lines = 30) {
    $logFile = Join-Path $InstallDir 'logs\log-system.log'
    if (Test-Path $logFile) { return @(Get-Content $logFile -Encoding UTF8 -Tail $lines) }
    return @()
}
$quickFile = Get-ChildItem 'C:\Users\31384\Documents\trae_projects\v b\素材' -Filter '*.txt' | Select-Object -First 1 -ExpandProperty FullName
$results = [ordered]@{}
if ($Which -eq 'offline' -or $Which -eq 'all') {
    $proc = Start-App @('-Duncle.network.force=offline', '-Duncle.offline.demo=true') @('-m', 'com.unclezs.novel.app.main/com.unclezs.novel.app.main.App')
    Start-Sleep -Seconds 10
    $shots = Capture-All $proc.Id '离线主页与提示框'
    $logs = Log-Tail 40
    $results.offline = [ordered]@{
        pid = $proc.Id
        screenshots = $shots
        dialogLogged = ((($logs -join "`n") -match '离线提示框已弹出'))
        stateLogged = ((($logs -join "`n") -match 'CHECKING -> OFFLINE'))
    }
    Stop-App $proc
}
if ($Which -eq 'audio' -or $Which -eq 'all') {
    $proc = Start-App @('-Duncle.network.force=offline', '-Duncle.audio.force=unavailable', '-Duncle.audio.demo=true') @('-m', 'com.unclezs.novel.app.main/com.unclezs.novel.app.main.QuickApp', $quickFile)
    Start-Sleep -Seconds 12
    $shots = Capture-All $proc.Id '快速阅读与音频提示'
    $logs = Log-Tail 40
    $results.audio = [ordered]@{
        pid = $proc.Id
        screenshots = $shots
        dialogLogged = ((($logs -join "`n") -match '音频提示框已弹出'))
        offlineLogged = ((($logs -join "`n") -match 'CHECKING -> OFFLINE'))
    }
    Stop-App $proc
}
if ($Which -eq 'recovery' -or $Which -eq 'all') {
    $proc = Start-App @('-Duncle.network.probe.url=http://127.0.0.1:18080/') @('-m', 'com.unclezs.novel.app.main/com.unclezs.novel.app.main.App')
    Start-Sleep -Seconds 8
    $shots1 = Capture-All $proc.Id '联网前'
    # 用 TcpListener 模拟一个最小 HTTP 服务（标准用户无需 URLACL）
    $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 18080)
    try { $listener.Start() } catch { }
    $end = (Get-Date).AddSeconds(26)
    while ((Get-Date) -lt $end) {
        try {
            if ($listener.Pending()) {
                $client = $listener.AcceptTcpClient()
                $stream = $client.GetStream()
                $stream.ReadTimeout = 1000
                $buffer = New-Object byte[] 1024
                try { [void]$stream.Read($buffer, 0, $buffer.Length) } catch { }
                $body = [System.Text.Encoding]::ASCII.GetBytes('ok')
                $head = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Length: 2`r`nConnection: close`r`n`r`n")
                $stream.Write($head, 0, $head.Length)
                $stream.Write($body, 0, $body.Length)
                $stream.Flush()
                $client.Close()
            }
        } catch { }
        Start-Sleep -Milliseconds 150
    }
    try { $listener.Stop() } catch { }
    Start-Sleep -Seconds 2
    $logs = Log-Tail 80
    $shots2 = Capture-All $proc.Id '联网恢复后'
    $results.recovery = [ordered]@{
        pid = $proc.Id
        becameOnline = ((($logs -join "`n") -match 'OFFLINE -> ONLINE'))
        screenshotsBefore = $shots1
        screenshotsAfter = $shots2
    }
    Stop-App $proc
}
if ($Which -eq 'benchmark' -or $Which -eq 'all') {
    Get-Process javaw -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    $bench = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '..\构建\配置\benchmark.ps1') -InstallDir $InstallDir 2>&1 | Out-String
    $json = ''
    if ($bench -match '(?s)\{.*\}') { $json = $Matches[0] }
    $results.benchmark = [ordered]@{ raw = $bench.Trim(); parsed = $json }
}
$results | ConvertTo-Json -Depth 5
