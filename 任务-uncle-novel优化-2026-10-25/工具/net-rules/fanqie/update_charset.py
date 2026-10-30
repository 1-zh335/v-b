# -*- coding: utf-8 -*-
"""更新番茄 PUA 字符映射表并重新生成规则（字体映射过期时使用）。

用途：
  当番茄正文出现大量未还原的私用区字符（U+E3E8~U+E55B）时，说明字体映射表已过期。
  本脚本从上游开源项目拉取最新 charset.json，覆盖本地副本后重新生成规则。

用法：
  python update_charset.py            # 拉取上游最新 charset.json 并重建规则
  python update_charset.py --local    # 不联网，仅用本地 charset-upstream.json 重建规则

上游：https://github.com/ckenkuo/fanqie-cdp-downloader （MIT，仅供学习研究）
"""
import base64
import json
import os
import subprocess
import sys

import requests

BASE = os.path.dirname(os.path.abspath(__file__))
LOCAL_CHARSET = os.path.join(BASE, "charset-upstream.json")
UPSTREAM_API = ("https://api.github.com/repos/ckenkuo/fanqie-cdp-downloader/"
                "contents/src/charset.json")


def fetch_upstream():
    """从 GitHub API 拉取上游 charset.json（base64）并覆盖本地副本。"""
    headers = {"User-Agent": "Mozilla/5.0"}
    r = requests.get(UPSTREAM_API, headers=headers, timeout=30)
    r.raise_for_status()
    payload = r.json()
    content = base64.b64decode(payload["content"])
    with open(LOCAL_CHARSET, "wb") as fh:
        fh.write(content)
    data = json.loads(content.decode("utf-8"))
    print(f"[OK] 已更新 {LOCAL_CHARSET}：mode0={len(data[0])} mode1={len(data[1])}")


def main():
    if "--local" not in sys.argv:
        fetch_upstream()
    data = json.load(open(LOCAL_CHARSET, encoding="utf-8"))
    if len(data) < 2:
        print("[ERR] charset 结构异常（应为 2 个数组）")
        sys.exit(1)
    script = os.path.join(BASE, "make_fanqie_rule.py")
    print("[..] 重新生成规则 ...")
    subprocess.check_call([sys.executable, "-X", "utf8", script])
    print("[OK] 完成。建议复测：")
    print("     java DownloadTest <rules-番茄可用.json> novel.snssdk.com 西游记")


if __name__ == "__main__":
    main()
