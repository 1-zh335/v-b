# 2026-10-28 核查：知乎插件文、插件市场、dshmarket / dshopen / dsh-plugin-health、DeepSeek 搜索 API

## 1. 知乎文章（从夸克窗口用 Windows UI Automation 提取，全文见 `知乎回答-全文.txt`）

- 问题：《如何评价 DeepSeek 开放自研搜索 API，单价为每 1000 次成功请求 5 元？》
- 回答：yaoj，1513 赞同，编辑于 2026-10-20；截图见 `夸克-知乎回答页.png`
- 推荐清单（原文结构）：
  - 一、基础插件：`dshmarket`、`dshopen`（精选索引，也可只加索引源）、`dsh-cost-meter`、`dsh-plugin-health`
  - 二、多 agent：`dsh-tower`、`dsh-cockpit`（注意同名包需用 Release tgz）、`agency-agents`、`dsh-roundtable-harness`
  - 三、搜索与资料：`dsh-free-search`、`dsh-zhihu-search`、`dsh-pdf-mineru`、`dsh-ai-library`
  - 四、前端/内容：`eac-design-world`、`dsh-oil-ui`、`dsh-tongflow`、`dsh-image-gen`、`dsh-brewreel`、`@deepblend/dsh-blender-bundle`、`dsh-openwrite`、`dsh-cuigengji-plugin`、`dsh-novel-writer`
  - 五、记忆与防翻车：`@agentscope-ai/reme-dsh-plugin`、`@zilliz/memsearch-dsh`、`billion-context`、`cc-safety-net`；作者自述该组"痛点大众、可能与官方撞车、有副作用，需自行斟酌"
- 两处已被现状推翻的说法：
  1. "官方默认没内置社区商店，得先装 dshmarket" —— 现 0.2.1-rc.3 已内置「插件 → 发现」+ 索引源，不装 dshmarket 也能逛。
  2. 另一高赞回答称"QPS 每账号 5" —— 官方文档现为 **Search 100/s、Fetch 25/s**（账号级）。

## 2. 本次改动

1. `AGENTS.md`：内核字面值 `0.2.1-rc.2` → `0.2.1-rc.3`（含 §1 两处、§9 两处、页首修订说明）。
2. `~/.dsh/profiles/desktop/cordis.patch.yml` 末尾新增官方插件市场索引源：
   ```yaml
   - id: plugin-market
     name: "@deepseek-ai/dsh-plugin-market"
     config:
       indexes:
         - https://dshopen.org/index.json
   ```
   官方服务已读取成功（`plugin_market list_indexes` 返回标题 "Open Plugin Market"；发现页可见 911 个插件、11 类）。
3. `dsh-cost-meter` 两个 profile 均从 `1.9.31` 升级到 `1.9.41`（宿主 0.2.1-rc.3 兼容；`engines.dsh = >=0.2.0-rc.1 <0.3.0-0`）。
4. 兼容性实测时创建的临时 profile `tmp-healthtest` 已删除并核验（现存 profile：desktop、web、node_modules）。

## 3. 兼容性核对结论

| 目标 | 形态 | 判定 | 依据 |
|---|---|---|---|
| `dshmarket@1.71.1` | 插件（第三方市场） | **兼容**（发现页「安装」可点） | dshopen 索引 `compatible: true`；`engines.dsh` 含 `^0.2.1-rc.1`，覆盖 0.2.1-rc.3 |
| `dsh-plugin-health@0.5.0` | 插件（体检） | **兼容**（官方安装闸门实测通过） | 不在 dshopen 索引（911 条无此包），发现页搜不到；用临时 profile 跑官方 `dsh plugin add`，exit 0 安装成功，随后删除 |
| `dshopen` | 索引数据（format 1，911 插件） | 已配置，非插件 | 官方 Host fetch 压缩后 262 KB / 约 2 s，远低于 15 s 超时 |
| `dsh-cost-meter@1.9.41` | 已装插件 | 已升级生效 | 两 profile 依赖/锁/安装目录均为 1.9.41；宿主条目 `include:cost-meter` active |

DSH 兼容闸门实现（`@deepseek-ai/dsh-app-boot` 的 `plugin-compatibility`）：`semver.satisfies(runtimeVersion, range, { includePrerelease: true })`，故 `0.2.1-rc.3` 这类预发布版参与范围判定。

## 4. 证据文件

- `夸克-知乎回答页.png`：夸克中打开的知乎回答
- `01-发现页-开放插件市场.png`：官方「发现」页加载 911 插件索引
- `02-发现页-搜索dshmarket.png`：搜索 dshmarket，卡片显示可安装（★9,296 / v1.71.1）
- `知乎回答-全文.txt`：UIA 提取的回答全文（约 9.5k 字符）

## 5. 回滚

- 移除索引源：删除上面那段 `plugin-market` 覆盖项，保存后刷新页面。
- 回退 cost-meter：`dsh plugin --profile web add dsh-cost-meter@1.9.31 --save-exact`（desktop 同理）。
