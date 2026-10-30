param(
    [Parameter(Mandatory=$true)][string]$CacheDir,
    [Parameter(Mandatory=$true)][string]$OutFile,
    [switch]$Gbk
)
# 旧版 Uncle小说 4.x 缓存书籍恢复脚本
# 用法示例：
#   powershell -NoProfile -ExecutionPolicy Bypass -File 恢复旧版书籍.ps1 `
#     -CacheDir "C:\旧版目录\cache\9ad2a359188349248f78692a06490562" `
#     -OutFile  "D:\大王饶命-恢复.txt"
#   -Gbk 可选：输出 GBK 编码（若新版导入后乱码可改用此模式）
$ErrorActionPreference = 'Stop'
$bookJson = Join-Path $CacheDir 'book.json'
if (-not (Test-Path -LiteralPath $bookJson)) {
    Write-Host "[X] 找不到 $bookJson"
    exit 1
}
$chapters = Get-Content -LiteralPath $bookJson -Raw -Encoding UTF8 | ConvertFrom-Json
$sb = New-Object System.Text.StringBuilder
$ok = 0
$missing = 0
foreach ($ch in $chapters) {
    $name = [string]$ch.name
    $path = [string]$ch.contentPath
    if ([string]::IsNullOrWhiteSpace($path)) { $missing++; continue }
    # 旧版记录的是绝对路径，统一改用当前 CacheDir 下的同名文件
    $file = Join-Path $CacheDir (Split-Path -Leaf $path)
    if (-not (Test-Path -LiteralPath $file)) { $missing++; continue }
    [void]$sb.AppendLine($name.Trim())
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine((Get-Content -LiteralPath $file -Raw -Encoding UTF8))
    [void]$sb.AppendLine('')
    $ok++
}
$text = $sb.ToString()
$enc = if ($Gbk) { [System.Text.Encoding]::GetEncoding(936) } else { New-Object System.Text.UTF8Encoding($false) }
[System.IO.File]::WriteAllText($OutFile, $text, $enc)
$sizeKb = [math]::Round((Get-Item -LiteralPath $OutFile).Length / 1KB, 1)
Write-Host "[OK] 已恢复 $ok 章（缺失 $missing 章）→ $OutFile（$sizeKb KB，$(if ($Gbk) {'GBK'} else {'UTF-8'})）"
exit 0
