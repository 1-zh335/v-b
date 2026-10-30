# 工具/ — 跨任务可复用工具

> 本目录放跨任务复用的本地工具脚本；脚本一律遵守 `AGENTS.md` §2（`.ps1` = UTF-8 BOM + CRLF、源码尽量纯 ASCII）。
> 新增工具请同步在 `AGENTS.md` §5 的根目录清单或本 README 说明用途。

## 窗口查看.ps1（2026-10-29 新增）

**用途**：用户说「桌面已经打开了 X / 我已经打开了 / 在窗口里 / 在浏览器/夸克里看」时，先实际截屏 + 读窗口内容再回答；也用于 GUI/网页验收（对已被遮挡的窗口同样有效）。

- 实测环境：Windows 11 + PowerShell 5.1；1920×1080 @150%；夸克浏览器 7.4.2.1020（Chromium，进程 `quark`）；DSH 桌面端（Electron）
- 能力：窗口列表、窗口截图（PrintWindow，被遮挡也可截）、UIA 提取文字、UIA 树、激活窗口、按无障碍名点击、坐标点击、发送按键
- 输出目录：默认 `工具\截图\`

### 常用命令（路径含空格，必须加引号）

```powershell
$t = "C:\Users\31384\Documents\trae_projects\v b\工具\窗口查看.ps1"

# 1) 列出所有可见窗口（HWND / PID / 进程 / 标题 / 位置）
powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action List

# 2) 截目标窗口 → 必须用 read_image 目检
powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action Shot -Title "夸克"
powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action Shot -Title "夸克" -Out ".\证据\夸克.png"

# 3) 读窗口里的文字（比 OCR 可靠；可存 txt）
powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action Text -Title "夸克"
powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action Text -Title "夸克" -Out ".\证据\页面文字.txt"

# 4) 看全部 UIA 元素（找按钮/链接的名字，点击用）
powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action Tree -Title "夸克"

# 5) 点击 + 重截核验
powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action Invoke -Title "夸克" -Name "下载Skill"
powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action Shot -Title "夸克"

# 6) 其他：激活窗口 / 坐标点击 / 发送按键
powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action Activate -Title "夸克"
powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action Click -X 800 -Y 600
powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action Send -Title "夸克" -Keys "^r"
```

### 参数

| 参数 | 说明 |
|------|------|
| `-Action` | `List` / `Shot` / `Text` / `Tree` / `Activate` / `Invoke` / `Click` / `Send` |
| `-Title` | 窗口标题子串（如 `夸克`、`DeepSeek Harness`） |
| `-ProcId` | 按进程 ID 选窗口（与 `-Title` 二选一） |
| `-Out` | 截图 PNG 或文字 TXT 的输出路径（默认截图到 `工具\截图\`） |
| `-Name` / `-Exact` | `Invoke` 用：无障碍名（默认包含匹配，`-Exact` 精确匹配） |
| `-X` `-Y` | `Click` 用：屏幕绝对坐标 |
| `-Keys` | `Send` 用：SendKeys 语法（如 `^r`、`{ENTER}`） |
| `-MaxText` | `Text` 最多输出字符数（默认 20000） |

### 边界与注意

- 截图是像素级：文字小/缩放异常时结合 `-Action Text` 读文字
- **标题匹配已归一化零宽字符与多余空格**：Edge 窗口标题里带 U+200B（`Microsoft​ Edge`），2026-10-30 实测用普通空格 `-Title "Microsoft Edge"` 已能命中；仍匹配不到时改用 `-ProcId`
- **PrintWindow 不支持时自动回退**：部分 Chromium 窗口 PrintWindow 返回黑图，脚本会自动激活窗口并改用屏幕裁剪（输出里会标明 `ScreenCrop`）
- UIA 依赖程序的无障碍树：Chromium/Electron 一般可用；纯自绘界面可能只有少量元素
- 点击优先用 `Invoke`（按无障碍名），失败才退回坐标点击；点击后必须重新截图核验
- 需要浏览器级深度自动化（批量操作、注入 JS、登录态操作）时，改用 Edge `--remote-debugging-port` + Playwright/CDP，不要用本工具硬点
- 截图可能含隐私（授权码/账号/聊天记录），写进交付文档前必须遮挡或只记录必要字段

### 验证记录

见 `任务-桌面窗口查看能力-2026-10-29/`：
- `截图\quark-技能页-窗口截图.png`（PrintWindow 截取被遮挡的夸克窗口，1942×1030）
- `证据\quark-技能页-文字.txt`（UIA 提取 98 条文字）
- `证据\quark-技能页-UIA树.txt`（151 个元素的类型/名字/矩形/Pattern）

## 浏览器/（2026-10-29 新增）

`浏览器\start-edge.ps1` + `浏览器\browser.mjs`：给 Edge 开 `--remote-debugging-port=9222`（独立 profile，不影响日常 Edge），用 playwright-core 1.64.1 通过 CDP 做打开页面/点击/填表/读文字/截图/执行 JS。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "工具\浏览器\start-edge.ps1" -Url "https://example.com"   # 或 -Headless
node "工具\浏览器\browser.mjs" goto --url "https://example.com" --shot ".\shot.png"
node "工具\浏览器\browser.mjs" text
node "工具\浏览器\browser.mjs" close       # 或 start-edge.ps1 -Stop
```

分工：网页站点的多步操作 → 浏览器驱动；桌面客户端窗口（夸克/DSH 等）→ `窗口查看.ps1`。详情、实测记录与安全注意见 `浏览器\README.md`。