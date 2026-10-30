# 任务：GitHub 推送与网络绕过（2026-10-31）

## 目标

把工作区 `main` 分支（7 个提交）推送到 GitHub，并配置成"以后免输入即可 push"的永久权限。

## 障碍（实测）

- `https://github.com` 默认解析到 `20.205.243.166`，连接频繁超时或被重置（GFW 干扰），导致：
  - DSH 内置浏览器 / Edge 打不开 GitHub 登录页与 token 页；
  - `push-to-github.bat` 卡在"页面下载失败/推送失败"（脚本本身无问题）；
- 排查结论（均为本机实测）：
  - `api.github.com` **可达**（HTTP 200）；
  - `ssh.github.com:443` 可完成 SSH 握手（`Permission denied (publickey)`，说明链路通）；
  - `codeload.github.com` / `raw.githubusercontent.com` / `objects.githubusercontent.com` 可达；
  - `github.com` 部分 IP 间歇可达（实测 `20.27.177.113` 成功；`.166/.169` 时好时坏）；
  - 本机无代理进程、无 gh CLI、无已存 GitHub 凭据。

## 解决过程

1. **Edge 强制解析**：`msedge.exe --host-resolver-rules="MAP github.com 20.205.243.166" https://github.com/settings/tokens` → 登录页正常加载（此前失败）。
2. **登录**：Edge 已记住账号密码，用 `工具\窗口查看.ps1` 点击 `Sign in` 完成登录（出现 2FA 时需本人处理）。
3. **生成 token**：页面自动化点击 `Generate new token (classic)` → Note `dsh-permanent` → `Expiration: No expiration` → Scopes 只勾 `repo` → `Generate token`。
4. **取 token**：`Ctrl+A / Ctrl+C` 复制页面文本，从剪贴板正则提取 `ghp_...`（40 字符），全程不打印 token。
5. **建仓库**：用 token 调 `api.github.com` 创建公开仓库 `v-b`（`auto_init=false`）。
6. **永久凭据**：`git credential approve` 把 token 写入 **Windows 凭据管理器**；`git remote add origin https://github.com/1-zh335/v-b.git`。
7. **推送**：直接 `git push` 仍被重置 → 设置 `git config --global http.curloptResolve "github.com:443:20.27.177.113"` 后重试，**推送成功**（`main -> main`，upstream 已设置）。

## 结果（已验证）

| 项 | 证据 |
|---|---|
| 仓库 | https://github.com/1-zh335/v-b （公开，默认分支 `main`） |
| 远端提交 | 7 个，HEAD `07f0dd90a121a06495395e4e5c9c0935fe2238a`（与本地一致） |
| 本地/远端一致 | 本地 `git log` HEAD = 远端 HEAD |
| 永久凭据 | `git ls-remote origin` 退出码 0（未再输入 token） |
| 凭据存储 | Windows 凭据管理器 `git:https://github.com`（classic token、无过期、仅 `repo` 权限） |
| 网络绕过 | `git config --global http.curloptResolve = github.com:443:20.27.177.113` |

## 日常使用 / 故障处理

```powershell
# 以后正常推送（凭据已存，免输入）
git -C "C:\Users\31384\Documents\trae_projects\v b" push origin main
```

若 `github.com` 连不上（`Recv failure: Connection was reset` / 超时）：

1. 换一个可用 IP：`git config --global http.curloptResolve "github.com:443:<IP>"`，可尝试 `20.27.177.113`、`20.205.243.166/.169`、`20.200.245.247`、`140.82.112.x`；
2. 网页访问：用 `msedge.exe --host-resolver-rules="MAP github.com <IP>"` 启动后再打开 GitHub；
3. 不确定网络时先测：`curl.exe -sS -o NUL -w '%{http_code}' --resolve github.com:443:<IP> https://github.com/` 返回 200 再操作。

## 安全与清理

- token **未写入任何文件/仓库/文档**，只存于 Windows 凭据管理器；对话中曾出现 token 截图，**相关截图已全部删除**（`工具\截图\` 已清空并加入 `.gitignore`）。
- 如需撤销权限：GitHub → Settings → Developer settings → Personal access tokens 删除 `dsh-permanent`；再删除本机凭据（控制面板 → 凭据管理器 → Windows 凭据 → `git:https://github.com`）。
- `http.curloptResolve` 是全局 git 配置，如果不想要可 `git config --global --unset http.curloptResolve`（但当前网络环境下会使 push 再次失败）。

## 回滚

```powershell
git -C "C:\Users\31384\Documents\trae_projects\v b" remote remove origin
git config --global --unset http.curloptResolve
# 撤销 token：见上"安全与清理"
```
