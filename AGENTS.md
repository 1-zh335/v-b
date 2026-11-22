# AGENTS.md — 本机 DSH/Trae 共用工程规范（唯一规则正文）

> **本机唯一规则正文**：`C:\Users\31384\Documents\trae_projects\v b\AGENTS.md`（工作区根，即 DSH 项目根；Trae 与 DSH 都加载）。
> **生效范围**：本工作区（`v b`）内所有 DSH 会话与 Trae 项目会话；离开本工作区时按下方「指针」规则处理。
> **加载机制**：DSH 先加载用户级 `$DSH_HOME/AGENTS.md`（本机为**指针**，只给路径不含规则正文）→ 再加载「项目根 → 当前工作目录」链上的 `AGENTS.md`/`CLAUDE.md`（及 `.local` 变体）；本工作区含 `.git`，项目根即工作区根。Trae 通过 `AI.rules.importAgentsMd`（已显式设 `true`）自动加载项目根 `AGENTS.md`，用户级 `~/.trae-cn/user_rules/工程规范.md` 只是指针。
> **优先级**：用户直接指令 > 项目级 `AGENTS.md`（本文件，更具体） > 其他指针/说明。本文件不覆盖系统/用户的直接指令。
> **最后修订**：**2026-11-22**（2026-11-22 补记：完成 GitHub CLI 登录，账号 `1-zh335`，token scopes `repo`/`read:org`/`gist`，keyring 存储；审阅与整理：复核 DSH 已自动升级到 `0.2.2-rc.5`、subagent 同步 rc.5；把两个 Uncle小说快捷方式全部移入 `任务-uncle-novel优化-2026-10-25\` 并补充「快捷方式污染桌面」教训；更新 §0 版本/插件/HEAD 字面值与技能核验；以网盘 39,496 B（2026-11-16）与 44,935 B（2026-11-17）两版为骨架，环境事实按本机实测重写；当晚从上游安装 10 个第三方技能并通过 DSH 技能目录发现验证；同日修复技能运行前置（Playwright/Edge、gh、yarn）与 Windows/DSH 兼容问题）。
> **维护铁律**：规则正文只改本文件；`$DSH_HOME/AGENTS.md`、`~/.trae-cn/user_rules/工程规范.md` 仅允许放**指针**（路径说明，不写规则正文）；禁止再建其他规则副本。

---

## 0. 本机事实核对表（2026-11-22 复核）

以下为**实测**值。⚠️ 版本号会漂移（DSH nightly、Edge、夸克自动更新），**引用前先核**（命令见下方核对片段）。

| 项目 | 实测值 |
| --- | --- |
| 用户 / 权限 | `MOSS\31384`，**标准用户**（`IsInRole(Administrator)=False`）；需要管理员的操作直接说明并请用户执行，不要反复尝试提权 |
| 操作系统 | **Windows 11 家庭版 Insider Preview 中文版** `10.0.26340`，64-bit |
| 时区 | China Standard Time（UTC+8） |
| 控制台代码页 | DSH 工具进程内 **65001（UTF-8）**；但 `.bat`/`.cmd` 文件本身按 §2 仍用 **GBK + CRLF + `chcp 936 >nul`** |
| PowerShell | DSH 的 `pwsh` 工具实测 **Windows PowerShell 5.1**（`5.1.26100.9233`）；`ExecutionPolicy=Unrestricted`，仍统一用 `powershell -NoProfile -ExecutionPolicy Bypass -File "x.ps1"` 执行脚本；**避免 PS7 独有语法** |
| 默认工作目录 | `C:\Users\31384\Documents\trae_projects\v b`（**路径含空格**，命令引用必须加引号） |
| 项目根 | 工作目录含 `.git` → DSH 项目根 = 工作区根；规则加载链 = `$DSH_HOME\AGENTS.md`（指针）→ 项目根 `AGENTS.md`（正文） |
| DSH 桌面端 | **`0.2.2-rc.5`**（2026-11-19 复核：exe/runtime/CLI 均 rc.5；2026-11-18 19:34 由 rc.3 自动升级到 rc.5；nightly 自动更新；精确值以 `dsh --version` 与 `runtime.json` 为准） |
| DSH 安装目录 | `C:\Users\31384\AppData\Local\Programs\DeepSeek Harness\`；主程序 `...\DeepSeek Harness.exe` |
| DSH CLI | `...\resources\runtime\cli\bin\dsh.cmd`（PATH 首位，裸 `dsh` 即此；npm 全局 `@deepseek-ai/dsh@0.1.1-rc.2` 仍装但排在 PATH 之后、当前不生效） |
| DSH_HOME | `C:\Users\31384\.dsh` |
| profiles | **只保留 `desktop`**（桌面 App）；`web` profile 已于 2026-11-18 清理并归档到 `~\.dsh\profiles-archive\web-20261118`（用户只要桌面版，不要重装/启用 `dsh web`） |
| DSH 运行时 | Node **v24.21.0**、pnpm **11.28.5**、Python **3.12.14**（`...\resources\runtime\primary-runtime\dependencies\`） |
| 系统 Node/npm | Node **v26.7.0** / npm **11.19.0**（`C:\Program Files\nodejs\`；npm 全局前缀 `C:\Users\31384\AppData\Roaming\npm`，已装 `@deepseek-ai/dsh@0.1.1-rc.2`、`pnpm@11.24.0`）。与 DSH 自带运行时**双版本并存，勿混用** |
| 系统 Python | **3.12.10**（`C:\Users\31384\AppData\Local\Programs\Python\Python312\python.exe`，pip 25.0.1；`WindowsApps` 商店占位不遮蔽） |
| git / bash / curl | git **2.55.0.windows.3**（`C:\Program Files\Git\cmd\git.exe`）；bash `C:\Program Files\Git\bin\bash.exe`；curl 8.21.0（`C:\Windows\System32\curl.exe`） |
| 浏览器 | Edge **157.0.4341.60**（`C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`，唯一常用；**未装 Chrome**）；夸克浏览器 **7.4.7.1036**（`C:\Program Files\Quark\quark.exe`，Chromium 内核，PrintWindow/UIA 可用） |
| Trae | `C:\Users\31384\AppData\Local\Programs\Trae CN\Trae CN.exe` **3.4.20**；已显式开启 `AI.rules.importAgentsMd=true`，项目根 `AGENTS.md` 自动生效 |
| 屏幕 | 1920×1080 @150% 缩放；截图前必须 DPI 感知（`工具\窗口查看.ps1` 已处理） |
| 已装 DSH 插件（desktop） | `dsh-cost-meter@1.9.62`；`@deepseek-ai/dsh-subagent-codex@0.2.2-rc.5`；`@deepseek-ai/dsh-subagent-claude-code@0.2.2-rc.5`；`@dsh-pet/bridge@0.2.0`（link）；插件市场索引 `https://dshopen.org/index.json`。精确值以 `~/.dsh/profiles/desktop/package.json` 为准 |
| 桌宠 | 已安装 **v4.4.0**（`%LOCALAPPDATA%\Programs\dsh-pet-standalone-webm-chat\`，运行中，HKCU Run 自启）；`harness_autostart` 已于 2026-11-18 关闭（不再自动启动 `dsh web`）；`@dsh-pet/bridge` 联动保留 |
| 夸克网盘 Skill | `~\.dsh\skills\quarkclouddrive`（**1.0.25，已授权**，账号「时雨既溯」/SVIP+）；用 DSH 自带 node 执行 `scripts\quark-drive.cjs` |
| 用户级技能（第三方） | **已安装 10 个**（2026-11-22 复核）：`cache-components`、`code-reviewer`、`find-skills`、`fix`、`frontend-code-review`、`frontend-design`、`fullstack-developer`、`pr-creator`、`update-docs`、`webapp-testing`；另有 `quarkclouddrive`（1.0.25）。来源/文件数见 §9.6；DSH 会话技能目录已刷新出现全部 10 个名称（2026-11-19 复核） |
| 可选伴生技能 | `next-dev-loop`（2026-11-22 安装，来源 `vercel/next.js` canary `skills/next-dev-loop`，1 个 SKILL.md）；配合 `cache-components` 使用；要求 Next.js 16.3+ Turbopack；`agent-browser` 0.43.0 已安装并用本机 Edge 冒烟通过（`AGENT_BROWSER_EXECUTABLE_PATH` 指向 Edge，无需 Chrome） |
| 技能运行依赖 | Python Playwright **1.65.2**（已安装；Edge channel + localhost `--no-proxy-server` 冒烟通过）；GitHub CLI **2.105.0**（**已登录账号 `1-zh335`**，token scopes `repo`/`read:org`/`gist`，keyring 存储；`gh auth setup-git` 已执行）；Yarn **1.22.22**（已安装）；详见 §9.6 |
| 本地工具 | `工具\窗口查看.ps1`（16,485 B，UTF-8 BOM+CRLF）；`工具\浏览器\`（Edge CDP + playwright-core 1.64.1）；`push-to-github.bat`/`.ps1`；`dsh-start.bat` 已于 2026-11-18 归档（网页版清理，不再使用） |
| 不存在的工具 | ❌ `check_win_bat_standards`；❌ `wmic`；❌ Chrome；❌ `dsh web`（本机不再使用网页版） |
| 网络 | `github.com` 偶发被阻断（2026-11-17 晚所有候选 IP 超时、2026-11-19 再次超时；`api.github.com` 通常可达）；可用 `git config --global http.curloptResolve "github.com:443:<IP>"` 轮换 IP，或改走 GitHub API contents / `codeload.github.com`；token 只存 Windows 凭据管理器，禁止写入文件/文档/日志 |
| 权限模式 | **`danger-full-access` + 审批禁用**：文件沙箱不限制，需要审批的动作自动失败——**不要请求提权/`sandbox_permissions`** |
| 默认模型 | 以 DSH 桌面端设置为准（本会话为 `deepseek-flash`，Provider `deepseek-account`；子代理可用模型见 profile `cordis.patch.yml`） |
| 工作区 git | 分支 `main`，HEAD `c7821d0`（2026-11-22），远程 `origin=https://github.com/1-zh335/v-b.git`；已推送、工作区干净（2026-11-22 复核）；后续提交以 `git log` 为准 |

