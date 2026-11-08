# 任务：Git 仓库深度整理（2026-11-09）

## 目标

整理工作区 Git 仓库：提交未入库内容、把大文件/二进制/旧截图从仓库历史中移除（本地文件全部保留）、重写历史并 force push，让公开仓库只保留文档/工具/文本证据。

## 整理前状态

| 项 | 数值 |
|---|---|
| 分支/远端 | `main` / `origin = https://github.com/1-zh335/v-b.git`，8 个提交，与远端对齐（`a0d33e5`） |
| 未提交 | 2 个已跟踪改动（`AGENTS.md`、`任务-大肥鱼桌宠/README.md`）+ 未跟踪任务目录 `任务-DSH安装文档与云盘上传-2026-10-31/`（15 个文件，1.4 MB） |
| 已跟踪内容 | 713 个文件 / 34.05 MB；git 对象 21.21 MB |
| 主要体积 | 截图 121 个 13.63 MB、素材 txt 6.44 MB、PDF 5.62 MB、TTS bin 50 个 2.71 MB、jar 备份 1.60 MB、解包 class/appjar 216 个 1.17 MB、备份文件 0.54 MB |
| 重复文件 | 45 组完全重复（54 个副本，1.19 MB） |

## 执行步骤（均有命令/输出）

1. **提交未入库改动**：`a839fe5`（AGENTS 插件记录 + 桌宠 MiMo TTS 核对）；新任务目录暂不提交。
2. **停止跟踪清理对象**：394 个文件（旧截图/PDF/jar/bin/class/woff/素材/备份）从索引移除，工作区文件保留；`.gitignore` 增加瘦身规则；提交 `f51ecf1`（amend 后）。
3. **完整备份**（在 `C:\Users\31384\Documents\v-b-backup-2026-11-09\`）：
   - `repo-mirror.git`（`git clone --no-hardlinks --mirror`，含全部旧提交）
   - `vb-all-2026-11-09.bundle`（`git bundle create --all`，22.2 MB，`git bundle verify` 通过）
   - `cleanup-files-2026-11-09.zip`（394 个将被移出历史的本地文件，25.4 MB）
4. **历史重写**：用 `git filter-repo 2.47.0` 在 `--no-local` 新鲜克隆中执行（`--invert-paths --path-glob ...`），移除：
   - `*.png` / `*.jpg` / `*.jpeg`（旧截图；新任务 4 张截图不在旧历史中）
   - `*.pdf`、`*.jar`、`*.jar.*`、`*.bin`、`*.class`、`*.woff` / `*.woff2`、`*.orig`
   - `*/appjar/*`（解包 jar 目录）、`*素材转换*`、`*原始空规则备份`
5. **接回主仓库**：`git fetch <重写克隆> main` → `git reset --hard FETCH_HEAD`；重写后 HEAD 树与重置前**逐文件一致**（319 个文件，0 差异）。
6. **新增提交**：新任务目录（文档 + 4 张证据截图）+ 本次 README/任务记录 + `AGENTS.md`/`.gitignore` 更新。
7. **force push**：`git push --force-with-lease=main:<旧远端 sha> origin main`，网络失败时按 `http.curloptResolve` 轮换 IP 重试。

## 验证结果

| 项 | 结果 | 证据 |
|---|---|---|
| 提交历史保留 | 重写后 10 个提交，另加整理提交（推送 HEAD `46fc121`，共 11 个；SHA 变化、消息/顺序保留） | `git log --oneline` |
| 历史违禁路径 | 0（对 `--name-only` 全历史扫描：png/jpg/pdf/jar/bin/class/woff/orig/appjar/素材转换/原始空规则备份） | 重写克隆内扫描输出 |
| HEAD 文件一致性 | 旧 319 = 新 319，双向差异 0 | 两个 `git ls-tree`/`ls-files` 对比 |
| 本地文件保全 | 394/394 个被移出历史的文件仍在工作区 | 清单逐项 `Test-Path` |
| 仓库体积 | 重写克隆 pack **775 KB**；远端全新克隆 pack **1.76 MiB**（含 4 张证据截图）；本地 `.git` 23.24 MB → **1.84 MB**（gc 后） | `git count-objects -vH` / 远端 `git clone --no-local` |
| 当前跟踪内容 | 319 个文件 / 约 2.98 MB | `git ls-files` + 文件大小统计 |
| GitHub API `size` 字段 | 仍显示 21696 KB（force push 后不可达对象短时计入；以全新克隆 1.76 MiB 为准，GitHub 侧 GC 后可能更新） | API `/repos/1-zh335/v-b` | force push 成功；远端全新克隆：**12 个提交 / 335 个文件 / pack 1.76 MiB**；远端树扫描仅 4 个例外条目（用户指定入库的证据截图），其余无 png/pdf/jar/bin/class/素材残留 | `git push` 输出 / `git ls-remote` / GitHub API trees / 远端 `git clone` |

## 推送结果

- **已推送**（2026-11-09）：`git push --force-with-lease=main:a0d33e57aa63e62212b98cc891ff77e181988eb8 origin main` 成功，输出 `+ a0d33e5...46fc121 main -> main (forced update)`；`git ls-remote origin main` 返回 `46fc1217f2d1279928b2719fd7b523b6316b598a`，本地 `main...origin/main` 同步（无 ahead/behind）。随后补充本次文档记录提交并普通推送成功（`46fc121..30c7569  main -> main`），远端 HEAD 现为 `30c7569`。

## 回滚

旧历史完整保存在备份目录，任选其一恢复：

```powershell
# 方式 A：从 bundle 恢复（推荐，先备份当前 .git）
git clone "C:\Users\31384\Documents\v-b-backup-2026-11-09\vb-all-2026-11-09.bundle" "D:\vb-restore"

# 方式 B：从镜像仓库恢复
git clone --mirror "C:\Users\31384\Documents\v-b-backup-2026-11-09\repo-mirror.git" "D:\vb-restore.git"

# 方式 C：只找回被清理的本地文件（zip 解压覆盖回工作区）
Expand-Archive "C:\Users\31384\Documents\v-b-backup-2026-11-09\cleanup-files-2026-11-09.zip" "D:\vb-cleanup-restore"
```

远端回滚：在 GitHub 仓库 Settings → Danger Zone 无法直接恢复；需从备份重新 push（`git push --force`）。因此备份目录**不要删除**，确认稳定后再清理。

## 后续规则

- 截图、PDF、JAR、`*.bin`、`*.class`、字体、素材、备份默认不入库（`.gitignore` 排除，本地保留）；
- 例外仅限经用户确认要入库的证据截图（当前为新任务的 4 张，`.gitignore` 用 `!` 放行）；
- 新增同类大文件时先确认是否真的需要进公开仓库。
