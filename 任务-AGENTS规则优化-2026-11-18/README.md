# 任务：夸克网盘最新 AGENTS.md 的获取、优化与本机部署 — 2026-11-18

## 1. 需求

用户原文（逐字）：

> 验证一下当前是否为最新版本，同时将DSH的网页版进行清理。 我只需要桌面版。 另外，查询夸克网盘中的最新agenrs.MD文件。将其优化并布置到本机上，使得dsh和trae按其指导来进行工作

拆解：① 从夸克网盘找到最新 `AGENTS.md`；② 按本机环境优化；③ 部署为 DSH 与 Trae 都实际加载的规则源。

## 2. 来源（夸克网盘，2026-11-18 00:48 查询）

- Skill：`quarkclouddrive` 1.0.25，已授权；用 `search --keyword "AGENTS"` 查询，共 4 个结果：`agents` 文件夹、`SKILL.md`、`lark-apps-plugin-install.md`、**`AGENTS.md`**。
- **最新 AGENTS.md**（唯一规则文件）：`fid = ~1zBVDF3bbCgUfdTWpgDHosfBHXCRD2nYz58AvcFAiYXYC8vRbbnqzdz0sJhBMapwTmvZXdRFgk6yB4n6-zw6kvU|FtJuCdOcmao`；大小 **39,496 B**；`created_at/updated_at = 1794762626360`（**2026-11-16 01:10:26 UTC+8**）；位于网盘根目录。
- 下载 39,496 B 版到 `下载\旧版-39496-2026-11-16\AGENTS.md`（SHA-256 `F9AE86BF…`）。- **复查时发现网盘根目录还有更新的 44,935 B 版 `AGENTS.md`（2026-11-17 21:30 上传，created_at/updated_at 1794922256233/1794922443729），已下载到 `下载\AGENTS.md`；该新版新增技能发现机制与 §9.6 用户级技能章节。**
- ⚠️ 该文件是**另一台机器**（`desktop-kji2ku0`、`F:\DeeoSeek`、`E:\论文`，无 Trae、无桌宠）的定制规则，路径与事实均不适用本机，因此必须优化后再部署。

## 3. 优化内容

以云端版**结构与通用规则为骨架**（规则加载机制、编码规范、视觉验收、承诺纪律、备份原则、DSH 运行机制），做以下改造：

1. **环境事实全部替换为本机 2026-11-18 实测**：用户 `MOSS\31384`、Win11 26340、DSH `0.2.2-rc.3`、`%LOCALAPPDATA%` 安装路径、DSH_HOME、只保留 desktop profile、系统 Node/npm 与 DSH 双运行时、系统 Python、git/bash/curl、Edge 157.0.4341.60、Quark 7.4.7.1036、Trae 3.4.20、插件版本、桌宠等。
2. **规则架构适配本机**：云端要求「唯一用户级 `$DSH_HOME/AGENTS.md`、禁止指针」；本机同时有 Trae，改为 **工作区唯一正文 + 两个纯指针**（`$DSH_HOME/AGENTS.md`、`~/.trae-cn/user_rules/工程规范.md`），并显式开启 Trae `AI.rules.importAgentsMd=true`。
3. **补充本机独有经验**：2026-11-17 DSH 更新失败修复（旧 installer + 运行实例）、内核升级后 subagent 版本对齐、2026-11-18 网页版清理（仅桌面版）。
4. 保留云端通用教训（备份精简原则、编码坑、窗口先看、网络排障等），删除仅适用于云机源的路径与假设。

