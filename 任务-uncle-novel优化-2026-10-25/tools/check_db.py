import sqlite3
import sys

path = sys.argv[1]
print('DB:', path)
try:
    con = sqlite3.connect(path)
    print(' integrity:', con.execute('PRAGMA integrity_check').fetchone()[0])
    tables = [r[0] for r in con.execute("select name from sqlite_master where type='table' order by name")]
    print(' tables:', tables)
    for t in tables:
        try:
            n = con.execute('select count(*) from "%s"' % t).fetchone()[0]
            print('  %-24s %d' % (t, n))
        except Exception as e:
            print('  %-24s ERROR %s' % (t, e))
    con.close()
except Exception as e:
    print(' OPEN ERROR:', e)
