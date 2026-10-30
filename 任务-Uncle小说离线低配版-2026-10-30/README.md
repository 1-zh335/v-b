# 任务：Uncle小说 离线低配重构版（目标机 DTPC953）— 2026-10-30

> 目标软件：本工作区 `任务-uncle-novel优化-2026-10-25` 交付的 **Uncle小说 v5.0.44 增强版**
> 目标设备：**DTPC953**（设备信息来自夸克网盘「目标端设备详情」文件夹，已取证到 `目标端设备详情/`）
> 部署场景：**仅偶尔可联网**（大部分时间离线，偶尔接入网络）

---

## 1. 目标设备画像（摘自 DxDiag / AIDA64 / MSInfo32 / CPU-Z 导出）

| 项 | 实测值 | 对软件的约束 |
|---|---|---|
| 主机 | ASUS Mini PC PN40（Vivo PC，Mini PC 机箱） | 无独显、小机箱 |
| OS | Windows 10 Enterprise 2019 LTSC x64，10.0.17763（1809，RS5） | 需兼容旧 Win10；无应用商店/UWP 依赖 |
| CPU | Intel Celeron J4005，2 核 2 线程，2.0–2.4 GHz，4MB L2，14nm | 低算力：控制启动耗时/后台任务/动画 |
| RAM | 4 GB DDR4-2400（实际可用 3.82 GB，采样时仅剩 **667 MB** 可用），最大支持 8 GB | JVM 堆必须收紧；禁止内存缓存滥用 |
| 显卡 | **Microsoft 基本显示适配器**（Intel UHD 600 驱动未安装），WDDM 1.3，共享显存 1957 MB | 无硬件加速 → JavaFX 必须走软件渲染（`prism.order=sw`） |
| 显示 | Lenovo LS2224A 22" LCD，1920×1080，96 DPI（100% 缩放） | 默认窗口按 1080p/96DPI 排版，不要沿用 150% 假设 |
| 音频 | DxDiag：**未找到声卡**（Realtek ALC3236 / HDMI 音频驱动未装） | TTS/有声播放不可用，需明确提示 |
| 磁盘 | M.2 SSD 128GB：C: 81.3GB（50.2GB 空闲）、D: 40.1GB（33.8GB 空闲） | 安装体积可接受（当前包解压约 146MB），但避免额外大缓存 |
| 网络 | Realtek PCIe GBE，报告时 IP 172.30.80.149；部署环境为**间歇联网** | 联网功能必须感知在线/离线并差异化提示，恢复后自动可用 |
| BIOS | AMI 0804 / 2019-05-05，UEFI，Secure Boot 关闭 | 无影响 |
| 其他 | 域环境 `dt.kersentech.com`；用户 `DTPC953`；IE11；打印机若干 | 安装需离线、无管理员依赖（当前安装包已是用户目录） |

---

## 2. 需求拆解（本次重构范围）

1. **离线/联网状态感知 + UI 差异化**
   - 启动即检测网络（后台线程，不阻塞 UI），每 15s（离线）/60s（在线）复检；
   - 离线时：主窗口标题显示「（离线）」/ 阅读器标题追加「 · 离线」；点击联网功能时弹出**统一样式的离线提示框**（说明哪些功能可用、哪些需要网络、可「重试联网」、无网恢复后自动启用）；恢复联网时 Toast 提示「网络已恢复，在线功能已启用」；
   - 联网功能清单：书源搜索、全网搜书、有声搜索、解析下载、下载任务的开始/续传、有声播放、TTS 朗读、书籍自动更新、更换/搜索封面、书源网络导入。
   - 本地功能永不拦截：本地 TXT 快速阅读、导入本地小说（本地选择/拖入）、书架阅读、阅读进度、设置、卸载。