5. **新增桌面整洁规则（2026-11-18）**：在 §5 增加「项目/任务快捷方式一律放进对应工作区任务文件夹」规则，并据用户要求把桌面 `Uncle小说 · 本地TXT快速阅读.lnk` 移入 `任务-uncle-novel优化-2026-10-25\`（详见 `任务-桌面快捷方式整理-2026-11-18\README.md`）。

6. **并入云端 2026-11-17 更新版的技能机制**：新增 §9.6「用户级技能（第三方）」、§9.1 技能发现机制、§10 技能自检；当时本机未安装这 10 个技能（云端版事实属于另一台机器）；2026-11-19 22:01 已按上游来源全部安装，见 §9 与 `任务-第三方技能安装-2026-11-19`。

**结果**：51,656 B / 434 行，UTF-8 无 BOM，LF；< 65536 渲染预算；SHA-256 `9B02C66D57B79975F8530926BFBF957ABF324E5D43DF5DB09F56037BF7870586`。

## 4. 部署位置与验证

| 位置 | 内容 | 验证 |
|---|---|---|
| `C:\Users\31384\Documents\trae_projects\v b\AGENTS.md` | **唯一规则正文**（51,656 B） | 工作区根仅此 1 个 `AGENTS.md`；UTF-8 无 BOM；大小 < 65,536 B |
| `C:\Users\31384\.dsh\AGENTS.md` | DSH 用户级**指针**（只给路径） | 文件存在；内容 6 行、无规则正文 |
| `C:\Users\31384\.trae-cn\user_rules\工程规范.md` | Trae 用户级**指针** | 文件存在；内容 5 行、无规则正文 |
| `%APPDATA%\Trae CN\User\settings.json` | 新增 `"AI.rules.importAgentsMd": true` | JSON 解析通过；与已有 `importClaudeMd=true` 并存 |

- **DSH**：新文件写入后，会话指令加载器已刷新注入（系统提示显示新 `AGENTS.md` 内容）；规则 §9.1 约定——**新会话/新基线完整生效**，当前会话已注入内容不保证热替换。
- **Trae 实际加载 ✅（2026-11-18 01:08 实测）**：启动 Trae 3.4.20 → 打开工作区 `v b`（窗口标题变为 `v b - TRAE CN`）→ 在 Agent 提问「只根据项目根 AGENTS.md 回答……」→ Trae 回答写明「以下三处均直接引用 AGENTS.md 原文，不加任何推断」，并引用第 196 行 `dsh-start.bat`/`DSH 启动.lnk` 归档内容、以及「当前文件约 45 KB 内 / 网盘源文件 39,496 B（2026-11-16 上传）」等本文件独有内容，**证明规则已被实际读取**。截图见 `调研\Trae加载实测\00–05*.png`。
- **第三方技能安装（2026-11-19 22:01）**：已从上游安装全部 10 个技能（28 个文件）到 `$DSH_HOME\skills`，DSH 技能目录已刷新出现全部名称；此前 21:18「未安装」核验已被取代。详见 `任务-第三方技能安装-2026-11-19\README.md`。
- **Trae 最新 §9.6 验证（2026-11-19 21:25）**：启动 Trae 后打开旧任务提问，回答称「§9.6 未提及技能目录/10 个技能」——**旧任务沿用规则快照，未重载新内容**；点击「新任务」后重新提问，Trae 正确引用 §9.6：「本机 `$DSH_HOME\skills` 下实际只有 quarkclouddrive（1.0.25）」「云端列出的 10 个第三方技能不在本机，未安装」，并引用 §0 第 40 行列出的 10 个技能名（以上为 21:25 当时回答；22:01 已安装全部技能）。截图 `调研\Trae加载实测\06-旧任务未重载-仍用旧规则.png`、`07-新任务已加载最新§9.6.png`。
- **旧版本恢复**：工作区旧 `AGENTS.md` 为 41,809 B（CRLF 工作副本），其 LF 版在 git HEAD（41,558 B）中，可用 `git -C "C:\Users\31384\Documents\trae_projects\v b" show HEAD:AGENTS.md` 恢复；按新版 §6「默认不备份」，未额外保留本地副本。
- 优化版已按用户 2026-11-18 要求上传网盘（结果见 §7，上传后回填）。

## 5. 未验证 / 待确认

- **Trae 设置热重载**：本次走的是「先写入设置 → 启动 Trae → 打开工作区」路径并实测通过；Trae 运行中修改该设置是否即时生效未单独验证（⚠️）。
- **DSH 新会话完整生效**：当前会话在文件改动后已收到注入更新，但按机制以新会话为准（⚠️ 已按机制说明，不作「已完全生效」承诺）。
- 云端最新 AGENTS.md 可能继续更新；本任务只取 2026-11-16 版本（查询时点最新）。
- 未验证 `Documents\AGENTS(1).md` 等历史副本是否仍被某个工具读取（本机 DSH/Trae 均不加载该路径；未删除用户文件）。

## 6. 文件清单

- 云端原件：`下载\AGENTS.md`（44,935 B，2026-11-17 更新版）+ `下载\旧版-39496-2026-11-16\AGENTS.md`（39,496 B，SHA-256 `F9AE86…` 见上）
- 部署正文：工作区根 `AGENTS.md`（51,656 B，SHA-256 `9B02C6…`）
- 指针：`~/.dsh/AGENTS.md`、`~/.trae-cn/user_rules/工程规范.md`
- Trae 设置：`%APPDATA%\Trae CN\User\settings.json`

## 7. 网盘上传记录（2026-11-18）

| 项目 | 内容 |
|---|---|
| 上传文件 | AGENTS-本机优化版-2026-11-18.md（46,936 B，内容 = 工作区 AGENTS.md 副本） |
| 上传时间 | 2026-11-18 2026-11-18 01:12:29（UTC+8） |
| 上传结果 | code:0、ileSize:46,936、ileId:66de91d60ba845e1bfb2ffc4c10e6882、ecordId:83da153a-596c-42c1-8db1-a76bcb8778b7、ullPath:夸克网盘 |
| 网盘 fid | ~1Mg7V6xVnZSImSYggqfcETybLR9fGg-iSIRs4tqJFwXtuVNTJ2ML5P1LAhtIDyKw7hwv1HNo4iiDPnut7fWWw9M\|5DBNTtMVjas |
| 上传后 search | search --keyword "AGENTS-本机优化版" → **total:1**、filename AGENTS-本机优化版-2026-11-18.md、size 46,936 |
| 说明 | 未删除旧文件：网盘根目录仍有 2026-11-17 版 AGENTS.md（44,935 B，另一台机器规则），另有一份 39,496 B 旧版；本次以独立文件名上传本机优化版，避免误删。如用户要求替换旧 AGENTS.md，需登录夸克网盘网页后删除旧文件再上传同名版本（官方 Skill 无删除命令）。 |
## 8. 2026-11-19 审阅与二次上传

- 审阅报告：`调研\AGENTS审阅-2026-11-19.md`
- 2026-11-19 21:26 部署版（技能安装前）：**48,627 B / 416 行**，UTF-8 无 BOM，SHA-256 `D0B2A914E1254F739FD80382B666656A5F7CA32E0BBE5DCA06CC1FA2FC7B3C2A`。
- 复核修正：DSH 已自动升到 `0.2.2-rc.5`、subagent 同步 rc.5、HEAD 更新为 `409e98c`；§5/§8/§10 增加「快捷方式污染桌面」教训与桌面自检；§9.1 增加「Trae 旧任务不热重载、需新建任务」实测。
- 二次上传（夸克网盘）：文件名 `AGENTS-本机优化版-2026-11-19.md`，48,627 B；fileId `097c04a8929e4ec381952974c057107c`，recordId `34a5a946-0d30-41ad-83a1-6b8cb2822d55`；网盘 fid `~1rTGZDsSj510DJL37TV1bRyS23se0dkb6WKVJ_AVIt6UWxTvbCxZ4WZoUP14qrMQgbtFlMAKk9rGROZ7rHiHRQc|ifGWADz1nVs`；search `AGENTS-本机优化版` 共 2 条（2026-11-18 版 46,936 B + 2026-11-19 版 48,627 B），本次 2026-11-19 版核验 size=48,627。
- 未删除旧文件（2026-11-18 版 46,936 B、网盘旧 AGENTS.md 等），避免误删。
## 9. 技能安装后的 AGENTS 二次同步（2026-11-19 22:02）

- 安装 10 个技能后，AGENTS.md 更新为 **50,653 B / 432 行**，UTF-8 无 BOM，SHA-256 `A05FC78CC6CE53C13B3B4A066E794C2B544810C0CED9FF3342FC96AD657BCA0F`；§0 技能行、§9.1 技能发现、§9.6 来源表已改为「已安装」。
- 已上传夸克网盘：`AGENTS-本机优化版-2026-11-19-技能版.md`（50,653 B）；fileId `aad26c75b6e74b99b19e3781dd874d41`，recordId `1ec5d4b6-4c43-47ac-af7b-5ae26542ba19`；网盘 fid `~1CbX4f0RbwHEOk6kif7vJAiv2E0_rgCEhV0QNCz-rkiQVWz3QZH0oqkXR-OJilIPyXiOqoO-PhPZJMxJUT0RmTY|UwJ04H1rrTw`；search 核验 total=1、size=50,653。
- 技能安装详细记录见 `任务-第三方技能安装-2026-11-19\README.md`。
## 10. 技能运行修复后的 AGENTS 再同步（2026-11-19 22:38）

- 修复依赖（Playwright 1.65.2、gh 2.105.0、yarn 1.22.22）及技能 Windows/DSH 适配后，AGENTS.md 更新为 **51,656 B / 434 行**，UTF-8 无 BOM，SHA-256 `9B02C66D57B79975F8530926BFBF957ABF324E5D43DF5DB09F56037BF7870586`；§0 新增技能运行依赖行，§9.6 新增运行前置/本地适配说明。
- 已上传夸克网盘：`AGENTS-本机优化版-2026-11-19-修复版.md`（51,656 B）；fileId `70291cd5dee541e8bee81f89709bf66e`，recordId `953bda43-3641-4cf8-9e04-dabc20bf675e`；网盘 fid `~1-pY_x06w0PkhMLl8Z6Td0IZss6YcXGKHWAkHJE09fCMu4eTkEYEl88CX3S7OxfUHmRuMgb-mpSEJz2ZRzVrHwI|u0K8w_-o8lw`；search `AGENTS-本机优化版` 共 4 条，其中修复版 size=51,656 已核验。
- 技能修复明细见 `任务-第三方技能安装-2026-11-19\调研\修复验证.txt` 与兼容性报告 §8。
