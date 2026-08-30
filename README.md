# v b — 本地工作区

> 本机任务工作区（Windows 11 / DeepSeek Harness + Trae）。
> 所有工程规范以 `.trae/rules/工程规范.md` 为唯一来源（DSH 侧副本 `C:\Users\31384\.dsh\AGENTS.md`）。

## 目录内容

- `dsh-start.bat` — DSH Web UI 启动脚本（桌面「DSH 启动」快捷方式目标）
- `.trae/rules/工程规范.md` — 本机 AI Agent 工程规范（编码/环境/验收流程）
- `任务X/` — 各任务目录（中文命名，见规范 §5）

## 约定

- 新任务在根目录下新建中文命名子目录（如 `任务1`）
- 改 `.bat`/`.cmd`/`.vbs` 后立即按规范 §2 校验（GBK + CRLF）
- 修改规范：先改 `.trae/rules/工程规范.md`，再同步 `~/.dsh/AGENTS.md`
- 推送前 `git status` 确认无敏感/大文件；排除规则见 `.gitignore`
