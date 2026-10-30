# Uncle小说 5.0.44 增强版 TTS（朗读）可用性调研报告

- 测试日期：2026-10-27（UTC+8）
- 测试对象：本机已安装版 `%LOCALAPPDATA%\Programs\UncleNovel`（5.0.44，app.jar 530 KB 级）
- 测试人：tts-analyst（接口调研）；最终播放验收由 Lead 负责（本次未启动 GUI、未修改安装目录）
- 结论一句话：**内置 8 个引擎当前（2026-10-27）全部实测可用，无需替换 jar 内 `tts.json`；主要风险是百度代理限流与思必驰 URL 长度/耗时限制。**

---

## 0. 摘要（TL;DR）

| 项目 | 结论 |
|---|---|
| 内置 8 引擎是否可用 | **全部可用**：百度 POST（度博文）+ 思必驰 7 音色，均为 HTTP 200 / `audio/mp3`、`FF F3` 帧头、34–47 帧，app 真实代码路径（`TTSConfig.getFormattedParams` → `Http.bytes`）逐个验证通过 |
| 是否需要替换 `tts.json` | **不需要**；默认 `speaker=0`（度博文）即可用。若想加女声，可选用 `tts-候选.json`（内置 8 项 + 追加百度度小美 per=0），本次按 Lead 决定**不安装** |
| 开源替代（有道/搜狗/Google 等） | **均不可用**：有道 500/688、搜狗反爬 HTML、Google 超时/404、百度 GET 版失效；能用的公开源只剩内置这 8 个（另加百度翻译 gettts，实测是度小美同一音频且限 110 字，无补充价值） |
| 主要风险 | ① 百度代理限流：HTTP 200 返回 JSON（`err_no=529`），会被当 mp3 缓存 → “点了没声音”；② 思必驰 URL 约 280 字上限（300 字起 414），200 字以上合成耗时可能 > app 的 10s 读超时 |
| 本地 TTS 服务（可选） | 技术可行：edge-tts / Windows SAPI 均能返回 MP3/WAV，已用 app 自身 `Http.bytes` 端到端验证；但需额外常驻服务与依赖，**不推荐默认启用**，仅作将来接口失联时的备选 |

---

## 1. 实测方法与判定标准

### 1.1 两种测试通道

1. **Python 标准库请求**（精确记录状态码、Content-Type、字节数、响应头、耗时、音频头十六进制、MP3 帧数/时长）：脚本为 `工具\tts-test\ttslib.py` 及 `builtin_test.py` / `stress_test.py` / `alt_test.py` / `equiv_test.py`。
2. **app 真实代码路径复现**（最有力证据）：用 app 自带 JRE 的 `javac/java` 直接调用 app.jar 里的
   `com.unclezs.novel.app.main.model.config.TTSConfig#getFormattedParams(text)` 和
   `com.unclezs.novel.analyzer.request.Http#bytes(params)`，
   与 `TTSPlayer.toAudio()` 内部完全一致，UA、编码、超时、重定向、异常行为全部一致。脚本为 `工具\tts-test\java\TtsProbe.java`，日志 `java_*.log`。

### 1.2 音频有效性判定

- `sniff`：MP3 需为 `ID3` 或 MPEG 帧同步 `FF F3/FF F2/FF FB`；WAV 需 `RIFF`；
- MP3 帧数解析 ≥3 帧（JavaFX `MediaPlayer` 的最低要求，本机所有可用样本 34–4873 帧）；
- 状态码 200 且 Content-Type 为 `audio/mp3`/`audio/mpeg`/`audio/wav`；
- 对“app 二次编码后服务端能否读对文本”的判定：同一引擎用 **app 二次编码**与**正常一次编码**各请求一次，若返回音频字节 **md5 完全一致**，说明服务端等价处理、app 读出来是正确的原文。

### 1.3 测试文本

- 短文本：`测试朗读`（4 字）；
- 长文本：小说段落（60 / 100 / 130 / 200 / 250 / 280 / 300 / 320 / 350 / 400 / 600 / 800 字，按需）。

---

