# -*- coding: utf-8 -*-
"""生成 365小说（shukuge.com）修复版规则并输出到 work/365book-fix2.json。

修复点：
1. search.detail.url 改为相对 CSS（div.bookdesc > a@href），并用 script 把 /book/<id>/ 补成
   /book/<id>/index.html（书信息页没有章节列表，index.html 才是目录页）；
2. search.detail 全部字段用相对 CSS，搜索只发 1 个请求（原规则为每条结果抓详情页，48 条约 55 秒）；
3. 目录/正文沿用原规则（css:div#list > dl > dd / auto:1）。
"""
import json
import os

BASE = os.path.dirname(os.path.abspath(__file__))
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")

APPEND_INDEX = ('result = result + (result.endsWith("/") ? "index.html" : "");')

rule = {
    "name": "🎉 365小说网（修复）",
    "site": "http://www.shukuge.com/",
    "group": "联网书源-实测2026",
    "enabled": True,
    "audio": False,
    "weight": 3,
    "params": {"userAgent": UA},
    "search": {
        "params": {
            "url": "http://www.shukuge.com/Search?wd={{keyword}}",
            "charset": "UTF-8",
            "mediaType": "",
            "dynamicDelayTime": 500,
        },
        "list": "css:div.panel-body > div.listitem",
        "detail": {
            "url": {"rule": "css:div.bookdesc > a@href", "script": APPEND_INDEX},
            "title": "css:div.bookdesc > a > h2@text",
            "author": {"rule": "css:div.bookdesc > p.sp > span:nth-child(1)@text",
                       "replace": ["作者：##"]},
            "category": {"rule": "css:div.bookdesc > p.sp > span:nth-child(2)@text",
                         "replace": ["分类：##"]},
            "state": {"rule": "css:div.bookdesc > p.sp > span:nth-child(3)@text",
                      "replace": ["状态：##"]},
            "latestChapterName": "css:div.bookdesc > p.desc > a@text",
            "latestChapterUrl": "css:div.bookdesc > p.desc > a@href",
        },
    },
    "detail": {},
    "toc": {
        "list": "css:div#list > dl > dd",
        "name": "css:a@text",
        "url": "css:a@href",
        "filter": True,
        "reverse": False,
        "autoNext": False,
        "enableNext": False,
    },
    "content": {
        "content": "auto:1",
        "enableNext": True,
        "next": "xpath://a[text()~='.*?下[一]{0,1}[页节].*']/@href",
    },
}

out = os.path.join(BASE, "work", "365book-fix2.json")
with open(out, "w", encoding="utf-8") as fh:
    json.dump([rule], fh, ensure_ascii=False, indent=2)
print("wrote", out)
