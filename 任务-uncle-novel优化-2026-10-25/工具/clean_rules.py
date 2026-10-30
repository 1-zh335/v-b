# -*- coding: utf-8 -*-
"""清理 rules.json 中过期的“番茄仅搜索”规则（site=novel.snssdk.com），保留可下载版。"""
import json, io, sys
for path in sys.argv[1:]:
    rules = json.load(io.open(path, encoding='utf-8'))
    before = len(rules)
    rules = [r for r in rules if 'snssdk' not in (r.get('site') or '')]
    io.open(path, 'w', encoding='utf-8').write(json.dumps(rules, ensure_ascii=False, indent=2))
    print('[OK] %s: %d -> %d 条' % (path, before, len(rules)))
    for r in rules:
        print('   -', r.get('name'), '|', r.get('site'), '| audio=', r.get('audio'))
