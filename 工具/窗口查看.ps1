param(
    [ValidateSet('List','Shot','Text','Tree','Activate','Invoke','Click','Send')]
    [string]$Action = 'List',
    [string]$Title = '',
    [int]$ProcId = 0,
    [string]$Out = '',
    [string]$Name = '',
    [switch]$Exact,
    [int]$X = -1,
    [int]$Y = -1,
    [string]$Keys = '',
    [int]$MaxText = 20000
)

# Generic desktop window inspector for DSH / Trae agents.
# ASCII-only source on purpose: avoids GBK/BOM encoding pitfalls (see AGENTS.md section 2).
# Actions:
#   List     - list visible top-level windows (HWND, PID, process, icon state, rect, title)
#   Shot     - capture one window to PNG via PrintWindow (works even when occluded), fallback to screen crop
#   Text     - extract unique visible text via UI Automation (read page/app content)
#   Tree     - dump UI Automation tree (control type / name / rect / supported patterns)
#   Activate - restore and bring the window to foreground
#   Invoke   - click a UI element by accessible name (Invoke/Toggle/Selection/Expand, else center click)
#   Click    - raw click at absolute screen coordinates
#   Send     - activate window then send keystrokes (SendKeys syntax)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class WinPeek {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr ctx);
    public struct RECT { public int L, T, R, B; }
    public static void MakeDpiAware() {
        try { SetProcessDpiAwarenessContext(new IntPtr(-4)); } catch { }
        try { SetProcessDPIAware(); } catch { }
    }
    public static List<IntPtr> TopWindows() {
        var list = new List<IntPtr>();
        EnumWindows((h, l) => { if (IsWindowVisible(h)) list.Add(h); return true; }, IntPtr.Zero);
        return list;
    }
    public static string WindowText(IntPtr h) {
        var sb = new StringBuilder(512);
        GetWindowText(h, sb, 512);
        return sb.ToString();
    }
    public static string ClassName(IntPtr h) {
        var sb = new StringBuilder(256);
        GetClassName(h, sb, 256);
        return sb.ToString();
    }
    public static int RectWidth(IntPtr h) {
        RECT r; GetWindowRect(h, out r); return r.R - r.L;
    }
    public static void ClickAt(int x, int y) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(120);
        mouse_event(0x0002, 0, 0, 0, IntPtr.Zero);
        System.Threading.Thread.Sleep(60);
        mouse_event(0x0004, 0, 0, 0, IntPtr.Zero);
    }
}
"@
[WinPeek]::MakeDpiAware()

function Get-VisibleWindows {
    $result = New-Object System.Collections.ArrayList
    foreach ($h in [WinPeek]::TopWindows()) {
        $title = [WinPeek]::WindowText($h)
        if ([string]::IsNullOrWhiteSpace($title)) { continue }
        $procId = 0
        [void][WinPeek]::GetWindowThreadProcessId($h, [ref]$procId)
        $procName = ''
        $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if ($p) { $procName = $p.ProcessName }
        $r = New-Object WinPeek+RECT
        [void][WinPeek]::GetWindowRect($h, [ref]$r)
        $obj = [PSCustomObject]@{
            Hwnd    = [int64]$h
            ProcId  = [int]$procId
            Process = $procName
            Iconic  = [WinPeek]::IsIconic($h)
            Left    = $r.L
            Top     = $r.T
            Width   = $r.R - $r.L
            Height  = $r.B - $r.T
            Title   = $title
            Class   = [WinPeek]::ClassName($h)
        }
        [void]$result.Add($obj)
    }
    return $result
}

function Normalize-WindowTitle([string]$s) {
    if ([string]::IsNullOrEmpty($s)) { return '' }
    # Some apps (e.g. Edge) put zero-width chars (U+200B/U+FEFF) inside titles; strip them before matching.
    $clean = $s -replace '[\u200B-\u200F\uFEFF]', ''
    $clean = $clean -replace '\s+', ' '
    return $clean.Trim()
}

