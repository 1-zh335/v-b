# 任务：安装夸克网盘 Skill 并授权账号（2026-10-29）

## 目标

1. 安装夸克网盘官方 Skill（`quarkclouddrive` 1.0.25）到 DSH 用户级技能目录，使本机 DSH 所有会话可用。
2. 使用用户提供的授权码完成账号绑定（非交互式 `login --token`）。

## 信息来源

- 技能压缩包：`https://pdds.quark.cn/download/stfile/eekkigineefiegmgo/quarkclouddrive-1.0.25.zip`
- 本地副本：`C:\Users\31384\Downloads\quarkclouddrive-1.0.25.zip`（289,229 字节，SHA256 `56C34E9A9313AE29D39475B4FF9DA9E92FBFD59699BF5843E3382E54434FFFB8`）
- 授权码：用户消息提供（不写入任何文件，仅用于一次性登录）

## 安装位置（依据 DSH 技能发现规则）

`@deepseek-ai/dsh-skill-filesystem` 默认扫描的用户级根目录（rank 400）为
`<DSH_HOME>/skills`，即：

```
C:\Users\31384\.dsh\skills\quarkclouddrive\
```

（同目录规则：project-dsh `<项目根>/.dsh/skills` rank 100、user-agents `~/.agents/skills` rank 500。）

## 文件结构

```
任务-夸克网盘Skill安装-2026-10-29/
├── README.md                 # 本说明
├── install.log               # 安装与授权过程日志（汇总）
└── pkg/                      # 从 zip 解压的原始安装包（安装完成后清理）
    ├── SKILL.md
    ├── references/*.md
    └── scripts/{install.sh,uninstall.sh,quark-drive.cjs,hash-worker.cjs}
```

## 操作流程

1. 解压 zip 到任务目录 `pkg/`，校验内容（SKILL.md + references + scripts，非 exe 安装包）。
2. 将包内容复制到 `~/.dsh/skills/quarkclouddrive/`。
3. 在技能目录执行 `bash scripts/install.sh`：检测环境、向官方接口拉取最新包、覆盖脚本与文档、`node scripts/quark-drive.cjs --version` 自检。
4. 执行 `node scripts/quark-drive.cjs login --token <授权码>` 完成授权。
5. 验证：技能出现在 DSH 技能目录（后续模型步骤的 `<available_skills>` 更新），CLI 可查询账号信息。

## 验收标准

- [x] `~/.dsh/skills/quarkclouddrive/scripts/quark-drive.cjs` 存在，`--version` 正常输出。
- [x] DSH 技能目录中可见 `quarkclouddrive` 技能。
- [x] `login` 返回 `code: 0`，账号绑定成功；按技能要求展示会员权益表。

## 执行结果（2026-10-29 20:45 左右）

- 安装：`bash scripts/install.sh` 退出码 0，接口版本 1.0.25 与本地一致，`install_result success:true updated:false`。
- 技能收录：本会话技能目录刷新后新增 `quarkclouddrive`（`~/.dsh/skills` 由 `dsh-skill-filesystem` 用户级根目录扫描）。
- 授权：`login --token` 返回 `code: 0`，状态 `install_confirmed`（授权范围：全部文件）。
- 账号探活：`get-user-info` 成功，昵称「时雨既溯」，SVIP+，有效期至 2026-11-29，容量 6.03 TB / 10 TB。
- 官方核对：用户提供的提示词/技能地址与夸克官方 Skill 页（b.quark.cn）"复制下方提示词"内容一致，
  安装脚本请求的 skill_config 接口来自官方开放平台 `open-api-drive.quark.cn`。
- 临时解压副本 `pkg/` 已清理；详细记录见 `install.log`、`login.log`（`.log` 不入库）。

## 回退方式

- 卸载：先执行 `bash ~/.dsh/skills/quarkclouddrive/scripts/uninstall.sh`（撤销授权、清本地配置），再删除
  `C:\Users\31384\.dsh\skills\quarkclouddrive` 目录。
- 本任务未修改 DSH profile 配置、未安装系统级软件。
