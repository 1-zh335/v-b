param(
    [Parameter(Mandatory=$true)][ValidateSet('launch','activate','click','key','shot','dump')]
    [string]$Action,
    [int]$TargetPid = -1,
    [string]$Exe = '',
    [string]$WorkDir = '',
    [int]$X = 0,
    [int]$Y = 0,
    [int]$Vk = 0,
    [string]$OutDir = ''
)
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class GuiAct {
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr p);
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    public static IntPtr FindMain(int pid) {
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
    public static bool Activate(IntPtr h) {
        ShowWindow(h, 9);
        BringWindowToTop(h);
        if (SetForegroundWindow(h)) return true;
        IntPtr fg = GetForegroundWindow();
        if (fg == IntPtr.Zero) return false;
        uint fgPid; uint fgThread = GetWindowThreadProcessId(fg, out fgPid);
        uint myThread = GetCurrentThreadId();
        if (AttachThreadInput(myThread, fgThread, true)) {
            bool ok = SetForegroundWindow(h);
            AttachThreadInput(myThread, fgThread, false);
            return ok;
        }
        return false;
    }
    public static void Click(int x, int y) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(200);
        mouse_event(0x0002, 0, 0, 0, IntPtr.Zero);
        System.Threading.Thread.Sleep(80);
        mouse_event(0x0004, 0, 0, 0, IntPtr.Zero);
    }
    public static void Key(IntPtr h, int vk) {
        PostMessage(h, 0x0100, (IntPtr)vk, IntPtr.Zero);
        System.Threading.Thread.Sleep(80);
        PostMessage(h, 0x0101, (IntPtr)vk, IntPtr.Zero);
    }
}
"@

function Get-AppWindow([int]$procId) {
    $uia = [System.Windows.Automation.AutomationElement]::RootElement
    $cond = New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::ProcessIdProperty), $procId
    return $uia.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
}
function Save-Shot([string]$path) {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen(0,0,0,0,(New-Object System.Drawing.Size $b.Width,$b.Height))
    $g.Dispose(); $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    Write-Host "SHOT: $path"
}

if ($Action -eq 'launch') {
    $p = Start-Process -FilePath $Exe -WorkingDirectory $WorkDir -PassThru
    Write-Host "PID: $($p.Id)"
    exit 0
}
if ($TargetPid -le 0) { throw 'TargetPid required' }
if ($Action -eq 'activate') {
    $hwnd = [GuiAct]::FindMain($TargetPid)
    Write-Host "HWND: $hwnd"
    $ok = [GuiAct]::Activate($hwnd)
    $fg = [GuiAct]::GetForegroundWindow()
    Write-Host "Activate=$ok Foreground=$fg Match=$($fg -eq $hwnd)"
    exit 0
}
if ($Action -eq 'click') {
    [GuiAct]::Click($X, $Y)
    Write-Host "Clicked ($X,$Y)"
    Start-Sleep -Milliseconds 800
    exit 0
}
if ($Action -eq 'key') {
    $hwnd = [GuiAct]::FindMain($TargetPid)
    [void][GuiAct]::Activate($hwnd)
    [GuiAct]::Key($hwnd, $Vk)
    Write-Host "Key sent: $Vk"
    exit 0
}
if ($Action -eq 'shot') {
    if (-not $OutDir) { $OutDir = '.' }
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    Save-Shot (Join-Path $OutDir ("shot-" + (Get-Date -Format 'HHmmss') + ".png"))
    exit 0
}
if ($Action -eq 'dump') {
    $win = Get-AppWindow $TargetPid
    if (-not $win) { Write-Host 'NO_WINDOW'; exit 1 }
    $all = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    $i = 0
    foreach ($e in $all) {
        $i++
        $ct = $e.Current.ControlType.ProgrammaticName
        $nm = ($e.Current.Name -replace "`r?`n", ' ')
        $r = $e.Current.BoundingRectangle
        if ($nm -or $ct -match 'Edit|Button|ComboBox|Text') {
            Write-Host ("{0}`t{1}`t[{2}]`t{3},{4} {5}x{6}" -f $i, $ct, $nm, [int]$r.X, [int]$r.Y, [int]$r.Width, [int]$r.Height)
        }
    }
    exit 0
}
