# 任务：桌面/已打开窗口查看能力（2026-10-29）

## 1. 背景（用户反馈）

用户在两个历史任务里都说明过「桌面已经打开夸克浏览器」：

- `任务-夸克网盘Skill安装-2026-10-29`（夸克官方 Skill 页 `b.quark.cn`，页面上有技能安装提示词、技能地址、授权码入口）
- `任务-dsh插件调整-2026-10-25`（11-28 的核查子任务：夸克窗口里打开的知乎回答页）

但当时我主要用日志/接口/headless 页面推断，没有去看用户眼前那个窗口，被用户质问「为什么还是没学会点进去看」。

根因：规则里只有「视觉验收闭环」（针对自己生成的网页/3D 产物），没有一条规则要求「用户说窗口已打开 = 必须去看用户当前窗口」，也没有可直接执行的窗口截图/读字工具，于是默认退回到日志与 HTTP 请求。

## 2. 本次交付

1. **工具**：`工具\窗口查看.ps1`（UTF-8 BOM + CRLF，源码纯 ASCII）
   - `List` 列窗口；`Shot` 用 PrintWindow 截取窗口（**被遮挡也能截**，DPI 感知后取物理分辨率）；`Text`/`Tree` 用 UI Automation 读文字/元素；`Activate` 激活；`Invoke` 按无障碍名点击；`Click`/`Send` 兜底
2. **规则**（已写入唯一规则文档 `AGENTS.md`，Trae 与 DSH 同时生效）：
   - §1 环境：新增夸克浏览器（Chromium）与 DSH Electron 窗口可截屏/UIA 的事实
   - §5 工作区根清单：新增 `工具/`
   - §6 新增小节「桌面/已打开窗口：先看再答（强制）」：触发词、标准命令、证据要求、禁止事项、唯一允许求助的情况、能力边界
   - §8 新增教训：「桌面已打开」却被忽略
   - §9 新增工具说明与全部 Actions
3. **验证证据**（本目录）：
   - `截图\quark-技能页-窗口截图.png`：夸克窗口在 DSH 窗口之后的被遮挡状态下，PrintWindow 截取成功（1942×1030，559,727 字节）
   - `证据\quark-技能页-文字.txt`：UIA 提取 98 条唯一文字
   - `证据\quark-技能页-UIA树.txt`：151 个元素的类型/名字/矩形/可用 Pattern
   - `备份\AGENTS.md.bak`、`备份\README.md.bak`：改动前快照

## 3. 实测结论（截屏 + UIA 双重核验）

- 窗口：`夸克网盘Skill - 夸克`（PID 5184，窗口类 `Chrome_WidgetWin_1`，进程 `C:\Program Files\Quark\quark.exe` 7.4.2.1020）
- 页面：`b.quark.cn/apps/quarkcloud_skill_info/routes/...`，标题「夸克网盘Skill — 将网盘接入AI大脑，一句话管理你的文件」
- 页面文字包含：「已安装夸克网盘技能！」「安装指南」「请安装 夸克网盘Skill,并授权账号」「技能地址：https://pdds.quark.cn/download/stfile/.../quarkclouddrive-1.0.25.zip」「授权码：**********」「复制技能地址」「目前已支持：千问-办公助理 / Codex / OpenClaw」
- 说明：两项证据一致（截图肉眼可见 + UIA 文本），如当时按 §6 执行即可直接读到用户提到的技能地址/授权码入口，无需反复询问

## 4. 工具自检结果

| 检查 | 结果 |
|------|------|
| `-Action List` | exit 0，正确列出 7 个可见窗口（含夸克、DSH、资源管理器） |
| `-Action Shot -Title 夸克` | exit 0，PrintWindow 模式出图 1942×1030 |
| `-Action Text -Title 夸克` | exit 0，98 条唯一文字 |
| `-Action Tree -Title 夸克` | exit 0，151 个元素（含 Pattern/矩形） |
| `-Action Activate -Title "DeepSeek Harness"` | exit 0，foreground match=True |
| `-Action Invoke -Name 不存在元素` | 明确报错退出 1，**不误点击** |
| 脚本编码 | UTF-8 BOM（239,187,191）、CRLF、正文纯 ASCII、语法解析 0 错误 |

## 5. 能力边界（为什么不是「真·电脑操作」）

- 能做：截任意可见窗口（含被遮挡）、读 UIA 文字、按无障碍名点击、坐标点击、发按键、激活窗口
- 不能做/不稳定的：全自动理解复杂动态页面（依赖 UIA 树质量）、纯 Canvas/游戏类界面、需要浏览器登录态的深层操作
- 需要「像人一样上网点」的深度自动化时，用 Edge `--remote-debugging-port=9222` + Playwright/CDP（本机未预装 Playwright，可按需安装）
- 截图含隐私（授权码/账号/聊天记录）时，交付文档必须遮挡或只记录必要字段

## 6. 回滚

1. 恢复规则：`copy /y "备份\AGENTS.md.bak" "..\AGENTS.md"`、`copy /y "备份\README.md.bak" "..\README.md"`
2. 删除工具与任务目录（如不再需要）：删除 `工具\` 与 `任务-桌面窗口查看能力-2026-10-29\`
3. 本次未修改任何系统配置、未安装软件

## 7. git 状态

未提交。新增：`工具/`、`任务-桌面窗口查看能力-2026-10-29/`；修改：`AGENTS.md`、`README.md`。
