# -*- coding: utf-8 -*-
"""构造/修复「联网书源」候选规则，供 DownloadTest 逐条实测迭代。

输出到 work/ 目录：
- hongxiu-fixed.json  红袖：修复 detail.url（script 拼接章节列表 API）+ 正文换行替换
- fanqie.json         番茄：搜索可用，目录 API 已失效（仅搜索）
- xshuquge-new.json   书趣阁（xshuquge.net）：按当前站点 HTML 重建的规则

用法：python build_candidates.py
"""
import json
import os

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "..", "..", "参考", "网络规则", "raw")
WORK = os.path.join(BASE, "work")
os.makedirs(WORK, exist_ok=True)

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")


def load(name):
    with open(os.path.join(RAW, name), encoding="utf-8") as fh:
        return json.load(fh)


def dump(obj, name):
    path = os.path.join(WORK, name)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(obj, fh, ensure_ascii=False, indent=2)
    print("wrote", path)


def fix_hongxiu(rule):
    """红袖：detail.url 用 script 拼章节列表地址；正文去掉 JSON 转义残留的 \\r\\n 字面量。"""
    search = rule.setdefault("search", {})
    search.setdefault("detail", {})["url"] = {
        "rule": "$.bookId",
        "script": "\"https://appapi.hongxiu.com/api/v1/chapter/list?bookId=\"+result+\"&lastChapterId=0&md5Signature= h2\""
    }
    content = rule.setdefault("content", {})
    content["content"] = {
        "rule": "$.data.chapterContent",
        # 接口返回的正文里换行是字面量 \r\n（JSON 未反转义）；replace 语法：正则##替换文本
        "replace": ["\\\\r\\\\n##\n", "\\\\n##\n"]
    }
    return rule


def fix_hongxiu_script(rule):
    """红袖（备用方案）：正文用 Nashorn 脚本做字面量批量替换。"""
    rule = fix_hongxiu(rule)
    rule["content"]["content"] = {
        "rule": "$.data.chapterContent",
        "script": "result = new java.lang.String(result).replaceAll(java.util.regex.Pattern.quote(\"\\\\r\\\\n\"), \"\\n\");"
    }
    return rule


def new_xshuquge():
    """书趣阁（www.xshuquge.net，原 shuquge.com 域名已跳转）当前可用的完整规则。"""
    return {
        "name": "🎉 书趣阁（新域名）",
        "site": "http://www.xshuquge.net/",
        "group": "联网书源-实测",
        "enabled": True,
        "audio": False,
        "weight": 10,
        "params": {"userAgent": UA},
        "search": {
            "params": {
                "url": "http://www.xshuquge.net/search.php",
                "method": "POST",
                "charset": "UTF-8",
                "mediaType": "application/x-www-form-urlencoded",
                "body": "s=&searchkey={{keyword}}",
                "dynamicDelayTime": 500
            },
            "list": "css:div.bookbox",
            "detail": {
                "url": "css:div.bookinfo > h4 > a@href",
                "title": "css:div.bookinfo > h4 > a@text",
                "author": {"rule": "css:div.bookinfo > div.author@text", "replace": ["作者：##"]},
                "category": {"rule": "css:div.bookinfo > div.cat@text", "replace": ["分类：##"]},
                "latestChapterName": {"rule": "css:div.bookinfo > div.update > a@text"},
                "latestChapterUrl": "css:div.bookinfo > div.update > a@href"
            }
        },
        "detail": {},
        "toc": {
            "list": "css:div.listmain > dl > dd",
            "name": "css:a@text",
            "url": "css:a@href",
            "filter": True,
            "reverse": False,
            "autoNext": False,
            "enableNext": False
        },
        "content": {
            "content": "//div[@id=\"content\"]/text()",
            "enableNext": False,
            "next": "xpath://a[text()~='.*?下[一]{0,1}[页节].*']/@href"
        }
    }


def fast_365book(rule):
    """365book 搜索加速版：search.detail 里 page=detail 的字段会为每条结果抓一次详情页，
    48 条结果 ≈ 55 秒；去掉这些字段后搜索只发 1 个请求（详情页仍在「打开书籍」时按 detail 规则解析）。"""
    detail = rule.get("search", {}).get("detail", {})
    for key in list(detail.keys()):
        val = detail[key]
        if isinstance(val, dict) and val.get("page") == "detail":
            del detail[key]
    return rule


def main():
    text = load("book_text.json")
    book365 = load("365book.json")
    hongxiu = [r for r in text if "红袖" in (r.get("name") or "")][0]
    fanqie = [r for r in text if "番茄" in (r.get("name") or "")][0]
    dump([fix_hongxiu(json.loads(json.dumps(hongxiu)))], "hongxiu-fixed.json")
    dump([fix_hongxiu_script(json.loads(json.dumps(hongxiu)))], "hongxiu-script.json")
    dump([fanqie], "fanqie.json")
    dump([new_xshuquge()], "xshuquge-new.json")
    dump(book365, "365book.copy.json")
    dump([fast_365book(json.loads(json.dumps(book365[0])))], "365book-fast.json")


if __name__ == "__main__":
    main()