2. **全局老板键（新功能，本次重点补齐）**
   - 现状：完整版已有「老板键」（配置 `hotkey.globalBossKey`，默认 `alt U`），但实现依赖托盘；**本地TXT快速阅读模式完全没有注册全局热键**。
   - 目标：两种模式都支持全局老板键，按一次隐藏全部窗口（并从托盘/任务栏消失），再按一次恢复；配置化（默认 `alt U`，完整版设置页可录制，快速阅读模式改 `conf.json`）；启动画面/说明中提示老板键位。
   - 要求：不依赖托盘也能工作；隐藏时 `Platform.setImplicitExit(false)` 防止应用退出；恢复时回到前台。
3. **低配/无 GPU/无声卡运行优化**
   - JVM：`-Xms64m -Xmx512m -XX:MaxMetaspaceSize=192m -XX:ReservedCodeCacheSize=96m -XX:+UseSerialGC`（完整版与快速阅读一致口径）；
   - JavaFX：强制软件渲染 `-Dprism.order=sw -Dprism.forceGPU=false`、关闭 LCD 次像素（已有）；
   - 交互：默认关闭翻页动画/页面阴影、降低后台线程（下载线程 1、重试 1）、书架自动更新关闭；
   - 目标档配置：阅读窗口 1100×760、字号 22、行距 0.25（1080p/96DPI 更易读）；
   - 无声卡：TTS/有声播放入口点击时提示「未检测到音频设备」，不报错堆栈；
   - 分析上报（MixPanel）在目标档/离线/属性关闭时完全跳过（省启动耗时）。
4. **离线部署与目标机自检**
   - 交付「离线低配版」压缩包：内嵌 runtime + 程序 + 配置 + 安装/卸载/快捷方式脚本 + 离线说明；
   - 附带 `目标机环境自检.ps1`：检查 OS 版本、CPU/内存、显示适配器、音频设备、磁盘空间、网络状态，输出报告 txt（部署到目标机后先跑）；
   - 安装结束有明显 `[OK]` 标志；安装后可用 `--offline-selftest` 类参数自检（启动即退出/打印状态）。
5. **验收**
   - 本机模拟：`-Duncle.network.force=offline/online` 验证离线态、恢复态；`-Duncle.audio.force=unavailable` 验证无声卡提示；低配参数下启动/内存实测；
   - 全部 UI 变更截图目检（`read_image`）；
   - 离线安装包端到端安装测试 + SHA256。

---

## 3. 架构与代码契约

### 3.1 新增类（app 模块，patch-src 注入）

**`com.unclezs.novel.app.main.core.OfflineGuard`**（新）

```java
public enum State { CHECKING, ONLINE, OFFLINE }
public static void start();                       // 幂等；App.init / QuickApp.init 调用
public static void stop();
public static State state();
public static boolean isOffline();                // 仅 OFFLINE 为 true（CHECKING 不算离线）
public static boolean isOnline();
public static boolean isChecking();
public static ReadOnlyObjectProperty<State> stateProperty();
public static boolean guardNetwork(String feature); // 非在线 → 弹离线提示框并返回 true（调用方 return）
public static boolean guardAudio(String feature);   // 无音频设备 → 弹提示框并返回 true
public static boolean guardTts(String feature);     // 先 guardAudio 再 guardNetwork
public static boolean hasAudioDevice();
public static String titleSuffix();               // " · 离线" / ""
public static String homeTitle();                 // "Uncle小说" / "Uncle小说（离线）"
public static void bindTitle(StageDecorator decorator, String baseTitle); // 标题随状态刷新
public static void bindWindowTitle(javafx.stage.Stage stage, String baseTitle);
public static boolean isTargetProfile();          // -Duncle.target.profile=true
public static boolean isAnalyticsDisabled();      // 目标档/离线/-Duncle.analytics.disabled=true

// 测试/部署属性：
// -Duncle.network.force=auto|online|offline
// -Duncle.network.probe.url=https://www.baidu.com/
// -Duncle.network.interval.online.ms=60000
// -Duncle.network.interval.offline.ms=15000
// -Duncle.network.timeout.ms=3000
// -Duncle.audio.force=auto|available|unavailable
```

