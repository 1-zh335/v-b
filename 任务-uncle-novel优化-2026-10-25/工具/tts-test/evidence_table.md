| 样本文件 | 字节 | 类型 | 帧数/时长(s) | 头部(hex) | 说明 |
|---|---|---|---|---|---|
| builtin1_百度-度博文.mp3 | 11232 | MP3-FRAME | 39/1.4 | FF F3 88 C4 | 内置①百度 POST http，app 真实路径（短文本） |
| builtin1b_百度-度博文-https.mp3 | 11232 | MP3-FRAME | 39/1.4 | FF F3 88 C4 | 内置①百度 POST https（短文本） |
| builtin2_思必驰-客服芳芳.mp3 | 4104 | MP3-FRAME | 38/1.37 | FF F3 38 C4 | 内置②思必驰 gdfanfp |
| builtin3_思必驰-小玲甜美女神.mp3 | 4536 | MP3-FRAME | 42/1.51 | FF F3 38 C4 | 内置③思必驰 zhilingfp |
| builtin4_思必驰-风趣幽默星爷.mp3 | 4536 | MP3-FRAME | 42/1.51 | FF F3 38 C4 | 内置④思必驰 zxcmp |
| builtin5_思必驰-温柔小兰.mp3 | 4428 | MP3-FRAME | 41/1.48 | FF F3 38 C4 | 内置⑤思必驰 gqlanfp |
| builtin6_思必驰-风趣淡定葛爷.mp3 | 5076 | MP3-FRAME | 47/1.69 | FF F3 38 C4 | 内置⑥思必驰 geyoump |
| builtin7_思必驰-四川话胖胖.mp3 | 4104 | MP3-FRAME | 38/1.37 | FF F3 38 C4 | 内置⑦思必驰 ppangf_csn |
| builtin8_思必驰-郭德纲.mp3 | 3672 | MP3-FRAME | 34/1.22 | FF F3 38 C4 | 内置⑧思必驰 gdgmfp |
| cand_百度-度小美per0.mp3 | 13536 | MP3-FRAME | 47/1.69 | FF F3 88 C4 | 候选新增：百度 per=0 度小美（app 编码） |
| equiv_百度-一次编码对照.mp3 | 11232 | MP3-FRAME | 39/1.4 | FF F3 88 C4 | 对照：正常一次编码（与 app 二次编码音频 md5 相同） |
| equiv_思必驰- app二次编码.mp3 | 4104 | MP3-FRAME | 38/1.37 | FF F3 38 C4 | 对照：app 二次编码 |
| equiv_思必驰-一次编码对照.mp3 | 4104 | MP3-FRAME | 38/1.37 | FF F3 38 C4 | 对照：正常一次编码（md5 相同） |
| long_百度-130字app路径.mp3 | 223488 | MP3-FRAME | 776/27.94 | FF F3 88 C4 | 百度 POST 长文本 130 字，app 路径（223488 B） |
| long_思必驰-130字app路径.mp3 | 78192 | MP3-FRAME | 724/26.06 | FF F3 38 C4 | 思必驰 130 字，app 路径（78192 B，耗时 5.7s） |
| long_百度-800字.mp3 | 1403424 | MP3-FRAME | 4873/175.43 | FF F3 88 C4 | 百度 POST 800 字（1403424 B，175s 音频） |
| long_思必驰-200字.mp3 | 121824 | MP3-FRAME | 1128/40.61 | FF F3 38 C4 | 思必驰 200 字（121824 B，40.6s，耗时 8.5s） |
| dui_400字_414错误.html | 174 | TEXT | 0/0.0 | 3C 68 74 6D | 思必驰 400 字 → 414 Request-URI Too Large |
| baidu_限流错误样例.json | 176 | TEXT | 0/0.0 | 7B 22 63 6F | 百度代理限流回包（HTTP 200 + JSON err_no=529） |
| baidu_GET版失效.json | 151 | TEXT | 0/0.0 | 7B 22 63 6F | 百度 GET 版：Not verified user |
| youdao_dictvoice_500.json | 120 | TEXT | 0/0.0 | 7B 22 74 69 | 有道 dictvoice：HTTP 500 |
| sogou_反爬HTML.html | 25630 | TEXT | 0/0.0 | 3C 21 44 4F | 搜狗：返回 HTML 反爬页 |
| google_cn_404.html | 1680 | TEXT | 0/0.0 | 3C 21 44 4F | Google 翻译 TTS：404/超时 |
| alt_百度翻译gettts.mp3 | 13536 | MP3-FRAME | 47/1.69 | FF F3 88 C4 | 百度翻译 gettts（与度小美同一音频） |
| alt_百度翻译gettts_100字.mp3 | 204480 | MP3-FRAME | 710/25.56 | FF F3 88 C4 | 百度翻译 gettts 100 字可用 |
| alt_百度翻译gettts_130字_空响应.bin | 0 | EMPTY | 0/0.0 |  | 百度翻译 gettts 130 字 → 200 但 0 字节 |
| local_edge-直连合成.mp3 | 29088 | MP3-FRAME | 202/4.85 | FF F3 64 C4 | edge-tts 直接合成（zh-CN-XiaoxiaoNeural） |
| local_edge-本地服务短文本.mp3 | 10368 | MP3-FRAME | 72/1.73 | FF F3 64 C4 | 本地 edge-tts 服务 → app 路径（10368 B） |
| local_edge-本地服务130字.mp3 | 166608 | MP3-FRAME | 1157/27.77 | FF F3 64 C4 | 本地 edge-tts 服务 130 字 → app 路径（166608 B） |
| local_sapi-离线WAV短文本.wav | 91948 | WAV | 1/0.02 | 52 49 46 46 | Windows SAPI(Huihui) 本地服务 → app 路径（91948 B） |
| local_sapi-离线WAV130字.wav | 1912230 | WAV | 144/4.04 | 52 49 46 46 | SAPI 130 字 WAV（1912230 B） |
| baidu_per1_音色失效样例.json | 199 | TEXT | 0/0.0 | 7B 22 63 6F | 百度 per=1 等音色失效：err_no=501 |
