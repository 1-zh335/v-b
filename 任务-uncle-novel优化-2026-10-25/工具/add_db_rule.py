# -*- coding: utf-8 -*-
"""向 core.db 追加本地 TXT 章节规则（=== 分隔标题），供官方「导入本地小说」流程复用。"""
import sqlite3
import sys
import os

RULE_ID = -19
RULE_NAME = '=== 分隔标题（本地TXT）'
RULE_TEXT = r'^\s*={2,}.*={2,}\s*$'
RULE_ORDER = 1

for db in sys.argv[1:]:
    if not os.path.exists(db):
        print('SKIP (not found):', db)
        continue
    con = sqlite3.connect(db)
    cols = [r[1] for r in con.execute('PRAGMA table_info(txt_toc_rule)')]
    if not cols:
        print('NO TABLE txt_toc_rule:', db)
        con.close()
        continue
    con.execute('DELETE FROM txt_toc_rule WHERE id = ?', (RULE_ID,))
    con.execute('INSERT INTO txt_toc_rule(id, name, rule, "order") VALUES(?,?,?,?)',
                (RULE_ID, RULE_NAME, RULE_TEXT, RULE_ORDER))
    con.commit()
    rows = con.execute('SELECT count(*) FROM txt_toc_rule').fetchone()[0]
    print('[OK] %s -> 规则已写入(id=%d), 现有规则 %d 条' % (db, RULE_ID, rows))
    con.close()
