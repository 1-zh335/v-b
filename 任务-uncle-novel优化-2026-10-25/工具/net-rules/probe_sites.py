# -*- coding: utf-8 -*-
"""对 Uncle 小说书源规则里的 search 节点做原始 HTTP 可达性实测。

用途：Java 端 NovelMatcher.search 是「规则是否真能搜出书」的权威判定；
本脚本补充原始 HTTP 细节（状态码/重定向/编码/反爬提示/列表 XPath 命中数），
用于报告里的每站点实测表。

用法：
    python probe_sites.py <rules.json> [<rules2.json> ...] -o out.json [-k 关键词]
"""
import argparse
import json
import re
import sys
import time
import urllib.parse

import requests
from lxml import etree

UA_DEFAULT = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
              "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")

ANTI_BOT_MARKERS = [
    "验证码", "安全验证", "人机验证", "访问过于频繁", "频繁访问", "请稍后再试",
    "Just a moment", "cf-chl", "Cloudflare", "Attention Required",
    "请开启JavaScript", "启用JavaScript", "enable JavaScript",
    "404 Not Found", "页面不存在", "网站已关闭", "域名已过期",
]


def pick_charset(rule):
    """取 search.params.charset；空/缺省返回 None 表示按响应头/自动探测。"""
    cs = ((rule.get("search") or {}).get("params") or {}).get("charset") or ""
    cs = cs.strip()
    return cs or None


def url_encode_keyword(keyword, charset):
    """按站点声明编码对关键词做 URL 编码（GBK 站点用 GBK，否则 UTF-8）。"""
    enc = (charset or "UTF-8").upper().replace("-", "")
    pyenc = "gbk" if enc in ("GBK", "GB2312", "GB18030") else "utf-8"
    return urllib.parse.quote(keyword, encoding=pyenc, safe="")


def build_request(rule, keyword):
    """按规则 search.params 构造请求；返回 (method, url, headers, data/body_bytes, charset)。"""
    search = rule.get("search") or {}
    params = search.get("params") or {}
    charset = pick_charset(rule)
    kw_enc = url_encode_keyword(keyword, charset)
    url = (params.get("url") or "").replace("{{keyword}}", kw_enc)
    url = url.replace("{{page}}", "1")
    headers = {"User-Agent": UA_DEFAULT}
    rule_ua = (rule.get("params") or {}).get("userAgent")
    if rule_ua:
        headers["User-Agent"] = rule_ua
    for k, v in (params.get("headers") or {}).items():
        headers[k] = str(v).replace("{{keyword}}", kw_enc)
    method = (params.get("method") or "GET").upper()
    body = params.get("body")
    data = None
    if method == "POST":
        if body:
            pyenc = "gbk" if (charset or "").upper().replace("-", "") in ("GBK", "GB2312", "GB18030") else "utf-8"
            try:
                data = body.replace("{{keyword}}", keyword).replace("{{page}}", "1").encode(pyenc)
            except UnicodeEncodeError:
                data = body.replace("{{keyword}}", keyword).replace("{{page}}", "1").encode("utf-8")
        else:
            data = b""
        mt = params.get("mediaType")
        if mt:
            headers["Content-Type"] = mt
    return method, url, headers, data, charset


def try_xpath(html_text, xpath, keyword):
    """尽力用 lxml 复现 JsoupXpath 的 list 规则；返回 (命中数, 说明)。"""
    if not xpath or not isinstance(xpath, str):
        return -1, "list 非字符串或为空（脚本型）"
    expr = xpath.strip()
    # JsoupXpath 语法迁移：/// 相对路径、[-1] 末元素、text()~= 正则比较
    expr = expr.replace("///", ".//")
    expr = re.sub(r"\[-1\]", "[last()]", expr)
    expr = re.sub(r"\[-2\]", "[last()-1]", expr)
    if "~=" in expr:
        return -1, "含 JsoupXpath 专有 text()~= 语法，lxml 不支持"
    try:
        tree = etree.HTML(html_text)
        if tree is None:
            return -1, "HTML 解析失败"
        nodes = tree.xpath(expr)
    except Exception as e:  # noqa: BLE001
        return -1, "lxml 无法求值(%s)" % str(e)[:80]
    hit = 0
    for n in nodes:
        if isinstance(n, etree._Element):
            txt = " ".join(n.itertext()).strip()
            if txt:
                hit += 1
        else:
            hit += 1
    return hit, "xpath ok"


