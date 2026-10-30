# -*- coding: utf-8 -*-
"""合并文本/有声书源规则到 conf/rules.json（幂等：按 site 去重）。"""
import json, sys, os, io

def load(path):
    with io.open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

target = sys.argv[1]
base = load(sys.argv[2])                     # 现有 conf/rules.json（4 条）
updates = []
for p in sys.argv[3:]:
    updates.extend(load(p))                  # 新规则（番茄/有声）

rules = list(base)
for nr in updates:
    site = nr.get('site')
    # 先删掉同 site 或同名（番茄旧版仅搜索）的规则
    rules = [r for r in rules if r.get('site') != site and r.get('name') != nr.get('name')]
    rules.append(nr)

with io.open(target, 'w', encoding='utf-8') as f:
    json.dump(rules, f, ensure_ascii=False, indent=2)
print('[OK] %s -> %d 条' % (target, len(rules)))
for r in rules:
    print('  - %-28s site=%-32s audio=%s weight=%s' % (r.get('name'), r.get('site'), r.get('audio'), r.get('weight')))
