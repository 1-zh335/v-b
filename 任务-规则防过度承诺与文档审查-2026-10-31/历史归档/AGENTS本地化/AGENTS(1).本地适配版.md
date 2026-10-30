# AGENTS.md — 本地工程规范（本机适配版：Windows 11 / 用户 31384）

> **来源与定位**：本文件由另一台机器的 `AGENTS.md`（用户 `d59049`、工作区 `D:\Vibe Coding`、Windows 10 LTSC）于 **2026-10-24 按本机环境逐条适配**，其中环境事实均已在本机实测核对（见 §1）。
> 本机 DSH（`dsh-agent-instructions` 0.1.1-rc.2）实际自动加载的是：`C:\Users\31384\.dsh\AGENTS.md`（全局）＋ 项目根（含 `.git` 的目录）到工作目录链上的 `AGENTS.md` / `CLAUDE.md`（及 `.local` 变体）。本文件名为 `AGENTS(1).md`，**不在自动加载候选内，当前不参与任何会话注入**；如需令其生效见 §9 末条。
> 本机现行规则唯一来源：`.trae\rules\工程规范.md`（Trae 读）→ 同步到 `C:\Users\31384\.dsh\AGENTS.md`（DSH 读）。本文件是该规范的完整适配副本，请勿在生效路径之外另建重复规则文件。
> 任何在本机工作的 AI Agent 必须遵守以下规范。最后修订：2026-10-24（本地环境适配）。

## 1. 环境信息（2026-10-24 本机实测）

- 系统：Windows 11 家庭版 Insider Preview 中文版 64-bit（NT 10.0.26340）；当前用户 `moss\31384` 为**标准用户**（`IsInRole(Administrator)` = False），提权操作会弹 UAC
- DSH 文件策略：本会话为 `danger-full-access`（文件读写不受沙箱限制）；审批提示默认禁用，需要审批的操作会被自动拒绝——**不要请求提权/沙箱升级**
- 时区：中国标准时间（UTC+8，`China Standard Time`），`Get-Date` 直接可用
- 工作目录：`C:\Users\31384\Documents\trae_projects\v b`（**路径含空格**，命令行引用必须加引号）
- Node.js：**双版本并存**
  - 系统级：`C:\Program Files\nodejs\node.exe` v26.7.0（npm 11.19.0；npm 全局前缀 `C:\Users\31384\AppData\Roaming\npm`，已装 `@deepseek-ai/dsh@0.1.1-rc.2`、`pnpm@11.24.0`）
  - Trae 内置：`C:\Users\31384\.trae-cn\binaries\node\versions\22.23.2\node.exe` v22.23.2（npm 10.9.8；npm 全局前缀即该版本目录本身）
  - 本会话实测裸 `node`/`npm`/`dsh` 解析到**系统级** v26.7.0；Trae 内置版需用绝对路径，两者依赖树不同，勿混用
