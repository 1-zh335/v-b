"""稳定性/限流/长度上限实测：百度 POST、百度翻译 gettts、思必驰。

关注点：
1) 百度 err_no=529 proxy ratelimiter 的触发条件（间隔/频率）；
2) 思必驰 GET 的 URL 长度上限（414）与正文长度关系；
3) 百度翻译 gettts 的 text 长度上限与 spd 有效范围；
4) 长时间停顿后是否恢复。
"""
import json
import os
import sys
import time
import urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ttslib

BASE = os.path.dirname(os.path.abspath(__file__))
SAMPLES = os.path.join(BASE, "samples")
RESULTS = []


def app_encode(text):
    once = urllib.parse.quote(text, safe="")
    return "".join("%%%02X" % b for b in once.encode())


UNIT = "林轩缓缓睁开双眼，发现自己竟然躺在一张陌生的木床上，四周一片寂静，只有窗外的风声轻轻拂过。"


def text_of(n):
    s = ""
    while len(s) < n:
        s += UNIT
    return s[:n]


def baidu_post(text, per="106"):
    body = ("tex=" + app_encode(text) + "&per=" + per +
            "&cuid=baidu_speech_demo&idx=1&cod=2&lan=zh&ctp=1&pdt=301&vol=5&aue=3&pit=5&_res_tag_=audio")
    return ttslib.request("POST", "http://tts.baidu.com/text2audio", body=body,
                          headers={"User-Agent": ttslib.APP_UA}, timeout=20)


def dui(voice, text):
    url = ("https://dds.dui.ai/runtime/v1/synthesize?voiceId=" + voice + "&text=" +
           app_encode(text) + "&&speed=10&volume=100&audioType=mp3")
    return ttslib.request("GET", url, headers={"User-Agent": ttslib.APP_UA}, timeout=20)


def fanyi(text, spd="5"):
    url = "https://fanyi.baidu.com/gettts?lan=zh&text=" + app_encode(text) + "&spd=" + spd + "&source=web"
    return ttslib.request("GET", url, headers={"User-Agent": ttslib.APP_UA}, timeout=20)


def log(section, name, res, extra=None):
    s = ttslib.summarize(res)
    rec = {"section": section, "name": name, "status": s["status"], "ok": s["ok"],
           "sniff": s["sniff"], "len": s["len"], "frames": s["mp3_frames"],
           "duration": s["mp3_duration"], "ms": s["ms"], "err": s["err"][:120]}
    if s.get("preview"):
        rec["preview"] = s["preview"][:160]
    if extra:
        rec.update(extra)
    RESULTS.append(rec)
    print("[%-14s] %-28s status=%-4s ok=%-5s %-8s len=%-7s dur=%-6s ms=%-5s %s"
          % (section, name, rec["status"], rec["ok"], rec["sniff"], rec["len"],
             rec["duration"], rec["ms"], ("ERR:" + rec["err"][:50]) if rec["err"] else
             ("PREVIEW:" + rec.get("preview", "")[:70]) if rec.get("preview") else ""))
    return rec


def main():
    # ---------- 1. 百度 POST 间隔影响 ----------
    t = text_of(10)
    for gap in (0.0, 0.5, 1.0, 2.0):
        ok = 0
        runs = []
        for i in range(6):
            r = baidu_post(t)
            s = ttslib.summarize(r)
            good = s["sniff"].startswith("MP3") and s["mp3_frames"] >= 3
            ok += 1 if good else 0
            runs.append({"good": good, "status": s["status"], "preview": s.get("preview", "")[:80]})
            time.sleep(gap)
        RESULTS.append({"section": "baidu-gap", "gap": gap, "ok": ok, "n": 6, "runs": runs})
        print("[baidu-gap] 间隔 %.1fs：成功 %d/6" % (gap, ok))

    # ---------- 2. 百度 POST 长文本（间隔 1.5s，含耗时） ----------
    for n in (100, 300, 600):
        r = baidu_post(text_of(n))
        log("baidu-long2", "post_len%d" % n, r, {"chars": n})
        time.sleep(1.5)

    # ---------- 3. 百度 https 与 http 对比 ----------
    for scheme in ("http", "https"):
        ok = 0
        for i in range(5):
            body = ("tex=" + app_encode(t) +
                    "&per=106&cuid=baidu_speech_demo&idx=1&cod=2&lan=zh&ctp=1&pdt=301&vol=5&aue=3&pit=5&_res_tag_=audio")
            r = ttslib.request("POST", scheme + "://tts.baidu.com/text2audio", body=body,
                               headers={"User-Agent": ttslib.APP_UA}, timeout=20)
            s = ttslib.summarize(r)
            ok += 1 if s["sniff"].startswith("MP3") else 0
            time.sleep(0.6)
        RESULTS.append({"section": "baidu-scheme", "scheme": scheme, "ok": ok, "n": 5})
        print("[baidu-scheme] %s 成功 %d/5" % (scheme, ok))

    # ---------- 4. 思必驰稳定性 + URL 长度阈值 ----------
    ok = 0
    for i in range(10):
        r = dui("gdfanfp", t)
        s = ttslib.summarize(r)
        ok += 1 if s["sniff"].startswith("MP3") else 0
        time.sleep(0.2)
    RESULTS.append({"section": "dui-stab", "ok": ok, "n": 10})
    print("[dui-stab] 10 次连续（0.2s 间隔）成功 %d/10" % ok)

    for n in (250, 280, 300, 320, 350):
        url_len = len("https://dds.dui.ai/runtime/v1/synthesize?voiceId=gdfanfp&text=" + app_encode(text_of(n)) +
                      "&&speed=10&volume=100&audioType=mp3")
        r = dui("gdfanfp", text_of(n))
        log("dui-len", "dui_len%d" % n, r, {"chars": n, "url_len": url_len})
        time.sleep(0.8)

    # ---------- 5. 百度翻译 gettts 长度/spd 上限 ----------
    for n in (110, 120, 135, 150, 170):
        url = "https://fanyi.baidu.com/gettts?lan=zh&text=" + app_encode(text_of(n)) + "&spd=5&source=web"
        r = fanyi(text_of(n))
        log("fanyi-len", "fanyi_len%d" % n, r, {"chars": n, "url_len": len(url)})
        time.sleep(1.0)
    for spd in ("1", "2", "3", "5", "7", "9"):
        log("fanyi-spd", "fanyi_spd" + spd, fanyi(t, spd), {"spd": spd})
        time.sleep(0.8)

    # ---------- 6. 静置 8 秒后百度是否恢复 ----------
    print("静置 8s ...")
    time.sleep(8)
    log("baidu-recover", "post_after_pause", baidu_post(t))

    with open(os.path.join(BASE, "results_stress.json"), "w", encoding="utf-8") as f:
        json.dump(RESULTS, f, ensure_ascii=False, indent=2)
    print("\n写入 results_stress.json")


if __name__ == "__main__":
    main()
