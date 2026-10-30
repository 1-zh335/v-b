"""内置引擎 + 百度系/思必驰 实测：音色、长文本、稳定性、请求头影响。

关键约定：app(TTSConfig.getFormattedParams) 会对 {{text}} 做二次全字符百分号编码；
百度/思必驰实测均能容忍（服务端等价于二次解码）。本脚本用“app 式二次编码”发请求，
并以“浏览器式一次编码”作为对照，字节一致即证明 app 内可读对原文。
"""
import hashlib
import json
import os
import sys
import time
import urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ttslib

BASE = os.path.dirname(os.path.abspath(__file__))
SAMPLES = os.path.join(BASE, "samples")


def app_encode(text):
    """复刻 hutool PercentCodec 二次全字符编码后的最终串（服务端解码一次后=一次编码串）。"""
    once = urllib.parse.quote(text, safe="")
    return "".join("%%%02X" % b for b in once.encode())


def once_encode(text):
    return urllib.parse.quote(text, safe="")


def make_texts():
    """构造不同长度的中文测试文本。"""
    unit = "林轩缓缓睁开双眼，发现自己竟然躺在一张陌生的木床上，四周一片寂静。"
    texts = {"len10": "测试朗读", "len20": "这是一个语音合成接口可用性测试。"}
    for n in (60, 100, 200, 400, 800):
        s = ""
        while len(s) < n:
            s += unit
        texts["len%d" % n] = s[:n]
    return texts


def baidu_post(text, per="106", variant="app", app_faithful=False):
    """百度 POST；app_faithful=True 时不发 Content-Type（与 app 的 MediaType 空一致）。"""
    enc = app_encode(text) if variant == "app" else once_encode(text)
    body = ("tex=" + enc + "&per=" + per +
            "&cuid=baidu_speech_demo&idx=1&cod=2&lan=zh&ctp=1&pdt=301&vol=5&aue=3&pit=5&_res_tag_=audio")
    ct = None if app_faithful else "application/x-www-form-urlencoded"
    res = ttslib.request("POST", "http://tts.baidu.com/text2audio", body=body,
                         headers={"User-Agent": ttslib.APP_UA}, timeout=15, content_type=ct)
    return res


def dui(voice, text, variant="app"):
    enc = app_encode(text) if variant == "app" else once_encode(text)
    url = ("https://dds.dui.ai/runtime/v1/synthesize?voiceId=" + voice + "&text=" + enc +
           "&&speed=10&volume=100&audioType=mp3")
    return ttslib.request("GET", url, headers={"User-Agent": ttslib.APP_UA}, timeout=15)


def fanyi_baidu(text, spd="5", variant="app"):
    enc = app_encode(text) if variant == "app" else once_encode(text)
    url = "https://fanyi.baidu.com/gettts?lan=zh&text=" + enc + "&spd=" + spd + "&source=web"
    return ttslib.request("GET", url, headers={"User-Agent": ttslib.APP_UA}, timeout=15)


