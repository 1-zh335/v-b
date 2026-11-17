# AGENTS.md — 本机 DSH 行为与工程规范（唯一规则来源）

> **位置**：`C:\Users\Administrator.DESKTOP-KJI2KU0\.dsh\AGENTS.md`（即 `$DSH_HOME/AGENTS.md`，DSH **用户级全局规则**）
> **生效范围**：本机（`desktop-kji2ku0\administrator`）**所有** DSH 会话与工作目录，无需复制到各工作区。
> **加载机制**（2026-11-16 依本机 DSH 0.2.2-rc.3 源码 `@deepseek-ai/dsh-agent-instructions` 核实）：先加载用户级 `$DSH_HOME/AGENTS.md`（以及共享根 `~/.agents/AGENTS.md`，本机不存在），再加载「项目根 → 当前工作目录」链上的 `AGENTS.md` / `CLAUDE.md`（及 `.local` 变体）；单文件源码上限 1 MiB，每条链渲染预算 **65536 字节**；项目根 = 从工作目录向上第一个含 `.git` 的目录，都没有则以工作目录为根。
> **优先级**：用户直接指令 > 项目级 `AGENTS.md`（更具体） > 本文件（更宽泛）。本文件不覆盖系统/用户的直接指令。
> **最后修订**：**2026-11-16**（由本机 2 份旧版 + 微信接收版 + GitHub 仓库版 + 网盘版 5 份来源综合优化为本机唯一版本，来源与处置见 §11；同日按用户意见修订备份策略：**取消「改前先备份」的默认动作**，改为 §6「默认不备份、仅必要时最小快照 + 限期清理」）。
> **维护铁律**：本机只保留这一份规则正文；**禁止再建任何副本或指针**（历史上 4 处副本曾导致改一处漏三处、旧内容继续注入）。

---

## 0. 本机事实核对表（2026-11-16 实测）

以下为**实测**值。⚠️ 版本号会漂移（DSH nightly、Edge、Quark 自动更新），**引用前先核**（命令见 §10）。

