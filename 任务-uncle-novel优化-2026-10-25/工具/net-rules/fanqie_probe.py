# -*- coding: utf-8 -*-
"""番茄小说（fanqie / fqnovel）下载接口探测脚本。

目的：为 task-1 找到「无签名/弱签名、可在 AnalyzerRule 内直接请求」的目录 + 正文接口。
输出：每条候选接口的 HTTP 状态、Content-Type、字节数、响应片段、是否含章节/正文特征。

用法：python fanqie_probe.py [关键词] [bookId]
"""
import json
import re
import sys
import time

import requests

BROWSER_UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
              "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")
MOBILE_UA = ("Mozilla/5.0 (Linux; Android 10; M2007J22C Build/QP1A.190711.020; wv) "
             "AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/83.0.4103.101 Mobile Safari/537.36")


def show(tag, r, elapsed):
    body = r.content
    text = body.decode("utf-8", "replace")
    print(f"--- {tag}")
    print(f"    status={r.status_code} ct={r.headers.get('Content-Type','')!r} bytes={len(body)} "
          f"final={r.url} ms={int(elapsed*1000)}")
    if len(body) < 1500:
        print(f"    body: {text[:250]!r}")
    else:
        # 只打印前 300 字符 + 关键特征
        feats = []
        for kw in ["itemId", "chapterId", "chapterList", "content", "bookName", "chapterName",
                   "__INITIAL_STATE__", "volume", "catalog", "directory", "item_id", "title"]:
            if kw in text:
                feats.append(kw)
        print(f"    features={feats}")
        print(f"    head: {text[:220]!r}")


def main():
    keyword = sys.argv[1] if len(sys.argv) > 1 else "诡秘之主"
    book_id = sys.argv[2] if len(sys.argv) > 2 else None
    s = requests.Session()
    s.headers.update({
        "User-Agent": BROWSER_UA,
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "zh-CN,zh;q=0.9",
        "Referer": "https://fanqienovel.com/",
    })

    # 0. 搜索拿 book_id（复用之前验证过的搜索 API）
    if not book_id:
        try:
            r = s.get("https://novel.snssdk.com/api/novel/channel/homepage/search/search/v1/?aid=13&q="
                      + requests.utils.quote(keyword), timeout=20)
            j = r.json()
            items = j.get("data", {}).get("ret_data", [])
            if items:
                book_id = items[0].get("book_id")
                print(f"== search: {len(items)} 条, first={items[0].get('title')} book_id={book_id}")
        except Exception as e:  # noqa: BLE001
            print("== search FAIL", repr(e)[:150])
    print("== book_id =", book_id)

    probes = []
    # A. 网页版 SSR / HTML
    probes.append(("A1 fanqienovel page HTML", "GET", f"https://fanqienovel.com/page/{book_id}", None))
    # B. 网页版 API
    probes.append(("B1 directory/detail", "GET",
                   f"https://fanqienovel.com/api/reader/directory/detail?bookId={book_id}", None))
    probes.append(("B2 book/info", "GET", f"https://fanqienovel.com/api/reader/book/info?book_id={book_id}", None))
    # C. 旧移动端 API（基线）
    probes.append(("C1 api5 dir (旧)", "GET",
                   "https://api5-normal-lf.fqnovel.com/reading/bookapi/directory/all_items/v/"
                   f"?need_version=true&book_id={book_id}&iid=2665637677906061&aid=1967&app_name=novelapp&version_code=495",
                   None))
    probes.append(("C2 multi-detail", "GET",
                   f"https://api5-normal-lf.fqnovel.com/reading/bookapi/multi-detail/v/?aid=1967&iid=1&book_id={book_id}&need_abstract=1",
                   None))
    probes.append(("C3 sinfonlineb dir", "GET",
                   "https://api5-normal-sinfonlineb.fqnovel.com/reading/bookapi/directory/all_items/v/"
                   f"?need_version=true&book_id={book_id}&iid=2665637677906061&aid=1967&app_name=novelapp&version_code=495",
                   None))
    probes.append(("C4 snssdk dir detail", "GET",
                   f"https://novel.snssdk.com/api/novel/book/directory/detail/v1/?group_id={book_id}&item_id={book_id}",
                   None))
    # D. 网页阅读器（需要 itemId，先用 book_id 试探）
    probes.append(("D1 reader page HTML", "GET", f"https://fanqienovel.com/reader/{book_id}", None))
    probes.append(("D2 reader/full api", "GET",
                   f"https://fanqienovel.com/api/reader/full?itemId={book_id}&bookId={book_id}", None))

    for tag, method, url, _ in probes:
        try:
            t = time.time()
            r = s.request(method, url, timeout=20, allow_redirects=True)
            show(tag, r, time.time() - t)
        except Exception as e:  # noqa: BLE001
            print(f"--- {tag}\n    FAIL {type(e).__name__}: {str(e)[:200]}")


if __name__ == "__main__":
    main()