**核对片段**（一次跑完，输出即上表依据）：

```powershell
$PSVersionTable.PSVersion; (Get-ExecutionPolicy).ToString(); [Console]::OutputEncoding.CodePage
(Get-CimInstance Win32_OperatingSystem).Caption; (Get-CimInstance Win32_OperatingSystem).Version
$env:DSH_HOME; dsh --version
$d = "$env:LOCALAPPDATA\Programs\DeepSeek Harness\resources\runtime\primary-runtime\dependencies"
& "$d\node\bin\node.exe" -v; & "$d\python\python.exe" -V
& "C:\Program Files\nodejs\node.exe" -v; & "C:\Program Files\nodejs\npm.cmd" -v
& "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe" --version; & "C:\Program Files\Git\cmd\git.exe" --version
(Get-Item "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe").VersionInfo.ProductVersion
(Get-Item "C:\Program Files\Quark\quark.exe").VersionInfo.ProductVersion
```

> 其他机器/旧文档里的路径（如 `F:\DeeoSeek`、`E:\论文`、`C:\Users\Administrator.DESKTOP-KJI2KU0`、`C:\Users\d59049`、`C:\Users\14510`、`D:\Vibe Coding`、`C:\Program Files\Python312`）在本机**不存在**，出现即视为过期内容，不得照抄。

---

## 1. 语言与交互

- **始终用中文回复**（含代码注释、文档、提交说明）。
- **不确定就问，不要假设**：给出多种解释而非默默选一个；有更简单方案直接指出；困惑时停下问。
- **破坏性操作先说清楚**（删除什么、覆盖什么、影响范围），再执行；是否备份按 §6「备份与清理」分级判断——**能重建/可从来源恢复的默认不备份**，避免堆积冗余副本。
- 用户说「桌面已经打开了 X / 我这边显示 / 在窗口里」→ 先看窗口（§6），不要凭日志/接口推断（历史教训见 §8）。
- 交付前自检：每个「已…」都有证据吗？有没有把推断写成事实？有没有承诺未来行为？

---

## 2. 脚本编码规范（最高优先级，违反必致中文乱码 / 解析错误）

| 文件类型 | 编码 | 行尾 | 其他要求 |
| --- | --- | --- | --- |
| `.bat` / `.cmd` | **GBK / ANSI(936)** | **CRLF（必须）** | 前两行内必须有 `chcp 936 >nul`（推荐第 1 行 `@echo off`）；**禁止 `chcp 65001`**；不得有 UTF-8 BOM |
| `.ps1` | **UTF-8 with BOM** | CRLF | 用 `powershell -NoProfile -ExecutionPolicy Bypass -File "x.ps1"` 执行 |
| `.vbs` | **GBK 无 BOM** | CRLF | `chcp` 是 cmd 内部命令，写进 `.vbs` 会语法报错，不做首行检查 |
| 其他文本（`.md`/`.json`/`.js`/`.ts`/`.py` 等） | **UTF-8 无 BOM** | LF | — |

### 硬约束

- **绝对禁止**把含中文的 `.bat`/`.cmd` 写成 UTF-8（无 BOM + `chcp 65001` 会让中文 `::` 注释报 `'xxx' is not recognized`）。
- Write 工具输出的是 **UTF-8 无 BOM + LF**，写完 `.bat`/`.cmd`/`.vbs` 后**必须立即转码**：

  ```powershell
  $p = "文件路径"
  $t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)                  # 刚写完：按 UTF-8 读
  $t = $t -replace "`r`n", "`n" -replace "`n", "`r`n"                                   # 先归一化再转 CRLF
  [System.IO.File]::WriteAllText($p, $t, [System.Text.Encoding]::GetEncoding(936))       # 存为 GBK
  ```

- `.ps1` 需 UTF-8 **BOM** + CRLF，同样要转一次：

  ```powershell
  $p = "x.ps1"
  $t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
  $t = $t -replace "`r`n", "`n" -replace "`n", "`r`n"
  [System.IO.File]::WriteAllText($p, $t, [System.Text.UTF8Encoding]::new($true))        # $true = 带 BOM
  ```