| 项目 | 实测值 |
| --- | --- |
| 用户 / 权限 | `desktop-kji2ku0\administrator`，**标准用户**（`IsInRole(Administrator)=False`）；需要管理员的操作直接说明并请用户执行，不要反复尝试提权 |
| 操作系统 | **Windows 11 专业版** `10.0.26300`，64-bit |
| 时区 | Asia/Shanghai（UTC+8） |
| 控制台代码页 | DSH 工具进程内为 **65001（UTF-8）**；但 `.bat`/`.cmd` 文件本身按 §2 仍用 **GBK + CRLF + `chcp 936 >nul`**（面向 cmd 双击/计划任务场景） |
| PowerShell | DSH 的 `pwsh` 工具实测为 **Windows PowerShell 5.1**（`5.1.26100.9818`，Desktop 版）；`ExecutionPolicy = RemoteSigned` → 跑 `.ps1` 必须 `powershell -NoProfile -ExecutionPolicy Bypass -File "x.ps1"` |
| 默认工作目录 | `E:\论文`（另有默认工作区 `E:\OneDrive\文档\deepseek-harness\default-workspace`） |
| 项目根判定 | `E:\论文` 及其祖先**没有** `.git` → DSH 项目根 = 工作目录本身；规则主要由用户级本文件提供 |
| DSH 桌面端 | **`0.2.2-rc.3`**（nightly 自动升级；精确值以 `dsh --version` 与 `runtime.json` 为准） |
| DSH 安装目录 | `F:\DeeoSeek`（**非默认路径**，不要照抄其他机器/文档里的 `%LOCALAPPDATA%\Programs\DeepSeek Harness`）；主程序 `F:\DeeoSeek\DeepSeek Harness.exe` |
| DSH CLI | `F:\DeeoSeek\resources\runtime\cli\bin\dsh.cmd`（已加入**用户级 PATH**；新开进程可直接 `dsh`） |
| DSH_HOME | `C:\Users\Administrator.DESKTOP-KJI2KU0\.dsh`（用户级/系统级环境变量为空属正常，由宿主进程注入） |
| profiles | `desktop`（桌面 App 使用）、`web`（`dsh web` / `E:\论文\dsh-start.bat` 使用） |
| DSH 运行时 | Node **v24.21.0**：`F:\DeeoSeek\resources\runtime\primary-runtime\dependencies\node\bin\node.exe`；pnpm **11.28.5**：`...\dependencies\pnpm\bin\pnpm.mjs`；Python **3.12.14**：`...\dependencies\python\python.exe` |
| 系统 Python | **3.12.10**：`C:\Program Files\Python312\python.exe`（PATH 上 `python` 可用） |
| 系统 Node/npm | ❌ **未安装**（不要找系统 node/npm，也不要找 Trae；一律用 DSH 自带运行时绝对路径） |
| git / bash / curl | git **2.55.0.windows.2**：`F:\Git\cmd\git.exe`；bash：`F:\Git\bin\bash.exe`；curl：`C:\Windows\system32\curl.exe` |
| 浏览器 | **Edge 157.0.4341.60**：`C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`（唯一常用浏览器）；夸克浏览器 **7.4.9.1045**：`F:\Quark\quark.exe`（Chromium 内核）；**没有 Chrome** |
| 屏幕 / 长路径 | 1920×1080；`LongPathsEnabled = 1`（长路径已启用，仍建议目录别过深） |
| 已装 DSH 插件 | `dsh-cost-meter@1.9.62`（desktop + web，界面「设置 → 费用」/ 侧栏余额）；插件市场索引 `https://dshopen.org/index.json`；子代理 `dsh-subagent-codex` / `dsh-subagent-claude-code@0.2.2-rc.1`。精确清单以 `~/.dsh/profiles/<profile>/package.json` 为准 |
| 桌宠 | ❌ **未安装，且用户明确要求不要「DP/大肥鱼桌宠」及 `@dsh-pet/bridge`**——不要提议、下载或安装 |
| 夸克网盘 Skill | `~/.dsh/skills/quarkclouddrive`（**1.0.25，已授权**，账号「时雨既溯」/ SVIP+）；用 DSH 自带 node 执行 `scripts/quark-drive.cjs` |
| 本地工具 | `E:\论文\工具\窗口查看.ps1`（16,485 B，UTF-8 BOM+CRLF）；`E:\论文\工具\浏览器\`（Edge CDP + playwright-core 1.64.1）；`E:\论文\dsh-start.bat`（GBK+CRLF，`dsh web` 端口 3080） |
| 不存在的工具 | ❌ `check_win_bat_standards` 校验工具、❌ Trae、❌ 系统 node/npm、❌ `wmic`、❌ Chrome |
| 网络 | npm registry、`api.github.com`、夸克下载域名可达；`raw.githubusercontent.com` / 偶发 `github.com` 直连会 Connection reset（可改用 `codeload.github.com` tar.gz 或 API contents 取文件） |
| 权限模式 | **`danger-full-access` + `approval: never`**：文件沙箱不限制，审批提示禁用、需审批动作自动失败——**不要请求提权/`sandbox_permissions`** |
| 默认模型 | `deepseek-account` / `deepseek-flash`（`reasoningEffort: max`）；子代理可选模型见 profile `cordis.patch.yml` |

**核对片段**（一次跑完，输出即上表依据）：

```powershell
$PSVersionTable.PSVersion; (Get-ExecutionPolicy).ToString(); [Console]::OutputEncoding.CodePage
(Get-CimInstance Win32_OperatingSystem).Caption; (Get-CimInstance Win32_OperatingSystem).Version
$env:DSH_HOME; & "F:\DeeoSeek\resources\runtime\cli\bin\dsh.cmd" --version
$d = "F:\DeeoSeek\resources\runtime\primary-runtime\dependencies"
& "$d\node\bin\node.exe" -v; & "$d\python\python.exe" -V
& "C:\Program Files\Python312\python.exe" --version; & "F:\Git\cmd\git.exe" --version
(Get-Item "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe").VersionInfo.ProductVersion
[Environment]::GetEnvironmentVariable('Path','User') -split ';' | Where-Object { $_ -match 'DeeoSeek' }
```

> 其他机器遗留路径（如 `C:\Users\d59049`、`C:\Users\31384`、`C:\Users\14510`、`D:\Vibe Coding`、`C:\Program Files\nodejs`、`%LOCALAPPDATA%\Programs\DeepSeek Harness`）在本机**全部不存在**，出现即视为过期内容，不得照抄。

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

## 4. 工具链：一律使用绝对路径

⚠️ 本机 `node` / `npm` **不存在**；`python` 可解析到系统 Python312；git 在 `F:\Git`。不要依赖 PATH 找 node/npm，也不要再去找 Trae。

```powershell
$d    = "F:\DeeoSeek\resources\runtime\primary-runtime\dependencies"
$node = "$d\node\bin\node.exe"
$pnpm = "$d\pnpm\bin\pnpm.mjs"
$py   = "$d\python\python.exe"

