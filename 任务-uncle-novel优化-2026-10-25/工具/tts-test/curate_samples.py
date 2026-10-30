"""整理证据样本：把测试过程中产生的样本复制成命名清晰的一组，并生成证据表。

输出：
  工具\\tts-test\\samples\\final\\*        取样后的音频/错误响应样本
  工具\\tts-test\\evidence_table.md       证据表（供报告引用）
"""
import json
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ttslib

BASE = os.path.dirname(os.path.abspath(__file__))
S = os.path.join(BASE, "samples")
SJ = os.path.join(BASE, "samples_java")
SJS = os.path.join(BASE, "samples_java_short")
SJB = os.path.join(BASE, "samples_java_builtin")
FIN = os.path.join(S, "final")

# (源相对路径, 目标名, 说明)
COPIES = [
    ("samples_java_builtin/builtin_baidu_post.bin", "builtin1_百度-度博文.mp3", "内置①百度 POST http，app 真实路径（短文本）"),
    ("samples_java_builtin/builtin_baidu_post_https.bin", "builtin1b_百度-度博文-https.mp3", "内置①百度 POST https（短文本）"),
    ("samples_java_builtin/builtin_dui_gdfanfp.bin", "builtin2_思必驰-客服芳芳.mp3", "内置②思必驰 gdfanfp"),
    ("samples_java_builtin/builtin_dui_zhilingfp.bin", "builtin3_思必驰-小玲甜美女神.mp3", "内置③思必驰 zhilingfp"),
    ("samples_java_builtin/builtin_dui_zxcmp.bin", "builtin4_思必驰-风趣幽默星爷.mp3", "内置④思必驰 zxcmp"),
    ("samples_java_builtin/builtin_dui_gqlanfp.bin", "builtin5_思必驰-温柔小兰.mp3", "内置⑤思必驰 gqlanfp"),
    ("samples_java_builtin/builtin_dui_geyoump.bin", "builtin6_思必驰-风趣淡定葛爷.mp3", "内置⑥思必驰 geyoump"),
    ("samples_java_builtin/builtin_dui_ppangf_csn.bin", "builtin7_思必驰-四川话胖胖.mp3", "内置⑦思必驰 ppangf_csn"),
    ("samples_java_builtin/builtin_dui_gdgmfp.bin", "builtin8_思必驰-郭德纲.mp3", "内置⑧思必驰 gdgmfp"),
    ("samples/baidu_per0_app.mp3", "cand_百度-度小美per0.mp3", "候选新增：百度 per=0 度小美（app 编码）"),
    ("samples/baidu_post_http_B_normal.mp3", "equiv_百度-一次编码对照.mp3", "对照：正常一次编码（与 app 二次编码音频 md5 相同）"),
    ("samples/dui_gdfanfp_A_app.mp3", "equiv_思必驰- app二次编码.mp3", "对照：app 二次编码"),
    ("samples/dui_gdfanfp_B_normal.mp3", "equiv_思必驰-一次编码对照.mp3", "对照：正常一次编码（md5 相同）"),
    ("samples_java/builtin_baidu_post.bin", "long_百度-130字app路径.mp3", "百度 POST 长文本 130 字，app 路径（223488 B）"),
    ("samples_java/builtin_dui_gdfanfp.bin", "long_思必驰-130字app路径.mp3", "思必驰 130 字，app 路径（78192 B，耗时 5.7s）"),
    ("samples/baidu_post_len800.mp3", "long_百度-800字.mp3", "百度 POST 800 字（1403424 B，175s 音频）"),
    ("samples/dui_gdfanfp_len200.mp3", "long_思必驰-200字.mp3", "思必驰 200 字（121824 B，40.6s，耗时 8.5s）"),
    ("samples/dui_gdfanfp_len400.bin", "dui_400字_414错误.html", "思必驰 400 字 → 414 Request-URI Too Large"),
    ("samples/baidu_post_len20.bin", "baidu_限流错误样例.json", "百度代理限流回包（HTTP 200 + JSON err_no=529）"),
    ("samples/baidu_get_http_per106_app.bin", "baidu_GET版失效.json", "百度 GET 版：Not verified user"),
    ("samples/youdao_dictvoice_browser_app.bin", "youdao_dictvoice_500.json", "有道 dictvoice：HTTP 500"),
    ("samples/sogou_synthesis_app.bin", "sogou_反爬HTML.html", "搜狗：返回 HTML 反爬页"),
    ("samples/google_translate_cn_app.bin", "google_cn_404.html", "Google 翻译 TTS：404/超时"),
    ("samples/fanyi_len10.mp3", "alt_百度翻译gettts.mp3", "百度翻译 gettts（与度小美同一音频）"),
    ("samples/fanyi_len100.mp3", "alt_百度翻译gettts_100字.mp3", "百度翻译 gettts 100 字可用"),
    ("samples_java/baidu_fanyi_gettts.bin", "alt_百度翻译gettts_130字_空响应.bin", "百度翻译 gettts 130 字 → 200 但 0 字节"),
    ("samples/edge_tts_xiaoxiao.mp3", "local_edge-直连合成.mp3", "edge-tts 直接合成（zh-CN-XiaoxiaoNeural）"),
    ("samples_java_short/local_edge_tts.bin", "local_edge-本地服务短文本.mp3", "本地 edge-tts 服务 → app 路径（10368 B）"),
    ("samples_java/local_edge_tts.bin", "local_edge-本地服务130字.mp3", "本地 edge-tts 服务 130 字 → app 路径（166608 B）"),
    ("samples_java_short/local_sapi_tts.bin", "local_sapi-离线WAV短文本.wav", "Windows SAPI(Huihui) 本地服务 → app 路径（91948 B）"),
    ("samples_java/local_sapi_tts.bin", "local_sapi-离线WAV130字.wav", "SAPI 130 字 WAV（1912230 B）"),
    ("samples/baidu_per1_app.bin", "baidu_per1_音色失效样例.json", "百度 per=1 等音色失效：err_no=501"),
]


def mp3_or_wav(path):
    data = open(path, "rb").read()
    info = ttslib.summarize({"ok": True, "status": 200, "content_type": "", "len": len(data),
                             "bytes": data, "ms": 0, "final_url": ""})
    return info


def main():
    os.makedirs(FIN, exist_ok=True)
    rows = []
    for src, dst, note in COPIES:
        sp = os.path.join(BASE, src.replace("/", os.sep))
        if not os.path.exists(sp):
            print("MISSING:", src)
            rows.append([dst, "-", "缺失", "-", "-", note])
            continue
        dp = os.path.join(FIN, dst)
        shutil.copyfile(sp, dp)
        info = mp3_or_wav(dp)
        rows.append([dst, str(os.path.getsize(dp)), info["sniff"],
                     "%s/%s" % (info["mp3_frames"], info["mp3_duration"]),
                     info["head_hex"][:11], note])

    lines = ["| 样本文件 | 字节 | 类型 | 帧数/时长(s) | 头部(hex) | 说明 |",
             "|---|---|---|---|---|---|"]
    for r in rows:
        lines.append("| " + " | ".join(r) + " |")
    with open(os.path.join(BASE, "evidence_table.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    print("\n共整理样本 %d 个 -> %s" % (len(rows), FIN))


if __name__ == "__main__":
    main()
