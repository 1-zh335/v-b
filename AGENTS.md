# AGENTS.md — 本地工程规范（Trae + DSH 共用唯一规则文档）

> **定位**：本文件是本机**唯一**规则文档（`C:\Users\31384\Documents\trae_projects\v b\AGENTS.md`），Trae 与 DSH 都直接读取它；改这一个文件即两边同时生效，**不需要任何同步或副本**。
> - **Trae**：项目根 `AGENTS.md` 自动纳入规则上下文（设置项 `AI.rules.importAgentsMd` 默认 true，本机未关闭；原 `.trae\rules\工程规范.md` 已合并删除，避免重复注入）
> - **DSH**：`dsh-agent-instructions` 自动加载项目根（含 `.git` 的目录）到工作目录链上的 `AGENTS.md` / `CLAUDE.md`（及 `.local` 变体）；全局 `C:\Users\31384\.dsh\AGENTS.md` 已改为指向本文件的简短指针
> 本文件由另一台机器的 `AGENTS.md`（用户 `d59049`、工作区 `D:\Vibe Coding`、Windows 10 LTSC）于 **2026-10-24 本地适配**，并合并原 Trae 项目规则（`.trae\rules\工程规范.md`）与 Trae 个人规则（`~/.trae-cn/user_rules\工程规范.md`）中的有效内容；环境事实均本机实测核对（见 §1）。
> 任何在本机工作的 AI Agent 必须遵守以下规范。最后修订：2026-11-10（环境复核：Edge 156→**157.0.4341.42**、Quark 7.4.2.1020→**7.4.7.1036**；DSH 仍 `0.2.1-rc.5` 但 nightly 最新 `0.2.2-rc.1` 已下载待应用；校正 2026-11-09 仓库整理后的数字：远端 HEAD `39cb981`、pack 约 1.76MiB、13 个提交；详见 `任务-DSH环境最新汇总-2026-11-10\`）；2026-11-09（仓库深度整理：重写历史移除 31MB 大文件/二进制/旧截图，本地文件保留，git 对象 21.2MB→pack 约 1.76MiB；详见 `任务-仓库整理-2026-11-09/README.md`）；2026-10-31（16:3x 更新 §9 插件实装记录：cost-meter 升至 `1.9.46`、desktop 两个 subagent 升至 `0.2.1-rc.5` 并 active、`settings.yaml` 实测不存在；同日完成 GitHub 推送与网络绕行记录，见 §1/§8/§9；此前新增 §6「承诺与交付纪律（防过度承诺）」与 §10「文档维护与自检」；校正 DSH 内核 `0.2.1-rc.5`、补 `@dsh-pet/bridge` 实装态、更新 `.trae/` 已删除与工作区根历史目录；此前 2026-10-29 新增 Edge CDP 9222 + Playwright-core 浏览器自动化与 §6「桌面/已打开窗口：先看再答」；2026-10-28 内核曾为 `0.2.1-rc.3`；2026-10-25 修正「DSH 版本」「裸 `dsh` 解析」；Trae / DSH 单一规则文档整合）。

## 1. 环境信息（2026-10-31 本机复核）

- 系统：Windows 11 家庭版 Insider Preview 中文版 64-bit（NT 10.0.26340）；当前用户 `moss\31384` 为**标准用户**（`IsInRole(Administrator)` = False），提权操作会弹 UAC
- DSH 文件策略：本会话为 `danger-full-access`（文件读写不受沙箱限制）；审批提示默认禁用，需要审批的操作会被自动拒绝——**不要请求提权/沙箱升级**
- 时区：中国标准时间（UTC+8，`China Standard Time`），`Get-Date` 直接可用
- 工作目录：`C:\Users\31384\Documents\trae_projects\v b`（**路径含空格**，命令行引用必须加引号）
- Node.js：**双版本并存**
  - 系统级：`C:\Program Files\nodejs\node.exe` v26.7.0（npm 11.19.0；npm 全局前缀 `C:\Users\31384\AppData\Roaming\npm`，已装 `@deepseek-ai/dsh@0.1.1-rc.2`、`pnpm@11.24.0`）
  - Trae 内置：`C:\Users\31384\.trae-cn\binaries\node\versions\22.23.2\node.exe` v22.23.2（npm 10.9.8；npm 全局前缀即该版本目录本身）
  - 本机实测裸 `node`/`npm` 解析到**系统级** v26.7.0；但**裸 `dsh` 不是 npm 全局那个**——PATH 首位是桌面端自带 CLI（见下条），`dsh --version` = 桌面端内核版本（2026-10-31 实测 `0.2.1-rc.5`；nightly 会自动升级，精确值以运行时 `runtime.json` 的 `desktopVersion` 为准，核对命令见 §10）。npm 全局 `@deepseek-ai/dsh@0.1.1-rc.2` 仍装着但排在 PATH 之后、当前不生效；Trae 内置版需用绝对路径，两者依赖树不同，勿混用
  - 桌面端运行时：Node `24.21.0`、pnpm `11.28.5`、Python `3.12.14`（见 `resources\runtime\primary-runtime\runtime.json`）；`dsh plugin` 装插件时用的就是这套 pnpm，其内置 **24 小时 `minimumReleaseAge`** 会让刚发布的新版本被暂缓或报 `ERR_PNPM_MINIMUM_RELEASE_AGE_VIOLATION`——改用已满 24h 的版本，或加 `--config.minimum-release-age=0`
- Python：3.12.10（pip 25.0.1），安装于 `C:\Users\31384\AppData\Local\Programs\Python\Python312\`；本机实测裸 `python`/`pip` 已正确解析到 Python312（`WindowsApps` 商店占位仍在 PATH 末尾但不遮蔽），`py -3` 可用。脚本内仍建议绝对路径（`start` 子进程等场景会丢 PATH 继承）
- 浏览器/客户端（视觉验收 + 「用户已打开窗口」场景）：**未安装 Chrome**；Edge `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`（2026-11-10 实测 157.0.4341.42；Edge 自动更新，精确值以安装文件版本为准）；**夸克浏览器（夸克网盘）** `C:\Program Files\Quark\quark.exe`（7.4.7.1036，2026-11-05 更新，Chromium 内核，进程名 `quark`，窗口类 `Chrome_WidgetWin_1`，实测 PrintWindow 截屏 + UIA 读字均可用）；DSH 桌面端为 Electron 窗口，同样可截屏 + UIA。屏幕 1920×1080 @150% 缩放，截图前必须 DPI 感知（`工具\窗口查看.ps1` 已处理）；**浏览器级自动化**：Edge `--remote-debugging-port=9222` + `工具\浏览器\`（Playwright-core），见 §9
- git：`C:\Program Files\Git\cmd\git.exe`（2.55.0.windows.3）；工作区 git 仓库（分支 `main`，提交身份 `1-zh335 <3138470565@qq.com>`，`core.quotepath=false`）。**远程已配置并已推送**：`origin = https://github.com/1-zh335/v-b.git`（公开；2026-10-31 首次推送，2026-11-09 深度整理后 force push，远端 HEAD `39cb981`（2026-11-10 实测））；令牌（classic、`repo`、无过期）已存入 **Windows 凭据管理器**，之后 `git push` 免输入。**本机访问 github.com 受网络干扰**：默认 DNS/IP 时常超时或被重置；已用 `git config --global http.curloptResolve "github.com:443:140.82.112.3"` 绕过（2026-11-10 23:3x 实测可用；`20.27.177.113` 当时超时；另有 `20.205.243.166/.169`、`20.200.245.247` 等会漂移）；浏览器访问 github.com 需以 `--host-resolver-rules="MAP github.com <IP>"` 启动 Edge。详见 §8 与任务记录；2026-11-09 深度整理后历史已重写（大文件/二进制/旧截图移出历史但保留本地），仓库 pack 约 1.76MiB，详见 `任务-仓库整理-2026-11-09\README.md`
- Trae：`C:\Users\31384\AppData\Local\Programs\Trae CN\Trae CN.exe`（3.4.7）
- DSH：**桌面端内核 `0.2.1-rc.5`**（2026-10-31 实测 `0.2.1-rc.5`；2026-11-10 复核未变，nightly 最新 `0.2.2-rc.1` 已于 2026-11-08 下载待应用；nightly 渠道自动升级；精确值以 `resources\runtime\primary-runtime\runtime.json` 的 `desktopVersion` 为准）；程序位置 `C:\Users\31384\AppData\Local\Programs\DeepSeek Harness\DeepSeek Harness.exe`；命令行入口 = 桌面端自带 CLI `resources\runtime\cli\bin\dsh.cmd`（PATH 首位，`dsh --version` = 桌面端内核版本，2026-10-31 实测 `0.2.1-rc.5`）。npm 全局另装 `@deepseek-ai/dsh@0.1.1-rc.2`（`...\AppData\Roaming\npm\dsh.ps1`），PATH 在其后、当前不生效，**升级它不会改变 `dsh` 的实际版本**；`DSH_HOME=C:\Users\31384\.dsh`；GUI 端口随启动变化，以运行时提示为准；`dsh-start.bat` 固定使用 3080
- 硬件信息参考：`C:\Users\31384\Desktop\DxDiag.txt`（本机不存在，跳过，不影响任务）
- 回复语言：始终用中文

