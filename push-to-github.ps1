# ============================================================
# v b 工作区 -> GitHub 一键上传脚本
# 用法：双击 push-to-github.bat 运行本脚本
# 令牌只在运行时输入（不可见），不写入任何文件；
# 成功后令牌存入系统凭据管理器，之后 git push 无需再输入。
# ============================================================

$ErrorActionPreference = 'Stop'
$git = 'C:\Program Files\Git\cmd\git.exe'
if (-not (Test-Path -LiteralPath $git)) { $git = 'git' }

# ---- 可按需修改的参数 ----
$repoName = 'v-b'          # GitHub 仓库名（不能含空格）
$repoPrivate = $false      # $true = 私有, $false = 公开
# ---------------------------

$ws = Split-Path -Parent $PSCommandPath
Set-Location -LiteralPath $ws

Write-Host '=== v b 工作区 -> GitHub 一键上传 ===' -ForegroundColor Cyan
Write-Host ('工作区: ' + $ws)

if ($repoPrivate) { $visibility = '私有' } else { $visibility = '公开' }
Write-Host ('目标仓库: ' + $repoName + '（' + $visibility + '）')

Write-Host ''
Write-Host '请先在手机/电脑浏览器登录 GitHub 生成个人访问令牌（Token, classic）：'
Write-Host '  1) 打开 https://github.com/settings/tokens'
Write-Host '  2) Generate new token -> Tokens (classic)'
Write-Host '  3) Note 随意（如 dsh-upload），Scopes 勾选 repo，期限 30 天'
Write-Host '  4) 生成后复制 ghp_ 开头的完整令牌'
Write-Host ''
$secure = Read-Host '请把令牌粘贴到这里（输入时不可见，粘贴后回车）' -AsSecureString
if ($secure.Length -eq 0) {
    Write-Host '未输入令牌，已取消。' -ForegroundColor Yellow
    exit 1
}
$token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
$headers = @{ Authorization = 'Bearer ' + $token; 'User-Agent' = 'v-b-workspace-upload' }

# 1) 验证令牌，获取账号名
try {
    $user = Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers $headers -Method Get
}
catch {
    Write-Host '令牌校验失败：请确认令牌完整（ghp_ 开头）、未过期、且勾选了 repo 权限。' -ForegroundColor Red
    exit 1
}
Write-Host ('已连接 GitHub 账号: ' + $user.login)

# 2) 确保仓库存在：不存在则创建；已存在且属于本账号则复用
$repoApi = 'https://api.github.com/repos/' + $user.login + '/' + $repoName
$repoUrl = 'https://github.com/' + $user.login + '/' + $repoName + '.git'
$repoExists = $false
try {
    Invoke-RestMethod -Uri $repoApi -Headers $headers -Method Get | Out-Null
    $repoExists = $true
}
catch {
    $repoExists = $false
}
if ($repoExists) {
    Write-Host ('仓库已存在，将直接复用: ' + $repoUrl)
}
else {
    $body = @{ name = $repoName; private = [bool]$repoPrivate; auto_init = $false } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri 'https://api.github.com/user/repos' -Headers $headers -Method Post -Body $body -ContentType 'application/json' | Out-Null
        Write-Host ('已创建仓库: ' + $repoUrl)
    }
    catch {
        Write-Host '创建仓库失败（仓库名可能已被他人占用或网络异常）。' -ForegroundColor Red
        Write-Host '解决办法：到 https://github.com/new 手动创建同名空仓库后重新运行本脚本。' -ForegroundColor Yellow
        exit 1
    }
}

# 3) 设置远程 origin
$existing = (& $git remote get-url origin 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($existing)) {
    & $git remote add origin $repoUrl
    Write-Host '已添加远程 origin'
}
elseif ($existing -ne $repoUrl) {
    & $git remote set-url origin $repoUrl
    Write-Host '已更新远程 origin'
}
else {
    Write-Host '远程 origin 已配置'
}

# 4) 令牌存入系统凭据管理器（后续 push 免输入；不写入仓库配置）
$cred = 'protocol=https' + "`n" + 'host=github.com' + "`n" + 'username=' + $user.login + "`n" + 'password=' + $token + "`n`n"
$cred | & $git credential approve

# 5) 推送
Write-Host ''
Write-Host '正在推送 main 分支...' -ForegroundColor Cyan
& $git push -u origin main
if ($LASTEXITCODE -ne 0) {
    Write-Host '推送失败：可能网络不畅，稍后重新运行本脚本重试即可。' -ForegroundColor Red
    $token = $null
    exit 1
}

$token = $null
Write-Host ''
Write-Host '=== 上传成功 ===' -ForegroundColor Green
Write-Host ('仓库地址: ' + $repoUrl)
Write-Host ('浏览器打开: https://github.com/' + $user.login + '/' + $repoName)
Write-Host '令牌已存入凭据管理器；如需撤销请到 GitHub -> Settings -> Developer settings -> Personal access tokens。'