& $node -v                        # v24.21.0
& $py   -V                        # Python 3.12.14（DSH 自带）
& $node $pnpm install             # 用这个 node 跑 pnpm，不要找 pnpm.exe
& "C:\Program Files\Python312\python.exe" --version   # 系统 Python 3.12.10
```

- `.bat` 里调用 node 必须写**绝对路径**；不要用 `start` 调 node/npm（子 cmd 环境会丢 PATH 继承）。
- 首次使用前 `Test-Path` 确认路径存在；DSH 升级/搬迁后以 `F:\DeeoSeek\resources\runtime\primary-runtime\dependencies\` 下实际目录为准。
- 缺库先装：Python 用 `& $py -m pip install <包>` 或 `& "C:\Program Files\Python312\python.exe" -m pip install <包>`；Node 用 `& $node $pnpm add <包>`（注意 pnpm 跨盘会回退到 `E:\.pnpm-store`，属正常）。
- Vite 等大项目 OOM 时可加 `--max-old-space-size=4096`（本机内存充足，先从 4096 起试）。
- 需要读 DSH 安装包 `app.asar` 内容时，用 **Electron 可执行文件 + `ELECTRON_RUN_AS_NODE=1`**（`F:\DeeoSeek\DeepSeek Harness.exe` 即 DSH 的 `DSH_NODE_EXECUTABLE`），普通 node 不可遍历 asar。
- Git Bash 在 `F:\Git\bin\bash.exe`（`bash scripts/install.sh` 等场景用）；curl 在 `C:\Windows\system32\curl.exe`。

---

## 5. 目录与项目结构约定

- 默认工作目录 `E:\论文`；**新任务在当前工作目录下建中文命名子文件夹**（如 `任务-DSH新机安装-2026-11-11`）。任务目录/文件名可用中文，但**脚本内部的路径、变量名用英文**，减少编码坑。
- 写功能代码**之前**先生成项目文档（`README.md` / `DESIGN.md`）说明目标、文件结构、逻辑流程。
- 临时测试文件/截图/下载物**用完即删**；测试服务进程用完停止。
- 打包交付类项目可按交付形态分目录：`1-开箱即用`（绿色版）、`2-安装器`（setup）、`3-单文件exe`；非打包任务不适用。
- **版本管理现状**：`E:\论文` **不是 git 仓库**（本机也未配 GitHub remote/凭据）；需要留档时只对**关键文件**做快照或打 zip（不打整目录），并按 §6 登记保留期限；不要假设 `git` 仓库存在。日后若建仓库：中文路径用 `git config core.quotepath false` 显示。
- **规则文件位置**：本机唯一规则正文 = `$DSH_HOME\AGENTS.md`（本文件）。**不要**再把规则复制到工作区、`.trae\rules\`、`~/.agents\AGENTS.md` 等任何位置；`E:\论文` 根目录**不再保留** `AGENTS.md` 副本（历史副本已归档，见 §11）。
- 工作区根保留：`工具/`（跨任务工具）、`任务X/`（新任务）、`dsh-start.bat`；其余临时/历史目录按需清理归档。
- 本机 `E:\论文` 现有 `工具\窗口查看.ps1`、`工具\浏览器\`（含 `node_modules`）、`dsh-start.bat`，属可复用资产，勿随意删除。

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
  $t = "E:\论文\工具\窗口查看.ps1"
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
- **不要依赖本机不存在的工具**：`check_win_bat_standards`、Trae、系统 node/npm、wmic、Chrome 在本机都没有；需要校验就用 §2 的 PowerShell 片段自己实现。
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
- **版本字面量漂移**：DSH nightly 会自动升级（本机 2026-11-11 为 0.2.2-rc.1 → 2026-11-16 已 0.2.2-rc.3）；Edge/夸克也自动更新。引用版本前先按 §0/§10 核对。

---

## 9. DSH 运行机制与本机操作说明

### 9.1 规则加载（2026-11-16 依 0.2.2-rc.3 源码核实）

- 用户级：`$DSH_HOME/AGENTS.md`（本文件；共享根 `~/.agents/AGENTS.md` 本机不存在）。
- 项目级：从**项目根**到**会话工作目录**的每一层，按 `AGENTS.md` → `CLAUDE.md` → `AGENTS.local.md` → `CLAUDE.local.md` 顺序加载（同目录存在的都加载，按 trimmed 内容去重；宽泛 → 具体，**更具体者优先**）。
- 项目根 = 从工作目录向上找第一个含 `.git` 的目录；都没有则以工作目录为根（本机 `E:\论文` 无 `.git`，故项目链只有工作目录一层）。
- 预算：单文件源码上限 **1 MiB**；每条链渲染预算 **65536 字节**，超预算先丢弃较宽泛的文件、再截断最具体的文件。本文件 + 项目级文件之和不要逼近上限。
- 子目录的 `AGENTS.md` 在文件操作触及该目录后于**下一步**追加注入（无文件监听，不跟随 shell 的 `cd`）。
- 生效核对：`dsh --profile web --dump-config` 可见 `agent-instructions` 行（`maxBytes: 65536`）；desktop profile 的 dump 被禁止（见 §8）。**改完本文件后，新会话/新基线生效；当前会话已注入的内容不会热替换。**

### 9.2 权限模式

- 本机 profile 默认预设 **`danger-full-access` + `approval: never`**：无需逐次请求审批，自主决定修改；但因此**更要自律**：破坏性操作前先说明，是否快照按 §6 分级（能恢复的不备份）。
- 审批提示已禁用：需要审批的动作会被自动拒绝，**不要调用 `sandbox_permissions` 请求提权**，也不要请求用户批准沙箱升级。

### 9.3 profiles 与插件

- 位置：`~/.dsh\profiles\desktop\`（桌面 App）、`~/.dsh\profiles\web\`（`dsh web` / `dsh-start.bat`）；每个 profile 含 `package.json`（`dsh.profile.bundles`）、`cordis.patch.yml`、`pnpm-lock.yaml`、`cordis.yml`。
- 用户配置只改 `cordis.patch.yml`（`cordis.yml` 是空入口列表，勿手改）。
- 插件管理：`plugin_manager` 工具（live 安装/启停，**优先**）或 `dsh plugin --profile <desktop|web> add|remove <包>`（写 profile，需重启桌面端）；`dsh plugin list` 无内置子命令，用 `dsh plugin --profile <p> list --depth=0`。
- 已装：`dsh-cost-meter@1.9.62`（两 profile；界面「设置 → 费用」/侧栏余额/费用明细）；插件市场索引 `https://dshopen.org/index.json`；子代理 codex / claude-code。
- 升级：DSH 走桌面端 nightly 自动更新；**不要**用 `npm install -g @deepseek-ai/dsh`（本机无系统 npm，且不改变桌面端 `dsh` 版本）。
- 装插件时的 pnpm 有 24h `minimumReleaseAge`：刚发布版本可能被暂缓或报 `ERR_PNPM_MINIMUM_RELEASE_AGE_VIOLATION`；改用已满 24h 版本，或 `--config.minimum-release-age=0`。
- **桌宠与 `@dsh-pet/bridge`：本机未装、用户明确不要**——不要尝试安装或写入 profile。