## 2. 朗读链路逆向结论（决定 tts.json 怎么改）

### 2.1 配置加载：只读 jar 内资源，无外部覆盖

- `ReaderView` 常量：`DEFAULTS_TTS_CONFIG = "assets/defaults/tts.json"`；`initTTSPlayer()` 中：
  `GsonUtils.me().fromJson(IoUtil.readUtf8(ResourceUtils.stream("assets/defaults/tts.json")), ...)`。
- `ResourceUtils.stream()` → `Thread.currentThread().getContextClassLoader().getResourceAsStream(path)`，**只查 classpath（jar 内）**，不会读磁盘 `conf/` 或用户目录。
- `conf.json` 中与朗读相关的只有：`reader.speaker`（选中引擎下标，默认 0）、`reader.speed`（播放速度）。
- **落地含义**：要换/加引擎必须改 `runtime\modules\app.jar` 内 `assets/defaults/tts.json`；且**不要删改前 8 项的顺序/数量**，否则旧用户 `speaker` 下标可能越界（本次 Lead 决定整体不替换，见 §6）。

### 2.2 文本编码：`{{text}}` 会被“二次百分号编码”

`TTSConfig.getFormattedParams(text)` 反编译结果（app.jar 原版、增强版备份、安装版三份一致，下面为语义等价的示意写法）：

```java
RequestParams p = params.copy();
String t = RFC3986.GEN_DELIMS.encode(RFC3986.GEN_DELIMS.encode(text, UTF_8), UTF_8); // 两次全字符编码
if (StrUtil.isNotBlank(params.getBody())) p.setBody(params.getBody().replace("{{text}}", t));
p.setUrl(params.getUrl().replace("{{text}}", t));
```

实测“测试朗读”最终请求（`http://tts.baidu.com/text2audio` POST）：

```
BODY=tex=%25%45%36%25%42%35%25%38%42%25%45%38%25%41%46%25%39%35%25%45%36%25%39%43%25%39%37%25%45%38%25%41%46%25%42%42&per=106&...
```

即服务端解码一次得到的是 `%E6%B5%8B...`（一次编码串）而非中文。**因此只有“能二次解码”的 TTS 服务在 app 内才能读对文本**。实测百度、思必驰都恰好能容忍（见 §3.2）；有道等不能，且本身也已失效。

> 抓包复核：本地回声服务（`echo_server.py` + `java` 探针，日志 `echo_log.jsonl`）确认 OkHttp 发出的原始查询串就是上表格式化结果（`...&text=%25%45%36...`），服务端只解码一次后收到 `%E6%B5%8B%E8%AF%95%E6%9C%97%E8%AF%BB`；POST 请求确实**不带 Content-Type**，UA 为固定 macOS Chrome 87。即“二次编码”不是测试误差，而是 app 实际行为。

### 2.3 HTTP 与播放实现（`Http` / `TTSPlayer`）