def detect_encoding(resp, declared):
    """按规则 charset > 响应头 > 网页 meta > 猜测 的顺序确定解码编码。"""
    candidates = []
    if declared:
        candidates.append(declared)
    ct = resp.headers.get("Content-Type", "")
    m = re.search(r"charset=([\w\-]+)", ct, re.I)
    if m:
        candidates.append(m.group(1))
    head = resp.content[:4096]
    m = re.search(rb'charset=["\']?([\w\-]+)', head, re.I)
    if m:
        candidates.append(m.group(1).decode("ascii", "ignore"))
    candidates += ["utf-8", "gb18030"]
    for cs in candidates:
        if not cs:
            continue
        cs = cs.strip().lower().replace("gb2312", "gb18030")
        try:
            return cs, resp.content.decode(cs, errors="replace")
        except (LookupError, UnicodeDecodeError):
            continue
    return "latin-1", resp.content.decode("latin-1", errors="replace")


def probe(rule, keyword):
    """实测单条规则的搜索请求，返回结果字典。"""
    name = rule.get("name")
    site = rule.get("site")
    search = rule.get("search") or {}
    if not search:
        return {"name": name, "site": site, "ok": False, "reason": "无 search 节点"}
    try:
        method, url, headers, data, declared = build_request(rule, keyword)
    except Exception as e:  # noqa: BLE001
        return {"name": name, "site": site, "ok": False, "reason": "构造请求失败: %s" % e}
    out = {
        "name": name, "site": site, "method": method, "url": url,
        "declaredCharset": declared, "headers": {k: v[:60] for k, v in headers.items()},
    }
    t0 = time.time()
    try:
        resp = requests.request(method, url, headers=headers, data=data,
                                timeout=(12, 25), allow_redirects=True)
        ms = int((time.time() - t0) * 1000)
        enc, text = detect_encoding(resp, declared)
        list_rule = search.get("list")
        list_xpath = list_rule if isinstance(list_rule, str) else None
        hit, xnote = try_xpath(text, list_xpath, keyword)
        markers = [m for m in ANTI_BOT_MARKERS if m.lower() in text.lower()]
        kw_in_page = keyword in text
        out.update({
            "ok": resp.status_code == 200,
            "status": resp.status_code,
            "finalUrl": resp.url,
            "ms": ms,
            "bytes": len(resp.content),
            "contentType": resp.headers.get("Content-Type", ""),
            "encodingUsed": enc,
            "keywordInPage": kw_in_page,
            "listHit": hit,
            "listNote": xnote,
            "antiBot": markers,
            "textLen": len(text),
        })
        if len(text) < 500:
            out["bodyHead"] = text[:400]
        elif hit == 0 and resp.status_code == 200:
            out["bodyHead"] = text[:300]
    except Exception as e:  # noqa: BLE001
        ms = int((time.time() - t0) * 1000)
        out.update({"ok": False, "status": None, "ms": ms, "reason": "%s: %s" % (type(e).__name__, str(e)[:200])})
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("-k", "--keyword", default="诡秘之主")
    args = ap.parse_args()

    all_results = []
    for f in args.files:
        with open(f, encoding="utf-8") as fh:
            data = json.load(fh)
        if isinstance(data, dict):
            data = [data]
        for rule in data:
            if rule.get("audio") is True:
                continue
            print("[probe]", rule.get("name"), rule.get("site"), flush=True)
            all_results.append(probe(rule, args.keyword))
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(all_results, fh, ensure_ascii=False, indent=2)
    print("== wrote", args.out, "count=", len(all_results))


if __name__ == "__main__":
    sys.exit(main())