行为细则：
- 探测：`HttpURLConnection HEAD`（可配置 URL），`code>0 && code<500` 视为在线；异常视为离线。
- 状态变化仅在 FX 线程更新属性；首次进入 OFFLINE 且窗口已显示时 Toast.warn：「离线模式：本地阅读可用；联网功能需网络，恢复后自动启用」；从 OFFLINE 恢复→Toast.success：「网络已恢复，在线功能已启用」。
- `guardNetwork` 提示框：标题「离线模式」，正文说明「当前未检测到可用网络（本机为间歇联网环境）」「可继续使用：本地 TXT 快速阅读 / 导入本地小说 / 书架与阅读进度」「网络恢复后自动启用在线功能，无需重启」；按钮「重试联网」「继续离线」；重试在后台探测并 Toast 结果。
- `guardAudio` 提示框：标题「音频不可用」，正文说明「未检测到音频设备（目标机未安装声卡驱动）」「朗读/有声播放不可用；阅读、下载不受影响」；按钮「知道了」。

**`com.unclezs.novel.app.main.core.BossKey`**（新）

```java
public static void install();   // 注册全局老板键（读 conf.hotkey.globalBossKey，默认 alt U），幂等
public static void toggle();    // FX：全部窗口隐藏 ↔ 恢复（Platform.setImplicitExit(false)）
public static boolean isInstalled();
public static String stroke();  // 当前老板键位文本
```

**`com.unclezs.novel.app.main.manager.HotkeyManager`**（改）：移除内部老板键注册（改由 BossKey 统一注册），保留阅读器窗口热键。

**`com.unclezs.novel.app.main.App`**（改）：`init()` 增加 `OfflineGuard.start()` 与 `BossKey.install()`；`start()` 中更新检查与 MixPanel 埋点按「目标档/离线」跳过。

**`com.unclezs.novel.app.main.QuickApp`**（改）：`init()` 增加 `OfflineGuard.start()` + `BossKey.install()`；欢迎页显示「离线可用 · 老板键 {stroke} 隐藏/恢复」；窗口标题绑定离线状态。

**`com.unclezs.novel.app.main.views.reader.ReaderView`**（改）：
- `updatePageTitle()` 末尾追加 `OfflineGuard.titleSuffix()`；
- `onSpeakClicked()`：开始朗读时 `if (OfflineGuard.guardTts("朗读")) { settingDrawer.close(); return; }`；
- `onPlayClicked()`：`if (OfflineGuard.guardAudio("朗读")) { settingDrawer.close(); return; }`。

**`com.unclezs.novel.app.main.util.MixPanelHelper`**（改）：`event(...)`/`sendEvent(...)` 开头 `if (OfflineGuard.isAnalyticsDisabled()) return;`。

### 3.2 视图拦截（patch-src overlays，见下）

| 文件 | 插入点 | 逻辑 |
|---|---|---|
| `views/home/HomeView.java` | `onCreated()` 末尾 | `OfflineGuard.start(); OfflineGuard.bindTitle(getRoot(), "Uncle小说");` |
| `views/home/SearchNovelView.java` | `search(SearchEvent)` 开头 | `if (OfflineGuard.guardNetwork("书源搜索")) return;` |
| `views/home/SearchNetworkView.java` | `search(SearchEvent)` 开头 | `if (OfflineGuard.guardNetwork("全网搜书")) return;` |
| `views/home/SearchAudioView.java` | `search(SearchEvent)` 开头 | `if (OfflineGuard.guardNetwork("有声搜索")) return;` |
| `views/home/AnalysisView.java` | `onAnalysis(ActionClickedEvent)` 开头 | `if (OfflineGuard.guardNetwork("解析下载")) return;` |
| `views/home/AudioBookShelfView.java` | `playChapter()` 开头 | `if (OfflineGuard.guardNetwork("有声播放")) return;`（另加 guardAudio） |
| `views/home/FictionBookshelfView.java` | `onCreated()` 自动更新处 / `onShow()` 封面下载 / `searchCover()` | 离线时跳过自动更新与封面下载；searchCover 用 guardNetwork |
| `views/home/RuleManagerView.java` | 网络导入菜单项点击处 | `if (OfflineGuard.guardNetwork("书源网络导入")) return;` |
| `views/home/DownloadManagerView.java` | 恢复/开始下载按钮 handler | `if (OfflineGuard.guardNetwork("下载")) return;` |