| 项 | 实测/反编译结论 |
|---|---|
| 客户端 | OkHttp（`novel-analyzer.jar` 的 `OkHttpClient` 实现），静态单例 |
| 超时 | connect 10s / read 10s（`HttpConfig.defaultConfig()`） |
| 重定向 | `followRedirects=true` |
| 重试 | `retryOnConnectionFailure=true` |
| User-Agent | 强制附加 `Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36`（macOS Chrome 87，固定值） |
| Referer | 仅当配置里显式写 `Referer: auto` 才补，内置配置都没有 |
| POST Content-Type | `MediaType.NONE`（空）→ **不发 Content-Type**；实测百度照常返回 MP3 |
| 非 2xx | `handleFailed()` 抛 `RequestFailedException`（包装成 IOException）→ 本次播放失败 |
| 200 + JSON/HTML | **不抛异常**，字节原样写入 `caches\tts\` 后交 `MediaPlayer` → 播放失败（无提示） |
| 缓存 | 文件名 = 段落文本 `hashCode()`；`caches\tts` 超过 10 MB 整体清空；播放时若缓存文件已存在直接复用（坏文件会被复用，直到清缓存/换页） |
| 预取 | 每页所有段落按队列预取，两次请求之间 **sleep 2000 ms**（`TTSPlayer$1`） |
| 播放格式 | JavaFX `MediaPlayer`：MP3/AAC/WAV 等；MP3 至少 3 帧 |

> 结论：app 的请求节奏是“每段落一次、间隔约 2s”，这与百度限流实测的“≥2s 基本安全”相吻合；但预取突发或用户快速切段仍可能触发限流。

---

## 3. 内置引擎实测（重点）

### 3.1 内置 8 引擎逐项结果（app 真实路径，短文本“测试朗读”）

| # | 名称（tts.json） | 请求 | 状态码 | Content-Type | 字节 | 音频头（hex） | 帧数/时长 | 结论 |
|---|---|---|---|---|---|---|---|---|
| 0 | 度博文 | POST `http://tts.baidu.com/text2audio` | 200 | `audio/mp3` | 11232 | `FF F3 88 C4` | 39 帧 / 1.40s | ✅ 可用 |
| 1 | 思必驰 客服芳芳（gdfanfp） | GET `dds.dui.ai` | 200 | `audio/mpeg` | 4104 | `FF F3 38 C4` | 38 / 1.37s | ✅ 可用 |
| 2 | 思必驰 小玲甜美女神（zhilingfp） | GET | 200 | `audio/mpeg` | 4536 | `FF F3 38 C4` | 42 / 1.51s | ✅ 可用 |
| 3 | 思必驰 风趣幽默星爷（zxcmp） | GET | 200 | `audio/mpeg` | 4536 | `FF F3 38 C4` | 42 / 1.51s | ✅ 可用 |
| 4 | 思必驰 温柔小兰（gqlanfp） | GET | 200 | `audio/mpeg` | 4428 | `FF F3 38 C4` | 41 / 1.48s | ✅ 可用 |
| 5 | 思必驰 风趣淡定葛爷（geyoump） | GET | 200 | `audio/mpeg` | 5076 | `FF F3 38 C4` | 47 / 1.69s | ✅ 可用 |
| 6 | 思必驰 四川话胖胖（ppangf_csn） | GET | 200 | `audio/mpeg` | 4104 | `FF F3 38 C4` | 38 / 1.37s | ✅ 可用 |
| 7 | 思必驰 郭德纲（gdgmfp） | GET | 200 | `audio/mpeg` | 3672 | `FF F3 38 C4` | 34 / 1.22s | ✅ 可用 |
| + | 百度 POST https 版 | POST `https://tts.baidu.com/text2audio` | 200 | `audio/mp3` | 11232 | `FF F3 88 C4` | 39 / 1.40s | ⚠️ 可用但不如 http 稳（成功率 3/5 vs 5/5） |