### 9.4 夸克网盘 Skill（`~/.dsh\skills\quarkclouddrive`）

- 状态：**1.0.25，已授权**；技能目录含 `SKILL.md`、`references\`、`scripts\`、`deepseek\config.json`（授权状态，不含授权码）。
- 调用方式：`& $node "~/.dsh\skills\quarkclouddrive\scripts\quark-drive.cjs" <command>`（工作目录=技能目录；node 用 §4 的绝对路径）。
- 每次用户输入后首次调用 CLI 前，先 `bash scripts/install.sh`（安装自检/允许自动升级）；`success: true, updated: true` 时后续命令带 `--skill-updated`。
- 公共参数：`--session-input "<用户原始提问，逐字>"`、`--session-id "<时间戳-6位随机>"`（同会话复用；**不要把授权码/token 放进 `--session-input`**）。
- 输出：NDJSON；最后 `result.notice.text` 非空时必须**原文另起一段完整展示**；`login` 成功按 Skill 规则展示授权范围/能力/会员权益表；搜索必须 Markdown 表格（≤5 条预览），中间步骤用 `--stdout-only`；上传/转存的目录参数**禁止**自动填 `"0"`。
- 安全：**禁止读取/分析/输出 `quark-drive.cjs` 源码**；不要向用户暴露字段名/技术细节；卸载走 `uninstall.sh` + 删目录，且必须先二次确认。
- 常用：`get-user-info`（账号/会员/容量探活）、`search`、`browse`、`upload`、`download --fid <FID> --output-dir <目录>`（注意该 CLI 版本无 `read-file` 命令）。

### 9.5 本地工具

- **窗口查看**：`E:\论文\工具\窗口查看.ps1`（UTF-8 BOM+CRLF，纯 ASCII 源码）。Actions：`List`、`Shot`（`-Title` 子串/`-ProcId`，`-Out` 指定路径）、`Text`、`Tree`、`Activate`、`Invoke -Name`、`Click -X -Y`、`Send -Keys`。用法见 §6。
- **浏览器自动化**：`E:\论文\工具\浏览器\` —— `start-edge.ps1` 用独立 profile 启动带 `--remote-debugging-port=9222` 的 Edge（`-Headless`、`-Stop`）；`browser.mjs`（playwright-core 1.64.1）动作：`status`/`list`/`goto`/`shot`/`text`/`html`/`click`/`type`/`eval`/`close`。**安全**：CDP 无鉴权、仅绑 127.0.0.1；结束后 `-Stop`/`close`；不要暴露局域网。
- **dsh-start.bat**：`E:\论文\dsh-start.bat`（GBK+CRLF，端口 3080 启动 `dsh web`，已占用时直接开浏览器）。
- 编码校验：按 §2 片段，改完立即验。

### 9.6 维护铁律

- **只改本文件**：`$DSH_HOME\AGENTS.md` 是本机唯一规则正文；不建副本、不建指针；需要项目专属补充时先与用户确认（项目级 `AGENTS.md` 更具体、优先级更高，但本机默认不建第二份）。
- 改环境（升级 DSH/Edge、增删插件、装/删工具、换路径）后：更新 §0/§9 对应行 + 页首「最后修订」日期。
- 本文件内容与代码同等对待：必须可执行、可验证；无法验证的写法按 §6 承诺纪律处理。

---

## 10. 文档维护与自检

- 本文件的**版本字面值会漂移**，引用前先核（命令见 §0 核对片段）；关键项：`dsh --version`、`runtime.json` 的 `desktopVersion/node/pnpm/python`、Edge/夸克安装文件 `ProductVersion`。
- **改环境必须同步改文档**：升级/增删插件/换工具后更新 §0/§9，并在页首写日期与变化；不允许「只改操作、不改文档」。
- **大改后自检清单**：§0 列出的绝对路径逐一 `Test-Path`；§9 提到的工具文件存在；`E:\论文` 根目录无重复 `AGENTS.md`；本文件大小 < 65536 B；示例命令至少抽 1 条实际跑通。
- 本文件写下的流程与代码同等对待：**必须可执行、可验证**。

---

## 11. 版本来源与合并说明（2026-11-16）

本机原有 / 网盘 / 历史来源共 5 份，经逐字节比对后合并为本文件；旧副本已归档到
`E:\论文\任务-DSH新机安装-2026-11-11\备份\AGENTS-历史版本-20261116\`（`.bak`，不再被 DSH 加载；属一次性归档，归本任务管理，按 §6 到期清理）。

| 来源 | 大小 | 内容修订 | 说明 |
| --- | --- | --- | --- |
| 本机旧 `E:\论文\AGENTS.md` | 12,866 B | 2026-08-21 | 最早版本（sha256 `6D7EA8F7…`）；**与网盘 AGENTS.md 逐字节一致** |
| 本机旧 `E:\论文\AGENTS(1).md` | 14,737 B | 2026-09-03 | 第二版（sha256 `1F020E76…`）；**与网盘 AGENTS(1).md 逐字节一致** |
| 网盘 `AGENTS.md` / `AGENTS(1).md` | 12,866 / 14,737 B | 2026-08-28 / 2026-09-09 上传 | 内容 = 上面两份旧版（旧版中**最新**的是 AGENTS(1).md） |
| 微信接收版（旧机 DSH 适配） | 17,766 B | 2026-09-28 | 已按另一台 DSH 机（`14510`、Win11 26220）适配；含 §0 事实表、DSH 规则加载机制、GBK 控制台输出坑、Edge 截图字符集坑等有效内容 |
| GitHub 仓库版（源机适配） | 41,558 B | 2026-11-10 | 内容最新最全（多轮教训、承诺纪律、窗口先看规则、GitHub 排障等），但环境全部指向前一台机器（`moss\31384`、`D:\Vibe Coding` 系路径、桌宠、系统 Node 等），不能直接套用 |

**合并方式**：以「仓库版（2026-11-10）」为骨架取其全部规则与教训 → 融入「微信版」的 DSH 机制/编码细节 → **环境事实全部替换为本机 2026-11-16 实测值**（DSH 0.2.2-rc.3、`F:\DeeoSeek`、无系统 node、Edge/Quark 版本、已装插件、夸克 Skill 已授权、无桌宠等）→ 删除/改写所有指向其他机器与本机不存在路径的段落 → 保留跨机通用铁律。
**结论**：合并后本文件 = 本机唯一规则来源；网盘那两份属旧版（已被本文件取代），如需同步网盘，请以本文件为准重新上传。