> 视图类清单以实际源码为准；overlay 必须是 lombok 清理后的完整类文件（见 §5 构建）。

### 3.3 运行配置（`构建/配置/`）

| 文件 | 内容 |
|---|---|
| `launcher.vmoptions`（完整版） | `-Xms64m -Xmx512m -XX:MaxMetaspaceSize=192m -XX:ReservedCodeCacheSize=96m -XX:+UseSerialGC -Dprism.order=sw -Dprism.forceGPU=false -Dprism.lcdtext=false -Duncle.target.profile=true -Duncle.analytics.disabled=true -Duncle.update.check=false -Dfile.encoding=UTF-8` |
| `本地TXT快速阅读.bat` | javaw 参数同上（快速模式堆 `-Xmx448m` 即可），`%*` 透传文件 |
| `初始化配置.ps1`（目标档） | 阅读窗口 1100×760、字号 22、行距 0.25、`flipAnimation=false`、`showShadow=false`、`bookShelf.autoUpdate=false`、下载线程 1/重试 1、`alwaysShowBookTitle=true` |
| `创建快捷方式.ps1` | 两个快捷方式 + 发送到；快速阅读快捷方式带低配 JVM 参数 |
| `目标机环境自检.ps1` | 输出 `目标机自检报告.txt`：OS/CPU/RAM/显卡/声卡/磁盘/网络/DPI |
| `benchmark.ps1` | 受限 JVM（-Xmx512m + sw）下启动耗时/RSS 采样 |

### 3.4 交付结构（`交付/`）

```
Uncle小说-离线低配版-DTPC953.zip
├─ 使用说明-离线版.txt / 离线部署指南.md
├─ 安装到本机.bat / 卸载.bat / 创建快捷方式.ps1 / 初始化配置.ps1
├─ 本地TXT快速阅读.bat / 目标机环境自检.ps1
├─ 书源-可选/（沿用上一版）
└─ uncle-novel/（内嵌 runtime + app.jar 补丁 + conf 目标档 + 快捷方式素材）
```

---

## 4. 目录结构与分工

```
任务-Uncle小说离线低配版-2026-10-30/
├─ README.md                 # 本设计
├─ 目标端设备详情/            # 夸克网盘取回的 5 份设备信息（分析依据）
├─ 构建/
│  ├─ patch-src/             # Lead 维护：OfflineGuard/BossKey/App/HotkeyManager/QuickApp/ReaderView/MixPanelHelper
│  └─ patch-src-views/       # ui-offline-dev 维护：9 个视图 overlay
├─ 构建/配置/                # Lead 维护：launcher.vmoptions、初始化配置、bat、自检、benchmark
├─ 文档/                     # docs-offline 维护：目标设备适配报告、离线使用说明、部署指南（Lead 补测试报告）
├─ 截图/                     # 验收截图（Lead 负责）
├─ 测试/                     # 测试记录 JSON/log
├─ 工具/                     # build-patch.ps1（支持 -PatchDirs/-PrepareOnly）、deploy、quick-test、gui-act、lombok.jar
└─ 交付/                     # 最终 zip + SHA256
```

**Write scope 约定**：Lead 只写 `构建/patch-src/`、`构建/配置/`、`工具/`、`截图/`、`测试/`、根 README、交付；`ui-offline-dev` 只写 `构建/patch-src-views/`；`docs-offline` 只写 `文档/`。禁止跨目录写。

---

## 5. 构建流程（可复现）