## 2. 脚本编码规范（最高优先级，违反会导致中文乱码/解析错误）

| 文件类型                          | 编码             | 行尾           | 其他要求                                                                 |
| ----------------------------- | -------------- | ------------ | -------------------------------------------------------------------- |
| `.bat` / `.cmd`               | **GBK/ANSI(936)** | **CRLF（必须）** | 第 1 行 `chcp 936 >nul`（第 2 行 `@echo off` 推荐）；禁止 `chcp 65001`           |
| `.ps1`                        | UTF-8 with BOM | CRLF         | 用 `powershell -NoProfile -ExecutionPolicy Bypass -File "path"` 执行        |
| `.vbs`                        | GBK 无 BOM      | CRLF         | —                                                                    |
| 其他文本（.md/.json/.js/.ts/.py 等） | UTF-8          | LF 可         | —                                                                    |

### 硬约束

- **绝对禁止**把含中文的 `.bat`/`.cmd` 写成 UTF-8（无 BOM + chcp 65001 会让中文 `::` 注释报 `'xxx' is not recognized`）
- Write 工具输出的是 UTF-8 + LF；写完 `.bat`/`.cmd`/`.vbs` 后**必须**立即转成 GBK + CRLF。下述片段仅适用于「刚写出、仍是 UTF-8」的文件：
  ```powershell
  $p = "文件路径"
  $t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
  $t = $t -replace "`r`n", "`n"     # 先归一化为 LF
  $t = $t -replace "`n", "`r`n"     # 再转成 CRLF
  [System.IO.File]::WriteAllText($p, $t, [System.Text.Encoding]::GetEncoding(936))  # 存为 GBK
  ```
  > 已转成 GBK 的文件若再次处理，读取时编码要改成 `GetEncoding(936)`，别用 UTF-8 二次读坏。
- `.ps1` 需 UTF-8 BOM + CRLF，Write 工具输出后同样要转一次：
  ```powershell
  $p = "x.ps1"
  $t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
  $t = $t -replace "`r`n", "`n" -replace "`n", "`r`n"     # 转 CRLF
  [System.IO.File]::WriteAllText($p, $t, [System.Text.UTF8Encoding]::new($true))  # $true = 带 BOM
  ```
  > 一次性脚本最省事的做法是**全程纯 ASCII**，中文用 `[char]0xXXXX` 转义（如 `"DSH $([char]0x542F)$([char]0x52A8).lnk"` = `DSH 启动.lnk`），从根上避开 BOM/GBK 坑
- 读 GBK 文件若显示乱码，用 PowerShell 读：
  ```powershell
  [System.IO.File]::ReadAllText("path", [System.Text.Encoding]::GetEncoding(936))
  ```
- 转码后**立即验证**：本机**未安装** `check_win_bat_standards` 工具（原机器专用的自定义插件，本机 profile 里没有），统一改用手动校验（命令见 §9）：`.bat`/`.cmd` 校验 ① GBK 非 UTF-8 ② CRLF 非 LF ③ 首行 `chcp 936 >nul`，且不得出现 UTF-8 BOM（`EF BB BF`）；`.vbs` 只校验 GBK 无 BOM（`chcp` 是 cmd 内部命令，写进 `.vbs` 首行会语法报错，不适用首行检查）
- 本工作区 `dsh-start.bat`、`push-to-github.bat`（GBK+CRLF+`chcp 936`）与 `push-to-github.ps1`（UTF-8 BOM+CRLF）均已实测合规，可直接当模板

## 3. PowerShell / 批处理语法规范

- 本机 PowerShell 为 **Windows PowerShell 5.1**（5.1.26100.9233），脚本避免 PS7 独有语法（`&&`、`??`、三元运算）；命令分隔用 `;` 或换行，**绝不用** `&&`
- **禁止**用 `powershell -Command "..."` 内嵌含 `$` 变量的多行脚本：外层 PowerShell 会先展开 `$var`（未定义则变空字符串），传给内层 powershell 时脚本已被破坏（如 `$shell.CreateShortcut()` 变成 `.CreateShortcut()`，报 `Expected expression`）。正确做法：把脚本写成 `.ps1` 文件，用 `powershell -NoProfile -ExecutionPolicy Bypass -File "x.ps1"` 执行
- PowerShell 脚本内不要经 `cmd.exe` / `command.exe` 间接执行命令
- 路径含空格必须加引号：`"C:\Users\31384\Documents\trae_projects\v b\file"`；`start` 命令路径含空格用 `start /d "path"`
- 批处理括号块内要用 `!errorlevel!` 必须先开延迟展开，且值先存变量再比较：
  ```bat
  setlocal EnableDelayedExpansion
  ...
  set "ERR=!errorlevel!"
  if "!ERR!"=="0" ...
  ```
- **调用外部命令（尤其 `.cmd` shim，如本机 `dsh` 现为桌面端自带 `dsh.cmd`）传参时禁用 `!VAR!` 延迟展开**：实测 `dsh web --port !PORT!` 会把 `!PORT!` 原样传给 dsh（报 `--port must be a number, got "!PORT!"`），而同脚本里 `echo !PORT!` 却能正常展开。顶层已 `set` 的变量直接改用 `%VAR%` 普通展开即可
- 时间戳用 `Get-Date`；不要依赖 `wmic`（Win10 起已弃用，**本机 Win11 已无 `wmic` 命令**，新脚本无兼容保障）

## 4. Node.js 使用规范

- 脚本（`.bat` 等）里调用 node 用 **node.exe 绝对路径**，不依赖 PATH 或 npm（`start` 子 cmd 环境会丢 PATH 继承）：
  ```bat
  "C:\Program Files\nodejs\node.exe" script.js
  ```
- 需要 npm 时用 `"C:\Program Files\nodejs\npm.cmd"`，或在确认 PATH 已刷新后直接用 `npm`；本机 **Trae 内置 Node（v22.23.2）与系统 Node（v26.7.0）并存、npm 全局前缀不同**，装全局包/跑依赖前先确认用的是哪一套
- 若确需 Trae 内置 Node 动态定位（版本号随 Trae 升级变化，目录内可能新旧混存，按名排序会错选，用 `/o-d` 按目录时间倒序）：
  ```bat
  for /f "delims=" %%V in ('dir /b /ad /o-d "C:\Users\31384\.trae-cn\binaries\node\versions"') do set "NODE_EXE=C:\Users\31384\.trae-cn\binaries\node\versions\%%V\node.exe" & goto :node_found
  :node_found
  "%NODE_EXE%" script.js
  ```
- Vite 大项目内存不足（OOM）时可加 `--max-old-space-size=4096`
- 缺库先 `npm install`；Python 库用 `py -3 -m pip install <包>` 或 Python312 绝对路径（本机 pip 25.0.1 已可用，见 §1）

## 5. 项目结构约定

- 新任务必须在当前工作目录下建**中文命名子文件夹**（如"任务1"、"任务2"）；任务文件夹用中文没问题，但脚本内部的路径、变量名避免中文（用英文名或相对路径），减少编码坑
- 写功能代码前**先**生成项目文档（README.md / DESIGN.md）说明目标、文件结构、逻辑流程
- 临时测试文件用完即删
- 打包交付类项目（用户要求 .exe 交付时）的产物可按交付形态分文件夹存放，种类与命名不强制；历史项目常用可参考：`1-开箱即用`（免安装绿色版）、`2-安装器`（setup 安装包）、`3-单文件exe`（单文件便携版）；非打包任务不适用
- 工作区 `C:\Users\31384\Documents\trae_projects\v b` **已是 git 仓库**（2026-08-30 初始化，分支 `main`，已有初始提交；**2026-10-31 已配置远程 `origin` 并推送**，详见 §1/§9）：`git status` 把中文路径显示成 `\351\241\271...` 转义串时，是 `core.quotepath` 默认值所致，执行 `git config core.quotepath false` 即可（只影响显示，本仓库已设置）
- git CLI 经 winget 安装（Git for Windows 2.55.0，路径 `C:\Program Files\Git\cmd\git.exe`）；若命令不可用，新开终端或改用绝对路径。**本仓库曾启用 sparse-checkout（cone：仅根文件 + `/docs/` + `/pet/`），2026-10-31 已执行 `git sparse-checkout disable` 以允许任务目录入库**；今后 `git add -A` 若报 `outside of your sparse-checkout definition`，先 `git sparse-checkout disable` 再提交。注意：关闭 sparse-checkout 会从 HEAD 恢复工作区里已删除但尚未提交删除的文件（2026-10-31 就恢复了旧的 `.trae/rules/工程规范.md`），恢复后要重新删除并提交。
- 上传 GitHub：**优先使用工作区一键脚本**——双击 `push-to-github.bat`，按提示粘贴个人访问令牌（repo 权限），脚本自动完成建仓库（`v-b`，公开）→ 关联远程 → 推送 `main`；手动方式：先在 GitHub 建空仓库，再 `git remote add origin <仓库地址>` → `git push -u origin main`；推送前 `git status` 并确认无敏感/大文件（排除规则见仓库根 `.gitignore`，已按本节排除目录维护）
- 工作区根只保留：`AGENTS.md`（本文件，唯一规则文档）、`README.md`、`dsh-start.bat`、`push-to-github.bat`、`push-to-github.ps1`、`.gitignore`、`.gitattributes`、`工具/`（跨任务可复用工具，如 `窗口查看.ps1`）、`任务X/`（新任务一律建此类目录）；旧规则历史已归档到 `任务-规则防过度承诺与文档审查-2026-10-31/历史归档/`（2026-10-31 根目录清理：`AGENTS本地化/`、`规则统一/`、`素材/`、`logs/`、`npm-install.log` 已移除）；`.trae/` 已于 2026-10 删除（Trae 规则全部并入本文件，勿重建）；仓库只存文档/工具/小体积证据，大文件（`*.jar`、字体、`runtime/`、`交付/`、`素材/` 等）已在 `.gitignore` 排除，**禁止 `git add -f` 强塞**；本地日志与临时文件不入库；2026-11-09 深度整理后，截图/PDF/JAR/bin/class/字体/素材/备份默认不入库（`.gitignore`），仅用户指定保留的证据截图例外

### 审查/扫描时必须排除的目录（体积巨大或无意义）

- `node_modules/`
- `dist/`、`.next/`、`build/`
- `.git/`
- 任何 `*.log`、`*.zip`、`*.7z`、`*.rar`、`*.exe`、`*.dll`
- Python 产物目录：`__pycache__/`、`.venv/`、`.pytest_cache/`

## 6. 开发与测试协议

- **不要立即打包成 .exe**。先提供源码，在终端运行验证通过后再考虑打包
- 出错/失败时：分析终端输出 → 修代码 → 重跑验证，直到稳定；删除失败产物

### 视觉验收闭环（生成-观察-验证-优化）

- **凡用户看得见的产物（网页/GUI/3D 场景/渲染结果），验收必须包含视觉维度**——接口 200 ≠ 界面正确：前端拼 URL 缺 `?` 报 404、词云接口返回单字这类 bug 只有渲染出来才暴露
- 闭环流程：生成 → 运行 → **截图 → 目检 → 修复 → 重截复验**，直到所见即所期；截图后必须用 DSH 的 `read_image` 工具亲自看（Trae 侧则用图片预览/文件读取），按布局/颜色/文字/交互/3D 效果逐项对照
- 网页/3D 截图用本机 **Edge 无头**（本机未装 Chrome；Edge 实测可用，版本随自动更新漂移）：
  ```powershell
  $edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
  & $edge --headless=new --disable-gpu --no-first-run --hide-scrollbars --window-size=1440,940 --virtual-time-budget=9000 --screenshot="shot.png" "http://localhost:3000/"
  ```
  - 若日后安装 Chrome（`C:\Program Files (x86)\Google\Chrome\Application\chrome.exe`），把 `$edge` 换成 chrome.exe 路径即可，参数不变
  - 渲染慢就加大 `--virtual-time-budget`（词云 16-20 秒、3D 场景 30 秒）；WebGL/3D 加 `--use-angle=swiftshader` 软渲染
  - SPA 无路由时给各视图加 URL 深链（如 `#cloud`、`#search=词`）以便直达截图
