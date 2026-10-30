param(
    [int]$Port = 9222,
    [string]$Url = 'about:blank',
    [switch]$Headless,
    [string]$ProfileDir = '',
    [string]$EdgePath = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    [int]$WaitSec = 25,
    [switch]$Stop
)

# Start Microsoft Edge with remote debugging (CDP) enabled, in an isolated profile.
# ASCII-only source on purpose (see AGENTS.md section 2).
# Default profile: %LOCALAPPDATA%\DSH\edge-automation-profile
# The debug port binds to 127.0.0.1 only; CDP has no auth, keep it local and stop when done.

$ErrorActionPreference = 'Stop'

function Get-CdpVersion([int]$p) {
    try {
        return Invoke-RestMethod -Uri ("http://127.0.0.1:{0}/json/version" -f $p) -UseBasicParsing -TimeoutSec 2
    } catch {
        return $null
    }
}

if ($Stop) {
    $conn = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $conn) {
        Write-Host ("[OK] nothing listening on 127.0.0.1:{0}" -f $Port)
        exit 0
    }
    $ownerPid = $conn.OwningProcess
    Write-Host ("[INFO] stopping Edge CDP instance (pid {0}) ..." -f $ownerPid)
    & taskkill /PID $ownerPid /T /F | Out-Null
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 500
        if (-not (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)) {
            Write-Host ("[OK] stopped; port {0} closed" -f $Port)
            exit 0
        }
    }
    Write-Host ("[FAIL] port {0} still listening after stop" -f $Port)
    exit 1
}

$existing = Get-CdpVersion $Port
if ($existing) {
    Write-Host ("[OK] CDP already ready at 127.0.0.1:{0} (reusing running instance)" -f $Port)
    Write-Host ("     Browser: {0}" -f $existing.Browser)
    Write-Host ("     WebSocket: {0}" -f $existing.webSocketDebuggerUrl)
    exit 0
}

if (-not (Test-Path -LiteralPath $EdgePath)) {
    Write-Host ("[FAIL] Edge not found: {0}" -f $EdgePath)
    exit 1
}

if ([string]::IsNullOrWhiteSpace($ProfileDir)) {
    $ProfileDir = Join-Path $env:LOCALAPPDATA 'DSH\edge-automation-profile'
}
New-Item -ItemType Directory -Force -Path $ProfileDir | Out-Null

$edgeArgs = New-Object System.Collections.ArrayList
if ($Headless) {
    [void]$edgeArgs.Add('--headless=new')
    [void]$edgeArgs.Add('--disable-gpu')
    [void]$edgeArgs.Add('--hide-scrollbars')
}
[void]$edgeArgs.Add(("--remote-debugging-port={0}" -f $Port))
[void]$edgeArgs.Add(("--user-data-dir={0}" -f $ProfileDir))
[void]$edgeArgs.Add('--no-first-run')
[void]$edgeArgs.Add('--no-default-browser-check')
[void]$edgeArgs.Add('--disable-sync')
[void]$edgeArgs.Add('--disable-background-networking')
[void]$edgeArgs.Add($Url)
$quoted = @($edgeArgs | ForEach-Object { if ("$_" -match '\s') { '"' + $_ + '"' } else { $_ } })

Write-Host ("[INFO] launching Edge (headless={0})" -f [bool]$Headless)
Write-Host ("[INFO] profile: {0}" -f $ProfileDir)
Write-Host ("[INFO] user-data-dir is isolated; your daily Edge profile is NOT touched" )
$proc = Start-Process -FilePath $EdgePath -ArgumentList $quoted -PassThru

$deadline = (Get-Date).AddSeconds($WaitSec)
$version = $null
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
    $version = Get-CdpVersion $Port
    if ($version) { break }
}

if (-not $version) {
    Write-Host ("[FAIL] CDP not ready after {0}s (Edge pid {1})" -f $WaitSec, $proc.Id)
    exit 1
}

Write-Host ("[OK] Edge CDP ready at 127.0.0.1:{0} (pid {1})" -f $Port, $proc.Id)
Write-Host ("     Browser: {0}" -f $version.Browser)
Write-Host ("     WebSocket: {0}" -f $version.webSocketDebuggerUrl)
Write-Host ("     Profile: {0}" -f $ProfileDir)
Write-Host ("     Next: node browser.mjs status --port {0}   (run from {1})" -f $Port, (Split-Path -Parent $PSCommandPath))
exit 0
