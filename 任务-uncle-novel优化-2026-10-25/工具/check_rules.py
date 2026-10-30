# -*- coding: utf-8 -*-
"""测试章节识别规则对素材文件的覆盖率，并导出报告。"""
import os
import re
import glob
import sqlite3
import json

MAT = r'C:\Users\31384\Documents\trae_projects\v b\素材'
ROOT = r'C:\Users\31384\Documents\trae_projects\v b\任务-uncle-novel优化-2026-10-25'
DB = os.path.join(os.environ['LOCALAPPDATA'], r'Programs\UncleNovel\conf\core.db')
OUT = os.path.join(ROOT, r'参考\章节规则分析.txt')

# 候选章节规则（Python 语法与 Java 正则基本兼容）
CANDIDATES = [
    ('std_chapter', r'^\s*第[0-9零一二三四五六七八九十百千两]{1,12}[章节回卷集部篇][^\n]{0,40}$'),
    ('std_chapter_loose', r'^\s*第[0-9零一二三四五六七八九十百千两]{1,12}[章节回卷集部篇].{0,40}$'),
    ('deng_hao', r'^\s*={2,}.*={2,}\s*$'),
    ('bookname_chapter', r'^.*《[^》]{1,20}》\s*第[0-9零一二三四五六七八九十百千两]{1,12}[章节回卷].{0,40}$'),
    ('free_read', r'^.*第[0-9零一二三四五六七八九十百千两]{1,12}章.{0,60}免费阅读.*$'),
    ('numbered', r'^\s*(?:第)?[0-9]{1,5}[、.．,，]\s*\S.{0,30}$'),
    ('volume', r'^\s*第[0-9零一二三四五六七八九十百千两]{1,12}[卷部集篇].{0,40}$'),
]


def guess_encoding(path):
    raw = open(path, 'rb').read(200000)
    for enc in ('utf-8-sig', 'utf-8', 'gbk', 'gb18030'):
        try:
            raw.decode(enc)
            return enc
        except Exception:
            pass
    return 'gb18030'


def dump_db_rules(fh):
    fh.write('== 当前 conf/core.db 的 txt_toc_rule 规则 ==\n')
    if not os.path.exists(DB):
        fh.write('  数据库不存在: %s\n' % DB)
        return
    con = sqlite3.connect(DB)
    cols = [r[1] for r in con.execute('PRAGMA table_info(txt_toc_rule)')]
    fh.write('  列: %s\n' % cols)
    for row in con.execute('SELECT * FROM txt_toc_rule'):
        fh.write('  %s\n' % (row,))
    con.close()
    fh.write('\n')


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as fh:
        dump_db_rules(fh)
        fh.write('== 素材文件 × 候选规则 覆盖率（粗测，按行匹配） ==\n')
        for p in sorted(glob.glob(os.path.join(MAT, '*.txt'))):
            enc = guess_encoding(p)
            with open(p, 'r', encoding=enc, errors='replace') as f:
                lines = [l.strip() for l in f if l.strip()]
            fh.write('\n### %s  (%s, 非空行 %d)\n' % (os.path.basename(p), enc, len(lines)))
            for name, pat in CANDIDATES:
                cre = re.compile(pat)
                hits = [l for l in lines if len(l) < 120 and cre.match(l)]
                fh.write('  %-20s 命中 %6d 行；样例: %s\n' % (
                    name, len(hits), repr([h[:40] for h in hits[:3]])))
    print('OK ->', OUT)


if __name__ == '__main__':
    main()