- GUI 桌面应用/用户已打开的窗口：**不得等用户截图**，按下方「桌面/已打开窗口：先看再答」执行 `工具\窗口查看.ps1` 截屏 + `read_image` 目检；只有确实没有窗口或截图失败才请用户协助，并附失败证据
- 截图是临时验证物，闭环结束即清理；测试服务进程停止

### 桌面/已打开窗口：先看再答（强制，2026-10-29 新增）

- **触发条件**：用户说「桌面已经打开了 X」「我已经打开了/登录了」「在窗口里」「在浏览器/夸克里看」「那个页面」「我这边显示…」，或任务对象就在已运行的 GUI/客户端/网页里 → **第一动作必须是看窗口**：不是查日志、不是打接口、不是让用户复制内容
- 标准动作（DSH 侧，路径含空格一律加引号）：
  ```powershell
  $t = "C:\Users\31384\Documents\trae_projects\v b\工具\窗口查看.ps1"
  powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action List                     # 1) 找窗口：确认 HWND/PID/标题
  powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action Shot -Title "夸克"       # 2) 截图（被遮挡也能截）→ 必须 read_image 目检
  powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action Text -Title "夸克" -Out ".\证据\页面文字.txt"  # 3) 精确读文字/链接
  powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action Tree -Title "夸克"       # 4) 找可点元素
  powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action Invoke -Title "夸克" -Name "下载Skill"          # 5) 点击后必须重截核验
  ```
