# -*- coding: utf-8 -*-
"""生成最终交付的规则文件（app 格式 AnalyzerRule JSON 数组）。

输出：
- 参考/网络规则/rules-可用.json        实测可用（enabled=true，可直接内置 conf/rules.json）
- 参考/网络规则/rules-全部候选.json    全部候选（去重、enabled=false，供参考/手工挑选）
- 参考/网络规则/示例-自定义书源模板.json  字段齐全的最小示例模板（URL 占位）

用法：python make_final_rules.py
"""
import json
import os
import sys

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "..", "..", "参考", "网络规则", "raw")
OUT = os.path.join(BASE, "..", "..", "参考", "网络规则")
WORK = os.path.join(BASE, "work")

sys.path.insert(0, BASE)
import build_candidates as bc  # noqa: E402


def load(name):
    with open(os.path.join(RAW, name), encoding="utf-8") as fh:
        return json.load(fh)


def dump(obj, path):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(obj, fh, ensure_ascii=False, indent=2)
    print("wrote", path, "rules=", len(obj))


def main():
    text = load("book_text.json")
    anti = load("anti_theft.json")
    book365 = load("365book.json")

    # ===== rules-可用.json：4 条实测可搜索规则（3 条可完整下载 + 1 条仅搜索） =====
    hongxiu = bc.fix_hongxiu_script(json.loads(json.dumps(
        [r for r in text if "红袖" in (r.get("name") or "")][0])))
    hongxiu["enabled"] = True
    hongxiu["weight"] = 1
    hongxiu["group"] = "联网书源-实测2026"

    xshuquge = bc.new_xshuquge()
    xshuquge["weight"] = 2

    # 365 小说网：用按当前 HTML 修复后的规则（搜索快、书信息页自动补 index.html）
    with open(os.path.join(WORK, "365book-fix2.json"), encoding="utf-8") as fh:
        shukuge = json.load(fh)[0]
    shukuge["enabled"] = True
    shukuge["weight"] = 3
    shukuge["group"] = "联网书源-实测2026"

    fanqie = json.loads(json.dumps([r for r in text if "番茄" in (r.get("name") or "")][0]))
    fanqie["enabled"] = True
    fanqie["weight"] = 99          # 仅搜索可用：目录/正文接口已失效，排最后
    fanqie["group"] = "联网书源-实测2026-仅搜索"

    usable = [hongxiu, xshuquge, shukuge, fanqie]
    # 按 weight 升序，方便阅读
    usable.sort(key=lambda r: r.get("weight", 0))
    dump(usable, os.path.join(OUT, "rules-可用.json"))

    # ===== rules-全部候选.json：按 site 去重的全部社区候选（enabled=false） =====
    candidates = []
    seen = set()
    for rule in text + anti:
        site = (rule.get("site") or "").rstrip("/")
        if not site or site in seen:
            continue
        seen.add(site)
        r = json.loads(json.dumps(rule))
        r["enabled"] = False
        candidates.append(r)
    # 365book（社区 2025 年规则，可用）
    r = json.loads(json.dumps(book365[0]))
    r["enabled"] = False
    candidates.append(r)
    # 自行构造的书趣阁规则也放进候选（去重后）
    if "http://www.xshuquge.net" not in seen:
        r = bc.new_xshuquge()
        r["enabled"] = False
        candidates.append(r)
    dump(candidates, os.path.join(OUT, "rules-全部候选.json"))

    # ===== 示例模板：最小可解析规则，URL 用占位符 =====
    template = [{
        "name": "示例书源（导入后请改成真实站点）",
        "site": "https://www.example-novel.com/",
        "group": "自定义",
        "enabled": True,
        "audio": False,
        "weight": 10,
        "params": {"userAgent": bc.UA},
        "search": {
            "params": {
                "url": "https://www.example-novel.com/search.php?keyword={{keyword}}&page={{page}}",
                "method": "GET",
                "charset": "UTF-8",
                "dynamicDelayTime": 500
            },
            "list": "//div[@class=\"book-item\"]",
            "detail": {
                "url": "///h3/a/@href",
                "title": "///h3/a/text()",
                "author": {"rule": "///p[@class=\"author\"]/text()", "replace": ["作者：##"]}
            }
        },
        "detail": {},
        "toc": {
            "list": "//div[@id=\"list\"]/dl/dd",
            "name": "///a/text()",
            "url": "///a/@href",
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
    }]
    dump(template, os.path.join(OUT, "示例-自定义书源模板.json"))


if __name__ == "__main__":
    main()
