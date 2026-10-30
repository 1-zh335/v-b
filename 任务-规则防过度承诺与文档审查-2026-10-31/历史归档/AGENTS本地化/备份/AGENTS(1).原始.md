# AGENTS.md — 本地工程规范（Trae 与 DSH 共享）

> 本文件由 `dsh-agent-instructions` 自动注入到模型上下文，也供 Trae 读取。
> 任何在本工作区（`D:\Vibe Coding`）工作的 AI Agent 必须遵守以下规范。
> 最后修订：2026-09-03（新增 §6 测试清理与交付固化、§8 点检系统严重失误教训）；2026-08-15 起合并原 `.trae\rules\项目.md`，本文件为唯一规则来源

## 1. 环境信息

- 系统：Windows 10 LTSC 64-bit，标准用户权限（无管理员）
- 时区：Asia/Shanghai
- 硬件信息参考：`C:\Users\d59049\Desktop\桌面杂项\DxDiag.txt`（不存在或已挪动则跳过，不影响任务）
- Node.js：使用 Trae 自带版本（`C:\Users\d59049\.trae-cn\binaries\node\versions\<版本>\node.exe`，版本号随 Trae 升级变化，以目录内实际最新版为准，动态定位写法见 §4）
- Python：3.8.10（`C:\Users\d59049\AppData\Local\Programs\Python\Python38\`，PATH 上 `python`/`pip` 可直接用）
- 回复语言：始终用中文

## 2. 脚本编码规范（最高优先级，违反会导致中文乱码/解析错误）

| 文件类型                          | 编码             | 行尾           | 其他要求                                                                 |
| ----------------------------- | -------------- | ------------ | -------------------------------------------------------------------- |
| `.bat` / `.cmd`               | **GBK/ANSI(936)** | **CRLF（必须）** | 第 1 行 `chcp 936 >nul`（第 2 行 `@echo off` 推荐）；禁止 `chcp 65001`           |
| `.ps1`                        | UTF-8 with BOM | CRLF         | 用 `powershell -ExecutionPolicy Bypass -File "path"` 执行                   |
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
- 读 GBK 文件若显示乱码，用 PowerShell 读：
  ```powershell
  [System.IO.File]::ReadAllText("path", [System.Text.Encoding]::GetEncoding(936))
  ```
- 转码后**立即验证**（优先调用 `check_win_bat_standards` 工具）：`.bat`/`.cmd` 校验 ① GBK 非 UTF-8 ② CRLF 非 LF ③ 首行 `chcp 936 >nul`，不得出现 UTF-8 BOM（`EF BB BF`）；`.vbs` 只校验 GBK 无 BOM（`chcp` 是 cmd 内部命令，写进 `.vbs` 首行会语法报错，不适用首行检查）

## 3. PowerShell / 批处理语法规范

- 本机 PowerShell 为 Windows PowerShell 5.1，脚本避免 PS7 独有语法（`&&`、`??`、三元运算）；命令分隔用 `;` 或换行，**绝不用** `&&`
- PowerShell 脚本内不要经 `cmd.exe` / `command.exe` 间接执行命令
- 路径含空格必须加引号：`"D:\Vibe Coding\file"`；`start` 命令路径含空格用 `start /d "path"`
- 批处理括号块内要用 `!errorlevel!` 必须先开延迟展开，且值先存变量再比较：
  ```bat
  setlocal EnableDelayedExpansion
  ...
  set "ERR=!errorlevel!"
  if "!ERR!"=="0" ...
  ```
- 时间戳用 `Get-Date`；不要依赖 `wmic`（Win10 起已弃用、Win11 已移除，新脚本无兼容保障）

## 4. Node.js 使用规范

- `.bat` 里调用 node 脚本用 **node.exe 绝对路径**，不依赖 PATH 或 npm（`start` 在子 cmd 环境会丢 PATH 继承，别用 `start` 调 node/npm；版本号随 Trae 升级变化；目录新旧混存且命名不统一，如 `24.12.0` 与 `v24.14.0`，按名排序会错选旧版，故用 `/o-d` 按目录时间倒序）：
  ```bat
  for /f "delims=" %%V in ('dir /b /ad /o-d "C:\Users\d59049\.trae-cn\binaries\node\versions"') do set "NODE_EXE=C:\Users\d59049\.trae-cn\binaries\node\versions\%%V\node.exe" & goto :node_found
  :node_found
  "%NODE_EXE%" script.js
  ```
- Vite 大项目内存不足（OOM）时可加 `--max-old-space-size=4096`（诗云项目实测需要）
- 缺库先 `pip install`（Python）或 `npm install`，再回退 PowerShell

## 5. 项目结构约定

- 新任务必须在当前工作目录下建**中文命名子文件夹**（如"任务1"、"任务2"）；任务文件夹用中文没问题，但脚本内部的路径、变量名避免中文（用英文名或相对路径），减少编码坑
- 写功能代码前**先**生成项目文档（README.md / DESIGN.md）说明目标、文件结构、逻辑流程
- 打包交付类项目（用户要求 .exe 交付时）的产物可按交付形态分文件夹存放，种类与命名不强制；历史项目常用可参考：`1-开箱即用`（免安装绿色版）、`2-安装器`（setup 安装包）、`3-单文件exe`（单文件便携版）；非打包任务不适用
- 工作区本身是一个 git 仓库：`git status` 把中文路径显示成 `\351\241\271...` 转义串时，是 `core.quotepath` 默认值所致，执行 `git config core.quotepath false` 即可（只影响显示）

### 审查/扫描时必须排除的目录（体积巨大或无意义）

- `node_modules/`
- `dist/`、`.next/`、`build/`
- 本工作区特有：`chinese-poetry/`、`public/data/`（诗云语料，6.6GB）
- `.git/`
- 任何 `*.log`、`*.zip`、`*.7z`、`*.rar`、`*.exe`、`*.dll`
- Python 产物目录：`__pycache__/`、`.venv/`、`.pytest_cache/`

## 6. 开发与测试协议

- **不要立即打包成 .exe**。先提供源码，在终端运行验证通过后再考虑打包
- 出错/失败时：分析终端输出 → 修代码 → 重跑验证，直到稳定；删除失败产物

### 视觉验收闭环（生成-观察-验证-优化）

- **凡用户看得见的产物（网页/GUI/3D 场景/渲染结果），验收必须包含视觉维度**——接口 200 ≠ 界面正确：前端拼 URL 缺 `?` 报 404、词云接口返回单字这类 bug 只有渲染出来才暴露
- 闭环流程：生成 → 运行 → **截图 → 目检 → 修复 → 重截复验**，直到所见即所期；截图后必须用 `read_image` 亲自看，按布局/颜色/文字/交互/3D 效果逐项对照
- 网页/3D 截图用本机 Chrome 无头（找不到再试 Edge）：
  ```powershell
  $chrome = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
  & $chrome --headless=new --disable-gpu --no-first-run --hide-scrollbars --window-size=1440,940 --virtual-time-budget=9000 --screenshot="shot.png" "http://localhost:3000/"
  ```
  - 渲染慢就加大 `--virtual-time-budget`（词云 16-20s、3D 场景 30s）；WebGL/3D 加 `--use-angle=swiftshader` 软渲染
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
5. **本地补充** — 生成代码时加函数级注释（说明函数作用、关键参数与返回），来自原 Trae 规则。

## 8. 历史教训（务必避免重蹈）

- koa-connect 包装器在 Express→Koa 迁移时丢失 ctx.state 数据——需原生 Koa 重写
- **DSH 规范配置验证（2026-08-14 ~ 08-15，sess1/sess2）**：AGENTS.md 由 `dsh-agent-instructions` 自动读取注入，dsh 遵守只读约束与目录排除。`check_win_bat_standards` 校验工具最终落地为 **npm 静态包**（源码 `DSH规范插件\win-bat-standards-pkg\index.js`），经 profile 的 `cordis.patch.yml` insert 行 + `package.json` file: 依赖自动挂载，`dsh web` 启动即用——**以此静态方式为准**。早期动态插件方式（`harness.defineTool`）仅进程内有效、重启即失，仅作历史参考。关键教训：① 静态包 `module.exports.apply(ctx)` 里不能用 `harness`（Builtin 仅动态 eval 作用域可用，会 `ReferenceError: harness is not defined`）；② 注册工具**不要** `require('@deepseek-ai/dsh-tools')` 再用其 `defineTool`——dsh-tools 内部用 Symbol 作工具调度器键，插件自带副本会与 DSH 核心产生模块实例冲突，报 `Cannot read properties of undefined (reading 'prepare')`；正确做法是手写工具定义的 JSON Schema（等价于 defineTool 输出，含 output 与 render）直接 `ctx.tools.register({...})`（`inject: ['tools']`）；③ pnpm 对 file: 依赖在标准用户 Windows 下回退为「拷贝」而非 junction，改源码不同步，需手动 `New-Item -ItemType Junction` 把 `profile\node_modules\win-bat-standards` 指向源码目录
- **任务6 软件优化教训（2026-08-21）**：① 修改工作区**外**的用户生产/交付目录（如 `D:\TraceQuery_优化版`、`D:\SQLQC_发布版`）前必须先快照备份（快照存工作区 `任务6_软件分析\生产目录快照_<日期>\`），禁止无备份直接覆盖——驱动升级翻车后回退不顺即此教训；工作区 `D:\Vibe Coding` 内的文件处于测试中、可随时重写，**不必备份**，频繁备份浪费空间；② 升级基础组件（数据库驱动等）前必须先确认目标环境兼容性：产线 MySQL 非标准 8.x，MySql.Data 8.0.33 连接时报 `Unknown system variable 'lower_case_table_names'`，最终回退产线验证版（SQLQC=MySql.Data 6.9.9、TraceQuery=MySqlConnector 1.3.14），**驱动不随软件功能升级**；③ 向用户承诺的"流程/规范"必须实际落成文档文件（如 `任务6_软件分析\部署与变更流程.md`），不能只停留在对话回复中
- **视觉验收（2026-08-27，诗词库第七轮）**：前几轮「API 回归=验收」范式一路顺，UI 工作未切换验收维度，直到用户质疑"你不是有眼睛吗"才建立 headless 截图 + read_image 目检链路——首轮目检即揪出 2 个接口测试测不出的 bug（前端拼 URL 缺 `?` 404；词云 mode=word 返回单字）。凡用户看得见的产物一律走 §6 视觉验收闭环
- **点检系统严重失误（2026-09-02~03，详见 `素材库\严重失误总结_点检系统20260903.md`）**：给产线 v1 正在使用的表加列导致停摆——v1 的 INSERT 是隐式全列 7 值（`values(default,...)`），加任意列即报「列数不匹配」，反编译时已看到此事实、决策时却未接入。铁律：**改生产库表结构（加/删/改列、索引）前，必须读旧程序对该表的全部读写 SQL 验证兼容性，先备份并写清回退语句（目录快照规则同任务6 教训 ①）；无法本机实测必须标注「未经实测」并用替代验证复现，禁止把推断写成「已验证/不影响」**；IL/二进制提取的路径、格式、分隔符必须逐字节解码 + 与真实样本双验证（曾把「C:\点检记录」解成「C:\点检文件」、补零/全角冒号解错），禁止凭记忆近似

## 9. 给 DSH 的专属说明

- 工作目录默认 `D:\Vibe Coding`
- **权限模式**：danger-full-access（完全访问），由 DSH 主导任务、自主决定修改，无需逐次请求审批
- 改 `.bat`/`.cmd`/`.vbs` 后**必须立即**按 §2 末尾的验证清单校验（优先调用 `check_win_bat_standards` 工具），不合规立即修复后重存
- 改 `.ps1` 后必须验证有 UTF-8 BOM；改 `.vbs` 后必须验证无 BOM：
  ```powershell
  # .ps1 前 3 字节应为 239,187,191（UTF-8 BOM）；.vbs 应无任何 BOM
  [System.IO.File]::ReadAllBytes("x.ps1")[0..2] -join ','
  [System.IO.File]::ReadAllBytes("x.vbs")[0..2] -join ','
  ```
- 本规范是 Trae 与 DSH 的**唯一规则来源**（原 `.trae\rules\项目.md` 已合并删除，勿再重建重复规则文件，两边都读本文件）