```powershell
# 准备原始类（复制源码 + 去 lombok）并叠加 overlay，编译：
powershell -NoProfile -ExecutionPolicy Bypass -File "工具\build-patch.ps1" `
  -Classes App.java,HotkeyManager.java,MixPanelHelper.java,QuickApp.java,ReaderView.java,TxtLoader.java,HomeView.java,SearchNovelView.java,SearchNetworkView.java,SearchAudioView.java,AnalysisView.java,AudioBookShelfView.java,FictionBookshelfView.java,RuleManagerView.java,DownloadManagerView.java `
  -PatchDirs "构建\patch-src","构建\patch-src-views" -Clean
# 部署到本机安装目录（先备份 app.jar）
powershell -NoProfile -ExecutionPolicy Bypass -File "工具\deploy-patch.ps1"
```

## 6. 验收标准（必须全部满足）

1. 离线态：断网模拟下启动，主标题/阅读器标题显示离线；点「书源搜索/全网搜书/解析下载/朗读」弹出统一离线提示框；本地 TXT 快速阅读/导入/书架正常。
2. 恢复态：在线模拟下自动/点「重试联网」后状态恢复，Toast 提示，功能可用。
3. 老板键：完整版与快速阅读模式按 `Alt+U` 均能隐藏全部窗口、再按恢复；快速模式无托盘也能恢复；隐藏时应用不退出。
4. 无声卡：点朗读 → 「音频不可用」提示，无异常堆栈。
5. 低配：目标参数下启动正常、无 OOM/崩溃；启动耗时与 RSS 记录在测试报告。
6. 离线安装包：目标机执行安装脚本 → 多条 `[OK]`；断网下快速阅读可用；自检脚本输出报告。
7. 全部 UI 截图目检通过；交付 zip + SHA256 + 文档齐全。
---

## 7. 执行结果（2026-10-30）

### 7.1 交付物
| 文件 | 说明 |
|---|---|
| 交付\Uncle小说-离线低配版-DTPC953.zip | **126.1 MB / 235 条目**，SHA256 `7735C3F18F05B5E98A7BB8F76F4B0063B6489F85631ED505C8425E4615FD0DEC` |
| 交付\Uncle小说-离线低配版-DTPC953\ | 解压模板（与 zip 内容一致） |
| 交付\SHA256.txt / SHA256-带文件名.txt | 校验值 |
| 文档\（3 份） | 目标设备适配报告 / 离线使用说明书 / 离线部署指南（已回填实测） |
| 构建\patch-src\ + 构建\patch-src-views\ | 全部补丁源码（OfflineGuard、BossKey、App、HotkeyManager、MixPanelHelper、QuickApp、ReaderView、TxtLoader + 9 视图 overlay） |
| 构建\配置\ | 目标档 vmoptions、初始化配置、快捷方式、快速阅读 bat、目标机自检、benchmark、安装/卸载脚本 |
| 工具\ | build-patch / deploy-patch / offline-selftest / gui-offline-test / evidence-tests / quick-test |
| 测试\ | 自检报告示例、低配基准 JSON、安装前备份 |
| 截图\ | 离线标题、离线提示框、音频提示、老板键、联网前后等验收截图 |

### 7.2 实测结论（本机模拟，详见文档回填表）
- 完整版/快速阅读离线标题、离线拦截弹窗、无声卡提示均按设计显示；老板键 Alt+U 两模式隐藏/恢复通过；间歇联网自动恢复通过（日志 OFFLINE→ONLINE）。
- 目标档参数：快速阅读窗口 1.23s / RSS 258MB；完整版 3.58s / RSS 525MB（开发机数据，目标机待 benchmark 回填）。
- 离线安装端到端通过：退出码 0、10 条 [OK]，conf 目标值生效，快捷方式/发送到/自检脚本就位。

### 7.3 已知限制
- 未在 DTPC953 真机实测（目标机信息来自夸克网盘导出文件）；软件渲染在 Celeron J4005 上的实际帧率/启动耗时需真机 benchmark 回填。
- 目标机无声卡驱动：朗读/有声播放不可用（已提示）；TTS 相关功能仅在有音频设备的机器可用。
- 老板键在「关闭启用全局快捷键」后失效，重新勾选恢复；完整版改键需重启生效（快速阅读模式改 conf 需重启）。
- 离线包内文档的相对链接（../交付/ 等）在 zip 内不可解析，工作区文档为准。