样本文件（`工具\tts-test\samples\final\`）：`builtin1_百度-度博文.mp3`、`builtin2_思必驰-客服芳芳.mp3` … `builtin8_思必驰-郭德纲.mp3`。

### 3.2 二次编码等价性验证（证明“读对文本”）

| 引擎 | app 二次编码音频 md5 | 正常一次编码音频 md5 | 是否一致 |
|---|---|---|---|
| 百度 POST per=106 | `d50833e27c3c…`（11232 B） | `d50833e27c3c…`（11232 B） | ✅ 完全一致 |
| 百度 POST per=0 | `03396e8598ad…`（13536 B） | `03396e8598ad…`（13536 B） | ✅ 完全一致 |
| 百度翻译 gettts | `03396e8598ad…` | `03396e8598ad…` | ✅ 一致（且与 per=0 同音频） |
| 思必驰 gdfanfp | `79cc3ed7e8f3…`（4104 B） | `79cc3ed7e8f3…`（4104 B） | ✅ 完全一致 |

> 说明：若服务端只解码一次，app 内会朗读成“百分号 E 六…”之类的乱码；上述 md5 一致说明百度/思必驰服务端做了等效二次解码，**app 内读出的是正确的中文原文**。

### 3.3 百度 POST 的音色（per 参数）现状

逐一测试 9 个常见 per（0/1/3/4/5/103/106/110/111）：

- **per=106（度博文，内置默认）✅ 可用**；
- **per=0（度小美，女声）✅ 可用**（13536 B / 47 帧 / 1.69s，长短文本均通过；与百度翻译 gettts 同一音频）；
- per=1/3/4/5/103 → HTTP 200 + JSON：`err_no:501, err_detail:"failed to cluster verify with per:X and pdt:301."`；
- per=110/111 → HTTP 200 + JSON：`err_no:501, err_detail:"failed to find cluster with per and lan."`。

即：百度公开接口现在**只剩 2 个可用音色**（106 男声、0 女声）。若要加女声，可在 tts.json 末尾追加 per=0 项（见 `tts-候选.json` 第 9 项）。

### 3.4 长文本能力

| 引擎 | 字数 | 字节 | 帧/时长 | 响应耗时 | 结论 |
|---|---|---|---|---|---|
| 百度 POST（per=106） | 100 | 179136 | 622 / 22.39s | 0.62s | ✅ |
| 百度 POST | 300 | 522432 | — / 65.3s | 1.28s | ✅ |
| 百度 POST | 600 | 1045728 | — / 130.7s | 2.43s | ✅ |
| 百度 POST | 800 | 1403424 | 4873 / 175.4s | 2.85s | ✅（无 URL 长度问题，走 POST body） |
| 百度 POST | 130（app 路径） | 223488 | 776 / 27.94s | 1.16s | ✅ |
| 思必驰 gdfanfp | 130（app 路径） | 78192 | 724 / 26.06s | 5.66s | ✅（<10s 超时线） |
| 思必驰 gdfanfp | 200 | 121824 | 1128 / 40.61s | 8.54s | ⚠️ 接近 10s 超时 |
| 思必驰 gdfanfp | 250 | 151416 | — / 50.47s | 10.34s | ⚠️ 已超 10s，app 内易读超时失败 |
| 思必驰 gdfanfp | 280 | 171180 | — / 57.06s | 12.36s | ⚠️ 超时 |
| 思必驰 gdfanfp | 300 | — | — | 0.14s | ❌ HTTP 414（URL 8197 字符，openresty 8 KB 限制） |
| 百度翻译 gettts | 110 | 220896 | 710 / 27.61s | 1.11s | ✅（URL 3030 字符） |
| 百度翻译 gettts | 120+ | **0 字节** | — | 0.14s | ❌ HTTP 200 但空响应（URL 3300+ 字符） |

> 小说阅读器按换行分段，通常每段 30–200 字：思必驰安全线约 **≤200 字**；百度 POST 无 URL 限制，可支撑超长段落。

### 3.5 百度代理限流（关键风险）

- 触发时返回 **HTTP 200**，Content-Type `application/json`，正文形如：
  `{"convert_offline":true,"err_detail":"proxy ratelimiter failed.","err_msg":"ratelimit error","err_no":529,"err_subcode":407,...}`
- app 侧因为 `isSuccessful()==true` 不会抛错 → JSON 被写进 `caches/tts/` 当 mp3 → `MediaPlayer` 播放失败（表现为“点了没声音/卡一下跳过”），且该坏文件可能被复用。
- 限流成功率和请求间隔（各测 6 次）：

| 请求间隔 | 成功次数 |
|---|---|
| 0s（连续突发） | 3/6 |
| 0.5s | 5/6 |
| 1.0s | 5/6 |
| 2.0s | 6/6 |

- 另外：10 次快速连续（0.25s 间隔）7/10；高强度测试后按 2.5s 间隔模拟 10 段预取仍只有 7/10（说明限流窗口会累积）；**静置数秒~1 分钟后恢复**（实测 8s 后单次成功）。
- 对比：思必驰 10 次 0.2s 间隔 **10/10**、2.5s 间隔模拟预取 **10/10**，未见限流。
- http vs https：同一时段 http 5/5、https 3/5；内置配置用 http 是合适的，**不要改成 https**。

---

## 4. 公开替代接口实测（均无需 key）

| 候选接口 | 请求 | 状态码 | Content-Type | 字节 | 音频头 | 结论 |
|---|---|---|---|---|---|---|
| 有道 `https://dict.youdao.com/dictvoice?audio=…&le=zh` | GET | **500** | application/json | 120 | `7B 22 74`（JSON） | ❌ 失效；app/浏览器 UA+Referer、type=1 均 500 |
| 有道 `https://tts.youdao.com/fanyivoice` | GET | **688** | — | 0 | — | ❌ 失效（空响应） |
| 搜狗 `https://fanyi.sogou.com/reventondc/synthesis` | GET | 200 | text/html | 25136 | `3C 21 44`（HTML） | ❌ 返回反爬页面，非音频 |
| Google `https://translate.google.com/translate_tts` | GET | 超时 | — | 0 | — | ❌ 连接超时（100s），本网络不可达 |
| Google `https://translate.google.cn/translate_tts` | GET | **404** | text/html | 1680 | `3C 21 44` | ❌ 已关停 |
| 百度 GET 版 `http(s)://tts.baidu.com/text2audio?tex=…` | GET | 200 | application/json | 151 | `7B 22 63` | ❌ `Not verified user`（只有 POST 版可用） |
| 百度翻译 `https://fanyi.baidu.com/gettts?lan=zh&text=…&spd=5&source=web` | GET | 200 | audio/mpeg | 13536 | `FF F3 88 C4` | ⚠️ 可用但 = 度小美同一音频；限 ≤110 字；spd=1/2/3/5/7 有效（时长递减），spd=9 空响应 |
| textreadtts.com（Koishi 插件所用） | — | — | — | — | — | ❌ 已改付费：免费仅 40 字符（官网价格表实测查询） |
| openai.fm / ttsfm（免费 OpenAI 兼容） | POST JSON | — | — | — | — | ❌ 不兼容：需要 `Content-Type: application/json` 与原文 JSON body；本 app POST 不带 Content-Type 且 body 内文本是二次编码，未实测（结构上不可用） |
| 微软 Edge 朗读接口 | WebSocket | — | — | — | — | ❌ 非普通 HTTP GET/POST（需 WS + 鉴权头），只能走本地服务方案（§5） |

