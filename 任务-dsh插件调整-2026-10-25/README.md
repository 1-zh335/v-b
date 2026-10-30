# 任务：DSH 插件调整（dsh-cost-meter 安装 / web profile 旧插件清理）

- 执行日期：2026-10-25
- 执行人：DSH Agent（会话工作区 `C:\Users\31384\Documents\trae_projects\v b`）
- 关联规则：工作区根 `AGENTS.md`（§1 环境信息、§9 插件说明已同步修订）

## 1. 目标

1. 修正 `AGENTS.md` 中两处与实测不一致的环境记录（DSH 版本、裸 `dsh` 解析）。
2. 安装 `dsh-cost-meter`（文章推荐、且是本机宿主 0.2.1-rc.2 明确兼容的版本）。
3. 处理 web 端 DSH：原 `dsh-damage-pulse@4.0.0` 声明的 peer 只覆盖 DSH 0.1.x，与现宿主 0.2.1-rc.2 不兼容，且与 cost-meter 功能重叠 → 移除，换装 cost-meter。

## 2. 环境核查结论（修改 AGENTS.md 的依据）

| 项目 | 旧记录（失真） | 实测（2026-10-25） |
|---|---|---|
| DSH 版本 | CLI `0.1.1-rc.2`（npm 全局） | 桌面端内核 **`0.2.1-rc.2`**（app.asar `@deepseek-ai/dsh-desktop` 0.2.1-rc.2；`resources\runtime\primary-runtime\runtime.json` 的 `desktopVersion`） |
| 裸 `dsh` 解析 | 解析到系统级 npm 全局 | PATH 首位是桌面端自带 CLI `...\resources\runtime\cli\bin\dsh.cmd`，`dsh --version` = **0.2.1-rc.2**；npm 全局 `@deepseek-ai/dsh@0.1.1-rc.2` 仍安装但排在 PATH 之后、当前不生效 |

旁证：桌面端运行时 Node `24.21.0` / pnpm `11.28.5` / Python `3.12.14`（`runtime.json`）。

## 3. 执行记录

| 步骤 | 命令（桌面端自带 CLI） | 结果 |
|---|---|---|
| 快照备份 | 复制两 profile 配置 + 账本到本目录 `backup\` | 完成 |
| web 移除旧插件 | `dsh plugin --profile web remove dsh-damage-pulse` | exit 0，`- dsh-damage-pulse 4.0.0` |
| web 安装 cost-meter | `dsh plugin --profile web add dsh-cost-meter --save-exact` | exit 0，`+ dsh-cost-meter 1.9.31` |
| desktop 安装 cost-meter | `dsh plugin --profile desktop add dsh-cost-meter --save-exact` | exit 0，`+ dsh-cost-meter 1.9.31` |

说明：`pnpm add` 实际解析到 **1.9.31**（当时最新 1.9.36 因宿主 24h `minimumReleaseAge` 被暂缓，自动回退到已满 24h 的最新版 1.9.31），无需手工指定版本。

产物变化：

- `~/.dsh/profiles/web/package.json`：依赖 `dsh-cost-meter: "1.9.31"`；`dsh.profile.bundles` = `[dsh-base, dsh-web-app, dsh-cost-meter]`；`pnpm-lock.yaml` 不再含 damage-pulse。
- `~/.dsh/profiles/desktop/package.json`：依赖增加 `dsh-cost-meter: "1.9.31"`；`dsh.profile.bundles` 末尾追加 `dsh-cost-meter`。
- 运行中的桌面端已通过 HMR 热加载宿主插件：`plugin_manager` 清单出现 `include:cost-meter / dsh-cost-meter / active`（宿主条目 223 → 224）。
- `~/.dsh/data/dsh-token-monitor/usage.jsonl`（damage-pulse 旧账本，8255 B）**未删除**，保留作历史记录。

## 4. 备份与回退

备份位置：本目录 `backup\`

```
backup\profile-web\{package.json,cordis.patch.yml,cordis.yml,pnpm-lock.yaml,pnpm-workspace.yaml}
backup\profile-desktop\{package.json,cordis.patch.yml,cordis.yml,pnpm-lock.yaml,pnpm-workspace.yaml}
backup\data-token-monitor\usage.jsonl
backup\env-snapshot.txt
```

回退方式（任选其一）：

1. **只想退回旧插件组合**（web profile 重新装回 damage-pulse 4.0.0 / 升到兼容版 4.2.9）：
   ```powershell
   dsh plugin --profile web remove dsh-cost-meter
   dsh plugin --profile web add dsh-damage-pulse@4.2.9 --save-exact
   ```
   注：4.2.9 才明确适配 DSH 0.2.1-rc.2；4.0.0 与现宿主不兼容，不建议装回。
2. **完全恢复备份的配置**：把 `backup\profile-*\*` 拷回 `C:\Users\31384\.dsh\profiles\<profile>\`，删除对应 `node_modules` 后在 profile 目录执行 `pnpm install`（或直接 `dsh plugin --profile <p> add <原依赖>` 重建）。
3. 账本恢复：`backup\data-token-monitor\usage.jsonl` 拷回 `C:\Users\31384\.dsh\data\dsh-token-monitor\`。

## 5. 验证清单

- [x] `dsh --version` = 0.2.1-rc.2（`where dsh` 首位为桌面端 CLI）
- [x] web profile：`node_modules\dsh-cost-meter` 存在，lockfile 无 damage-pulse 残留
- [x] desktop profile：`package.json` 依赖与 bundles 均含 `dsh-cost-meter`
- [x] 运行中宿主已加载 cost-meter（`plugin_manager` 清单 active）
- [x] 旧账本文件保留
- [ ] 界面侧确认：客户端 bundle 需刷新页面（Electron 窗口 `Ctrl+R`）后，在「设置 → 费用」看到面板、输入区下方出现会话费用

## 6. 注意事项

- 桌面端为 nightly 渠道，自动更新会抬升内核版本；`dsh-cost-meter` 版本需跟随其 `dsh.compatibility`（当前声明 `>=0.2.0-rc.1 <0.3.0-0`）。
- 宿主 pnpm 内置 24h `minimumReleaseAge`：装刚发布的新版本会被暂缓（本次即解析到 1.9.31），必要时用 `--config.minimum-release-age=0` 或等待满 24h。
- 若仍想要鲸鱼娘：`dsh plugin --profile web add dsh-damage-pulse@4.2.9 --save-exact`；与 cost-meter 同时装会造成费用/余额展示重叠，建议只留一个。