- **证据要求**：结论必须能指出「截图文件路径 + 从截图/UIA 文字里看到的关键信息」；没看就回答 = 违规。截图含隐私（授权码/账号/聊天记录）时，交付文档里必须遮挡或只记录必要字段
- **禁止**：① 用户说窗口已打开却回答「我看不到你的屏幕」；② 未尝试工具就要求用户截图/复制；③ 用 headless 浏览器另开页面冒充「用户看到的页面」（要看的是用户当前那个窗口）
- **允许求助的唯一情况**：`-Action List` 找不到窗口、Shot 全黑且 `-Action Activate` 后重试仍失败、或 `-Action Text` 无任何文本；求助时必须附已执行命令与输出
- **能力边界**：截图 = 像素级目检；UIA = 读文字/按无障碍名点击（Chromium/Electron 一般可用，纯自绘界面可能元素不全）；需要浏览器级深度自动化（批量操作/注入 JS）用 `工具\浏览器\`（Edge CDP 9222 + Playwright-core，见 §9）

### 测试清理与交付固化

- 测试产物（临时文件、系统对象：计划任务/服务/注册表项/hosts 条目等）**用完即删**；删除后必须用 ≥2 种独立手段交叉核验——中文名任务在 GBK 控制台会变乱码（如 `鐐规鐪熷疄鏃跺埢閲囬泦`），字符串匹配会假阴性：删除优先用对象引用（`Unregister-ScheduledTask $task`），核验用非 ASCII 正则枚举 + 全量列表抽查
- 不得声称「已清理/已核验」除非：清理动作成功 + 核验手段已验证可靠 + 结果为空；「应该删了」的推断不是核验
- 交付物必须**版本固化后打 zip** 交付，禁止让用户直接复制仍在维护的工作区目录；安装脚本要有明显成功标志（如 `[OK] 已注册…`）并在文档写明「看到什么才算成功」；用户报失败先问输出再定位版本
- 「本机测试通过」只对测试的那份文件成立；换机/重拷后重新验证或校验哈希
- 仅适用特定版本/场景的脚本（如「仅 v2.1」SQL），文件名与首行必须注明适用范围与误用后果

### 承诺与交付纪律（防过度承诺，强制，2026-10-31 新增）

- **状态词只有四种，且必须带证据**：`已完成`（命令/操作 + 输出或 exit code + 证据路径/截图 + 时间，缺一只能降级）、`部分完成`（逐项列已做/未做）、`未开始`、`被阻塞`（原因 + 已尝试步骤 + 缺什么）
- **没有证据时禁用词**：`已生效`、`已搞定`、`没问题`、`理论上`、`应该`、`大概`、`基本可以`、`通通/全部`、`无需重启`、`等价于`、`完全一致`、`以后会自动`；必须改写成「未实测（依据：文档/日志/推断）」+ 验证方法
- **配置写入 ≠ 已生效**：文件/注册表/凭据/依赖写成功只算「已写入」；「已生效」必须有运行时证据（进程、日志、界面、接口返回、`plugin_manager` active 等）
- **命令超时/失败 ≠ 等价完成**：超时、非 0 退出、部分实例失败必须原样报告（例：`pnpm add … timed out after 300 seconds`），不得用「已写完 / 基本完成 / 其余等价」抹平
- **第三方软件行为**（桌宠 / DSH / 浏览器 / 驱动 / 安装器）只能引用官方文档或本机实测，并写清版本；仅文档依据写成「按文档（未实测）」
- **禁止预测类承诺**：`下次启动会…`、`以后自动…`、`重启后也会…` 不得作为交付结论；只能写「待验证假设 + 验证方法」
- **任务 README 的「验证结果」只放有证据的条目**；未验证内容单列「未验证 / 待确认」小节，不得混写
- **交付前四问**（回复前自检）：① 每个「已…」都有证据吗？② 有没有把推断写成事实？③ 有没有承诺未来行为？④ 有没有用「等价 / 完全一致 / 全部」却列不出对照项？
- **说过头话后的补救**：立即在任务 README 追加「事后核对」小节，标明当时哪些未验证、现在是否已验证；不删原文

## 7. Karpathy AI 编码原则

简单任务可灵活运用以下原则，不必机械逐条执行。

1. **Think Before Coding** — 不假设；不确定就问。给出多种解释而非默默选一个。直接指出更简单的替代方案。困惑时停下问。
2. **Simplicity First** — 最少代码。禁止：额外功能、一次性抽象、未要求的可配置性、不可能场景的错误处理。200 行能压到 50 行就重写。问自己：资深工程师会觉得这过度设计吗？
3. **Surgical Changes** — 不碰相邻代码/注释/格式。不重构没坏的代码。匹配现有风格。提死代码但不删。只移除自己改动产生的孤儿（import/变量/函数）。每行改动必须能追溯到用户需求。
4. **Goal-Driven Execution** — 定义可验证目标。"加校验" → "先写测试再让它过"；"修 bug" → "先写复现测试再修"。多步任务列出步骤+对应验证检查点。
5. **本地补充** — 生成代码时加函数级注释（说明函数作用、关键参数与返回）。

## 8. 历史教训（务必避免重蹈）

- `.bat` 的 `start` 命令在子 cmd 环境丢失 PATH 继承，导致 npm run dev 失败——改用 node.exe 绝对路径
- `start` 命令路径含空格必须用 `start /d "path"` 加引号
- koa-connect 包装器在 Express→Koa 迁移时丢失 ctx.state 数据——需原生 Koa 重写
- **修改工作区外的用户生产/交付目录前必须先快照备份**（快照存工作区对应任务子目录），禁止无备份直接覆盖；工作区内的文件处于测试中、可随时重写，不必备份
- **升级基础组件（数据库驱动等）前必须先确认目标环境兼容性**：产线数据库版本与驱动版本可能不匹配，驱动不随软件功能升级，以产线验证版为准（原机器案例：产线 MySQL 非标准 8.x，MySql.Data 8.0.33 报 `Unknown system variable 'lower_case_table_names'`，最终回退产线验证版；原理通用，本机不存该案例的项目）
- **向用户承诺的"流程/规范"必须实际落成文档文件**，不能只停留在对话回复中
- **视觉验收**：凡用户看得见的产物一律走 §6 视觉验收闭环，接口回归测试 ≠ 界面正确，必须截图目检
- **PowerShell 内嵌变量陷阱**：用 `powershell -Command "..."` 内嵌含 `$` 变量的多行脚本，外层 shell 会把 `$var` 展开为空（`$shell.CreateShortcut()` → `.CreateShortcut()`，报 `Expected expression`），曾重复失败数十次——必须写 `.ps1` 用 `-File` 执行
- **.ps1 中文编码坑**：Write 工具输出无 BOM UTF-8，PowerShell 5.1 按 GBK 读取会中文乱码（`DSH 启动.lnk` 被写成 `DSH 鍚姩.lnk`）；一次性脚本用纯 ASCII + `[char]0xXXXX` 转义中文最稳
- **批处理调用外部命令（.cmd shim）传参时 `!VAR!` 延迟展开失效**：`dsh web --port !PORT!` 传给 dsh 的是字面量 `!PORT!`（报 `--port must be a number`），而同脚本 `echo !PORT!` 却正常展开为 3080——顶层已 set 的变量改用 `%PORT%` 普通展开解决
- **DSH 自定义插件历史（原机器，本机未安装）**：原机器曾把 `check_win_bat_standards` 做成 npm 静态包，经 profile `cordis.patch.yml` insert + `package.json` file: 依赖挂载；教训是静态包 `module.exports.apply(ctx)` 里不能用 `harness`（Builtin 仅动态 eval 作用域可用）、注册工具不要 `require('@deepseek-ai/dsh-tools')` 的 `defineTool`（Symbol 调度键会与核心模块实例冲突）、Windows 下 file: 依赖会退化成拷贝而不是 junction。**本机 `~/.dsh/profiles/desktop/` 未安装该包，规范校验按 §2/§9 手动命令执行**；若日后在本机重做插件，上述教训仍适用
- **任务6 软件优化教训（原机器案例）**：修改工作区外生产目录前先快照；升级基础组件前确认产线兼容性；承诺的流程必须落成文档。本机只有 `C:` 盘，原案例的 `D:\TraceQuery_优化版`、`D:\SQLQC_发布版` 等路径不存在，原则照旧
- **点检系统严重失误（原机器 2026-09-02~03，原总结文档不在本机）**：给产线 v1 正在使用的表加列导致停摆——v1 的 INSERT 是隐式全列 7 值（`values(default,...)`），加任意列即报「列数不匹配」，反编译时已看到此事实、决策时却未接入。铁律：**改生产库表结构（加/删/改列、索引）前，必须读旧程序对该表的全部读写 SQL 验证兼容性，先备份并写清回退语句（目录快照规则同任务6 教训 ①）；无法本机实测必须标注「未经实测」并用替代验证复现，禁止把推断写成「已验证/不影响」**；IL/二进制提取的路径、格式、分隔符必须逐字节解码 + 与真实样本双验证，禁止凭记忆近似
- **规则副本教训（2026-10-24）**：历史上本机同一份规范存在 4 处副本（`.trae\rules\工程规范.md`、`~/.trae-cn/user_rules\工程规范.md`、`~/.dsh\AGENTS.md`、`Documents\AGENTS(1).md`），导致改一处漏三处、旧副本继续注入上下文（如 Python 未装、Chrome 截图等过期说法）。现已统一为工作区根 `AGENTS.md` 单一文档，其余位置只留指针；**禁止再新建规则副本**。另：DSH 的 Write 工具写文件会替换 inode，**会断开硬链接**（实测），所以不要用硬链接/符号链接方案做规则共享（符号链接同时需要管理员权限）
- **「桌面已打开」却被忽略（2026-10-29，夸克网盘 Skill 安装 / 2026-10-28 插件核查）**：用户两次说明桌面已打开夸克浏览器（页面含技能地址、安装提示词、授权码入口），我却只用日志/接口/headless 页面推断，没去看用户眼前那个窗口，被质问「为什么还是没学会点进去看」。**铁律：用户说窗口已打开 = 立刻 `工具\窗口查看.ps1 -Action List/Shot/Text` 看，先看再说；看不到才求助且必须附尝试证据。** 本机已实测：夸克（Chromium）与 DSH（Electron）窗口都能 PrintWindow 截屏 + UIA 读字，别再找借口。
- **大肥鱼桌宠「过度承诺」（2026-10-28~30，致命，用户点名）**：桌宠对 `desktop` profile 的 `pnpm add` 实测 **300 秒超时**（安装器报「部分实例安装失败」），我手工补 bundle 后在交付记录里写成「其余与正常安装 **等价**」；又写「DSH 对 profile bundle 变更做了 **热加载**，本次 **无需重启** 即生效」「下次重启 **也会** 正常加载」（机制未对照验证）、「**会尝试** 自动卸载」「与桌宠自身写入格式 **完全一致**」「改装 v4.3.4 可得 **106 段** 动画」（未核实）等断言。**教训：安装超时/部分失败就是失败，不许用「等价/已写完」抹平；机制与第三方行为没有对照实验就写「未实测」；跨版本/跨重启效果不许预测；「完全一致/106 段」这类量词必须有核对证据。** 事后核对（2026-10-31）：DSH 已升级到 `0.2.1-rc.5`，`plugin_manager` 中 `include:dsh-pet-bridge` 与 `include:cost-meter` 均 active，桌宠日志有 `[DSH STATE] idle -> working` 与联动音效——**最终能用 ≠ 当时那些话有依据**，两者必须分开陈述（详见 `任务-大肥鱼桌宠-2026-10-28\README.md` 的「事后核对」小节）。

- **GitHub 推送网络排障（2026-10-31）**：本机 `https://github.com` 默认解析到 `20.205.243.166` 时常超时/被重置（`api.github.com`、`ssh.github.com:443` 可达），导致浏览器登录页与 `git push` 都失败，`push-to-github.bat` 本身没有问题。解决：① git 用 `http.curloptResolve` 覆盖 IP（实测 `20.27.177.113` 成功；`.166/.169` 时好时坏）；② Edge 用 `--host-resolver-rules="MAP github.com <IP>"` 启动后登录 GitHub、生成 token；③ token 存入 Windows 凭据管理器后 `git push` 永久免输；④ 成功校验：本地 HEAD = 远端 HEAD、`git ls-remote origin` 退出码 0、API 显示仓库 7 commits。**教训：不要把「网络被阻断」误判成脚本/权限问题；`github.com` 超时先测 `api.github.com` 与 `ssh.github.com:443`，再按 IP 覆盖/轮换；GitHub 网页与 git 走不同链路，需分别处理；token 只存凭据管理器，禁止写进文档/仓库；不要用真实 token 做测试。**

