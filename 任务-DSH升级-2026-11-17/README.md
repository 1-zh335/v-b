# 任务：修复并完成 DSH 更新安装（0.2.1-rc.5 → 0.2.2-rc.3）

## 1. 需求（2026-11-17 20:47）

用户原文（逐字）：

> 本机环境似乎出了点问题，无法更新DSH的最新版本，请你帮我更新安装一下。

## 2. 诊断（只读实测）

| 项目 | 实测结果 |
|---|---|
| 当前安装版本 | `0.2.1-rc.5`（exe FileVersion、`runtime.json` 均为 rc.5；安装目录 `resources` 时间 2026-10-29 22:02:52） |
| 官方 nightly 最新 | **`0.2.2-rc.3`**（`nightly.yml` releaseDate `2026-11-13T07:31:42Z`；安装包 299,595,752 B；sha512 `GiJf8kx+…CKzQ==`） |
| 已下载更新包 | `%LOCALAPPDATA%\@deepseek-aidsh-desktop-updater\pending\deepseek-harness-0.2.2-rc.3-win-x64.exe`（299,595,752 B，2026-11-17 20:42:42） |
| 安装包校验 | ✅ SHA512 与官方 nightly.yml 完全一致；✅ Authenticode 签名有效（Hangzhou DeepSeek Artificial Intelligence Co., Ltd.） |
| 更新缓存根目录 | 仍留着 2026-10-30 的旧 `installer.exe`（289,408,544 B，对应 rc.5），`pending` 下是今天下载的 rc.3 |
| 运行实例 | 主 App（窗口 PID 19048、宿主 PID 19796，GUI 127.0.0.1:63520）+ **`dsh web` 常驻实例 PID 17120（127.0.0.1:38080）** + 多个子进程；均从安装目录同一 exe 运行 |
| 磁盘 | C: 可用 855.6 GiB（充足） |
| 更新日志 | 未找到 electron-updater 文件日志（`%APPDATA%\@deepseek-ai\dsh-desktop\logs` 不存在） |

**结论（⚠️ 推断，待安装验证）**：下载链路正常、安装包完整；失败点在"安装/替换文件"步骤。最可能原因：
1. 安装器运行时仍有多个 `DeepSeek Harness.exe` 实例（尤其独立的 `dsh web` 实例）在跑，安装器检测"应用正在运行"后未完成替换；
2. 更新缓存根目录的旧 `installer.exe`（rc.5）与 `pending` 的 rc.3 并存，更新流程未把新包提升为待执行安装包，点"更新"实际可能又跑了旧包 → 版本不变。

## 3. 修复方案（已安排）

1. **强制停止所有** `DeepSeek Harness.exe` 进程（主 App、`dsh web` 38080 实例、宿主与子进程；桌宠是独立进程，不动）；
2. 直接运行 **pending 里的 rc.3 安装包**（`/S` 静默安装，per-user，无需管理员）；
3. 安装后校验 exe FileVersion、`runtime.json.desktopVersion`、`dsh --version` 是否均为 `0.2.2-rc.3`；
4. 重新启动 DSH 桌面端；
5. 结果写入本目录 `install-result.txt`。

执行方式：已注册 Windows 计划任务 `DeepSeekHarnessUpdate_20261117`（**预期开始时间见 `schedule.txt`**），由 Task Scheduler 在独立进程执行，避免"安装器关闭 App 导致执行中断"；脚本位于 `%TEMP%\dsh_update_20261117.ps1`，完成后自删计划任务。

## 4. 风险与回滚

- 安装过程会关闭 DSH 桌面端并**中断当前会话**；重开后会话记录仍在。
- 安装包有官方签名且 SHA512 与源一致；旧版本安装包 `installer.exe`（rc.5）保留在更新缓存中，可手动回退（运行该安装包）。
- 安装失败时不会卸载旧版本；`install-result.txt` 会记录退出码与实际版本，供下一步排查。

## 5. 验证结果（2026-11-18 00:44 复核）

- **安装执行**（`install-result.txt` 原文摘要）：2026-11-17 20:57:01 计划任务启动 → 强制停止 9 个 `DeepSeek Harness.exe`（含 dsh web 38080 实例）→ 20:57:59 安装器 `exit code=0` → 20:58:09 `FileVersion=0.2.2-rc.3`、`runtime.json desktopVersion=0.2.2-rc.3` → 20:58:11 `dsh --version => 0.2.2-rc.3` → **RESULT: SUCCESS** → App 自动重启 → 计划任务自删。
- **版本核对（2026-11-18 00:44）**：官方 nightly 最新仍为 **`0.2.2-rc.3`**（`nightly.yml` releaseDate `2026-11-13T07:31:42.937Z`），本机已是最新，无需再升。
- **插件对齐（同日）**：升级后 subagent 两包 0.2.1-rc.5 与内核不兼容（`incompatible-version`、rows 空）→ 用 `dsh plugin --profile desktop add @deepseek-ai/dsh-subagent-codex@0.2.2-rc.3` 与 `...claude-code@0.2.2-rc.3` 升级（exit 0）；`plugin_manager` 中两包 **rows 恢复、active**；`dsh-cost-meter@1.9.62`、`@dsh-pet/bridge` 仍 active。
- **网页版清理**：另见 `任务-DSH桌面版清理-2026-11-18\README.md`（web profile 归档、38080 实例已停、桌宠 `harness_autostart` 关闭并验证不再拉起）。
- **未验证**：升级后 GUI 界面的更新提示/设置页显示（未逐项目检）；旧 rc.5 安装包仍在更新缓存根目录，可手动回退。
