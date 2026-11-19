# 任务：安装 10 个第三方 DSH 技能 — 2026-11-19

## 1. 需求

用户原文：

> 把那几个技能给我安装上啊

即：把云端 AGENTS.md §9.6 所列的 **10 个第三方技能**安装到本机 `$DSH_HOME\skills`（`C:\Users\31384\.dsh\skills`）。

## 2. 安装结果（已完成，2026-11-19 22:01）

- 安装路径：`C:\Users\31384\.dsh\skills\<技能名>\`
- 原有 `quarkclouddrive`（1.0.25）**未改动**；安装后共 11 个技能目录。
- 10 个技能与文件数：

| 技能 | 上游来源 | 本地文件数 |
| --- | --- | --- |
| `frontend-design` | anthropics/skills → `skills/frontend-design` | 2 |
| `webapp-testing` | anthropics/skills → `skills/webapp-testing` | 6 |
| `find-skills` | vercel-labs/skills → `skills/find-skills` | 1 |
| `frontend-code-review` | aiskillstore/marketplace → `skills/langgenius/frontend-code-review` | 9 |
| `code-reviewer` | google-gemini/gemini-cli → `.gemini/skills/code-reviewer` | 1 |
| `pr-creator` | google-gemini/gemini-cli → `.gemini/skills/pr-creator` | 1 |
| `fix` | react/react → `.claude/skills/fix` | 1 |
| `update-docs` | vercel/next.js → `.agents/skills/update-docs` | 3 |
| `cache-components` | vercel/next.js → `skills/next-cache-components-adoption` | 3 |
| `fullstack-developer` | aiskillstore/marketplace → `skills/shubhamsaboo/fullstack-developer` | 1 |

合计 **28 个文件**。

## 3. 安装方法

- 网络实测：`api.github.com` 200；`raw.githubusercontent.com` / `github.com` / jsdelivr 被 reset；`codeload.github.com` 很慢但可完成。
- 小仓库（anthropics/skills、vercel-labs/skills）：下载 codeload tar.gz 后解压取目录（分别约 4.1 MB / 0.45 MB）。
- 大仓库（gemini-cli、react、next.js、marketplace）：用 GitHub API `contents` 逐文件 base64 下载，避免整仓 tarball；未认证 API 限额 60 次/小时，本次控制在限额内。
- `frontend-code-review`：Dify 上游已移除该技能；按云端版说明从 `aiskillstore/marketplace` 的 `skills/langgenius/frontend-code-review` 镜像安装（SKILL.md + 8 references）。
- `cache-components`：上游目录仍叫 `next-cache-components-adoption`，安装为 `cache-components`，并把 SKILL.md frontmatter `name` 改为 `cache-components` 以匹配目录名。
- `fix`：原 `facebook/react` 已重定向到 `react/react`，按 `react/react` 下载。

## 4. 验证（2026-11-19）

- 10 个目录均存在，文件数与上表一致（总 28）。
- 每个 `SKILL.md` 存在，frontmatter 以 `---` 开头、含 `name:` 与 `description:`；`name` 与目录名一致。
- `references/`、`scripts/`、`examples/` 相对引用逐项 `Test-Path`：**0 缺失**（frontend-code-review 8 个、update-docs 2 个、cache-components 1 个、webapp-testing 1 个）。
- DSH 运行时发现：安装后下一步会话技能目录（available_skills）**出现全部 10 个名称**，无需重启。
- 详细逐项证据：`调研\安装验证.txt`。

## 5. 未验证 / 说明

- 未逐个执行 10 个技能的实际工作流（只验证安装完整性、引用与 DSH 发现）；具体行为待使用场景验证。
- `frontend-code-review` 为旧 Dify 版镜像（上游已删除），内容可能落后于 Dify 当前前端规范。
- `cache-components` 的 `description` 为 YAML 折叠块，脚本初检 desc_len=1 属解析方式问题；DSH 技能目录显示描述正常。
- 未在 `~/.agents/skills`、项目 `.dsh/skills` 等位置产生副本。

## 6. 回滚

删除 `C:\Users\31384\.dsh\skills\` 下对应 10 个目录即可；`quarkclouddrive` 不受影响。

## 7. 文档更新

- `AGENTS.md` §0「用户级技能」行、§9.1 技能发现、§9.6 来源表已更新为「已安装」。
- 审阅报告 `任务-AGENTS规则优化-2026-11-18\调研\AGENTS审阅-2026-11-19.md` 已追加事后更新说明。
## 8. 兼容性测试（2026-11-19）

- 测试报告：`调研\兼容性测试-2026-11-19.md`；证据：`调研\兼容性证据.txt`。
- **格式与 DSH 发现：10/10 通过**（均已出现在 DSH 技能目录；frontmatter/引用/文件数正常）。
- **上游版本：9/10 为安装时默认分支快照；rontend-code-review 为 Dify 已删除后的 marketplace 旧镜像，已过时。**
- **环境结论：3 个直接可用（frontend-design、update-docs 限 Next.js 仓库、fullstack-developer）；6 个有前置/上下文缺口；1 个过时。**
- 主要缺口：gh 未安装（code-reviewer/pr-creator 远程 PR）；Python playwright 未安装（webapp-testing）；yarn 未安装（fix）；
px skills 只识别 Trae CN、不识别 DSH（find-skills）；webapp-testing 的 /tmp 与 cache-components 的 Unix ind 需 Windows 适配；cache-components 建议的 
ext-dev-loop 伴生技能未装。
- 版本匹配：cache-components 要求 Next.js ≥16.3，当前 npm 最新 16.4.6，满足；update-docs 面向 Next.js canary；React 当前 19.3.1。
- 本次**未修改任何技能文件**，只做只读测试；需要补依赖/做 Windows 与 DSH 适配时再处理。
## 9. 2026-11-19 修复与验证

- **依赖已装**：Python Playwright 1.65.2、GitHub CLI 2.105.0（未登录）、Yarn 1.22.22；webapp-testing 用 Edge channel + --no-proxy-server 冒烟通过（with_server.py helper_exit=0、screenshot=True）。
- **技能修补**：webapp-testing（Windows/Edge/路径）、find-skills（DSH 路径说明）、cache-components（PowerShell find、next-dev-loop 可选）、code-reviewer/pr-creator（gh 与 preflight 条件）、fix（包管理器自适应）、frontend-code-review（标注 Dify 旧镜像）。
- 修复后 10 个技能、28 个文件；frontmatter 与引用校验通过。
- 详细记录：`调研\修复验证.txt`；审计报告已追加 §8 修复结果。
- 仍需人工处理：gh auth login（远程 PR）；rontend-code-review 上游已删除，无新版本可拉取。
