"""公开替代接口实测（无需 key 的候选）：有道、搜狗、Google、百度 GET、各头部差异。

判定标准（面向本 app）：
  1) 普通一次编码请求能否返回有效 MP3/WAV；
  2) app 二次编码请求是否同样返回有效音频（服务端需二次解码，否则 app 内读不对）；
  3) 状态码/Content-Type/字节数/音频头/耗时。
"""
import json
import os
import sys
import urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ttslib

BASE = os.path.dirname(os.path.abspath(__file__))
SAMPLES = os.path.join(BASE, "samples")
RESULTS = []
RAW = "测试朗读"


def app_encode(t):
    once = urllib.parse.quote(t, safe="")
    return "".join("%%%02X" % b for b in once.encode())


def once_encode(t):
    return urllib.parse.quote(t, safe="")


BROWSER_HEADERS = {"User-Agent": ttslib.BROWSER_UA, "Referer": "https://www.youdao.com/"}
APP_HEADERS = {"User-Agent": ttslib.APP_UA}


def clear_headers():
    """urllib 会带默认 UA；这里显式给空实现不必，保留默认 app UA 即可。"""
    return {}


CASES = [
    # name, method, url_template, body_template, extra_headers, timeout
    ("youdao_dictvoice_app_ua", "GET", "https://dict.youdao.com/dictvoice?audio={v}&le=zh", None, APP_HEADERS, 12),
    ("youdao_dictvoice_browser", "GET", "https://dict.youdao.com/dictvoice?audio={v}&le=zh", None,
     {"User-Agent": ttslib.BROWSER_UA, "Referer": "https://www.youdao.com/"}, 12),
    ("youdao_dictvoice_type1", "GET", "https://dict.youdao.com/dictvoice?audio={v}&le=zh&type=1", None,
     {"User-Agent": ttslib.BROWSER_UA, "Referer": "https://www.youdao.com/"}, 12),
    ("youdao_fanyivoice", "GET", "https://tts.youdao.com/fanyivoice?word={v}&le=zh&keyfrom=speaker-target", None,
     {"User-Agent": ttslib.BROWSER_UA, "Referer": "https://www.youdao.com/"}, 12),
    ("sogou_synthesis", "GET",
     "https://fanyi.sogou.com/reventondc/synthesis?text={v}&speed=1&lang=zh-CHS&from=translateweb&speaker=6", None,
     {"User-Agent": ttslib.BROWSER_UA, "Referer": "https://fanyi.sogou.com/"}, 12),
    ("google_translate", "GET",
     "https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=zh-CN&q={v}", None,
     {"User-Agent": ttslib.BROWSER_UA}, 6),
    ("google_translate_cn", "GET",
     "https://translate.google.cn/translate_tts?ie=UTF-8&client=tw-ob&tl=zh-CN&q={v}", None,
     {"User-Agent": ttslib.BROWSER_UA}, 6),
    ("baidu_get_http_per106", "GET",
     "http://tts.baidu.com/text2audio?tex={v}&per=106&cuid=baidu_speech_demo&idx=1&cod=2&lan=zh&ctp=1&pdt=301&vol=5&aue=3&pit=5&_res_tag_=audio",
     None, APP_HEADERS, 12),
    ("baidu_get_https_per106", "GET",
     "https://tts.baidu.com/text2audio?tex={v}&per=106&cuid=baidu_speech_demo&idx=1&cod=2&lan=zh&ctp=1&pdt=301&vol=5&aue=3&pit=5&_res_tag_=audio",
     None, APP_HEADERS, 12),
    ("baidu_post_https_106", "POST", "https://tts.baidu.com/text2audio",
     "tex={v}&per=106&cuid=baidu_speech_demo&idx=1&cod=2&lan=zh&ctp=1&pdt=301&vol=5&aue=3&pit=5&_res_tag_=audio",
     APP_HEADERS, 12),
]


def run(name, method, tpl, body_tpl, headers, timeout, variant):
    enc = app_encode(RAW) if variant == "app" else once_encode(RAW)
    url = tpl.replace("{v}", enc)
    body = body_tpl.replace("{v}", enc) if body_tpl else None
    res = ttslib.request(method, url, body=body, headers=headers, timeout=timeout)
    s = ttslib.summarize(res, SAMPLES, "%s_%s" % (name, variant))
    s.update({"name": name, "variant": variant, "req_url_len": len(url)})
    RESULTS.append(s)
    print("[%-24s/%-6s] status=%-4s type=%-24s len=%-7s %-9s frames=%-3s dur=%-5s %s"
          % (name, variant, s["status"], (s["content_type"] or "")[:24], s["len"], s["sniff"],
             s["mp3_frames"], s["mp3_duration"],
             ("ERR:" + s["err"][:40]) if s["err"] else
             (("PREVIEW:" + s.get("preview", "").replace("\n", " ")[:90]) if s.get("preview") else "")))
    return s


def main():
    for name, method, tpl, body_tpl, headers, timeout in CASES:
        run(name, method, tpl, body_tpl, headers, timeout, "app")
        run(name, method, tpl, body_tpl, headers, timeout, "normal")
    with open(os.path.join(BASE, "results_alt.json"), "w", encoding="utf-8") as f:
        json.dump(RESULTS, f, ensure_ascii=False, indent=2)
    print("\n写入 results_alt.json")


if __name__ == "__main__":
    main()