function Resolve-TargetWindow {
    $wins = Get-VisibleWindows
    if ($ProcId -gt 0) {
        $cand = @($wins | Where-Object { $_.ProcId -eq $ProcId })
        if ($cand.Count -eq 0) { throw "No visible window for process id $ProcId" }
        return ($cand | Sort-Object Width -Descending | Select-Object -First 1)
    }
    if ([string]::IsNullOrWhiteSpace($Title)) { throw "Need -Title <substring> or -ProcId <pid>" }
    $needle = Normalize-WindowTitle $Title
    $cand = @($wins | Where-Object { (Normalize-WindowTitle $_.Title) -like "*$needle*" })
    if ($cand.Count -eq 0) { throw "No visible window whose title contains '$Title' (zero-width characters are normalized; try -ProcId)" }
    return ($cand | Sort-Object Width -Descending | Select-Object -First 1)
}

function Show-WindowInfo($w) {
    Write-Host ("[OK] window HWND={0} PID={1} process={2} iconic={3} rect={4},{5} {6}x{7}" -f $w.Hwnd, $w.ProcId, $w.Process, $w.Iconic, $w.Left, $w.Top, $w.Width, $w.Height)
    Write-Host ("     title=[{0}] class=[{1}]" -f $w.Title, $w.Class)
}

function Activate-Window($w) {
    $h = [IntPtr]$w.Hwnd
    [void][WinPeek]::ShowWindow($h, 9)
    [void][WinPeek]::BringWindowToTop($h)
    [void][WinPeek]::SetForegroundWindow($h)
    Start-Sleep -Milliseconds 350
    $fg = [WinPeek]::GetForegroundWindow()
    return ($fg -eq $h)
}

function Test-BlankBitmap($bmp) {
    $w = $bmp.Width; $h = $bmp.Height
    if ($w -lt 4 -or $h -lt 4) { return $true }
    $colors = New-Object System.Collections.Generic.HashSet[string]
    for ($i = 1; $i -le 8; $i++) {
        for ($j = 1; $j -le 8; $j++) {
            $px = $bmp.GetPixel([int]($w * $i / 9), [int]($h * $j / 9))
            [void]$colors.Add(("{0},{1},{2}" -f $px.R, $px.G, $px.B))
            if ($colors.Count -gt 2) { return $false }
        }
    }
    return ($colors.Count -le 1)
}

function Save-WindowShot($w) {
    # output dir name is the two CJK chars for 'screenshot', kept as escapes so the file stays ASCII-only
    $shotWord = [string][char]0x622A + [string][char]0x56FE
    $dir = Join-Path $PSScriptRoot $shotWord
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if ([string]::IsNullOrWhiteSpace($Out)) {
        $safe = ($w.Title -replace '[\\/:*?"<>|]', '_')
        if ($safe.Length -gt 40) { $safe = $safe.Substring(0, 40) }
        $Out = Join-Path $dir ('window-' + $safe + '-' + (Get-Date -Format 'HHmmss') + '.png')
    } else {
        $parent = Split-Path -Parent $Out
        if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    }
    $h = [IntPtr]$w.Hwnd
    $width = $w.Width
    $height = $w.Height
    $mode = 'PrintWindow'
    if ($width -lt 4 -or $height -lt 4) { throw "Bad window rect: $width x $height" }
    $bmp = New-Object System.Drawing.Bitmap $width, $height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    $ok = [WinPeek]::PrintWindow($h, $hdc, 2)
    $g.ReleaseHdc($hdc)
    $g.Dispose()
    if ((-not $ok) -or (Test-BlankBitmap $bmp)) {
        $bmp.Dispose()
        $mode = 'ScreenCrop'
        [void](Activate-Window $w)
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $x1 = [Math]::Max(0, $w.Left); $y1 = [Math]::Max(0, $w.Top)
        $x2 = [Math]::Min($screen.Width, $w.Left + $w.Width)
        $y2 = [Math]::Min($screen.Height, $w.Top + $w.Height)
        $cw = $x2 - $x1; $ch = $y2 - $y1
        if ($cw -lt 4 -or $ch -lt 4) { throw "Window is outside the screen or minimized; capture failed" }
        $bmp = New-Object System.Drawing.Bitmap $cw, $ch
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($x1, $y1, 0, 0, (New-Object System.Drawing.Size $cw, $ch))
        $g.Dispose()
    }
    $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host ("[OK] screenshot saved ({0}) {1} ({2} bytes)" -f $mode, $Out, (Get-Item $Out).Length)
    Write-Host "NOTE: open it with read_image before drawing any conclusion."
}

