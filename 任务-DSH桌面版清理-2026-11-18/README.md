# 任务：DSH 桌面版清理（只保留桌面版）— 2026-11-18

## 1. 需求

用户原文（逐字，摘自 2026-11-17 晚的同一请求）：

> 验证一下当前是否为最新版本，同时将DSH的网页版进行清理。 我只需要桌面版。 另外，查询夸克网盘中的最新agenrs.MD文件。将其优化并布置到本机上，使得dsh和trae按其指导来进行工作

本目录只负责**网页版清理**；版本验证见 `任务-DSH升级-2026-11-17\README.md`，AGENTS 部署见 `任务-AGENTS规则优化-2026-11-18\README.md`。

## 2. 清理前状态（2026-11-18 00:44–00:50 实测）

| 项目 | 状态 |
|---|---|
| web profile | `~\.dsh\profiles\web`：1161 个文件 / **14.7 MB**；bundles：`dsh-base`、`dsh-web-app`、`dsh-cost-meter`、`@dsh-pet/bridge`；`cordis.patch.yml` 343 B |
| `dsh web` 实例 | host **PID 18868**，父进程 `cmd.exe` PID 18660；命令行 `dsh.CMD web --host 127.0.0.1 --port 38080`；监听 `127.0.0.1:38080` |
| 谁拉起的 | 桌宠 PID 18152（2026-11-18 00:44:10 启动）→ 00:44:31 通过 cmd 拉起 `dsh web`；桌宠配置 `harness_autostart=true` |
| 其它入口 | 工作区 `dsh-start.bat`（GBK+CRLF，启动 `dsh web` 3080）；桌面快捷方式 `DSH 启动.lnk` → 该 bat |
| 桌面端 | DSH 桌面 App 正常运行（宿主 PID 16308，GUI `127.0.0.1:55838`）；本任务不动桌面端 |

## 3. 操作（按顺序，2026-11-18 00:50 完成）

1. 停止桌宠进程 PID 18152（`Stop-Process -Force`）；
2. 修改桌宠 `%APPDATA%\dsh-pet-standalone-webm-chat\config.json`：`"harness_autostart": true` → **`false`**（保留 `agent_link.dsh=true` 与 `autostart_wanted=true`，桌宠仍随开机自启，只是不再拉起 DSH web）；
3. 停止 `dsh web`：父 `cmd.exe` PID 18660 + host PID 18868；
4. 归档 web profile：`~\.dsh\profiles\web` → **`~\.dsh\profiles-archive\web-20261118`**（未删除，便于回滚与 §6 到期清理）；
5. 归档入口：`dsh-start.bat`、桌面 `DSH 启动.lnk` → 本任务 `归档\`；
6. 重启桌宠（`dsh-pet-standalone-webm-chat.exe --slot 0`）。

## 4. 验证（2026-11-18 00:50–00:51 实测）

| 检查 | 结果 |
|---|---|
| 监听端口 38080 / 3080 | **0 个**（`Get-NetTCPConnection`） |
| `dsh web` 进程 | **0 个**（按命令行过滤） |
| `~/.dsh/profiles` 内容 | 只剩 `desktop`；`web` 不存在 |
| 桌宠 | PID **11544** 运行中；`harness_autostart=false`；日志 `pet-11544.log` 显示正常启动、`[DSH STATE]` 正常，无 web 启动记录 |
| 桌面端 | 6 个 `DeepSeek Harness.exe` 进程正常运行（GUI 正常） |
| 归档 | `归档\dsh-start.bat`（1,167 B）、`归档\DSH 启动.lnk`（1,013 B） |

## 5. 回滚方法

1. 停止桌宠 → 把 `~\.dsh\profiles-archive\web-20261118` 移回 `~\.dsh\profiles\web`；
2. 把 `归档\dsh-start.bat` 与 `归档\DSH 启动.lnk` 拷回原位；
3. 把桌宠配置 `harness_autostart` 改回 `true` → 重启桌宠；
4. 需要时运行 `dsh-start.bat` 启动 web（3080）。

## 6. 未验证 / 注意

- 只验证了**一个桌宠重启周期**：重启后未拉起 `dsh web`。若桌宠升级/重置配置/重复启动，建议复查 `harness_autostart` 与 38080 端口。
- 清理的是 **profile 与启动入口**；`dsh web` 命令和内置 web-app bundle 仍随 DSH 安装存在（这是桌面端自带组件，不是独立安装的软件），只是不再被自动/手动使用。
- 归档的 web profile 未删除；按 `AGENTS.md` §6 的备份策略，确认长期不用后可清理归档。
- 未改动 DSH 桌面端配置、插件与桌宠其它设置。

## 7. 证据文件

- 本目录 `归档\`（dsh-start.bat、DSH 启动.lnk）
- 桌宠配置：`%APPDATA%\dsh-pet-standalone-webm-chat\config.json`（`harness_autostart=false`）
- 归档 profile：`C:\Users\31384\.dsh\profiles-archive\web-20261118`