- **二次处理已转码文件时读取编码必须跟着改**：GBK 用 `GetEncoding(936)` 读，不要再用 UTF-8 读坏；读 GBK 乱码时用 `[System.IO.File]::ReadAllText("path", [System.Text.Encoding]::GetEncoding(936))`。
- **一次性脚本最省事的做法是全程纯 ASCII**，中文用 `[char]0xXXXX` 转义（如 `"DSH $([char]0x542F)$([char]0x52A8).lnk"` = `DSH 启动.lnk`），从根上避开 BOM/GBK 坑。
- **中文控制台输出不要直接捕获，落文件再按 GBK 读**：`.bat`/`.cmd` 等 GBK 程序的中文输出经工具管道捕获会变 `[OK] �����������`，设置 `[Console]::OutputEncoding` 也修不好：

  ```powershell
  cmd /c "`"$bat`" > `"$out.txt`" 2>&1"
  [System.IO.File]::ReadAllText("$out.txt", [System.Text.Encoding]::GetEncoding(936))   # 中文正确
  ```

### 转码后立即校验（本机无 `check_win_bat_standards` 工具，用下面片段代替）

```powershell
$p = "x.bat"                                   # .cmd 同理
$b = [System.IO.File]::ReadAllBytes($p)
$bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
$t = [System.Text.Encoding]::GetEncoding(936).GetString($b)
$crlf = ([regex]::Matches($t, "`r`n")).Count
$bareLF = ([regex]::Matches($t, "(?<!`r)`n")).Count
$head = ($t -split "`r`n")[0..1] -join ' | '
"BOM=$bom  CRLF=$crlf  裸LF=$bareLF  前两行='$head'"
# 合格判据：BOM=False 且 裸LF=0 且 前两行含 chcp 936 -> 三项全中才算通过
```

- `.ps1` 只校验 BOM：`[System.IO.File]::ReadAllBytes("x.ps1")[0..2] -join ','` 应为 `239,187,191`。
- `.vbs` 只校验 **GBK 且无 BOM**。

---

## 3. PowerShell / 批处理语法规范

- 本机 DSH 工具是 **Windows PowerShell 5.1**：**避免 PS7 独有语法**（`&&`、`??`、三元 `? :`、`-Parallel`）；命令分隔用 `;` 或换行，**绝不用 `&&`**。
- **禁止** `powershell -Command "…"` 内嵌含 `$` 变量的多行脚本（外层会先展开 `$var`，内层脚本被破坏，如 `$shell.CreateShortcut()` 变 `.CreateShortcut()` 报 `Expected expression`）→ 把脚本写成 `.ps1` 用 `-File` 执行。
- PowerShell 脚本内不要经 `cmd.exe` / `command.exe` 间接执行命令；路径含空格必须加引号；`start` 命令路径含空格用 `start /d "path"`。
- 批处理括号块内用 `!errorlevel!` 必须先 `setlocal EnableDelayedExpansion`，且先存变量再比较：

  ```bat
  setlocal EnableDelayedExpansion
  set "ERR=!errorlevel!"
  if "!ERR!"=="0" ...
  ```

- **调用外部命令（尤其 `.cmd` shim，如 `dsh.cmd`）传参时禁止用 `!VAR!` 延迟展开**：实测 `dsh web --port !PORT!` 会把 `!PORT!` 原样传入（报 `--port must be a number, got "!PORT!"`），而 `echo !PORT!` 却正常 —— 顶层已 `set` 的变量改用 `%VAR%` 普通展开。
- 时间戳用 `Get-Date`；**不要用 `wmic`**（本机不存在）。
- 正则/编码/字节级判断优先用 `[regex]`、`[System.IO.File]`、`[System.Text.Encoding]`，而不是外部命令。
- 需要长期运行的服务/端口占用检查用 `Get-NetTCPConnection -LocalPort <port>` / `Test-NetConnection`，不要依赖 `netstat | findstr` 的本地化输出。

---

## 4. 工具链：绝对路径优先，DSH 运行时与系统运行时分开

⚠️ 本机**同时存在**两套 Node 与两套 Python：DSH 自带运行时（桌面端内置）与系统级运行时。**跑 DSH 插件/DSH CLI 用自带的；跑普通项目脚本用系统级**，不要混用，也不要靠 PATH 猜。

```powershell
# DSH 自带运行时（与桌面端内核配套）
$d    = "$env:LOCALAPPDATA\Programs\DeepSeek Harness\resources\runtime\primary-runtime\dependencies"
$node = "$d\node\bin\node.exe"
$pnpm = "$d\pnpm\bin\pnpm.mjs"
$py   = "$d\python\python.exe"