function Get-UiaElements($w) {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle([IntPtr]$w.Hwnd)
    if (-not $root) { throw "UI Automation cannot resolve the window" }
    return @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition))
}

function Show-UiaText($w) {
    $elements = Get-UiaElements $w
    $seen = New-Object System.Collections.Generic.HashSet[string]
    $lines = New-Object System.Collections.ArrayList
    $total = 0
    foreach ($e in $elements) {
        $c = $e.Current
        $n = ($c.Name -replace "`r?`n", ' ').Trim()
        if ([string]::IsNullOrWhiteSpace($n)) { continue }
        if (-not $seen.Add($n)) { continue }
        $line = ('[{0}] {1}' -f $c.ControlType.ProgrammaticName.Replace('ControlType.', ''), $n)
        [void]$lines.Add($line)
        $total += $line.Length
        if ($total -ge $MaxText) { [void]$lines.Add('... [truncated]'); break }
    }
    if ([string]::IsNullOrWhiteSpace($Out)) {
        $lines | ForEach-Object { Write-Host $_ }
    } else {
        $parent = Split-Path -Parent $Out
        if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
        $lines | Set-Content -LiteralPath $Out -Encoding UTF8
        Write-Host ("[OK] text saved: {0} ({1} lines)" -f $Out, $lines.Count)
    }
    Write-Host ("[OK] extracted {0} unique text items from window [{1}]" -f $lines.Count, $w.Title)
}

function Show-UiaTree($w) {
    $elements = Get-UiaElements $w
    $i = 0
    $lines = New-Object System.Collections.ArrayList
    foreach ($e in $elements) {
        $i++
        $c = $e.Current
        $r = $c.BoundingRectangle
        $patterns = @($e.GetSupportedPatterns() | ForEach-Object { $_.ProgrammaticName.Replace('PatternIdentifiers.Pattern', '') })
        $line = ('{0,4} {1,-24} [{2,-30}] @{3},{4} {5}x{6} enabled={7} pats={8}' -f `
            $i, $c.ControlType.ProgrammaticName.Replace('ControlType.', ''), (($c.Name -replace "`r?`n", ' ').Trim()), `
            $r.X, $r.Y, $r.Width, $r.Height, $c.IsEnabled, ($patterns -join '|'))
        [void]$lines.Add($line)
    }
    if ([string]::IsNullOrWhiteSpace($Out)) {
        $lines | ForEach-Object { Write-Host $_ }
    } else {
        $lines | Set-Content -LiteralPath $Out -Encoding UTF8
        Write-Host ("[OK] tree saved: {0} ({1} elements)" -f $Out, $lines.Count)
    }
}

