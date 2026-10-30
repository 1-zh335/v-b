# -*- coding: utf-8 -*-
"""分析素材 TXT/DOCX 特征，输出 UTF-8 报告。"""
import os
import re
import glob
import json
import sys

d = r'C:\Users\31384\Documents\trae_projects\v b\素材'
out = r'C:\Users\31384\Documents\trae_projects\v b\任务-uncle-novel优化-2026-10-25\参考\素材分析.txt'

CH = re.compile(
    r'^\s*(第[0-9零一二三四五六七八九十百千两]{1,10}[章节回卷集部篇]'
    r'|Chapter\s*\d+|序章|楔子|前言|后记|番外|尾声|终章)'
)


def guess_encoding(path):
    raw = open(path, 'rb').read(200000)
    if raw.startswith(b'\xef\xbb\xbf'):
        return 'utf-8-sig'
    for enc in ('utf-8', 'gbk', 'gb18030', 'big5'):
        try:
            raw.decode(enc)
            return enc
        except Exception:
            continue
    return 'gb18030'


def analyze_txt(path, fh):
    size = os.path.getsize(path)
    enc = guess_encoding(path)
    line_count = 0
    chapters = 0
    samples = []
    first = ''
    with open(path, 'r', encoding=enc, errors='replace') as f:
        for line in f:
            line_count += 1
            if line_count == 1:
                first = line.strip()[:200]
            s = line.strip()
            if s and len(s) < 80 and CH.match(s):
                chapters += 1
                if len(samples) < 12:
                    samples.append(s)
    fh.write('%-46s | %8.2f MB | %8d 行 | %6d 章节-like | 编码=%s\n' % (
        os.path.basename(path), size / 1048576, line_count, chapters, enc))
    fh.write('    首行: %r\n' % first)
    fh.write('    章节样例: %r\n' % samples)


def analyze_docx(path, fh):
    try:
        import docx
    except ImportError:
        fh.write('%-46s | %8.2f MB | ! 缺少 python-docx，跳过内容分析\n' % (
            os.path.basename(path), os.path.getsize(path) / 1048576))
        return
    d = docx.Document(path)
    paras = [p.text for p in d.paragraphs]
    nonempty = [p for p in paras if p.strip()]
    ch = sum(1 for p in nonempty if len(p.strip()) < 80 and CH.match(p.strip()))
    fh.write('%-46s | %8.2f MB | %6d 段(非空) | %6d 章节-like | docx\n' % (
        os.path.basename(path), os.path.getsize(path) / 1048576, len(nonempty), ch))
    fh.write('    前 5 段: %r\n' % [p.strip()[:60] for p in nonempty[:5]])
    fh.write('    章节样例: %r\n' % [p.strip() for p in nonempty if len(p.strip()) < 80 and CH.match(p.strip())][:8])


def main():
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w', encoding='utf-8') as fh:
        fh.write('素材分析报告\n')
        fh.write('=' * 100 + '\n')
        for p in sorted(glob.glob(os.path.join(d, '*'))):
            if p.lower().endswith('.txt'):
                analyze_txt(p, fh)
                fh.write('-' * 100 + '\n')
            elif p.lower().endswith('.docx'):
                analyze_docx(p, fh)
                fh.write('-' * 100 + '\n')
    print('OK ->', out)


if __name__ == '__main__':
    main()
