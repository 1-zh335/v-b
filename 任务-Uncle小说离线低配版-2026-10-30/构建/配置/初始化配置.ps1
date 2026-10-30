param(
    [Parameter(Mandatory=$true)][string]$InstallDir
)
$ErrorActionPreference = 'Stop'
$confPath = Join-Path $InstallDir 'conf\conf.json'
if (Test-Path -LiteralPath $confPath) {
    Write-Host '[OK] 已存在 conf\conf.json，保留原有设置（覆盖升级不会重置）'
    exit 0
}
$downloadDir = Join-Path $InstallDir 'downloads'
$conf = [ordered]@{
    version = '5.0.44'
    basic = [ordered]@{
        tray = $false
        theme = 'default'
        lang = '简体中文'
        fonts = 'Microsoft YaHei'
    }
    download = [ordered]@{
        folder = $downloadDir
        threadNum = 1
        taskNum = 1
        retryNum = 1
        volume = $true
        mobi = $false
        txt = $true
        epub = $false
    }
    reader = [ordered]@{
        themeName = 'green'
        bgImage = ''
        fontSize = 22.0
        fontFamily = 'Microsoft YaHei'
        align = 'LEFT'
        simpleTraditional = 0
        speaker = 0
        speed = 1.0
        showHeader = $true
        windowTop = $false
        showShadow = $false
        flipAnimation = $false
        pageWidth = 0.9
        lineSpacing = 0.25
        stageWidth = 1120.0
        stageHeight = 760.0
    }
    bookShelf = [ordered]@{
        group = '全部'
        autoUpdate = $false
        alwaysShowBookTitle = $true
    }
    backup = [ordered]@{
        url = ''
        username = ''
        password = ''
        bookshelf = $true
        audio = $true
        rule = $true
        searchEngine = $true
        setting = $true
    }
    proxy = [ordered]@{
        httpProxy = $false
        useSystem = $false
    }
    hotkey = [ordered]@{
        readerNextPage = 'RIGHT'
        readerPrePage = 'LEFT'
        readerNextChapter = 'DOWN'
        readerPreChapter = 'UP'
        readerToc = 'ctrl C'
        globalBossKey = 'alt U'
        enabledGlobal = $true
    }
    debug = $false
}
$json = $conf | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($confPath, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "[OK] 已生成目标机调优配置: $confPath"
Write-Host '     （阅读 1120x760 / 字号 22 / 行距 0.25 / 关闭翻页动画与阴影 / 下载单线程）'
exit 0
