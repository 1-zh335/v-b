# v b — 本地工作区

> 本机任务工作区（Windows 11 / DeepSeek Harness + Trae）。
> 所有工程规范以根目录 `AGENTS.md` 为**唯一来源**：Trae 与 DSH 都直接自动加载同一文件；`.trae/rules/` 已清空、`C:\Users\31384\.dsh\AGENTS.md` 与 Trae 个人规则仅保留指针。

## 目录内容

- `AGENTS.md` — 本机 AI Agent 工程规范（Trae + DSH 共用唯一文档，改规则只改这里）
- `dsh-start.bat` — DSH Web UI 启动脚本（桌面「DSH 启动」快捷方式目标）
- `push-to-github.bat` / `push-to-github.ps1` — GitHub 一键上传
- `工具/` — 跨任务可复用工具（`窗口查看.ps1`：窗口截屏/UIA；`浏览器\`：Edge CDP + Playwright 驱动；见 `工具/README.md`）
- `任务-规则防过度承诺与文档审查-2026-10-31/历史归档/` — 旧规则文档与适配记录（2026-10-31 从根目录归档）
- `任务X/` — 各任务目录（中文命名，见规范 §5）

## 上传到 GitHub

**一键方式（推荐）**：双击 `push-to-github.bat`，按提示粘贴个人访问令牌（PAT）即可自动完成：验证账号 → 建仓库（`v-b`，公开，脚本开头可改）→ 关联远程 → 推送 `main`。
- 令牌只在运行时输入、不写入任何文件；成功后存入系统凭据管理器，之后 `git push` 免登录
- 令牌获取：https://github.com/settings/tokens → Generate new token → Tokens (classic) → 勾选 `repo` → 复制 `ghp_...`
- 用完可随时撤销：GitHub → Settings → Developer settings → Personal access tokens

**手动方式（备选）**：
1. 在 GitHub 新建空仓库：https://github.com/new（建议 `v-b`，**不要**勾选任何初始化文件）
2. 在仓库目录执行：
   ```powershell
   git remote add origin https://github.com/1-zh335/v-b.git
   git push -u origin main
   ```
3. 之后的增量上传：`git add -A && git commit -m "说明"`，再 `git push origin main`
4. 提交身份为 `1-zh335 <3138470565@qq.com>`；若要提交关联账号，请在 GitHub → Settings → Emails 验证该邮箱
5. 推送前 `git status` 确认无敏感/大文件（排除规则见 `.gitignore`）

## 约定

- 新任务在根目录下新建中文命名子目录（如 `任务1`）
- 改 `.bat`/`.cmd`/`.vbs` 后立即按规范 §2 校验（GBK + CRLF）
- 修改规范：只改根 `AGENTS.md`，Trae 与 DSH 自动生效，无需同步
- 推送前 `git status` 确认无敏感/大文件；排除规则见 `.gitignore`
