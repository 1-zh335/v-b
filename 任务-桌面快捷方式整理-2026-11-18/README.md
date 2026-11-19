# 任务：桌面快捷方式整理（Uncle小说）— 2026-11-18

## 1. 需求

用户原文（逐字）：

> Trae 实际加载实测，提交并推送这批规则/清理改动，@"C:\Users\31384\Desktop\Uncle小说 · 本地TXT快速阅读.lnk" 桌面上的这个小说快捷方式应该放在对应的工作文件夹之内，而不要放在桌面上，放在桌面上显的太乱。 在MD文件中体现出这一点。 优化一下。 然后将他上传进网盘。

本任务负责：把该快捷方式从桌面移入对应工作文件夹、更新文档规则；AGENTS.md 的最终上传见 `任务-AGENTS规则优化-2026-11-18\README.md`。

## 2. 处理前

- 桌面快捷方式：`C:\Users\31384\Desktop\Uncle小说 · 本地TXT快速阅读.lnk`（4,512 B）
- 指向：`%LOCALAPPDATA%\Programs\UncleNovel\runtime\bin\javaw.exe`；工作目录 `%LOCALAPPDATA%\Programs\UncleNovel`（目标有效）
- 对应工作文件夹：`C:\Users\31384\Documents\trae_projects\v b\任务-uncle-novel优化-2026-10-25\`（该任务 README 明确此快捷方式为该任务交付的两种启动方式之一）

## 3. 操作

1. `Move-Item` 将快捷方式移入 `任务-uncle-novel优化-2026-10-25\Uncle小说 · 本地TXT快速阅读.lnk`；
2. 在 `任务-uncle-novel优化-2026-10-25\README.md` 顶部补充 2026-11-18 整理说明；
3. 在 `AGENTS.md` §5 新增「桌面整洁」规则：项目/任务快捷方式一律放进对应工作区任务文件夹，不要留在桌面；
4. `.gitignore` 增加 `*.lnk`，本地快捷方式不入库（避免把只对本机有意义的二进制提交到仓库）。

## 4. 验证（2026-11-18 01:0x 实测）

| 检查 | 结果 |
|---|---|
| 桌面原快捷方式 | 已不存在（`Test-Path` = False） |
| 新位置 | `任务-uncle-novel优化-2026-10-25\Uncle小说 · 本地TXT快速阅读.lnk`（4,512 B） |
| 快捷方式有效性 | Target=`...\UncleNovel\runtime\bin\javaw.exe`、WorkingDirectory=`...\UncleNovel`，未变 |
| 桌面其余项目 | 未改动；`Uncle小说.lnk`（完整功能）仍在桌面（用户本次只点名本地TXT快捷方式；如需一并移走可再处理） |
| AGENTS.md | §5 已加入桌面整洁规则；页首「最后修订」已注明 |

## 5. 回滚

把快捷方式从 `任务-uncle-novel优化-2026-10-25\` 移回 `%USERPROFILE%\Desktop\` 即可；目标程序与工作目录不变。

## 6. 未验证 / 说明

- 未验证从任务文件夹内双击快捷方式启动应用（仅校验了 .lnk 的目标/工作目录字段与文件存在性）。
- 未移动桌面上的 `Uncle小说.lnk`（完整功能版），因用户只点名一个；如果也嫌乱可同样移入对应任务文件夹。
## 7. 2026-11-19 补充（用户追问第二个快捷方式）

- 用户指出桌面仍有 `C:\Users\31384\Desktop\Uncle小说.lnk`。核实：该快捷方式是安装器生成的「完整功能版」入口（2,262 B，Target=`Uncle小说.exe`），上次只移走了用户点名的 `Uncle小说 · 本地TXT快速阅读.lnk`，属于**只处理点名对象、未扫桌面同类项**的疏漏。
- 处置：已把 `Uncle小说.lnk` 也移入 `任务-uncle-novel优化-2026-10-25\`；桌面已无任何 Uncle 相关快捷方式（其余 DeepSeek Harness / TraeCode CN / 百度网盘 / 网易有道翻译 / 此电脑 属系统/常用应用入口，保留）。
- 验证：桌面 `Get-ChildItem *.lnk` 无 Uncle；任务目录现有两个快捷方式：`Uncle小说 · 本地TXT快速阅读.lnk`（4,512 B）与 `Uncle小说.lnk`（2,262 B），Target/WorkingDirectory 均有效。
- 教训已写入 AGENTS.md §5/§8/§10：项目安装器默认把多个快捷方式写到桌面；收尾必须枚举桌面 `.lnk/.url`，按 TargetPath 判断本项目产物并全部归位，不能只移用户点名的一个。
