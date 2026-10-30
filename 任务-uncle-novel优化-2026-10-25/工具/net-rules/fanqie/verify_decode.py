# -*- coding: utf-8 -*-
"""验证番茄 PUA 字体解密：用社区字符映射表解码 reader 页 SSR 正文。

映射来源：github.com/ckenkuo/fanqie-cdp-downloader 的 src/charset.json（MIT，仅供学习研究）
解码算法同该项目 decoder.py：
  PUA 码位区间 CODE=[[58344,58715],[58345,58716]]
  bias = ord(ch) - CODE[mode][0]，charset[mode][bias] 即真实字符
  两个 mode 各解一遍，取残留 PUA 更少的结果
"""
import json
import os
import re

import requests

BASE = os.path.dirname(os.path.abspath(__file__))
CHARSET = json.load(open(os.path.join(BASE, "charset-upstream.json"), encoding="utf-8"))
CODE = [[58344, 58715], [58345, 58716]]
UA = {"User-Agent": ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                     "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"),
      "Referer": "https://fanqienovel.com/"}


def decode(content):
    """按两套映射解码，返回 (文本, 模式, 残留PUA数, 原始PUA数)。"""
    lo, hi = min(c[0] for c in CODE), max(c[1] for c in CODE)
    raw_pua = sum(1 for ch in content if lo <= ord(ch) <= hi)
    best = None
    for mode in (0, 1):
        out = []
        for ch in content:
            uni = ord(ch)
            if CODE[mode][0] <= uni <= CODE[mode][1]:
                bias = uni - CODE[mode][0]
                if 0 <= bias < len(CHARSET[mode]) and CHARSET[mode][bias] != "?":
                    out.append(CHARSET[mode][bias])
                else:
                    out.append(ch)
            else:
                out.append(ch)
        text = "".join(out)
        left = sum(1 for ch in text if lo <= ord(ch) <= hi)
        if best is None or left < best[2]:
            best = (text, mode, left)
    return best[0], best[1], best[2], raw_pua


def extract_reader_json(html):
    """从 reader 页 HTML 提取 window.__INITIAL_STATE__ 的 JSON 对象。"""
    i = html.find("window.__INITIAL_STATE__=")
    if i < 0:
        return None
    start = html.find("{", i)
    depth = 0
    j = start
    in_str = False
    esc = False
    while j < len(html):
        ch = html[j]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
        else:
            if ch == '"':
                in_str = True
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    break
        j += 1
    try:
        return json.loads(html[start:j + 1])
    except Exception as e:  # noqa: BLE001
        print("  json parse fail:", e)
        return None


def html_to_text(html):
    """<p> 转段落换行，去标签，反转义实体。"""
    import html as H
    text = re.sub(r"</p>", "\n", html, flags=re.I)
    text = re.sub(r"<br\s*/?>", "\n", text, flags=re.I)
    text = re.sub(r"<[^>]+>", "", text)
    return H.unescape(text)


def fetch_chapter(item_id):
    r = requests.get(f"https://fanqienovel.com/reader/{item_id}", headers=UA, timeout=25)
    obj = extract_reader_json(r.text)
    if not obj:
        return None, None
    cd = (obj.get("reader") or {}).get("chapterData") or {}
    return cd, r.status_code


def main():
    cases = [
        ("诡秘剑主 第1章", "7062605748575928867"),
        ("诡秘剑主 第2章", "7062606245659673099"),
        ("西游记 第一回", "7345722492855520319"),
        ("西游记 第二回", "7345722494013148201"),
    ]
    for tag, item in cases:
        cd, status = fetch_chapter(item)
        if not cd:
            print(tag, "FAIL status=", status)
            continue
        raw = html_to_text(cd.get("content") or "")
        text, mode, left, raw_pua = decode(raw)
        print(f"== {tag}: status={status} 标题={cd.get('title')} 原始字数={len(raw)} 原始PUA={raw_pua} "
              f"mode={mode} 残留PUA={left} 还原率={(1 - left / raw_pua) * 100 if raw_pua else 100:.1f}%")
        print("   解码后:", text.strip().replace("\n", " ")[:120])


if __name__ == "__main__":
    main()