# 系统级运行时（普通项目 / 当前 DSH 工具进程的 PATH）
$sysNode = "C:\Program Files\nodejs\node.exe"
$sysNpm  = "C:\Program Files\nodejs\npm.cmd"
$sysPy   = "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
$git     = "C:\Program Files\Git\cmd\git.exe"
$bash    = "C:\Program Files\Git\bin\bash.exe"
```

- `.bat` 里调用 node 必须写**绝对路径**；不要用 `start` 调 node/npm（子 cmd 环境会丢 PATH 继承）。
- DSH 插件的安装/升级统一用 `dsh plugin --profile desktop add|remove`（内部用 DSH 自带 pnpm），不要用系统 npm 装 DSH 插件。
- 首次使用前 `Test-Path` 确认路径存在；DSH 升级后以安装目录 `resources\runtime\primary-runtime\dependencies\` 下实际目录为准。
- 缺库：Python 用 `& $sysPy -m pip install <包>` 或 `& $py -m pip install <包>`；Node 项目用 `& $sysNpm install` 或 `& $node $pnpm add <包>`（DSH profile 内）。
- Vite 等大项目 OOM 时可加 `--max-old-space-size=4096`。
- 需要读 DSH 安装包 `app.asar` 内容时，用 **Electron 可执行文件 + `ELECTRON_RUN_AS_NODE=1`**（`...\DeepSeek Harness.exe` 即 DSH 的 `DSH_NODE_EXECUTABLE`），普通 node 不可遍历 asar。
- Git Bash 在 `C:\Program Files\Git\bin\bash.exe`（`bash scripts/install.sh` 等场景用）；curl 在 `C:\Windows\System32\curl.exe`。
- Trae 自带 Node 不作为通用工具链；Trae 角色是编辑器/规则读取方，不是运行环境。

---

## 5. 目录与项目结构约定

- 默认工作目录 `C:\Users\31384\Documents\trae_projects\v b`（**含空格**）；**新任务在当前目录下建中文命名子文件夹**（如 `任务-DSH升级-2026-11-17`）。任务目录/文件名可用中文，但**脚本内部的路径、变量名用英文**，减少编码坑。
- 写功能代码**之前**先生成项目文档（`README.md` / `DESIGN.md`）说明目标、文件结构、逻辑流程。
- 临时测试文件/截图/下载物**用完即删**；测试服务进程用完停止。
- 打包交付类项目可按交付形态分目录：`1-开箱即用`（绿色版）、`2-安装器`（setup）、`3-单文件exe`；非打包任务不适用。
- **版本管理**：工作区是 git 仓库（分支 `main`，远程 `origin=https://github.com/1-zh335/v-b.git`）；提交/推送用 `push-to-github.bat` / `push-to-github.ps1`，推送前 `git status` 确认无敏感/大文件与临时产物。历史曾做深度整理（二进制移出历史但保留本地），**禁止 `git add -f` 强塞大文件**；截图/PDF/JAR/bin/class/字体/素材默认不入库（`.gitignore`）。
- **规则文件架构（本机特有，必须遵守）**：
  - **唯一规则正文** = 本文件 `C:\Users\31384\Documents\trae_projects\v b\AGENTS.md`（工作区根）。
  - `$DSH_HOME\AGENTS.md`（`C:\Users\31384\.dsh\AGENTS.md`）：**仅指针**，告诉 DSH 去读本文件，不写规则正文。
  - `~/.trae-cn/user_rules\工程规范.md`：**仅指针**，告诉 Trae 去读本文件，不写规则正文。
  - Trae 设置 `AI.rules.importAgentsMd=true`（已写入 `%APPDATA%\Trae CN\User\settings.json`），自动加载项目根 `AGENTS.md`。
  - **不要**在 `.trae\rules\`、`~/.agents\`、`Documents\AGENTS(1).md` 等位置再建规则副本；历史副本教训见 §8。
- **网页版已清理（2026-11-18）**：`~\.dsh\profiles\web` 已归档到 `~\.dsh\profiles-archive\web-20261118`；`dsh-start.bat` 与桌面「DSH 启动.lnk」已归档到 `任务-DSH桌面版清理-2026-11-18\归档\`；桌宠 `harness_autostart=false`。**不要再启动/重装 `dsh web`**，本机只用桌面版。
- **桌面整洁（2026-11-19 更新）**：桌面只放系统/常用应用入口；**项目/任务的快捷方式（`.lnk`/`.url`）一律放进对应工作区任务文件夹**，不要留在桌面。2026-11-18/19 已把 `Uncle小说 · 本地TXT快速阅读.lnk` 与 `Uncle小说.lnk` 都移入 `任务-uncle-novel优化-2026-10-25\`；安装器/构建脚本应在项目内生成快捷方式，验收时枚举桌面所有 `.lnk/.url` 按 TargetPath 归位。详见 `任务-桌面快捷方式整理-2026-11-18\README.md`。
- 工作区根保留：`AGENTS.md`（本文件）、`README.md`、`push-to-github.bat`/`.ps1`、`.gitignore`、`.gitattributes`、`工具/`（跨任务工具）、`任务X/`（新任务）；`dsh-start.bat` 已归档，不再放回根目录。
- 本机 `工具\窗口查看.ps1`、`工具\浏览器\`（含 `node_modules`）属可复用资产，勿随意删除。

### 审查 / 扫描时必须排除的目录

`node_modules/`、`dist/`、`.next/`、`build/`、`.git/`、`__pycache__/`、`.venv/`、`.pytest_cache/`，以及任何 `*.log`、`*.zip`、`*.7z`、`*.rar`、`*.exe`、`*.dll`。

---

## 6. 开发与测试协议

- **不要立即打包成 .exe**：先提供源码，在终端跑通、验证通过后再考虑打包。
- 出错时：分析终端输出 → 修代码 → **重跑验证**，直到稳定；失败产物删掉。
- 「本机测试通过」只对**测试过的那一份文件**成立；换机 / 重拷后必须重新验证或校验哈希。

### 视觉验收闭环（生成 → 观察 → 验证 → 优化）

- **凡用户看得见的产物（网页 / GUI / 3D 场景 / 渲染结果），验收必须包含视觉维度**：接口 200 ≠ 界面正确（拼 URL 缺 `?` 报 404、词云接口返回单字这类 bug 只有渲染出来才暴露）。
- 闭环：生成 → 运行 → **截图 → 用 `read_image` 亲自目检 → 修复 → 重截复验**，直到所见即所期；按布局/颜色/文字/交互/3D 效果逐项对照。
- 本机**只用 Edge** 无头截图（无 Chrome）：

  ```powershell
  $edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
  & $edge --headless=new --disable-gpu --no-first-run --hide-scrollbars `
    --window-size=1440,940 --virtual-time-budget=9000 `
    --user-data-dir="$env:TEMP\dsh-edge-profile" `
    --screenshot="shot.png" "http://localhost:3000/" 2>$null
  ```

  - 必须带 `--user-data-dir`（避免受日常配置干扰）；Edge 会把无关噪音打到 **stderr**，用 `2>$null` 屏蔽，**不要**当成失败。
  - 渲染慢就加大 `--virtual-time-budget`（词云 16–20s、3D 场景 30s）；WebGL/3D 可加 `--use-angle=swiftshader`。
  - SPA 无路由时给各视图加 URL 深链（如 `#cloud`、`#search=词`）以便直达截图。
  - **中文截图乱码**：命令行传 `data:` URL 或 HTML 未声明字符集时，Edge 回退到系统 ANSI（GBK）→ 中文乱码。修复：HTML 写 `<meta charset="utf-8">`，以 UTF-8 落盘后用 `file:///` 打开截图。

- **GUI 桌面应用 / 用户已打开的窗口**：运行后截窗口目检；无法自动截时请用户截图或描述所见（附失败证据）。
- **截图与测试服务都是临时验证物**：闭环结束即删除截图、停掉测试服务进程。

### 桌面 / 已打开窗口：先看再答（强制）

- **触发条件**：用户说「桌面已经打开了 X」「我已经打开了/登录了」「在窗口里」「在浏览器/夸克里看」「那个页面」「我这边显示…」，或任务对象就在已运行的 GUI/客户端/网页里 → **第一动作必须是看窗口**：不是查日志、不是打接口、不是让用户复制内容。
- 标准动作（本机路径）：

  ```powershell
  $t = "C:\Users\31384\Documents\trae_projects\v b\工具\窗口查看.ps1"
  powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action List                      # 1) 找窗口（HWND/PID/标题）
  powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action Shot -Title "夸克" -Out "shot.png"   # 2) 截图 → read_image 目检
  powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action Text -Title "夸克" -Out "page.txt"   # 3) 读文字/链接
  powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action Tree -Title "夸克"        # 4) 找可点元素
  powershell -NoProfile -ExecutionPolicy Bypass -File $t -Action Invoke -Title "夸克" -Name "下载Skill"  # 5) 点击后必须重截核验
  ```