function Invoke-UiaTarget($w) {
    $elements = Get-UiaElements $w
    $matches = New-Object System.Collections.ArrayList
    foreach ($e in $elements) {
        $n = $e.Current.Name
        if ([string]::IsNullOrWhiteSpace($n)) { continue }
        if ($Exact) {
            if ($n -eq $Name) { [void]$matches.Add($e) }
        } else {
            if ($n -like "*$Name*") { [void]$matches.Add($e) }
        }
    }
    if ($matches.Count -eq 0) { throw "No element name matches '$Name'" }
    $target = $matches[0]
    $c = $target.Current
    Write-Host ("[OK] target: [{0}] name=[{1}] rect={2},{3} {4}x{5}" -f $c.ControlType.ProgrammaticName.Replace('ControlType.', ''), $c.Name, $c.BoundingRectangle.X, $c.BoundingRectangle.Y, $c.BoundingRectangle.Width, $c.BoundingRectangle.Height)
    $clicked = $false
    foreach ($pattern in @([System.Windows.Automation.InvokePattern]::Pattern, [System.Windows.Automation.TogglePattern]::Pattern, [System.Windows.Automation.SelectionItemPattern]::Pattern, [System.Windows.Automation.ExpandCollapsePattern]::Pattern)) {
        $obj = $null
        if ($target.TryGetCurrentPattern($pattern, [ref]$obj)) {
            try {
                if ($pattern -eq [System.Windows.Automation.InvokePattern]::Pattern) { $obj.Invoke() }
                elseif ($pattern -eq [System.Windows.Automation.TogglePattern]::Pattern) { $obj.Toggle() }
                elseif ($pattern -eq [System.Windows.Automation.SelectionItemPattern]::Pattern) { $obj.Select() }
                else { $obj.Expand() }
                Write-Host ("[OK] invoked via {0}" -f $pattern.ProgrammaticName)
                $clicked = $true
                break
            } catch {
                Write-Host ("[WARN] pattern {0} failed: {1}" -f $pattern.ProgrammaticName, $_.Exception.Message)
            }
        }
    }
    if (-not $clicked) {
        [void](Activate-Window $w)
        $br = $c.BoundingRectangle
        if ([double]::IsInfinity($br.X) -or [double]::IsNaN($br.X)) { throw "Element is offscreen; cannot click by coordinates (use -Action Tree to inspect)" }
        $cx = [int]($br.X + $br.Width / 2)
        $cy = [int]($br.Y + $br.Height / 2)
        [WinPeek]::ClickAt($cx, $cy)
        Write-Host ("[OK] fallback center click at {0},{1}" -f $cx, $cy)
    }
    Start-Sleep -Milliseconds 800
    Write-Host "[OK] action done; take a fresh Shot to verify the result"
}

switch ($Action) {
    'List' {
        $wins = Get-VisibleWindows
        Write-Host ("{0,8} {1,7} {2,-22} {3,-6} {4,-4} {5,8} {6,10}  {7}" -f 'HWND', 'PID', 'PROCESS', 'ICONIC', 'CLS', 'RECT', 'SIZE', 'TITLE')
        foreach ($w in ($wins | Sort-Object Process, Title)) {
            Write-Host ("{0,8} {1,7} {2,-22} {3,-6} {4,-4} {5,8} {6,10}  {7}" -f $w.Hwnd, $w.ProcId, $w.Process, $w.Iconic, '', ("{0},{1}" -f $w.Left, $w.Top), ("{0}x{1}" -f $w.Width, $w.Height), $w.Title)
        }
        Write-Host ("[OK] {0} visible windows listed" -f $wins.Count)
    }
    'Shot' {
        $w = Resolve-TargetWindow
        Show-WindowInfo $w
        Save-WindowShot $w
    }
    'Text' {
        $w = Resolve-TargetWindow
        Show-WindowInfo $w
        Show-UiaText $w
    }
    'Tree' {
        $w = Resolve-TargetWindow
        Show-WindowInfo $w
        Show-UiaTree $w
    }
    'Activate' {
        $w = Resolve-TargetWindow
        Show-WindowInfo $w
        $ok = Activate-Window $w
        Write-Host ("[OK] activated={0} foreground match={1}" -f $ok, ([WinPeek]::GetForegroundWindow() -eq [IntPtr]$w.Hwnd))
    }
    'Invoke' {
        $w = Resolve-TargetWindow
        Show-WindowInfo $w
        Invoke-UiaTarget $w
    }
    'Click' {
        if ($X -lt 0 -or $Y -lt 0) { throw "Click needs -X <screenX> -Y <screenY>" }
        [WinPeek]::ClickAt($X, $Y)
        Write-Host ("[OK] clicked {0},{1}" -f $X, $Y)
    }
    'Send' {
        $w = Resolve-TargetWindow
        Show-WindowInfo $w
        [void](Activate-Window $w)
        [System.Windows.Forms.SendKeys]::SendWait($Keys)
        Write-Host ("[OK] sent keys: {0}" -f $Keys)
    }
}