**结论：没有比内置更优的“无需鉴权公开 HTTP 接口”。** 2026-10-27 时点上仍可用的只有：百度 `tts.baidu.com` POST（度博文/度小美）、百度翻译 gettts（=度小美、限 110 字）、思必驰 `dds.dui.ai` 7 音色。内置 8 项正好覆盖前两类，故**无需替换**。

---

## 5. 本地 TTS 服务方案（可选，已端到端验证）

### 5.1 可行性实测

- 本机 Python 3.12 `pip install edge-tts` 成功（edge-tts **7.3.1**，能列出 8 个 zh-CN 音色：Xiaoxiao/Xiaoyi/Yunjian/Yunxi/Yunxia/Yunyang/liaoning-Xiaobei/shaanxi-Xiaoni）。
- edge-tts 直连合成“测试朗读。这是一个语音合成可用性测试。”→ **29088 B MP3，FF F3 64 C4，202 帧 / 4.85s**。
- 自写本地服务 `工具\tts-test\local_tts_server.py`：把 app 发来的二次编码串 `unquote` 两次还原原文 → 合成 → 返回 `audio/mpeg`（或 WAV）。
  **用 app 自身 `TTSConfig.getFormattedParams` + `Http.bytes` 复现验证**：
  - edge 后端：短文本 10368 B（2.3s）、130 字 166608 B（2.0s），MP3 帧头 `FF F3 64 C4`，1157 帧 / 27.77s → ✅；
  - Windows SAPI 离线（本机 `Microsoft Huihui Desktop` zh-CN）后端：短文本 91948 B WAV、130 字 1912230 B WAV，`RIFF/WAVE` 头 → ✅ JavaFX 支持 WAV。
  - 服务端请求日志逐条确认：收到 `text=%25%45%36…`，解码两次后为 `测试朗读`/长段落原文（日志 `工具\tts-test\local_tts_requests.jsonl`）。
- app 侧只需一条配置（无需改代码）：`{"name":"本地EdgeTTS","params":{"url":"http://127.0.0.1:18523/tts?text={{text}}","method":"GET"}}`。