- **证据要求**：结论必须能指出「截图文件路径 + 从截图/UIA 文字里看到的关键信息」；没看就回答 = 违规。截图含隐私（授权码/账号/聊天记录）时，交付文档必须遮挡或只记录必要字段。
- **禁止**：① 用户说窗口已打开却回答「我看不到你的屏幕」；② 未尝试工具就要求用户截图/复制；③ 用 headless 浏览器另开页面冒充「用户看到的页面」。
- **允许求助的唯一情况**：`-Action List` 找不到窗口、Shot 全黑且 `-Action Activate` 后重试仍失败、或 `-Action Text` 无任何文本；求助时必须附已执行命令与输出。
- UIA 的 `Invoke -Name` 是**子串匹配 + 取第一个匹配**：名称过短（如「知道了」）可能命中对话正文里的同名按钮 → 需要精确时先 `-Action Tree` 拿坐标，再用 `-Action Click -X -Y`。
- 能力边界：截图 = 像素级目检；UIA = 读文字/按无障碍名点击（Chromium/Electron 一般可用，纯自绘界面可能元素不全）；需要浏览器级深度自动化（批量操作/注入 JS）用 `工具\浏览器\`（Edge CDP 9222 + Playwright，见 §9）。

### 测试清理与交付固化

- 测试产物（临时文件、系统对象：计划任务/服务/注册表项/hosts 条目等）**用完即删**；删除后必须用 **≥2 种独立手段交叉核验**。中文名对象在 GBK 控制台会变乱码（如 `鐐规鐪熷疄鏃跺埢閲囬泦`），字符串匹配会**假阴性**：删除优先用**对象引用**（`Unregister-ScheduledTask $task`），核验用**非 ASCII 正则枚举 + 全量列表抽查**。
- 不得声称「已清理 / 已核验」，除非：清理动作成功 **且** 核验手段已验证可靠 **且** 结果为空。「应该删了」的推断不算核验。
- 交付物必须**版本固化后打 zip** 交付，禁止让用户直接复制仍在维护的工作区目录；安装脚本要有明显成功标志（如 `[OK] 已注册…`）并在文档写明「看到什么才算成功」；用户报失败先问输出再定位版本。
- 仅适用特定版本 / 场景的脚本（如「仅 v2.1」SQL），**文件名与首行必须注明适用范围与误用后果**。

### 备份与清理（精简原则，2026-11-16 修订）

- **默认不备份**：能重新生成或从来源恢复的一律不做本地备份——源码/脚本产物、临时与测试文件、可从网盘/仓库/安装包再取的资产、已有版本控制或远端副本的数据；工作区内处于测试阶段的文件同样不备份。**不要「改之前先复制一份」当默认动作**，否则机器里会堆满 `*.bak` / `xxx(1).md` 式重复内容。
- **只在必要时做最小快照**（三条同时满足才做）：① 本机没有其他副本、也无法再生成；② 本次改动/删除不可逆；③ 内容有保留价值。快照只复制**受影响的文件/目录**（不整目录无差别复制），统一放一个归档位置（如 `任务X/备份/<主题>-<日期>/`），并在任务 README 登记来源、范围与**保留期限**（默认 30 天）。
- **删除前先判断可恢复性**：能从网盘/仓库/安装包/版本库重新拿回的，直接删（确认来源仍有效即可），不在本地留副本。
- **禁止**：整目录复制、每次小改都备份、同一对象重复快照、散落的 `.bak`/`(1)` 副本、无限期堆积。
- **到期清理**：任务收尾时检查备份目录，过期或无用途的备份删除；删除前确认主对象已定稿或有正式留存。

### 承诺与交付纪律（防过度承诺）

- **状态词只有四种，且必须带证据**：`已完成`（命令/操作 + 输出或 exit code + 证据路径/截图 + 时间，缺一只能降级）、`部分完成`（逐项列已做/未做）、`未开始`、`被阻塞`（原因 + 已尝试步骤 + 缺什么）。
- **没有证据时禁用词**：`已生效`、`已搞定`、`没问题`、`理论上`、`应该`、`大概`、`基本可以`、`全部`、`无需重启`、`等价于`、`完全一致`、`以后会自动`；改写成「未实测（依据：文档/日志/推断）」+ 验证方法。
- **配置写入 ≠ 已生效**：文件/注册表/依赖写成功只算「已写入」；「已生效」必须有运行时证据（进程、日志、界面、接口返回、`plugin_manager` active 等）。
- **命令超时/失败 ≠ 等价完成**：超时、非 0 退出、部分实例失败必须原样报告，不得用「已写完 / 基本完成 / 其余等价」抹平。
- **第三方软件行为**只能引用官方文档或本机实测，并写清版本；仅文档依据写「按文档（未实测）」。
- **禁止预测类承诺**（`下次启动会…`、`以后自动…`）；只能写「待验证假设 + 验证方法」。
- 任务 README 的「验证结果」只放有证据的条目；未验证内容单列「未验证 / 待确认」，不得混写。
- **说过头话后的补救**：立即在任务 README 追加「事后核对」小节，标明当时哪些未验证、现在是否已验证；不删原文。

---

## 7. Karpathy AI 编码原则

简单任务可灵活运用以下原则，不必机械逐条执行。

1. **Think Before Coding** — 不假设；不确定就问。给出多种解释而非默默选一个。直接指出更简单的替代方案。困惑时停下问。
2. **Simplicity First** — 最少代码。禁止：额外功能、一次性抽象、未要求的可配置性、不可能场景的错误处理。200 行能压到 50 行就重写。问自己：资深工程师会觉得这过度设计吗？
3. **Surgical Changes** — 不碰相邻代码/注释/格式。不重构没坏的代码。匹配现有风格。提死代码但不删。只移除自己改动产生的孤儿（import/变量/函数）。每行改动必须能追溯到用户需求。
4. **Goal-Driven Execution** — 定义可验证目标。「加校验」→「先写测试再让它过」；「修 bug」→「先写复现测试再修」。多步任务列出步骤 + 对应验证检查点。
5. **注释** — 生成代码时加函数级注释（作用、关键参数、返回）。

---

## 8. 铁律与历史教训（务必避免重蹈）

- **改生产库表结构前必须验证旧程序兼容性**：给产线正在使用的表加/删/改列、改索引前，必须读旧程序对该表的**全部读写 SQL** 验证兼容性，按 §6 做**最小快照**并写清**回退语句**（只备份受影响的表/脚本，登记保留期，不整库复制）。曾因忽略「v1 的 INSERT 是隐式全列 7 值」，加任意列即报「列数不匹配」导致产线停摆。
- **改工作区之外的用户生产 / 交付目录前，先判断是否可恢复**：可重建/有来源的**不备份**；不可再生成且影响不可逆的，才按 §6 做**最小快照**（只备受影响文件、集中一处、限期清理），并写清回退方法。工作区内文件默认不备份。
- **升级基础组件（数据库驱动等）前先确认目标环境兼容性**：产线数据库版本与驱动版本可能不匹配，**驱动不随软件功能升级**，以产线验证版为准。
- **无法本机实测的结论必须标注「未经实测」**，并用替代方式复现验证；**禁止把推断写成「已验证 / 不影响」**。
- **二进制 / IL 提取的路径、格式、分隔符必须逐字节解码 + 与真实样本双验证**（曾把「C:\点检记录」解成「C:\点检文件」、补零与全角冒号解错），禁止凭记忆近似。
- **视觉验收不可跳过**：曾长期以「API 回归 = 验收」交付 UI，直到用户质疑「你不是有眼睛吗」才建立截图目检链路，首轮目检即揪出 2 个接口测试测不出的 bug。
- **「桌面已打开」却被忽略**：用户两次说明桌面已打开夸克浏览器，却只用日志/接口/headless 页面推断，被质问「为什么还是没学会点进去看」。铁律：用户说窗口已打开 = 立刻 `窗口查看.ps1 -Action List/Shot/Text` 看，先看再说；看不到才求助且必须附尝试证据。
- **工具存在性/版本以 §0 为准**：`check_win_bat_standards`、`wmic`、Chrome 在本机不存在；系统 Node/npm/Python、Trae、DSH 自带运行时都存在但用途不同，勿混用或误删。需要编码校验时用 §2 的 PowerShell 片段自己实现。
- **`start` 陷阱**：`.bat` 的 `start` 在子 cmd 环境会丢 PATH 继承（曾致 `npm run dev` 失败）→ 用 node 绝对路径；`start` 路径含空格用 `start /d "path"` 加引号。
- **PowerShell 内嵌变量陷阱**：`powershell -Command "…"` 内嵌含 `$var` 的多行脚本会被外层先展开；必须写 `.ps1` 用 `-File` 执行。
- **`.ps1` 中文编码坑**：Write 工具输出无 BOM UTF-8，PowerShell 5.1 按 GBK 读取会中文乱码（`DSH 启动.lnk` → `DSH 鍚姩.lnk`）；一次性脚本用纯 ASCII + `[char]0xXXXX` 转义中文最稳。
- **批处理 `!VAR!` 调 `.cmd` shim 失效**：`dsh web --port !PORT!` 传入字面量 `!PORT!`；顶层 `set` 的变量改用 `%VAR%`。
- **规则副本教训（跨机通用）**：同一份规范曾存在 4 处副本（`.trae\rules\`、`~/.trae-cn/user_rules\`、`~/.dsh\AGENTS.md`、`Documents\AGENTS(1).md`），导致改一处漏三处、旧副本继续注入（如 Python 未装、Chrome 截图等过期说法）。**唯一文档 + 禁止副本**；DSH 的 Write 工具写文件会替换 inode、**会断开硬链接**，不要用硬链接/符号链接方案共享规则（符号链接还需管理员权限）。
- **过度承诺（桌宠案例，跨机通用）**：桌宠对 profile 的 `pnpm add` 实测 300 秒超时，却被写成「其余与正常安装等价」；又断言「DSH 热加载 bundle，无需重启」「下次重启也会正常加载」等未验证机制。**安装超时/部分失败就是失败，不许用「等价/已写完」抹平；机制与第三方行为没有对照实验就写「未实测」；跨版本/跨重启效果不许预测。**
- **网络排障**：不要把「网络被阻断」误判成脚本/权限问题；先测不同链路（`api.github.com`、`raw.githubusercontent.com`、`codeload.github.com`、npm registry），再决定换源/覆盖 IP；**token 只存凭据管理器，禁止写进文档/仓库/日志**，禁止用真实 token 做测试。本机实测 `raw.githubusercontent.com` / `github.com` 偶发 reset，可用 GitHub API contents 或 `codeload.github.com` tar.gz 绕行。
- **DSH 0.2.2 起的 profile 限制**：`dsh --profile desktop --dump-config` 报 `error: profile "desktop" is managed exclusively by the Electron application`（exit 1）。验证 desktop 配置改用「临时 DSH_HOME + 同 bundles 的等价 profile + node_modules junction 跑 `--dump-config`」，或只改 web profile 验证语法。**别再按旧文档直接 dump desktop**。
- **插件安装的生效标准**：命令 exit 0 ≠ 已生效；`plugin_manager` 显示 `fiberPhase: active` + GUI 面板/日志出现才算生效。优先用 `plugin_manager` 的 live 安装（不重启当前实例），CLI `dsh plugin add` 写入后通常需重启桌面端才加载。
- **授权码 / 一次性 token 处理**：不写入文件/日志/文档；CLI 输出保存前脱敏；不放进 `--session-input` 等追踪参数。夸克 Skill 授权状态写在技能目录 `deepseek\config.json`（不含授权码）。
- **版本字面量漂移**：DSH nightly 自动升级（本机 2026-11-17 由 0.2.1-rc.5 升到 0.2.2-rc.3，2026-11-18 又自动升到 0.2.2-rc.5）；Edge/夸克也会自动更新。引用版本前按 §0/§10 核对。
- **DSH 更新失败排查（2026-11-17 实测）**：更新包已下载但版本不变时，先检查更新缓存根目录是否残留旧 `installer.exe`，以及是否有多个 `DeepSeek Harness.exe` 实例（含独立 `dsh web` 实例）在跑；处理：停止全部实例 → 直接运行 `pending` 里的新版安装包 → 校验 exe FileVersion、`runtime.json.desktopVersion`、`dsh --version` 三处 → 重启桌面端。不要只反复点自动更新。
- **内核升级后必须对齐插件版本**：0.2.2-rc.3 下 subagent `0.2.1-rc.5` 报 `incompatible-version`（rows 为空）；用 `dsh plugin --profile desktop add <包>@0.2.2-rc.3` 升级，必要时重启；命令 exit 0 ≠ 已生效，以 `plugin_manager` 的 active/rows 为准。
- **快捷方式溢出桌面（2026-11-19 教训）**：项目安装器/构建脚本默认把快捷方式写到桌面；上次只移走用户点名的一个（`Uncle小说 · 本地TXT快速阅读.lnk`），另一个 `Uncle小说.lnk` 仍残留，被用户追问。**规则**：项目产物快捷方式必须生成/归档到对应任务目录；收尾时枚举桌面 `.lnk/.url`，按 TargetPath 判断属于本项目的全部移走；安装脚本应直接创建到任务目录或交付包内，不要让桌面成为「额外输出目录」。
- **网页版清理（2026-11-18）**：用户只要桌面版；`dsh web` 实例、web profile、`dsh-start.bat`/快捷方式已清理，桌宠 `harness_autostart` 已关闭。不要再按旧文档启动 web（3080/38080）。

---

## 9. DSH 运行机制与本机操作说明

### 9.1 规则加载（2026-11-19 按本机 0.2.2-rc.5 复核）

- **用户级**：`$DSH_HOME/AGENTS.md`（`C:\Users\31384\.dsh\AGENTS.md`）是**指针**，只告诉 DSH 去读工作区 AGENTS.md，不含规则正文。
- **项目级**：从「项目根」到「会话工作目录」的每一层，按 `AGENTS.md` → `CLAUDE.md` → `AGENTS.local.md` → `CLAUDE.local.md` 顺序加载（按 trimmed 内容去重，更具体者优先）。本工作区含 `.git` → 项目根 = `C:\Users\31384\Documents\trae_projects\v b`，正文即本文件。
- **Trae**：`AI.rules.importAgentsMd=true`（已显式写入 Trae 设置）→ 自动加载项目根 `AGENTS.md`；`~/.trae-cn/user_rules\工程规范.md` 仅指针。
- **预算**：单文件源码上限 **1 MiB**；每条链渲染预算 **65536 字节**；本文件 + 项目级文件之和不要逼近上限（当前文件约 51 KB 内，见 §10 自检）。
- **生效时机**：改完本文件后，**新会话/新基线**生效；当前会话已注入的内容不会热替换。Trae 若未立即生效，重启 Trae 或重新打开工作区。
- **Trae 刷新规则**：Trae 已有任务线程会沿用创建时的规则快照；改完 AGENTS.md 后必须**新建任务/会话**（或重启 Trae 后新任务）才能验证最新内容。实测 2026-11-19：旧任务仍按旧规则回答（说 §9.6 无技能内容），新建任务后正确引用最新 §9.6。
- **技能发现（2026-11-19 rc.5 实测）**：按 rank 扫描 项目根 `.dsh/skills`(100)、`.agents/skills`(200)、customSkillDirs(300)、`$DSH_HOME/skills`(400)、`~/.agents/skills`(500)、bundled(600)；每层只认 `<root>/<name>/SKILL.md` 或 `<root>/<name>.md`（不递归）；frontmatter 必须含 kebab-case 的 `name` 与 `description`，非法条目静默跳过。本机第三方技能目录为 `$DSH_HOME\skills\`（2026-11-19 已安装 10 个第三方技能 + quarkclouddrive，见 §9.6；新增目录后会话技能目录立即出现全部名称）。
- **禁止副本**：历史教训见 §8；任何情况下不要再建第二份规则正文或多余指针。

### 9.2 权限模式

- 本机 profile 默认 **`danger-full-access` + 审批提示禁用**：文件沙箱不限制、无需逐次审批；因此**更要自律**：破坏性操作先说清影响，是否备份按 §6 分级（有 git/远端/来源可恢复的默认不备份）。
- 需要审批的动作会被自动拒绝：**不要调用 `sandbox_permissions` 请求提权**，也不要请求用户批准沙箱升级。

### 9.3 profiles 与插件

- 位置：`~\.dsh\profiles\desktop\`（桌面 App）；**本机只保留 desktop**，`web` profile 已于 2026-11-18 归档到 `~\.dsh\profiles-archive\web-20261118`，不要重建、也不要再启动 `dsh web`。
- 每个 profile 含 `package.json`（`dsh.profile.bundles`）、`cordis.patch.yml`、`pnpm-lock.yaml`、`cordis.yml`；用户配置只改 `cordis.patch.yml`（`cordis.yml` 是空入口列表，勿手改）。
- 插件管理：优先 `plugin_manager` 工具（live 安装/启停/查询 active）；CLI `dsh plugin --profile desktop add|remove <包>` 写入后通常需重启桌面端才加载。`dsh plugin list` 无内置子命令，用 `dsh plugin --profile desktop list --depth=0`。
- 当前已装（desktop）：`dsh-cost-meter@1.9.62`、`@deepseek-ai/dsh-subagent-codex@0.2.2-rc.5`、`@deepseek-ai/dsh-subagent-claude-code@0.2.2-rc.5`、`@dsh-pet/bridge@0.2.0`（link）；插件市场索引 `https://dshopen.org/index.json`。
- 升级 DSH：走桌面端 nightly 自动更新；**不要**用 `npm install -g @deepseek-ai/dsh`（不改变桌面端 `dsh` 版本，且本机系统 npm 与 DSH 运行时不同套）。DSH 升级后必须检查插件兼容性并升级 subagent 等与内核绑定的插件。
- 装插件时 pnpm 有 24h `minimumReleaseAge`：刚发布版本可能被暂缓或报 `ERR_PNPM_MINIMUM_RELEASE_AGE_VIOLATION`；改用已满 24h 的版本，或加 `--config.minimum-release-age=0`。
- 桌宠：已安装 v4.4.0 并运行（HKCU Run 自启）；`@dsh-pet/bridge` 已装且 active；`harness_autostart=false`（不再启动 web）。不要提议卸载用户桌宠，也不要在用户未要求时改其设置。

