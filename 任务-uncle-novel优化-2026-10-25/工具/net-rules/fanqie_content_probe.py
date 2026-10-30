# -*- coding: utf-8 -*-
"""番茄网页接口结构分析 + 正文接口探测（task-1 第二步）。

1. 取目录 API JSON，打印结构（volume/chapterList 字段），拿真实 itemId + 章节名；
2. 用真实 itemId 试正文接口 / 阅读页 SSR；
3. 输出候选（接口, 参数, 正文提取方式）。
"""
import json
import sys

import requests

BROWSER_UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
              "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")


def main():
    book_id = sys.argv[1] if len(sys.argv) > 1 else "7062605224690584617"
    s = requests.Session()
    s.headers.update({
        "User-Agent": BROWSER_UA,
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "zh-CN,zh;q=0.9",
        "Referer": "https://fanqienovel.com/",
    })
    r = s.get(f"https://fanqienovel.com/api/reader/directory/detail?bookId={book_id}", timeout=20)
    j = r.json()
    print("== directory status", r.status_code, "bytes", len(r.content))
    data = j.get("data", {})
    print("== data keys:", list(data.keys()))
    for k in data.keys():
        v = data[k]
        if isinstance(v, list):
            print(f"   data.{k}: list len={len(v)} first={json.dumps(v[0], ensure_ascii=False)[:300] if v else None}")
        elif isinstance(v, dict):
            print(f"   data.{k}: dict keys={list(v.keys())[:12]}")
        else:
            print(f"   data.{k}: {json.dumps(v, ensure_ascii=False)[:200]}")
    # 找章节列表结构
    chapter_list = data.get("chapterList") or []
    print("\n== chapterList len:", len(chapter_list))
    if chapter_list:
        first_vol = chapter_list[0]
        print("   volume keys:", list(first_vol.keys()) if isinstance(first_vol, dict) else type(first_vol))
        print("   volume sample:", json.dumps(first_vol, ensure_ascii=False)[:800])
        # 找第一本书章节
        chapters = None
        for vol in chapter_list:
            for key in ("chapterList", "chapters", "chapterInfo"):
                if isinstance(vol, dict) and vol.get(key):
                    chapters = vol[key]
                    print(f"   found chapters under {key}, len={len(chapters)}, first={json.dumps(chapters[0], ensure_ascii=False)[:400]}")
                    break
            if chapters:
                break
        if chapters:
            item_id = chapters[0].get("itemId") or chapters[0].get("chapterId") or chapters[0].get("id")
            print("\n== first itemId =", item_id)
            # 候选正文接口
            urls = [
                ("full?itemId only", f"https://fanqienovel.com/api/reader/full?itemId={item_id}"),
                ("full?itemId+bookId", f"https://fanqienovel.com/api/reader/full?itemId={item_id}&bookId={book_id}"),
                ("reader page", f"https://fanqienovel.com/reader/{item_id}"),
                ("reader page with book", f"https://fanqienovel.com/reader/{item_id}?book_id={book_id}"),
                ("content api?", f"https://fanqienovel.com/api/reader/content?itemId={item_id}"),
            ]
            for tag, url in urls:
                try:
                    rr = s.get(url, timeout=20, allow_redirects=True)
                    body = rr.content
                    text = body.decode("utf-8", "replace")
                    print(f"\n--- {tag}: status={rr.status_code} ct={rr.headers.get('Content-Type','')!r} bytes={len(body)} final={rr.url}")
                    hints = [k for k in ["content", "__INITIAL_STATE__", "itemId", "chapterTitle", "reader", "login"] if k in text]
                    print("    hints:", hints)
                    print("    head:", text[:200].replace("\n", " "))
                except Exception as e:  # noqa: BLE001
                    print(f"\n--- {tag}: FAIL {type(e).__name__}: {str(e)[:150]}")


if __name__ == "__main__":
    main()
