# -*- coding: utf-8 -*-
"""把素材 docx 转为 UTF-8 txt（保留段落换行），并输出转换统计到临时日志。

用法: python convert_docx.py
输入: 素材\《深海余烬TXT下载地址列表》.docx
输出: 素材转换\深海余烬-由docx转换.txt        UTF-8（无 BOM），段落间 \n
临时: 工具\_docx_convert.log                 转换统计（供人工查看，分析结束删除）
"""
import os

from docx import Document

MAT = r'C:\Users\31384\Documents\trae_projects\v b\素材'
ROOT = r'C:\Users\31384\Documents\trae_projects\v b\任务-uncle-novel优化-2026-10-25'
SRC = os.path.join(MAT, '《深海余烬TXT下载地址列表》.docx')
DST_DIR = os.path.join(ROOT, '素材转换')
DST = os.path.join(DST_DIR, '深海余烬-由docx转换.txt')
LOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), '_docx_convert.log')


def main():
    os.makedirs(DST_DIR, exist_ok=True)
    doc = Document(SRC)
    paras = [p.text for p in doc.paragraphs]
    nonempty = [t for t in paras if t.strip()]
    # 段落文本内部若含软换行（w:br）会以 \n 形式出现，记录数量
    inner_breaks = sum(t.count('\n') for t in paras)
    text = '\n'.join(paras)
    with open(DST, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
        if not text.endswith('\n'):
            f.write('\n')

    lines = text.split('\n')
    with open(LOG, 'w', encoding='utf-8') as fh:
        fh.write('src=%s\n' % SRC)
        fh.write('dst=%s\n' % DST)
        fh.write('paragraphs=%d\n' % len(paras))
        fh.write('nonempty_paragraphs=%d\n' % len(nonempty))
        fh.write('inner_soft_breaks=%d\n' % inner_breaks)
        fh.write('output_lines=%d\n' % len(lines))
        fh.write('output_chars=%d\n' % len(text))
        fh.write('output_bytes=%d\n' % os.path.getsize(DST))
        fh.write('head6=%r\n' % lines[:6])
        fh.write('tail4=%r\n' % lines[-4:])
        eq = sum(1 for t in nonempty if t.strip().startswith('=') and t.strip().endswith('=') and '==' in t)
        fh.write('===_paras=%d\n' % eq)
        for k in ['免费阅读', '求月票', 'http', '本文件来自', '正在手打中', 'ps']:
            fh.write('contains %s = %d\n' % (k, sum(1 for t in nonempty if k in t)))
        # 连续重复段
        dup = sum(1 for i in range(1, len(nonempty)) if nonempty[i] == nonempty[i - 1])
        fh.write('consecutive_exact_dup_paras=%d\n' % dup)
    print('OK ->', DST)
    print('paragraphs=%d nonempty=%d lines=%d bytes=%d' % (
        len(paras), len(nonempty), len(lines), os.path.getsize(DST)))


if __name__ == '__main__':
    main()