## 9. Trae / DSH 共用机制与本机操作说明

- **唯一规则文档**：`C:\Users\31384\Documents\trae_projects\v b\AGENTS.md`（即本文件，git 仓库内，随仓库走）。**改规则只改这一个文件**，Trae 与 DSH 下次会话自动读取，无需同步；不要在任何其他位置再写规则正文。
- **加载链路（均已核对）**：
  - Trae 3.4.7：项目根 `AGENTS.md` 自动纳入规则上下文（设置 `AI.rules.importAgentsMd` 默认 true，本机未关闭）；原 `.trae\rules\工程规范.md` 已合并删除，避免同一规则被注入两遍。
  - DSH `0.2.1-rc.5`（2026-10-31 实测，桌面端内核，nightly 自动升级）：`dsh-agent-instructions` 加载 ① `$DSH_HOME/AGENTS.md`（本机已改为指向本文件的指针）② 项目根（含 `.git` 的目录）→ cwd 链上的 `AGENTS.md` / `CLAUDE.md`（再叠加 `.local` 变体），单文件上限 1 MB；本文件在项目根，自动加载。
- **跨工作区**：本文件只在 `v b` 工作区自动生效。在其他工作区做 DSH/Trae 任务时，全局指针会提示读取本文件；若希望那些工作区也自动生效，可在其根目录放一份 `AGENTS.md`，但本机仍以本文件为主版本。
- **工作目录默认** `C:\Users\31384\Documents\trae_projects\v b`；该目录含 `.git`，即 DSH 的「项目根」。
- **权限模式**：本机 profile 默认预设 `danger-full-access`（`~/.dsh/profiles/desktop/cordis.patch.yml` 的 `defaultPreset`），文件沙箱不限制；本会话审批提示禁用，需要审批的动作直接失败——**不要调用 `sandbox_permissions` 请求提权**。
- **插件与配置位置**：`C:\Users\31384\.dsh\profiles\desktop\`（桌面 App 使用）与 `...\profiles\web\`（`dsh web` / `dsh-start.bat` 使用），各含 `cordis.patch.yml`、`package.json`（`dsh.profile.bundles`）、`pnpm-lock.yaml`、`cordis.yml`；另 `settings.yaml` **实测不存在**（仅 `settings.yaml.imported`，导入遗留；设置覆盖在 profile `cordis.patch.yml` 与界面）。插件统一用 `dsh plugin --profile <desktop|web> add|remove <包>` 管理（走桌面端自带 CLI，宿主要求 0.2.x；安装成功会自动写入 `dsh.profile.bundles`）。**升级 DSH 走桌面端自动更新（nightly）；`npm install -g @deepseek-ai/dsh` 只更新后备那份 0.1.1-rc.2，对 `dsh` 命令无影响**。当前已装（2026-11-10 23:1x 实测）：两个 profile 均为 `dsh-cost-meter@1.9.62`（2026-10-31 由 1.9.41 升到 1.9.46，2026-11-10 23:1x 再升到 1.9.62，界面在「设置 → 费用」）；`desktop` profile 另装 `@deepseek-ai/dsh-subagent-codex` 与 `dsh-subagent-claude-code@0.2.1-rc.5`（15:0x 从 rc.3 升级，与内核匹配、`plugin_manager` 中 4 条 active）；`@dsh-pet/bridge@0.2.0`（link 到桌宠内置插件目录）也已写入两个 profile 的 dependencies/bundles——`desktop` 因桌宠安装器 `pnpm add` 300s 超时，bundle 条目为人工补齐（**不等价于正常安装，见 §8 教训**），2026-10-31 `plugin_manager` 实测 `include:dsh-pet-bridge` active；`desktop` profile 的 `cordis.patch.yml` 已配置官方插件市场索引源 `https://dshopen.org/index.json`（`- id: plugin-market` 覆盖项，2026-10-28 加；索引插件数随 `dshopen.org` 更新变化，2026-10-28 当时为 911 个）；`web` profile 原 `dsh-damage-pulse@4.0.0`（peer 仅覆盖 0.1.x，与 0.2.x 不兼容）已于 2026-10-25 移除，其账本 `~/.dsh/data/dsh-token-monitor/usage.jsonl` 保留，备份与回退见工作区 `任务-dsh插件调整-2026-10-25\`。
- **工具差异**：本机**没有** `check_win_bat_standards` 工具（原机器自建插件未迁移），`.bat`/`.ps1`/`.vbs` 编码校验一律手动执行（见下一条）；DSH 侧视觉验收用 `read_image`、交付展示用 `present`、并行任务可用 Agent Teams / `subagent` / `workflow`，任务与技能目录匹配时先调用 `skill`（本机提供 office 系列、cordis 插件开发、dsh-badge 等技能）。
- **桌面窗口查看工具（2026-10-29 新增）**：`工具\窗口查看.ps1`（UTF-8 BOM + CRLF、源码纯 ASCII；实测夸克 7.4.2.1020 被遮挡时 PrintWindow 仍可截、UIA 提取 98 条文字/151 个元素）。Actions：`List`、`Shot`（`-Title` 子串或 `-ProcId`；默认输出 `工具\截图\`）、`Text`（唯一文字列表，`-Out` 存 txt）、`Tree`（元素+矩形+可用 Pattern）、`Activate`、`Invoke -Name`（按无障碍名点击，无 Pattern 时回退中心点点击）、`Click -X -Y`、`Send -Keys`。用法与强制场景见 §6「桌面/已打开窗口：先看再答」；截图是临时物，交付后清理。
- **浏览器自动化（Edge CDP + Playwright，2026-10-29 新增）**：`工具\浏览器\`——`start-edge.ps1` 用独立 profile（`%LOCALAPPDATA%\DSH\edge-automation-profile`，不动日常 Edge）启动带 `--remote-debugging-port=9222` 的 Edge（`-Headless` 无头、`-Stop` 停止、端口占用时复用）；`browser.mjs` 用 playwright-core（1.64.1，本地 `node_modules`）连 CDP，动作：`status`/`list`/`goto`/`shot`/`text`/`html`/`click`/`type`/`eval`/`close`。实测 `Edg/156.0.4314.50`：启动/连接/导航/截图/填表/点击/读字/eval/关闭全部通过。常用：
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "工具\浏览器\start-edge.ps1" -Url "https://example.com"   # 或加 -Headless
  node "工具\浏览器\browser.mjs" goto --url "https://example.com" --shot ".\shot.png"
  node "工具\浏览器\browser.mjs" click --text "登录" ; node "工具\浏览器\browser.mjs" text
  node "工具\浏览器\browser.mjs" close            # 或 start-edge.ps1 -Stop
  ```
  **安全**：CDP 无鉴权、仅绑 127.0.0.1；不要用它处理高敏感账号，禁止暴露局域网，用完 `-Stop`；网页站点操作用本工具，桌面客户端窗口用 `工具\窗口查看.ps1`；详见 `工具\浏览器\README.md`。