- Python：3.12.10（pip 25.0.1），安装于 `C:\Users\31384\AppData\Local\Programs\Python\Python312\`；本机实测裸 `python`/`pip` 已正确解析到 Python312（`WindowsApps` 商店占位仍在 PATH 末尾但不遮蔽），`py -3` 可用。脚本内仍建议绝对路径（`start` 子进程等场景会丢 PATH 继承）
- 浏览器（视觉验收）：**未安装 Chrome**；Edge 已装 `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`（155.0.4283.62），无头截图已实测可用
- git：`C:\Program Files\Git\cmd\git.exe`（2.55.0.windows.3）；工作区已是 git 仓库（分支 `main`，已有初始提交，**当前无 `origin` 远程**；提交身份 `1-zh335 <3138470565@qq.com>`，`core.quotepath=false`）
- Trae：`C:\Users\31384\AppData\Local\Programs\Trae CN\Trae CN.exe`
- DSH：CLI `0.1.1-rc.2`（`C:\Users\31384\AppData\Roaming\npm\dsh.ps1`）；桌面端 `C:\Users\31384\AppData\Local\Programs\DeepSeek Harness\DeepSeek Harness.exe`；`DSH_HOME=C:\Users\31384\.dsh`；本会话 GUI 为 `http://127.0.0.1:60510`（端口随启动变化，以运行时提示为准）；`dsh-start.bat` 固定使用 3080
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
- **调用外部命令（尤其 npm 全局 `.cmd` shim，如本机 `dsh`）传参时禁用 `!VAR!` 延迟展开**：实测 `dsh web --port !PORT!` 会把 `!PORT!` 原样传给 dsh（报 `--port must be a number, got "!PORT!"`），而同脚本里 `echo !PORT!` 却能正常展开。顶层已 `set` 的变量直接改用 `%VAR%` 普通展开即可
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
- 工作区 `C:\Users\31384\Documents\trae_projects\v b` **已是 git 仓库**（2026-08-30 初始化，分支 `main`，已有初始提交，目前**尚未配置远程 `origin`**）：`git status` 把中文路径显示成 `\351\241\271...` 转义串时，是 `core.quotepath` 默认值所致，执行 `git config core.quotepath false` 即可（只影响显示，本仓库已设置）
- git CLI 经 winget 安装（Git for Windows 2.55.0，路径 `C:\Program Files\Git\cmd\git.exe`）；若命令不可用，新开终端或改用绝对路径
- 上传 GitHub：**优先使用工作区一键脚本**——双击 `push-to-github.bat`，按提示粘贴个人访问令牌（repo 权限），脚本自动完成建仓库（`v-b`，公开）→ 关联远程 → 推送 `main`；手动方式：先在 GitHub 建空仓库，再 `git remote add origin <仓库地址>` → `git push -u origin main`；推送前 `git status` 并确认无敏感/大文件（排除规则见仓库根 `.gitignore`，已按本节排除目录维护）
- 工作区根只保留：`.trae/`、`README.md`、`dsh-start.bat`、`push-to-github.bat`、`push-to-github.ps1`、`.gitignore`、`.gitattributes`、`任务X/`；本地日志与临时文件（如 `npm-install.log`）不入库（`.gitignore` 已排除 `*.log` 等）

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
- 闭环流程：生成 → 运行 → **截图 → 目检 → 修复 → 重截复验**，直到所见即所期；截图后必须用 DSH 的 `read_image` 工具亲自看，按布局/颜色/文字/交互/3D 效果逐项对照
- 网页/3D 截图用本机 **Edge 无头**（本机未装 Chrome；Edge 实测 155.0.4283.62 可用）：
  ```powershell
  $edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
  & $edge --headless=new --disable-gpu --no-first-run --hide-scrollbars --window-size=1440,940 --virtual-time-budget=9000 --screenshot="shot.png" "http://localhost:3000/"
  ```
  - 若日后安装 Chrome（`C:\Program Files (x86)\Google\Chrome\Application\chrome.exe`），把 `$edge` 换成 chrome.exe 路径即可，参数不变
  - 渲染慢就加大 `--virtual-time-budget`（词云 16-20 秒、3D 场景 30 秒）；WebGL/3D 加 `--use-angle=swiftshader` 软渲染
  - SPA 无路由时给各视图加 URL 深链（如 `#cloud`、`#search=词`）以便直达截图
- GUI 桌面应用：运行后窗口截图目检；无法自动截时请用户截图或描述所见
- 截图是临时验证物，闭环结束即清理；测试服务进程停止

### 测试清理与交付固化

