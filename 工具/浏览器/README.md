# 浏览器/ — Edge CDP + Playwright 驱动

> 给本机 Agent 提供"真实浏览器"操作能力：Edge 开启 `--remote-debugging-port=9222`，用 Playwright-core 通过 CDP 连接，执行打开页面/点击/填表/读文字/截图/执行 JS。
> 与 `工具\窗口查看.ps1` 的分工：**桌面/客户端窗口**（夸克、DSH 等）用窗口查看；**网页站点**的多步操作/登录态操作用本工具。

## 环境（实测）

| 项 | 值 |
|---|---|
| 浏览器 | Microsoft Edge **156.0.4314.50**，`C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe` |
| Node | 系统级 `C:\Program Files\nodejs\node.exe` v26.7.0 |
| 依赖 | `playwright-core@1.64.1`（只装在本目录 `node_modules`，不入库） |
| 调试端口 | `127.0.0.1:9222`（仅本机；CDP 无鉴权，勿暴露局域网） |
| 自动化 profile | `%LOCALAPPDATA%\DSH\edge-automation-profile`（独立目录，**不影响日常 Edge 配置**） |

## 文件

```
工具\浏览器\
├── start-edge.ps1     # 启动/停止带 CDP 的 Edge（UTF-8 BOM + CRLF，源码纯 ASCII）
├── browser.mjs        # Playwright-core CDP 驱动（status/goto/shot/text/html/click/type/eval/close）
├── package.json       # playwright-core 依赖声明
├── package-lock.json
├── test\fixture.html  # 自检页（点击/输入/读文字/截图用）
├── README.md          # 本文件
└── node_modules\      # 本地依赖（gitignore 已排除）
```

## 启动 / 停止 Edge

```powershell
$edge = "C:\Users\31384\Documents\trae_projects\v b\工具\浏览器\start-edge.ps1"

# 可见窗口（默认 about:blank；适合需要人工登录/目视的场景）
powershell -NoProfile -ExecutionPolicy Bypass -File $edge -Url "https://example.com"

# 无头模式（适合纯自动化、不打扰桌面）
powershell -NoProfile -ExecutionPolicy Bypass -File $edge -Headless -Url "https://example.com"

# 停止自动化实例（按端口找到进程树并结束）
powershell -NoProfile -ExecutionPolicy Bypass -File $edge -Stop
```

- 端口被占用时会**复用现有实例**并打印 `Browser` 与 `WebSocket` 地址
- 脚本会打印 `[OK] Edge CDP ready ...` 才算启动成功（失败退出码 1）
- 不要把 9222 暴露到局域网；不用时 `-Stop`（CDP 可被本机任意程序控制）

## 驱动命令

```powershell
$b = "C:\Users\31384\Documents\trae_projects\v b\工具\浏览器\browser.mjs"

node $b status                                  # 连接状态 + 页面列表
node $b list                                    # 同上（页面 index/title/url）
node $b goto --url "https://example.com"        # 当前页导航
node $b goto --new --url "https://example.com"  # 新标签页打开
node $b shot --out ".\shot.png"                 # 当前页截图（--full 整页）
node $b text                                    # 页面可见文字（--max 4000）
node $b html --selector "main"                  # 页面/元素 HTML
node $b click --selector "#btn"                 # 按选择器点击
node $b click --text "登录"                     # 按可见文字点击
node $b type --selector "#q" --text "关键词"     # 填表
node $b eval --js "document.title"              # 执行 JS（打印 JSON）
node $b close                                   # 关闭该 Edge 实例（CDP Browser.close）
```

通用参数：`--port 9222`、`--timeout 30000`、`--page N`、`--wait load|domcontentloaded|networkidle`、动作后可加 `--shot out.png` 顺手截图。

## 已验证（2026-10-29，本机实测）

| 检查 | 结果 |
|---|---|
| `start-edge.ps1 -Headless` | `[OK] Edge CDP ready`，`Browser: Edg/156.0.4314.50` |
| `start-edge.ps1`（可见） | 窗口 `about:blank - 个人 - Microsoft Edge` |
| `browser.mjs status` | connected，列出页面 |
| `goto` 本地自检页 | title `DSH 浏览器自检页`，http status 200 |
| `shot` | 截图成功（750×485 / 1137×734，文件已归档任务目录） |
| `type` + `click` + `text` | 输入"夸克网盘"→点击→文字变为"按钮已点击：夸克网盘" |
| `eval` | 返回 `{"title":"DSH 浏览器自检页","ua":"...Edg/156.0.0.0","p":"初始文本：等待点击"}` |
| `close` / `start-edge.ps1 -Stop` | 端口 9222 关闭、msedge 进程 0 |
| `node --check browser.mjs` | 通过；`start-edge.ps1` UTF-8 BOM + CRLF + 纯 ASCII |

## 限制与注意

1. **只能连"带 `--remote-debugging-port` 启动"的 Edge**；日常已在运行的 Edge 无法事后开启调试端口（需重启）。本工具用独立 profile 启动新实例，不打扰日常 Edge。
2. **登录态**：自动化 profile 独立，首次需在该 profile 里手动登录一次，之后复用；不要把日常 Edge profile 直接拿来开调试端口（文件锁 + 风险）。
3. **CDP 无鉴权**：任何本机进程/脚本都能通过 9222 控制这个浏览器；不要用它处理高敏感账号，用完 `-Stop`。
4. 需要"桌面客户端窗口"（夸克/DSH 等非网页）时改用 `工具\窗口查看.ps1`。
5. 截图、临时页面属临时验证物，用完清理；`node_modules`、自动化 profile 不入库。

## 安装/重装依赖

```powershell
Set-Location "C:\Users\31384\Documents\trae_projects\v b\工具\浏览器"
& "C:\Program Files\nodejs\npm.cmd" install --no-audit --no-fund
```