def main():
    results = []
    def rec(section, name, res, note=""):
        s = ttslib.summarize(res, SAMPLES, name)
        s.update({"section": section, "name": name, "note": note})
        results.append(s)
        print("[%-8s] %-26s status=%-5s type=%-22s len=%-7s head=%-14s frames=%-4s dur=%-5s %s"
              % (section, name, s["status"], (s["content_type"] or "")[:22], s["len"],
                 s["head_hex"][:14], s["mp3_frames"], s["mp3_duration"],
                 ("ERR:" + str(s["err"])[:40]) if s["err"] else (("PREVIEW:" + s.get("preview", "")[:60]) if s.get("preview") else "")))
        return s

    texts = make_texts()

    # ---------- 1. 百度 POST：各 per 音色（短文本，app 编码 vs 正常编码对照） ----------
    per_map = {"0": "度小美", "1": "度小宇", "3": "度逍遥", "4": "度丫丫",
               "5": "度小娇", "103": "度米朵", "106": "度博文", "110": "度小童", "111": "度小萌"}
    for per, label in per_map.items():
        a = baidu_post(texts["len10"], per, "app")
        b = baidu_post(texts["len10"], per, "normal")
        sa = rec("baidu-voice", "baidu_per%s_app" % per, a, label)
        sb = ttslib.summarize(b)
        sa["ref_ok"] = bool(b.get("bytes")) and sb["md5"] == sa["md5"]
        sa["ref_status"] = sb["status"]
        sa["ref_sniff"] = sb["sniff"]
        print("         per=%-4s %-6s 对照(一次编码) md5一致=%s ref_status=%s" % (per, label, sa["ref_ok"], sb["status"]))

    # ---------- 2. 百度 POST 长文本 / https / 无Content-Type ----------
    for key in ("len20", "len60", "len100", "len200", "len400", "len800"):
        res = baidu_post(texts[key], "106", "app")
        rec("baidu-long", "baidu_post_%s" % key, res, "chars=%d" % len(texts[key]))
    res = ttslib.request("POST", "https://tts.baidu.com/text2audio",
                         body=("tex=" + app_encode(texts["len10"]) +
                               "&per=106&cuid=baidu_speech_demo&idx=1&cod=2&lan=zh&ctp=1&pdt=301&vol=5&aue=3&pit=5&_res_tag_=audio"),
                         headers={"User-Agent": ttslib.APP_UA}, timeout=15)
    rec("baidu-https", "baidu_post_https", res)
    # app 忠实：POST 无 Content-Type
    body = ("tex=" + app_encode(texts["len10"]) +
            "&per=106&cuid=baidu_speech_demo&idx=1&cod=2&lan=zh&ctp=1&pdt=301&vol=5&aue=3&pit=5&_res_tag_=audio")
    res_noct = ttslib.request("POST", "http://tts.baidu.com/text2audio", body=body,
                              headers={"User-Agent": ttslib.APP_UA}, timeout=15, content_type=None)
    s_noct = rec("baidu-headers", "baidu_post_no_content_type", res_noct)
    res_plain_ua = ttslib.request("POST", "http://tts.baidu.com/text2audio", body=body,
                                  headers={"Content-Type": "application/x-www-form-urlencoded",
                                           "User-Agent": ttslib.BROWSER_UA}, timeout=15)
    s_plain = ttslib.summarize(res_plain_ua)
    s_noct["plain_ua_ref"] = (s_plain["md5"] == s_noct["md5"])
    print("         app无Content-Type vs 浏览器UA表单：md5一致=%s" % s_noct["plain_ua_ref"])

    # ---------- 3. 百度 POST 稳定性：连续 10 次 ----------
    stab = []
    for i in range(10):
        r = baidu_post(texts["len20"], "106", "app")
        s = ttslib.summarize(r)
        stab.append({"i": i, "status": s["status"], "len": s["len"], "sniff": s["sniff"],
                     "frames": s["mp3_frames"], "md5": s["md5"][:12], "ms": s["ms"]})
        time.sleep(0.25)
    results.append({"section": "baidu-stability", "name": "baidu_post_10x", "runs": stab})
    ok = sum(1 for x in stab if x["sniff"].startswith("MP3"))
    print("[baidu-stab] 10 次连续请求：成功 %d/10, 耗时 %s ms" % (ok, [x["ms"] for x in stab]))

    # ---------- 4. 思必驰 7 音色（app 编码；gdfanfp 另做一次编码对照） ----------
    dui_voices = [("gdfanfp", "客服芳芳"), ("zhilingfp", "小玲甜美女神"), ("zxcmp", "风趣幽默星爷"),
                  ("gqlanfp", "温柔小兰"), ("geyoump", "风趣淡定葛爷"), ("ppangf_csn", "四川话胖胖"),
                  ("gdgmfp", "郭德纲")]
    for vid, label in dui_voices:
        a = dui(vid, texts["len10"], "app")
        sa = rec("dui", "dui_%s" % vid, a, label)
        b = dui(vid, texts["len10"], "normal")
        sb = ttslib.summarize(b)
        sa["ref_ok"] = bool(b.get("bytes")) and sb["md5"] == sa["md5"]
        sa["ref_status"] = sb["status"]
        print("         %-12s %-10s 对照 md5一致=%s ref_status=%s ref_dur=%s" % (vid, label, sa["ref_ok"], sb["status"], sb["mp3_duration"]))
    rec("dui-long", "dui_gdfanfp_len200", dui("gdfanfp", texts["len200"], "app"), "chars=200")
    rec("dui-long", "dui_gdfanfp_len400", dui("gdfanfp", texts["len400"], "app"), "chars=400")

    # ---------- 5. 百度翻译 gettts（含长文本 URL 长度上限） ----------
    for key in ("len10", "len20", "len60", "len100", "len200"):
        res = fanyi_baidu(texts[key], "5", "app")
        s = rec("baidu-fanyi", "fanyi_%s" % key, res, "chars=%d" % len(texts[key]))
        s["req_url_len"] = len("https://fanyi.baidu.com/gettts?lan=zh&text=" + app_encode(texts[key]) + "&spd=5&source=web")
    for spd in ("3", "5", "7", "9"):
        rec("baidu-fanyi", "fanyi_spd%s" % spd, fanyi_baidu(texts["len10"], spd, "app"), "spd=" + spd)

    with open(os.path.join(BASE, "results_builtin.json"), "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    print("\n写入 results_builtin.json，样本目录:", SAMPLES)


if __name__ == "__main__":
    main()
