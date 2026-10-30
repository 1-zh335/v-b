# -*- coding: utf-8 -*-
"""生成番茄小说（fanqienovel.com）可下载书源规则。

思路（2026-10 实测）：
- 搜索：沿用社区规则的 novel.snssdk.com 搜索 API（book_id 在 ret_data[].book_id）；
- 目录：https://fanqienovel.com/api/reader/directory/detail?bookId=<book_id>，无需签名；
        JSONPath data.chapterListWithVolume[*][*] 为章节数组（itemId/title）；
- 正文：https://fanqienovel.com/reader/<itemId> 的 HTML 内嵌 window.__INITIAL_STATE__，
        其中 reader.chapterData.content 为正文 HTML；
        但正文字符被替换为 PUA 私用区码位（字体反爬），用社区 charset.json 映射表在 script 内还原。

输出：
- 工具/net-rules/fanqie/fanqie-rule.json（测试用）
- 参考/网络规则/fanqie/rules-番茄可用.json（交付）
"""
import json
import os

BASE = os.path.dirname(os.path.abspath(__file__))
FANQIE_DIR = os.path.join(BASE, "fanqie")
OUT_DIR = os.path.join(BASE, "..", "..", "参考", "网络规则", "fanqie")
os.makedirs(OUT_DIR, exist_ok=True)

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")

with open(os.path.join(FANQIE_DIR, "charset-upstream.json"), encoding="utf-8") as fh:
    CHARSET = json.load(fh)
with open(os.path.join(FANQIE_DIR, "content_script.js"), encoding="utf-8") as fh:
    CONTENT_SCRIPT = fh.read()

CONTENT_SCRIPT = CONTENT_SCRIPT.replace("__CHARSET0__", json.dumps(CHARSET[0], ensure_ascii=False))
CONTENT_SCRIPT = CONTENT_SCRIPT.replace("__CHARSET1__", json.dumps(CHARSET[1], ensure_ascii=False))

RULE = {
    "name": "💰番茄小说（可下载）",
    "site": "https://novel.snssdk.com/",
    "group": "联网书源-实测2026",
    "enabled": True,
    "audio": False,
    "weight": 4,
    "params": {"userAgent": UA},
    "search": {
        "params": {
            "url": "https://novel.snssdk.com/api/novel/channel/homepage/search/search/v1/?aid=13&q={{keyword}}",
            "charset": "UTF-8",
            "dynamicDelayTime": 500,
        },
        "list": "$.data.ret_data",
        "detail": {
            # 书 URL：番茄网页目录 API（toc 阶段直接解析它）
            "url": {
                "rule": "$.book_id",
                "script": "\"https://fanqienovel.com/api/reader/directory/detail?bookId=\"+result"
            },
            "title": {
                "rule": "$.title",
                "replace": ["<em>##", "</em>##"]
            },
            "author": "$.author",
            "category": "$.category",
            "introduce": "$.abstract",
            "coverUrl": "$.thumb_url",
            "state": "$.creation_status",
            "wordCount": "$.score",
        },
    },
    "detail": {},
    "toc": {
        "params": {
            "charset": "UTF-8",
            "headers": {
                "User-Agent": UA,
                "Referer": "https://fanqienovel.com/",
                "Accept": "application/json, text/plain, */*",
            },
        },
        "list": "$.data.chapterListWithVolume[*][*]",
        "name": "$.title",
        "url": {
            "rule": "$.itemId",
            "script": "\"https://fanqienovel.com/reader/\"+result"
        },
        "filter": False,
        "reverse": False,
        "autoNext": False,
        "enableNext": False,
    },
    "content": {
        "params": {
            "charset": "UTF-8",
            "headers": {
                "User-Agent": UA,
                "Referer": "https://fanqienovel.com/",
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            },
        },
        "content": {"script": CONTENT_SCRIPT},
        "enableNext": False,
        "next": "xpath://a[text()~='.*?下[一]{0,1}[页节].*']/@href",
    },
}

out = os.path.join(FANQIE_DIR, "fanqie-rule.json")
with open(out, "w", encoding="utf-8") as fh:
    json.dump([RULE], fh, ensure_ascii=False, indent=2)
print("wrote", out, "bytes=", os.path.getsize(out))

final = os.path.join(OUT_DIR, "rules-番茄可用.json")
with open(final, "w", encoding="utf-8") as fh:
    json.dump([RULE], fh, ensure_ascii=False, indent=2)
print("wrote", final, "bytes=", os.path.getsize(final))