- 改 `.bat`/`.cmd`/`.vbs` 后**必须立即**手动校验，不合规立即修复后重存：
  ```powershell
  $p = "x.bat"
  $b = [System.IO.File]::ReadAllBytes($p)
  "BOM: $($b[0..2] -join ',')"                                    # 不得为 239,187,191
  $t = [System.Text.Encoding]::GetEncoding(936).GetString($b)
  "CRLF: $(([regex]::Matches($t,"`r`n")).Count) / LF: $(([regex]::Matches($t,"`n")).Count)"  # 两者应相等
  ($t -split "`r`n")[0]                                           # 应为 chcp 936 >nul
  ```
- 改 `.ps1` 后必须验证有 UTF-8 BOM；改 `.vbs` 后必须验证无 BOM：
  ```powershell
  # .ps1 前 3 字节应为 239,187,191（UTF-8 BOM）；.vbs 应无任何 BOM
  [System.IO.File]::ReadAllBytes("x.ps1")[0..2] -join ','
  [System.IO.File]::ReadAllBytes("x.vbs")[0..2] -join ','
  ```
- **GitHub 仓库（2026-10-31 推送）**：`https://github.com/1-zh335/v-b`（公开，分支 `main`）；本地 `origin` 已配置；令牌（classic、`repo`、无过期）存于 Windows 凭据管理器，之后 `git push origin main` 免输入。若 `github.com` 连不上，按 §1/§8 换成当前可用 IP（`git config --global http.curloptResolve "github.com:443:<IP>"`）再试；远程只收文档/工具/小体积证据，大文件由 `.gitignore` 排除；2026-11-09 已重写历史移除约 31MB 旧截图/PDF/jar/bin/class/素材（本地保留，远端 HEAD `39cb981`），仓库 pack 约 1.76MiB。
- **维护铁律**：`.trae\rules\`（该目录已于 2026-10 删除，若重建只许放指针）、`C:\Users\31384\.trae-cn\user_rules\`、`C:\Users\31384\.dsh\AGENTS.md` 三处只允许放指针（说明"规则已统一到工作区根 AGENTS.md"），不得再写规则正文；改规则 = 只改本文件。

## 10. 文档维护与自检（2026-10-31 新增）

- 本文件的**版本字面值会漂移**（DSH nightly 自动升级、Edge 自动更新、插件版本更新）。引用前先核，别照抄旧值：
  ```powershell
  dsh --version
  Get-Content "$env:LOCALAPPDATA\Programs\DeepSeek Harness\resources\runtime\primary-runtime\runtime.json" -Raw | ConvertFrom-Json | Select-Object desktopVersion, node, pnpm, python
  (Get-Item "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe").VersionInfo.ProductVersion
  ```
- **改环境必须同步改文档**：升级 DSH/Edge、增删插件、安装/删除工具后，更新 §1/§9 对应行，并在页首「最后修订」写日期与变化；不允许「只改操作、不改文档」
- **大改后自检清单**：§1 列出的绝对路径逐一 `Test-Path`；§9 提到的工具文件存在；三处指针文件仍在；`git status` 无意外改动；本文件的示例命令至少抽 1 条实际跑通
- 本文件写下的流程与代码同等对待：**必须可执行、可验证**；无法验证的写法参照 §6 承诺纪律
