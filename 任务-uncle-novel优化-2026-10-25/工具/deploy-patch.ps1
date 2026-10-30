param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\UncleNovel'),
    [string]$ClassesDir = 'C:\Temp\uq-build\classes',
    [string]$BackupDir = 'C:\Temp\uq-build\backup'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$jar = Join-Path $InstallDir 'runtime\modules\app.jar'
if (-not (Test-Path $jar)) { throw "app.jar not found: $jar" }
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
$backup = Join-Path $BackupDir 'app.jar.bak'
if (-not (Test-Path $backup)) {
    Copy-Item $jar $backup -Force
    Write-Host "[OK] 已备份原始 app.jar -> $backup"
} else {
    Write-Host "[OK] 使用已有备份: $backup"
}

$zip = [System.IO.Compression.ZipFile]::Open($jar, [System.IO.Compression.ZipArchiveMode]::Update)
$count = 0
Get-ChildItem $ClassesDir -Recurse -Filter *.class | ForEach-Object {
    $entryName = $_.FullName.Substring($ClassesDir.Length).TrimStart('\').Replace('\', '/')
    $existing = $zip.GetEntry($entryName)
    if ($existing) { $existing.Delete() }
    $entry = $zip.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
    $stream = $entry.Open()
    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Close()
    $count++
    Write-Host "  + $entryName"
}
$zip.Dispose()
Write-Host "[OK] 已写入 $count 个 class 到 $jar"

# 校验 jar 模块完整性
& (Join-Path $InstallDir 'runtime\bin\jar.exe') --describe-module --file $jar 2>&1 | Select-Object -First 3 | ForEach-Object { Write-Host $_ }
exit 0
