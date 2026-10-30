# 任务：Edge 远程调试 + Playwright/CDP 驱动（2026-10-29）

## 1. 需求

用户要求：**给 Edge 开 `--remote-debugging-port=9222` + Playwright/CDP 驱动**。

目的：补足"桌面窗口只能看、不能深入操作"的能力——让本机 Agent 能对真实浏览器做多步操作：打开页面、点击按钮/链接、填表、读取页面文字、执行 JS、截图核验。

## 2. 方案（已落地）

| 组件 | 说明 |
|---|---|
| 浏览器 | Microsoft Edge 156.0.4314.50（Chromium 内核，本机已有；未装 Chrome） |
| 调试端口 | `127.0.0.1:9222`（CDP；仅本机监听，无鉴权） |
| 自动化 profile | `%LOCALAPPDATA%\DSH\edge-automation-profile`（独立，不影响日常 Edge） |
| 启动器 | `工具\浏览器\start-edge.ps1`：可见/无头/指定 URL/`-Stop` 停止；端口已占用时复用实例 |
| 驱动 | `工具\浏览器\browser.mjs`：playwright-core 1.64.1 `connectOverCDP`，动作 `status/list/goto/shot/text/html/click/type/eval/close` |
| 依赖 | 只装在 `工具\浏览器\node_modules`（`.gitignore` 排除 `node_modules/`）；未做系统级安装 |

## 3. 使用（最少三步）

```powershell
# 1) 启 Edge（可见；加 -Headless 则无头）
powershell -NoProfile -ExecutionPolicy Bypass -File "工具\浏览器\start-edge.ps1" -Url "https://example.com"

# 2) 驱动
node "工具\浏览器\browser.mjs" goto --url "https://example.com" --shot ".\shot.png"
node "工具\浏览器\browser.mjs" click --text "登录"
node "工具\浏览器\browser.mjs" text

# 3) 收尾
node "工具\浏览器\browser.mjs" close      # 或：start-edge.ps1 -Stop
```

## 4. 验证记录（本机实测，全部通过）

| 检查 | 命令/证据 | 结果 |
|---|---|---|
| 启动（无头） | `start-edge.ps1 -Headless` | `[OK] Edge CDP ready`，`Browser: Edg/156.0.4314.50` |
| 启动（可见） | `start-edge.ps1 -Url about:blank` | 窗口 `about:blank - 个人 - Microsoft Edge` |
| 连接/列表 | `browser.mjs status` | connected，contexts 1，pages 1 |
| 导航 | `browser.mjs goto --url file:///.../index.html` | title `DSH 浏览器自检页`，HTTP 200 |
| 截图 | `--shot` | `截图\01-自检页初始.png`（13070 B）、`02-点击后.png`（12525 B）、`03-可见模式.png`（25599 B） |
| 填表+点击+读字 | `type --selector #q` → `click --selector #btn` → `text` | 文字变为「按钮已点击：夸克网盘」 |
| eval | `eval --js "..."` | `{"title":"DSH 浏览器自检页","url":"file:///...","ua":"...Edg/156.0.0.0","p":"初始文本：等待点击"}`（见 `证据\page-eval.json`） |
| 关闭 | `browser.mjs close` / `start-edge.ps1 -Stop` | 端口 9222 关闭，msedge 进程 0 |
| 脚本规范 | `node --check`、字节检查 | browser.mjs 语法通过；start-edge.ps1 = UTF-8 BOM + CRLF + 纯 ASCII |

截图已人工目检（`read_image`）：自检页标题/段落/输入框/按钮显示正常，点击后文字变化与截图一致。

## 5. 安全与注意

1. **CDP 无鉴权**：本机任何进程都能通过 9222 控制该浏览器——只用独立自动化 profile，不处理高敏感账号，用完 `-Stop`，禁止把端口暴露到局域网。
2. **日常 Edge 不受影响**：自动化实例用独立 `--user-data-dir`；日常已在运行的 Edge 无法"事后"开启调试端口，需要时用本工具另起实例（或用同一 profile 前必须先完全退出日常 Edge，不推荐）。
3. **登录态**：在自动化 profile 里手动登录一次后会保留；首次使用需人工登录，注意账号安全。
4. **依赖来源可信**：playwright-core 来自 npm 官方 registry（1.64.1）；`node_modules` 不入库，重装见 `工具\浏览器\README.md`。
5. 与桌面窗口工具分工：网页站点操作 → 本工具；夸克/DSH 等桌面客户端窗口 → `工具\窗口查看.ps1`。

## 6. 文件与备份

```
任务-Edge调试与Playwright-2026-10-29\
├── README.md（本文件）
├── 截图\01-自检页初始.png / 02-点击后.png / 03-可见模式.png
├── 证据\page-text.txt / page-eval.json
└── 备份\AGENTS.md.bak / README.md.bak / 工具-README.md.bak
```

代码本体：`工具\浏览器\`（`start-edge.ps1`、`browser.mjs`、`package.json`、`test\fixture.html`、`README.md`）。

## 7. 规则同步（已写入唯一规则文档 AGENTS.md）

- §1 环境：Edge 版本更正为 156.0.4314.50，并注明 `工具\浏览器\` 自动化入口
- §6「桌面/已打开窗口」能力边界：浏览器级深度自动化 → 指向 `工具\浏览器\`
- §9：新增「浏览器自动化（Edge CDP + Playwright）」条目（启动/驱动/关闭命令、profile 隔离、安全要求）

## 8. 回滚

1. 删除 `工具\浏览器\`（含 `node_modules`）即移除驱动；删除 `%LOCALAPPDATA%\DSH\edge-automation-profile` 清除自动化 profile
2. 恢复文档：`备份\AGENTS.md.bak`、`备份\README.md.bak`、`备份\工具-README.md.bak` 拷回原位
3. 无系统级安装、无注册表/service/计划任务改动

## 9. git 状态

未提交。新增：`工具\浏览器\`、`任务-Edge调试与Playwright-2026-10-29\`；修改：`AGENTS.md`、`README.md`、`工具\README.md`。