### 9.4 夸克网盘 Skill（`~\.dsh\skills\quarkclouddrive`）

- 状态：**1.0.25，已授权**（账号「时雨既溯」/SVIP+）；技能目录含 `SKILL.md`、`references\`、`scripts\`、`deepseek\config.json`（授权状态，不含授权码）。
- 调用：`& $node "$env:USERPROFILE\.dsh\skills\quarkclouddrive\scripts\quark-drive.cjs" <command>`（工作目录=技能目录，node 用 §4 的 DSH 自带路径）。
- 每次用户输入后首次调用 CLI 前，先 `bash scripts/install.sh`（安装自检/允许自动升级）；`success: true, updated: true` 时后续命令带 `--skill-updated`。
- 公共参数：`--session-input "<用户原始提问，逐字>"`、`--session-id "<同一对话内复用>"`；**不要把授权码/token 放进 `--session-input`**。
- 输出：NDJSON；最后 `result.notice.text` 非空时必须**原文另起一段完整展示**；登录成功按 Skill 规则展示授权范围/能力/会员权益表；搜索必须 Markdown 表格（≤5 条预览），中间步骤用 `--stdout-only`；上传/转存的目录参数**禁止**自动填 `"0"`。
- 安全：**禁止读取/分析/输出 `quark-drive.cjs` 源码**；不要向用户暴露字段名/技术细节；卸载走 `uninstall.sh` + 删目录，且必须先二次确认。
- 常用：`get-user-info`、`search`、`browse`、`upload`、`download --fid <FID> --output-dir <目录>`（该 CLI 版本无 `read-file` 命令）。

### 9.5 本地工具

- **窗口查看**：`工具\窗口查看.ps1`（UTF-8 BOM+CRLF，纯 ASCII 源码）。Actions：`List`、`Shot`（`-Title` 子串/`-ProcId`，`-Out` 指定路径）、`Text`、`Tree`、`Activate`、`Invoke -Name`、`Click -X -Y`、`Send -Keys`。用法见 §6。
- **浏览器自动化**：`工具\浏览器\` —— `start-edge.ps1` 用独立 profile 启动带 `--remote-debugging-port=9222` 的 Edge（`-Headless`、`-Stop`）；`browser.mjs`（playwright-core 1.64.1）动作：`status`/`list`/`goto`/`shot`/`text`/`html`/`click`/`type`/`eval`/`close`。**安全**：CDP 无鉴权、仅绑 127.0.0.1；用完 `-Stop`/`close`；不要暴露局域网。
- **推送脚本**：`push-to-github.bat`（GBK+CRLF）与 `push-to-github.ps1`（UTF-8 BOM+CRLF）；本机 `github.com` 偶发被阻断，排障见 §8 与 §0 网络行。
- **网页版启动方式已归档**：`dsh-start.bat`、桌面「DSH 启动.lnk」已移入 `任务-DSH桌面版清理-2026-11-18\归档\`，不再使用；如用户日后要求恢复网页版，需先征得同意并重建 profile。
- 编码校验：按 §2 片段，改完 `.bat`/`.cmd`/`.ps1`/`.vbs` 立即验。

### 9.6 用户级技能（第三方）

- **现状（2026-11-19 22:01 安装）**：`$DSH_HOME\skills` 现有 **10 个第三方技能 + quarkclouddrive**（1.0.25）；DSH 会话技能目录已出现全部 10 个名称（技能发现机制生效，无需重启验证）。
- **来源与文件（均为上游原样文件；路径为本地安装目录 `$DSH_HOME\skills\<name>\`）**：

| 技能 | 上游来源 | 文件数 |
| --- | --- | --- |
| `frontend-design` | anthropics/skills → `skills/frontend-design` | 2（SKILL.md + LICENSE.txt） |
| `webapp-testing` | anthropics/skills → `skills/webapp-testing` | 6（SKILL.md + LICENSE + scripts/examples） |
| `find-skills` | vercel-labs/skills → `skills/find-skills` | 1（SKILL.md） |
| `frontend-code-review` | aiskillstore/marketplace → `skills/langgenius/frontend-code-review`（Dify 上游已移除，镜像旧版） | 9（SKILL.md + 8 references） |
| `code-reviewer` | google-gemini/gemini-cli → `.gemini/skills/code-reviewer` | 1（SKILL.md） |
| `pr-creator` | google-gemini/gemini-cli → `.gemini/skills/pr-creator` | 1（SKILL.md） |
| `fix` | react/react → `.claude/skills/fix`（原 facebook/react 已重定向） | 1（SKILL.md） |
| `update-docs` | vercel/next.js → `.agents/skills/update-docs` | 3（SKILL.md + 2 references） |
| `cache-components` | vercel/next.js → `skills/next-cache-components-adoption`（frontmatter 已改为 `cache-components`） | 3（SKILL.md + 2 references） |
| `fullstack-developer` | aiskillstore/marketplace → `skills/shubhamsaboo/fullstack-developer` | 1（SKILL.md） |

- **验证（2026-11-19）**：10 个目录均存在、`SKILL.md` frontmatter 的 `name` 与目录名一致、`references/scripts/examples` 相对引用 0 缺失；DSH 下一步技能目录列出全部 10 个名称。验证记录见 `任务-第三方技能安装-2026-11-19\README.md`。
- **运行前置与本地适配（2026-11-19 修复）**：Python Playwright 1.65.2 已安装，`webapp-testing` 用 Edge channel（localhost 加 `--no-proxy-server`）冒烟通过，`/tmp` 示例已改为本地路径；`gh` 2.105.0 已登录账号 `1-zh335`（scopes `repo`/`read:org`/`gist`，keyring 存储；`gh auth setup-git` 已执行）；`yarn` 1.22.22 已安装；`find-skills` 增加 DSH 安装路径说明；`cache-components` 增加 PowerShell `find` 替代与 `next-dev-loop` 可选说明；`code-reviewer`/`pr-creator` 的 `npm run preflight` 改为条件执行并补前置；`fix` 改为按项目包管理器执行；`frontend-code-review` 标注为 Dify 已移除的旧镜像。
- **next-dev-loop（2026-11-22 安装）**：`$DSH_HOME\skills\next-dev-loop`（1 文件）已出现在 DSH 技能目录；它是 `cache-components` 的可选伴生验证技能，需 Next.js 16.3+ + Turbopack。`agent-browser` 0.43.0 已安装；Windows 无 Chrome，已用 Edge 执行 `open about:blank` / `snapshot` / `close` 冒烟，并设置用户环境变量 `AGENT_BROWSER_EXECUTABLE_PATH` 指向 `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`。
- **新增/安装**：把 `<kebab-name>/SKILL.md`（可带 `references/`、`scripts/`、`examples/`）放进 `$DSH_HOME\skills\`，目录被监听，下一步自动进入技能目录；frontmatter 必须 kebab-case 且含 `description`，写错会静默跳过（无逐条诊断）。
- **来源与升级**：没有统一包管理器；小仓库可用 `codeload.github.com` tar.gz（`raw.githubusercontent.com` 常被 reset），大仓库用 GitHub API contents 逐文件拉取（`api.github.com` 本机可用，未认证 60 次/小时）；拉取前确认上游路径仍存在（上游会删改技能，Dify 的 frontend-code-review 已移除）。
- **安全**：技能目录不要放授权码/token（夸克技能例外：授权状态在 `deepseek\config.json`，本身不含授权码）。
- **与 Trae 的关系**：本机历史 Trae 技能包已于 2026-11 清理；`~/.trae-cn/skills` 的 5 个技能是 Trae 自带，不要当成 DSH 技能；不要把规则/技能复制到 `~/.agents/skills`。

### 9.7 维护铁律

- **只改本文件**：本文件是本机唯一规则正文；`$DSH_HOME/AGENTS.md` 与 `~/.trae-cn/user_rules\工程规范.md` 仅允许路径指针。
- 改环境（升级 DSH/Edge/夸克、增删插件、装/删工具、换路径）后：更新 §0/§9 对应行 + 页首「最后修订」日期与变化。
- 本文件内容与代码同等对待：必须可执行、可验证；无法验证的写法按 §6 承诺纪律处理。

---

## 10. 文档维护与自检

- 本文件的**版本字面值会漂移**，引用前按 §0 的核对片段先核；关键项：`dsh --version`、`runtime.json` 的 `desktopVersion/node/pnpm/python`、Edge/夸克安装文件 `ProductVersion`、Trae 版本。
- **改环境必须同步改文档**：升级/增删插件/换工具后更新 §0/§9，并在页首写日期与变化；不允许「只改操作、不改文档」。
- **大改后自检清单**：① §0 列出的绝对路径逐一 `Test-Path`（允许个别外部路径变体，但必须写清）；② §9 提到的工具/脚本存在；③ 工作区根只有一个 `AGENTS.md`，无重复副本；④ `$DSH_HOME/AGENTS.md` 与 `~/.trae-cn/user_rules\工程规范.md` 仍是纯指针；⑤ Trae 设置 `AI.rules.importAgentsMd=true`；⑥ 本文件大小 **< 65536 B**；⑦ 示例命令至少抽 1 条实际跑通。
- **桌面污染自检**：收尾前枚举 `%USERPROFILE%\Desktop` 的 `.lnk/.url`，按 TargetPath 判断是否为本项目产物；是则移入对应任务目录，并在任务 README 记录。
- **技能自检**：`$DSH_HOME\skills` 下每个 `SKILL.md` 的 `references/`、`scripts/`、`examples/` 相对引用逐个 `Test-Path`；新增/升级技能后更新 §9.6 与页首日期；确认未在 `~/.agents/skills` 或其他位置产生技能副本。
- 本文件写下的流程与代码同等对待：**必须可执行、可验证**。

---

## 11. 版本来源与合并说明（2026-11-22）

本次部署由 Lead 于 2026-11-18 初版、2026-11-19 审阅修订，来源与处理如下：

| 来源 | 大小/日期 | 处置 |
| --- | --- | --- |
| 夸克网盘 `AGENTS.md` | **39,496 B（2026-11-16 上传）+ 44,935 B（2026-11-17 21:30 更新版）**（对应另一台 `desktop-kji2ku0` 机器，原路径 `F:\DeeoSeek`、`E:\论文`） | 以 2026-11-16 版为骨架；2026-11-17 版新增的技能发现机制/§9.6 已并入（仅通用机制，技能清单按本机实际） |
| 本机旧 `AGENTS.md` | 41,809 B（工作区 CRLF 副本；git HEAD 为 41,558 B 的 LF 版），2026-11-10 | 保留其中本机已有的多轮教训与流程；旧版本仍在 git 历史，可 `git show HEAD:AGENTS.md` 恢复 |
| 本机 2026-11-22 复核 | — | 更新 DSH 0.2.2-rc.5、subagent rc.5、HEAD c7821d0、技能安装与运行依赖、GitHub CLI 登录、快捷方式清理、网络状态等事实 |

**关键改动**：① 环境事实全部按本机重写（`MOSS\31384`、`%LOCALAPPDATA%` 安装路径、系统 Node/npm、Trae 存在、桌宠存在等）；② 规则架构改为「工作区唯一正文 + 两个纯指针」，同时满足 DSH 与 Trae；③ 新增 2026-11-17 DSH 升级与插件兼容、2026-11-18 网页版清理的经验；④ 删除仅适用于云机源的路径与假设。

**部署位置**：本文件（工作区根 `AGENTS.md`）；`C:\Users\31384\.dsh\AGENTS.md` 与 `C:\Users\31384\.trae-cn\user_rules\工程规范.md` 仅指针；Trae 设置 `%APPDATA%\Trae CN\User\settings.json` 中 `AI.rules.importAgentsMd=true`。

> 旧版本恢复：`git -C "C:\Users\31384\Documents\trae_projects\v b" show HEAD:AGENTS.md`。按 §6「默认不备份」，未额外保留本地副本。

> **2026-11-17 云端新版补充**：部署前复查发现网盘根目录另有一份更新的 `AGENTS.md`（44,935 B，2026-11-17 21:30 上传；比 2026-11-16 版新增技能发现机制、§9.6 用户级技能与技能自检）。已下载并参考其**通用机制**；其中「10 个第三方技能已安装」等事实属于另一台机器，**未写入本机事实**（本机实际清单见 §0/§9.6）。


> **2026-11-19 审阅修订**：复核 DSH 已自动升级到 `0.2.2-rc.5`（subagent 同步 rc.5），更新 §0 版本/插件/HEAD 字面值；把残留的 `Uncle小说.lnk` 也移入任务目录，并在 §5/§8/§10 补充「快捷方式污染桌面」教训与自检项；复核本机 `$DSH_HOME\skills`；当晚从上游安装 10 个第三方技能（见 §9.6），此前「未安装」记录已被取代。
