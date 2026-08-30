# v b — 本地工作区

> 本机任务工作区（Windows 11 / DeepSeek Harness + Trae）。
> 所有工程规范以 `.trae/rules/工程规范.md` 为唯一来源（DSH 侧副本 `C:\Users\31384\.dsh\AGENTS.md`）。

## 目录内容

- `dsh-start.bat` — DSH Web UI 启动脚本（桌面「DSH 启动」快捷方式目标）
- `.trae/rules/工程规范.md` — 本机 AI Agent 工程规范（编码/环境/验收流程）
- `任务X/` — 各任务目录（中文命名，见规范 §5）

## 上传到 GitHub

1. 在 GitHub 新建**空**仓库：<https://github.com/new>，仓库名建议 `v-b`（不能含空格），**不要**勾选 README/.gitignore/LICENSE 等初始化文件，公开/私有任选
2. 关联远程并推送（当前分支 `main`，命令在仓库目录执行；HTTPS 首次会弹出 GitHub 登录/认证）：
   ```powershell
   git remote add origin https://github.com/1-zh335/v-b.git
   git push -u origin main
   ```
   - 仓库名与上面不同时，把 URL 中 `v-b` 换成实际名称
   - 或使用 GitHub Desktop：File → Add local repository → 选择本目录 → 首次操作选择 Publish repository
3. 推送前 `git status` 确认无敏感/大文件（排除规则见 `.gitignore`；本仓库当前约 20KB）
4. 提交身份：`1-zh335 <3138470565@qq.com>`（2026-08-30 设置）。若要提交记录关联账号，请在 GitHub → Settings → Emails 验证该邮箱；或改用 GitHub 的 noreply 邮箱（`git config user.email` 查看/修改）
5. 之后的增量上传只需 `git add -A && git commit -m "..."`，再 `git push origin main`

## 约定

- 新任务在根目录下新建中文命名子目录（如 `任务1`）
- 改 `.bat`/`.cmd`/`.vbs` 后立即按规范 §2 校验（GBK + CRLF）
- 修改规范：先改 `.trae/rules/工程规范.md`，再同步 `~/.dsh/AGENTS.md`
- 推送前 `git status` 确认无敏感/大文件；排除规则见 `.gitignore`
