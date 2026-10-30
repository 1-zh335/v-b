"""编码等价性测试：判断各 TTS 服务端对“二次百分号编码”文本的实际处理。

背景：Uncle小说 5.0.44 的 TTSConfig.getFormattedParams() 会对 {{text}} 做两次全字符百分号编码，
最终请求里服务端解码一次后看到的是「一次编码串」而非原文。本脚本对比：
  A = app 实际发出的二次编码串（hutool 全字符编码）
  B = 正常浏览器式一次编码串（服务端解码后=原文）
若 A 与 B 返回音频完全一致 => 服务端实际做了二次解码，app 能读对；
若 A 返回错误/不同音频 => app 内该引擎读出来是“百分号乱码”。
"""
import hashlib
import json
import os
import sys
import urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ttslib

BASE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(BASE, "samples")
RAW = "测试朗读"
ONCE = urllib.parse.quote(RAW, safe="")            # 服务端解码一次 => 原文
TWICE_APP = "".join("%%%02X" % b for b in ONCE.encode())  # app/hutool 全字符编码 => 服务端解码一次 => ONCE
TWICE_NORMAL = urllib.parse.quote(ONCE, safe="")

CASES = [
    # (名称, 方法, 基础URL, 参数名, 模板A(app串), 模板B(正常串))
    ("baidu_post_http", "POST", "http://tts.baidu.com/text2audio",
     "tex", TWICE_APP, ONCE),
    ("baidu_fanyi_gettts", "GET", "https://fanyi.baidu.com/gettts?lan=zh&text={v}&spd=5&source=web",
     "v", TWICE_APP, ONCE),
    ("dui_gdfanfp", "GET", "https://dds.dui.ai/runtime/v1/synthesize?voiceId=gdfanfp&text={v}&speed=10&volume=100&audioType=mp3",
     "v", TWICE_APP, ONCE),
    ("youdao_dictvoice", "GET", "https://dict.youdao.com/dictvoice?audio={v}&le=zh",
     "v", TWICE_APP, ONCE),
]


def run_case(name, method, url_tpl, var, app_val, normal_val, headers=None):
    """对单个服务分别用 app 串与正常串请求，返回两侧摘要。"""
    out = {}
    for tag, val in (("A_app", app_val), ("B_normal", normal_val)):
        url = url_tpl.replace("{v}", val)
        if method == "POST":
            body = url_tpl.replace("{v}", val)  # 不会走到这里
            res = ttslib.request(method, "http://tts.baidu.com/text2audio",
                                 body="tex=" + val + "&per=106&cuid=baidu_speech_demo&idx=1&cod=2&lan=zh&ctp=1&pdt=301&vol=5&aue=3&pit=5",
                                 headers=headers)
        else:
            res = ttslib.request(method, url, headers=headers)
        out[tag] = ttslib.summarize(res, OUT, "%s_%s" % (name, tag))
        out[tag]["req_url"] = url
    return out


def main():
    results = {}
    for name, method, url_tpl, var, app_val, normal_val in CASES:
        print("===", name)
        r = run_case(name, method, url_tpl, var, app_val, normal_val)
        results[name] = r
        for tag in ("A_app", "B_normal"):
            s = r[tag]
            print("  %-8s status=%-5s type=%-28s len=%-7s head=%-20s frames=%-4s dur=%-5s md5=%s %s"
                  % (tag, s["status"], (s["content_type"] or "")[:28], s["len"], s["head_hex"][:20],
                     s["mp3_frames"], s["mp3_duration"], s["md5"][:12],
                     ("preview=" + s.get("preview", "")[:80]) if s.get("preview") else ""))
        a, b = r["A_app"], r["B_normal"]
        if a["md5"] and a["md5"] == b["md5"]:
            print("  => 音频字节完全一致：服务端等价处理（已二次解码，app 可读对）")
        elif a["sniff"].startswith("MP3") and b["sniff"].startswith("MP3"):
            print("  => 两者都是 MP3 但字节不同，需按时长判断是否读同一文本")
        else:
            print("  => app 串失败或非音频 → app 内该引擎不可用")

    with open(os.path.join(BASE, "results_equiv.json"), "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    print("\n结果已写入 results_equiv.json")


if __name__ == "__main__":
    main()
