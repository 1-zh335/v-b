param(
    [ValidateSet('full','quick')][string]$Mode = 'full',
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\UncleNovel'),
    [string]$InputFile = '',
    [string]$OutDir = '',
    [switch]$ForceOffline,
    [switch]$ForceOnline,
    [switch]$NoAudio,
    [switch]$ClickSearch,
    [switch]$TestBossKey,
    [switch]$TestTtsDialog,
    [int]$RecoverySeconds = 0,
    [int]$ProbePort = 18080,
    [int]$WaitSeconds = 15
)
$ErrorActionPreference = 'Stop'
if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '..\截图\自动测试' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -ReferencedAssemblies @('System.Drawing') -TypeDefinition @"
using System;
using System.Text;
using System.Drawing;
using System.Runtime.InteropServices;
public class GuiWin {
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
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    public static void Aware() { try { SetThreadDpiAwarenessContext(new IntPtr(-4)); } catch { } }
    public static void Activate(IntPtr h) { try { Aware(); ShowWindow(h, 9); SetForegroundWindow(h); } catch { } }
    public static IntPtr[] WindowsOf(int pid) {
        Aware();
        var list = new System.Collections.Generic.List<IntPtr>();
        EnumWindows((h, l) => {
            uint p; GetWindowThreadProcessId(h, out p);
            if ((int)p == pid) { list.Add(h); }
            return true;
        }, IntPtr.Zero);
        return list.ToArray();
    }
    public static IntPtr MainWindow(int pid) {
        Aware();
        IntPtr best = IntPtr.Zero; long area = 0;
        foreach (var h in WindowsOf(pid)) {
            if (!IsWindowVisible(h)) { continue; }
            var cls = Cls(h);
            if (cls.StartsWith("GlassWndClass")) {
                RECT r; GetWindowRect(h, out r);
                long a = (long)(r.R - r.L) * (r.B - r.T);
                if (a > area) { area = a; best = h; }
            }
        }
        return best;
    }
    public static string Title(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
    public static string Cls(IntPtr h) { var sb = new StringBuilder(256); GetClassName(h, sb, 256); return sb.ToString(); }
    public static bool Visible(IntPtr h) { return IsWindowVisible(h); }
    public static void PressAltU() {
        keybd_event(0x12, 0, 0, UIntPtr.Zero); System.Threading.Thread.Sleep(80);
        keybd_event(0x55, 0, 0, UIntPtr.Zero); System.Threading.Thread.Sleep(80);
        keybd_event(0x55, 0, 2, UIntPtr.Zero); System.Threading.Thread.Sleep(80);
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
    try {
        $bmp = [GuiWin]::Capture($hwnd)
        if ($bmp) { $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose(); return $true }
    } catch { }
    return $false
}
function Get-UiTexts([IntPtr]$hwnd) {
    $result = @()
    try {
        $el = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
        if (-not $el) { return @() }
        $all = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        foreach ($e in $all) {
            $n = $e.Current.Name
            if ($n) { $result += $n }
        }
    } catch { }
    return $result
}
function Invoke-Button([IntPtr]$hwnd, [string]$name) {
    try {
        $el = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
        $cond = New-Object System.Windows.Automation.AndCondition(
            (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty), [System.Windows.Automation.ControlType]::Button),
            (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty), $name))
        $btn = $el.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
        if (-not $btn) { return $false }
        ($btn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke()
        return $true
    } catch { return $false }
}
function Get-DialogInfos([int]$targetPid) {
    $infos = @()
    foreach ($h in [GuiWin]::WindowsOf($targetPid)) {
        if (-not [GuiWin]::Visible($h)) { continue }
        $cls = [GuiWin]::Cls($h)
        if ($cls -notlike 'GlassWndClass*') { continue }
        $texts = Get-UiTexts $h
        $r = [GuiWin]::Capture($h)
        $w = 0; if ($r) { $w = $r.Width; $r.Dispose() }
        $infos += [ordered]@{ hwnd = $h.ToInt64(); cls = $cls; width = $w; texts = @($texts | Select-Object -First 30) }
    }
    return $infos
}
function Get-OtherWindows([int]$targetPid, [IntPtr]$mainHwnd) {
    $list = @()
    foreach ($h in [GuiWin]::WindowsOf($targetPid)) {
        if (-not [GuiWin]::Visible($h)) { continue }
        if ($h -eq $mainHwnd) { continue }
        if ([GuiWin]::Cls($h) -notlike 'GlassWndClass*') { continue }
        $list += $h
    }
    return $list
}
function Close-Window([IntPtr]$hwnd) {
    try { [void][GuiWin]::PostMessage($hwnd, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) } catch { }
}
$javaw = Join-Path $InstallDir 'runtime\bin\javaw.exe'
if (-not (Test-Path $javaw)) { throw "javaw not found: $javaw" }
Get-Process javaw -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process 'Uncle小说' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
$flags = @()
if ($ForceOffline) { $flags += '-Duncle.network.force=offline' }
if ($ForceOnline) { $flags += '-Duncle.network.force=online' }
if ($NoAudio) { $flags += '-Duncle.audio.force=unavailable' }
if ($RecoverySeconds -gt 0) { $flags += ('-Duncle.network.probe.url=http://127.0.0.1:' + $ProbePort + '/') }
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
) + $flags
if ($Mode -eq 'full') {
    $args = $common + @('-m', 'com.unclezs.novel.app.main/com.unclezs.novel.app.main.App')
} else {
    if (-not $InputFile) { $InputFile = Get-ChildItem 'C:\Users\31384\Documents\trae_projects\v b\素材' -Filter '*.txt' | Select-Object -First 1 -ExpandProperty FullName }
    $args = $common + @('-m', 'com.unclezs.novel.app.main/com.unclezs.novel.app.main.QuickApp', $InputFile)
}
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $javaw
$psi.Arguments = ($args | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
$psi.WorkingDirectory = $InstallDir
$psi.UseShellExecute = $false
$proc = [System.Diagnostics.Process]::Start($psi)
$hwnd = [IntPtr]::Zero
$readySw = [System.Diagnostics.Stopwatch]::StartNew()
while ($readySw.Elapsed.TotalSeconds -lt $WaitSeconds) {
    Start-Sleep -Milliseconds 500
    $hwnd = [GuiWin]::MainWindow($proc.Id)
    if ($hwnd -ne [IntPtr]::Zero) { break }
}
if ($hwnd -ne [IntPtr]::Zero) { [GuiWin]::Activate($hwnd) }
$uiTexts = @()
for ($i = 0; $i -lt 20; $i++) {
    $uiTexts = Get-UiTexts $hwnd
    if ($uiTexts.Count -gt 5) { break }
    Start-Sleep -Seconds 1
}
$windows = @()
foreach ($h in [GuiWin]::WindowsOf($proc.Id)) {
    $windows += [ordered]@{ hwnd = $h.ToInt64(); title = [GuiWin]::Title($h); cls = [GuiWin]::Cls($h); visible = [GuiWin]::Visible($h) }
}
$titleOffline = (@($uiTexts | Where-Object { $_ -match '离线' }).Count -gt 0)
$shotStart = Save-Shot $hwnd (Join-Path $OutDir '01-启动后.png')
$searchClicked = $false
$shotDialog = $false
$dialogInfos = @()
if ($ClickSearch) {
    [GuiWin]::Activate($hwnd)
    Start-Sleep -Milliseconds 600
    $searchClicked = Invoke-Button $hwnd '搜索小说'
    Start-Sleep -Seconds 2
    # 输入关键词并回车，触发真正的搜索（离线时弹出拦截框）
    $el3 = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
    $editCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty), [System.Windows.Automation.ControlType]::Edit
    $edit = $el3.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $editCond)
    if ($edit) {
        try { ($edit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)).SetValue('测试搜索') } catch { }
        [GuiWin]::Activate($hwnd)
        Start-Sleep -Milliseconds 400
        [void][GuiWin]::PostMessage($hwnd, 0x0100, [IntPtr]0x0D, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 80
        [void][GuiWin]::PostMessage($hwnd, 0x0101, [IntPtr]0x0D, [IntPtr]::Zero)
    }
    Start-Sleep -Seconds 3
    foreach ($dlg in (Get-OtherWindows $proc.Id $hwnd)) {
        if (Save-Shot $dlg (Join-Path $OutDir '02-离线提示框.png')) { $shotDialog = $true }
        $dialogInfos += [ordered]@{ hwnd = $dlg.ToInt64(); texts = @() }
        Close-Window $dlg
    }
    Start-Sleep -Seconds 1
}
$boss = [ordered]@{ pressed = $false; visibleAfterHide = $null; visibleAfterRestore = $null }
if ($TestBossKey) {
    [GuiWin]::PressAltU()
    Start-Sleep -Seconds 2
    $boss.pressed = $true
    $anyVisible = $false
    foreach ($h2 in [GuiWin]::WindowsOf($proc.Id)) {
        if ([GuiWin]::Visible($h2) -and ([GuiWin]::Cls($h2) -like 'GlassWndClass*')) { $anyVisible = $true }
    }
    $boss.visibleAfterHide = $anyVisible
    [GuiWin]::PressAltU()
    Start-Sleep -Seconds 2
    $restoredVisible = $false
    foreach ($h2 in [GuiWin]::WindowsOf($proc.Id)) {
        if ([GuiWin]::Visible($h2) -and ([GuiWin]::Cls($h2) -like 'GlassWndClass*')) { $restoredVisible = $true; $hwnd = $h2; break }
    }
    $boss.visibleAfterRestore = $restoredVisible
    $null = Save-Shot $hwnd (Join-Path $OutDir '03-老板键恢复后.png')
}
$tts = [ordered]@{ tried = $false; openedSettings = $false; clickedSpeak = $false; audioDialog = $false; dialogTexts = @() }
if ($TestTtsDialog) {
    $tts.tried = $true
    [GuiWin]::Activate($hwnd)
    Start-Sleep -Milliseconds 500
    $el = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
    $buttons = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants,
        (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty), [System.Windows.Automation.ControlType]::Button))
    foreach ($b in $buttons) {
        try {
            $r = $b.Current.BoundingRectangle
            if ($r.Y -ge 100 -or $r.Width -lt 8) { continue }
            ($b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke()
            Start-Sleep -Milliseconds 900
            $el2 = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
            $speakCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty), '朗读'
            $speak = $el2.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $speakCond)
            if ($speak) {
                $tts.openedSettings = $true
                ($speak.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke()
                $tts.clickedSpeak = $true
                break
            }
        } catch { }
    }
    Start-Sleep -Seconds 3
    foreach ($dlg in (Get-OtherWindows $proc.Id $hwnd)) {
        if (Save-Shot $dlg (Join-Path $OutDir '05-音频不可用提示框.png')) {
            $tts.audioDialog = $true
        }
        Close-Window $dlg
    }
    $tts.dialogTexts = @('见 05-音频不可用提示框.png（截图目检）')
}
$recovery = [ordered]@{ started = $false; titleOfflineAfter = $null; logHasOnline = $false }
if ($RecoverySeconds -gt 0) {
    $recovery.started = $true
    $listener = New-Object System.Net.HttpListener
    $prefix = 'http://127.0.0.1:' + $ProbePort + '/'
    $listener.Prefixes.Add($prefix)
    try { $listener.Start() } catch { }
    $end = (Get-Date).AddSeconds($RecoverySeconds)
    while ((Get-Date) -lt $end) {
        if ($listener.IsListening) {
            try {
                $ctx = $listener.GetContext()
                $bytes = [System.Text.Encoding]::UTF8.GetBytes('ok')
                $ctx.Response.StatusCode = 200
                $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
                $ctx.Response.OutputStream.Close()
            } catch { }
        }
        Start-Sleep -Milliseconds 200
    }
    try { $listener.Stop(); $listener.Close() } catch { }
    Start-Sleep -Seconds 2
    $hwnd = [GuiWin]::MainWindow($proc.Id)
    $texts2 = Get-UiTexts $hwnd
    $recovery.titleOfflineAfter = (@($texts2 | Where-Object { $_ -match '离线' }).Count -gt 0)
    $logFile = Join-Path $InstallDir 'logs\log-system.log'
    if (Test-Path $logFile) { $recovery.logHasOnline = (((Get-Content $logFile -Encoding UTF8 -Tail 80) -join "`n") -match 'OFFLINE -> ONLINE') }
    $null = Save-Shot $hwnd (Join-Path $OutDir '04-联网恢复后.png')
}
$logFile = Join-Path $InstallDir 'logs\log-system.log'
$logTail = @()
if (Test-Path $logFile) { $logTail = @(Get-Content $logFile -Encoding UTF8 -Tail 20 | ForEach-Object { [string]$_ }) }
$rss = 0
try { $proc.Refresh(); $rss = [math]::Round($proc.WorkingSet64 / 1MB, 1) } catch { }
$result = [ordered]@{
    mode = $Mode
    pid = $proc.Id
    windowTitle = [GuiWin]::Title($hwnd)
    uiTextCount = $uiTexts.Count
    titleOffline = $titleOffline
    windows = $windows
    searchClicked = $searchClicked
    dialogCount = $dialogInfos.Count
    dialogOfflineHint = ($dialogInfos.Count -gt 0)
    dialogTexts = @($dialogInfos | ForEach-Object { $_.texts } | Select-Object -First 20)
    bossKey = $boss
    tts = $tts
    recovery = $recovery
    shotStart = $shotStart
    shotDialog = $shotDialog
    rssMB = $rss
    logTail = $logTail
}
Get-Process -Id $proc.Id -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$result | ConvertTo-Json -Depth 6