### 5.2 结论与推荐

- **可行性**：技术可行，音质/长文本/无限流方面明显优于公开接口；已在本机跑通 app 真实请求路径。
- **不推荐默认启用**：需要用户机器额外安装 Python+edge-tts（联网到微软）或依赖 SAPI（离线但音色机械），还要常驻服务/开机自启/端口占用，部署复杂度明显高于“直接用内置 8 项”；且本方案与本次“不替换 jar 资源”的决定冲突。
- **定位**：仅作将来百度/思必驰接口失联时的备选。若将来要启用，最小启动方式：
  ```
  py -3 -m pip install edge-tts
  <项目目录>\工具\tts-test\.venv\Scripts\python.exe local_tts_server.py --port 18523
  # 然后把 tts.json 末尾追加上面的本地配置项；先启动服务，再开 app
  ```
  离线可改用 `--backend sapi`（无需联网）。现成脚本与说明已放入 `参考\TTS\可选-本地TTS服务\`。

---

## 6. 推荐与落地建议

### 6.1 最终推荐（按 Lead 决策）

1. **不替换 `runtime\modules\app.jar` 内的 `assets/defaults/tts.json`**：内置 8 项全部实测可用，零改动、零风险。
2. 保持 `conf.json` 中 `reader.speaker=0`（度博文）即可正常播放；用户可在朗读设置下拉框切换 7 个思必驰音色。
3. `参考\TTS\tts-候选.json` 为**可选备用文件**（内置 8 项顺序/名称/参数逐字保留 + 末尾追加“百度 度小美（女声）”），只在将来想增加女声/替换资源时使用；**本次不安装**。若安装，先备份原 `app.jar`，且前 8 项不要改动，避免旧 `speaker` 下标越界。

### 6.2 给用户的使用建议（三条）

1. **默认优先用思必驰音色**：实测 10/10 稳定、无限流；单段建议 **≤200 字**（超过约 280 字会返回 414、超过 200 字合成耗时可能 > app 的 10s 超时）。
2. **需要长段落/更快出音时用“度博文”（百度）**：单次请求间隔保持 **≥2 秒**（app 预取本身约 2s/段，正常朗读通常没问题）；避免连续快速切段/狂点，否则可能命中百度代理限流而无声。
3. **遇“点了没声音”**：先切换一个引擎（下拉框立即生效）再播放；或翻页后重播（缓存坏音频会随页面重建）；不要连续快速点同一段。若长时间无声，隔 1 分钟再试（百度限流恢复）。

### 6.3 风险清单

| 风险 | 说明 | 缓解 |
|---|---|---|
| 接口非官方/随时失效 | 百度 tts、思必驰 dds 均为公开免鉴权接口，无 SLA；官方项目 2024 年初停更（最后版本 v5.0.45，2024-01-18） | 内置双供应商冗余；失联时切换引擎 |
| 百度代理限流 | 200+JSON `err_no=529`，会被缓存成坏音频 | 间隔 ≥2s；遇无声切思必驰；翻页重建缓存 |
| 百度 https 不稳 | 同时段 3/5 成功 | 保持内置 http 配置，勿改 https |
| 思必驰 URL 长度 | 300 字起 414（URL 8 KB 限制） | 单段落 ≤200 字；超长段用百度 |
| 思必驰耗时 | 250 字 10.3s > app 10s 读超时 | 同上 |
| 缓存污染 | 200+JSON/HTML 会写入 `caches/tts` | 切引擎/翻页；缓存 >10 MB 自动清空 |
| 网络/代理环境 | app 走系统/配置代理（conf.json proxy 项），http 明文可能被企业网络拦截 | 保持直连；必要时用本地服务 |
| 隐私/版权 | 朗读文本会发送到第三方服务器；音频版权归服务方 | 仅个人阅读使用，不二次分发音频 |

### 6.4 验收方式（Lead 侧）

本次未启动 GUI。播放验收建议：打开一本本地 TXT → 朗读设置选“度博文”和任一“思必驰”音色 → 各试一段，确认出声、语速、切段连续；再连续点 10 段验证百度限流表现（预期大部分正常，偶发无声可切换）。

---

## 7. 证据与复现

### 7.1 脚本（`工具\tts-test\`）

| 文件 | 用途 |
|---|---|
| `ttslib.py` | HTTP 探测 + MP3 帧解析 + WAV/MP3/文本判定 |
| `equiv_test.py` | 二次编码 vs 一次编码等价性（md5） |
| `builtin_test.py` | 内置 8 引擎、百度 per 音色、长文本、10 次稳定性、https |
| `stress_test.py` | 限流间隔、思必驰长度阈值、百度翻译长度/spd、恢复 |
| `alt_test.py` | 有道/搜狗/Google/百度 GET 等替代接口 |
| `curate_samples.py` | 整理样本、生成 `evidence_table.md` |
| `echo_server.py` | 本地回声服务（验证 app 实际发出的查询串/body） |
| `java\TtsProbe.java` | **app 真实代码路径**探针（TTSConfig + Http.bytes） |
| `local_tts_server.py` | 本地 TTS 服务（edge-tts / SAPI 两种后端） |
| `results_*.json`、`java_*.log` | 原始结果与日志 |

### 7.2 音频/响应样本（`工具\tts-test\samples\final\`，共 32 个）

- 内置可用：`builtin1_百度-度博文.mp3` … `builtin8_思必驰-郭德纲.mp3`、`builtin1b_百度-度博文-https.mp3`
- 候选新增：`cand_百度-度小美per0.mp3`
- 等价性对照：`equiv_百度-一次编码对照.mp3`、`equiv_思必驰-一次编码对照.mp3`、`equiv_思必驰- app二次编码.mp3`
- 长文本：`long_百度-130字app路径.mp3`、`long_思必驰-130字app路径.mp3`、`long_百度-800字.mp3`、`long_思必驰-200字.mp3`
- 失败证据：`baidu_限流错误样例.json`、`baidu_GET版失效.json`、`baidu_per1_音色失效样例.json`、`dui_400字_414错误.html`、`youdao_dictvoice_500.json`、`sogou_反爬HTML.html`、`google_cn_404.html`、`alt_百度翻译gettts_130字_空响应.bin`
- 本地服务：`local_edge-直连合成.mp3`、`local_edge-本地服务短文本.mp3`、`local_edge-本地服务130字.mp3`、`local_sapi-离线WAV短文本.wav`、`local_sapi-离线WAV130字.wav`
- 完整清单见 `工具\tts-test\evidence_table.md`

### 7.3 关键事实来源（代码/日志）

- `参考\appjar\assets\defaults\tts.json`（= 安装版 jar 内 `assets/defaults/tts.json`，1917 B，8 项：度博文 + 7 个思必驰音色）
- `javap` 反编译：`ReaderView`、`TTSConfig`、`TTSPlayer`、`TTSPlayer$1`、`Http`、`HttpConfig`、`OkHttpClient`、`ResourceUtils`
- app 路径日志：`java_fetch_short.log`、`java_fetch_long.log`、`java_builtin8.log`、`java_local_short.log`、`java_local_long.log`
- 安装目录完整性核验（本次全程只读，未改安装目录）：当前 `runtime\modules\app.jar` 内 `assets/defaults/tts.json` 为 1917 B、sha256 `8880249DCBCD2FD0F3F8980CE77CB1018AE9E88CC353C9A68DE1751350E46ECA`，与原始备份逐字节一致；测试用 `ref_ok` 结论不受 jar 其他补丁影响
- 保存的反编译文本：`工具\tts-test\javap\`（TTSConfig / TTSPlayer / Http / HttpConfig / OkHttpClient / ReaderView 等）
- 抓包复核日志：`工具\tts-test\echo_log.jsonl`（服务端实际收到的查询串/正文/UA，GET 与 POST 各一条）

> 备注：内置 tts.json 实际为 8 项（`度博文` + 7 个思必驰音色）；文中“内置 8 引擎”指这 8 项，候选文件在其后追加第 9 项。
