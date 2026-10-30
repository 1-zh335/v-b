param(
    [string]$SourceRoot = '',
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\UncleNovel'),
    [string]$BuildRoot = 'C:\Temp\uq-build-offline',
    [string]$LombokPath = '',
    [string[]]$Classes = @('App.java','HotkeyManager.java','MixPanelHelper.java','ReaderView.java','TxtLoader.java','HomeView.java','SearchNovelView.java','SearchNetworkView.java','SearchAudioView.java','AnalysisView.java','AudioBookShelfView.java','FictionBookshelfView.java','RuleManagerView.java','DownloadManagerView.java'),
    [string[]]$PatchDirs = @(),
    [switch]$Clean,
    [switch]$PrepareOnly
)
$ErrorActionPreference = 'Stop'
$TaskRoot = Split-Path $PSScriptRoot -Parent
if (-not $SourceRoot) { $SourceRoot = 'C:\Users\31384\Documents\trae_projects\v b\任务-uncle-novel优化-2026-10-25\源码' }
if (-not $LombokPath) { $LombokPath = Join-Path $TaskRoot '工具\lombok.jar' }
if (-not $PatchDirs -or $PatchDirs.Count -eq 0) { $PatchDirs = @((Join-Path $TaskRoot '构建\patch-src'), (Join-Path $TaskRoot '构建\patch-src-views')) }
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Strip-Lombok([string]$path) {
    $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    $lines = $text -split "`r?`n"
    $out = New-Object System.Collections.Generic.List[string]
    $loggerInserted = $false
    $className = [System.IO.Path]::GetFileNameWithoutExtension($path)
    foreach ($line in $lines) {
        if ($line -match '^import\s+lombok') { continue }
        if ($line -match '^\s*@Slf4j\s*$') { continue }
        if (-not $loggerInserted -and $line -match '^\s*(public\s+)?(final\s+)?(abstract\s+)?class\s+\w+') {
            $out.Add($line)
            $out.Add('  private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger("' + $className + '");')
            $loggerInserted = $true
            continue
        }
        $out.Add($line)
    }
    $text = $out -join "`r`n"
    [System.IO.File]::WriteAllText($path, $text, $utf8)
}

function Find-Source([string]$simpleName) {
    $hits = Get-ChildItem $SourceRoot -Recurse -Filter $simpleName -File
    if (-not $hits) { throw "source not found: $simpleName" }
    return $hits[0].FullName
}

function Get-Package([string]$path) {
    $firstLine = Get-Content $path -TotalCount 8 -Encoding UTF8 | Where-Object { $_ -match '^\s*package\s+' } | Select-Object -First 1
    if (-not $firstLine) { throw "package not found: $path" }
    return ($firstLine -replace '^\s*package\s+', '' -replace '\s*;\s*$', '').Trim()
}

if ($Clean -and (Test-Path $BuildRoot)) { Remove-Item -Recurse -Force $BuildRoot }
$outDir = Join-Path $BuildRoot 'classes'
$patchSrc = Join-Path $BuildRoot 'patch-src'
New-Item -ItemType Directory -Force -Path $outDir, $patchSrc | Out-Null

# 1) 复制官方源码并去 lombok（成为可编译的补丁基座）
if ($Classes.Count -gt 0) {
    foreach ($cls in $Classes) {
        $orig = Find-Source $cls
        $pkg = Get-Package $orig
        $dest = Join-Path (Join-Path $patchSrc $pkg.Replace('.', '\')) $cls
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        Copy-Item $orig $dest -Force
        Strip-Lombok $dest
        Write-Host "[OK] 基座 $cls -> $dest"
    }
}

# 2) 叠加补丁 overlay（完整类文件，已去 lombok）
foreach ($dir in $PatchDirs) {
    if (-not (Test-Path $dir)) { Write-Host "[WARN] patch dir not found: $dir"; continue }
    Get-ChildItem $dir -Recurse -Filter *.java | ForEach-Object {
        $pkg = Get-Package $_.FullName
        $dest = Join-Path (Join-Path $patchSrc $pkg.Replace('.', '\')) $_.Name
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        Copy-Item $_.FullName $dest -Force
        Write-Host "[OK] overlay $($_.Name) <- $dir"
    }
}

if ($PrepareOnly) {
    Write-Host "[OK] 准备完成(未编译): $patchSrc"
    exit 0
}

# 3) 编译
$javac = Join-Path $InstallDir 'runtime\bin\javac.exe'
$modulePath = (Join-Path $InstallDir 'runtime\modules') + ';' + $LombokPath
$sources = @(Get-ChildItem $patchSrc -Recurse -Filter *.java | ForEach-Object { $_.FullName })
if ($sources.Count -eq 0) { throw 'no sources to compile' }
$argList = @('-encoding', 'UTF-8', '--module-path', $modulePath,
    '--patch-module', "com.unclezs.novel.app.main=$patchSrc",
    '-d', $outDir,
    '--add-exports=javafx.controls/com.sun.javafx.scene.control.skin=com.unclezs.novel.app.main',
    '--add-exports=javafx.graphics/com.sun.javafx.css=com.unclezs.novel.app.framework',
    '--add-exports=javafx.graphics/com.sun.javafx.stage=com.unclezs.novel.app.main,com.jfoenix',
    '--add-exports=javafx.graphics/com.sun.javafx.scene=com.jfoenix',
    '--add-exports=javafx.base/com.sun.javafx.binding=com.jfoenix',
    '--add-exports=javafx.base/com.sun.javafx.event=com.jfoenix',
    '--add-exports=javafx.controls/com.sun.javafx.scene.control.behavior=com.jfoenix',
    '--add-exports=javafx.controls/com.sun.javafx.scene.control=com.jfoenix',
    '--add-opens=com.jfoenix/com.jfoenix.controls=com.unclezs.novel.app.framework') + $sources
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $javac
$psi.Arguments = ($argList | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.StandardOutputEncoding = [System.Text.Encoding]::GetEncoding(936)
$psi.StandardErrorEncoding = [System.Text.Encoding]::GetEncoding(936)
$proc = [System.Diagnostics.Process]::Start($psi)
$stdout = $proc.StandardOutput.ReadToEnd()
$stderr = $proc.StandardError.ReadToEnd()
$proc.WaitForExit()
if ($stdout.Trim()) { Write-Host $stdout }
if ($stderr.Trim()) { Write-Host $stderr }
if ($proc.ExitCode -ne 0) { throw "javac failed: $($proc.ExitCode)" }

$classesOut = Get-ChildItem $outDir -Recurse -Filter *.class
Write-Host "[OK] 编译成功: $($classesOut.Count) 个 class 文件"
$classesOut | ForEach-Object { Write-Host ("  {0} ({1} B)" -f $_.FullName.Substring($outDir.Length).TrimStart('\'), $_.Length) }
exit 0