- 测试产物（临时文件、系统对象：计划任务/服务/注册表项/hosts 条目等）**用完即删**；删除后必须用 ≥2 种独立手段交叉核验——中文名任务在 GBK 控制台会变乱码（如 `鐐规鐪熷疄鏃跺埢閲囬泦`），字符串匹配会假阴性：删除优先用对象引用（`Unregister-ScheduledTask $task`），核验用非 ASCII 正则枚举 + 全量列表抽查
- 不得声称「已清理/已核验」除非：清理动作成功 + 核验手段已验证可靠 + 结果为空；「应该删了」的推断不是核验
- 交付物必须**版本固化后打 zip** 交付，禁止让用户直接复制仍在维护的工作区目录；安装脚本要有明显成功标志（如 `[OK] 已注册…`）并在文档写明「看到什么才算成功」；用户报失败先问输出再定位版本
- 「本机测试通过」只对测试的那份文件成立；换机/重拷后重新验证或校验哈希
- 仅适用特定版本/场景的脚本（如「仅 v2.1」SQL），文件名与首行必须注明适用范围与误用后果

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
- **批处理调用 npm 全局命令（.cmd shim）传参时 `!VAR!` 延迟展开失效**：`dsh web --port !PORT!` 传给 dsh 的是字面量 `!PORT!`（报 `--port must be a number`），而同脚本 `echo !PORT!` 却正常展开为 3080——顶层已 set 的变量改用 `%PORT%` 普通展开解决
- **DSH 自定义插件历史（原机器，本机未安装）**：原机器曾把 `check_win_bat_standards` 做成 npm 静态包，经 profile `cordis.patch.yml` insert + `package.json` file: 依赖挂载；教训是静态包 `module.exports.apply(ctx)` 里不能用 `harness`（Builtin 仅动态 eval 作用域可用）、注册工具不要 `require('@deepseek-ai/dsh-tools')` 的 `defineTool`（Symbol 调度键会与核心模块实例冲突）、Windows 下 file: 依赖会退化成拷贝而不是 junction。**本机 `~/.dsh/profiles/desktop/` 未安装该包，规范校验按 §2/§9 手动命令执行**；若日后在本机重做插件，上述教训仍适用
- **任务6 软件优化教训（原机器案例）**：修改工作区外生产目录前先快照；升级基础组件前确认产线兼容性；承诺的流程必须落成文档。本机只有 `C:` 盘，原案例的 `D:\TraceQuery_优化版`、`D:\SQLQC_发布版` 等路径不存在，原则照旧
- **点检系统严重失误（原机器 2026-09-02~03，原总结文档不在本机）**：给产线 v1 正在使用的表加列导致停摆——v1 的 INSERT 是隐式全列 7 值（`values(default,...)`），加任意列即报「列数不匹配」，反编译时已看到此事实、决策时却未接入。铁律：**改生产库表结构（加/删/改列、索引）前，必须读旧程序对该表的全部读写 SQL 验证兼容性，先备份并写清回退语句（目录快照规则同任务6 教训 ①）；无法本机实测必须标注「未经实测」并用替代验证复现，禁止把推断写成「已验证/不影响」**；IL/二进制提取的路径、格式、分隔符必须逐字节解码 + 与真实样本双验证，禁止凭记忆近似

## 9. 给 DSH 的说明（本机）

- 工作目录默认 `C:\Users\31384\Documents\trae_projects\v b`（DSH 会话 cwd）；该目录含 `.git`，即 DSH 的「项目根」
- **指令加载机制（已核对 DSH 0.1.1-rc.2 源码）**：`dsh-agent-instructions` 加载 ① `$DSH_HOME/AGENTS.md`（本机 `C:\Users\31384\.dsh\AGENTS.md`，全局）② 项目根→cwd 链上每个目录的 `AGENTS.md` / `CLAUDE.md`，再叠加同名 `.local` 变体（`AGENTS.local.md` / `CLAUDE.local.md`），越具体优先级越高；单文件上限 1 MB。本文件 `Documents\AGENTS(1).md` **不在候选名单，不会自动加载**
- **改规范的正确姿势**：先改 `.trae\rules\工程规范.md`（Trae 的 alwaysApply 规则），再同步到 `C:\Users\31384\.dsh\AGENTS.md`（DSH 用户全局）；若只想让规则随本项目走，可复制为工作区根 `AGENTS.md`（会被 git 跟踪并自动加载）
- **权限模式**：本机 profile 默认预设 `danger-full-access`（`~/.dsh/profiles/desktop/cordis.patch.yml` 的 `defaultPreset`），文件沙箱不限制；本会话审批提示禁用，需要审批的动作直接失败——**不要调用 `sandbox_permissions` 请求提权**
- **插件与配置位置**：`C:\Users\31384\.dsh\profiles\desktop\`（`cordis.patch.yml`、`package.json`、`cordis.yml`）、`C:\Users\31384\.dsh\settings.yaml`；插件经 `plugin_manager` / `plugin_market` 管理；升级 CLI 用 `"C:\Program Files\nodejs\npm.cmd" install -g @deepseek-ai/dsh@latest`（当前 0.1.1-rc.2）
- **工具差异**：本机**没有** `check_win_bat_standards` 工具（原机器自建插件未迁移），`.bat`/`.ps1`/`.vbs` 编码校验一律手动执行（见下一条）；视觉验收用 `read_image`；交付展示用 `present`；并行任务可用 Agent Teams / `subagent` / `workflow`；任务与技能目录匹配时先调用 `skill`（本机提供 office 系列、cordis 插件开发、dsh-badge 等技能）
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
- **本文件若要生效**：把内容合并进 `~/.dsh/AGENTS.md`（全局，推荐）、或复制为工作区根 `AGENTS.md`（项目级）；直接留在 `Documents\AGENTS(1).md` 不会对 Trae 或 DSH 产生作用（Trae 只读 `.trae\rules\`，DSH 只读上述候选名）
