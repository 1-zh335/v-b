# -*- coding: utf-8 -*-
"""章节识别基准构建脚本（对照 R1/R2/R3 三条候选规则扫描 7 个测试小说素材）。

输入:
  素材\\*.txt（6 个，GB18030 正文 + UTF-8 标题行混合编码）
  素材转换\\深海余烬-由docx转换.txt（由 convert_docx.py 生成的 UTF-8 文本）
输出:
  参考\\规则基准\\章节基准.json       机器可读基准
  工具\\_baseline_detail.txt          机器生成的明细报告（写 md 用；分析结束后删除）

口径:
  * 逐行解码：先 UTF-8 strict，失败再 GB18030 strict，仍失败用 GB18030 replace 并计数；
  * 规则 R1/R2/R3 与任务说明完全一致，逐行 re.match（等价于 app 按行匹配）；
  * 清洗：去首尾 '='、去书名《…》前缀、截断“正在手打中/免费阅读”及之后内容、去首尾空白、
    连续空白归一为单个空格；
  * 去重：清洗后标题与上一章标题完全相同（连续重复）则合并；
  * 章节正文：从本章标题行下一行起，到下一章标题行前止；字数为去空白后的字符数；
  * 每章平均字数 = 全文去空白字符数（扣除 R1 标题行）/ 去重后章节数（估算口径）。
"""
import os
import re
import json
import hashlib
import datetime
from collections import Counter

MAT = r'C:\Users\31384\Documents\trae_projects\v b\素材'
ROOT = r'C:\Users\31384\Documents\trae_projects\v b\任务-uncle-novel优化-2026-10-25'
CONV = os.path.join(ROOT, '素材转换', '深海余烬-由docx转换.txt')
SRC_DOCX = os.path.join(MAT, '《深海余烬TXT下载地址列表》.docx')
OUT_JSON = os.path.join(ROOT, '参考', '规则基准', '章节基准.json')
OUT_DETAIL = os.path.join(os.path.dirname(os.path.abspath(__file__)), '_baseline_detail.txt')

R1 = re.compile(r'^\s*={2,}.*={2,}\s*$')
R2 = re.compile(r'^[ \t\u3000]{0,4}第[0-9零〇一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,12}'
                r'[章节回卷集部篇][^\n]{0,80}$')
R3 = re.compile(r'^.*《[^》]{1,30}》[ \t\u3000]{0,4}第[0-9零〇一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,12}'
                r'[章节回卷][^\n]{0,80}$')
RULES = [('R1', R1, r'^\s*={2,}.*={2,}\s*$'),
         ('R2', R2, r'^[ \t\u3000]{0,4}第[数字]{1,12}[章节回卷集部篇][^\n]{0,80}$'),
         ('R3', R3, r'^.*《[^》]{1,30}》[ \t\u3000]{0,4}第[数字]{1,12}[章节回卷][^\n]{0,80}$')]

NUM_CHARS = '0-9零〇一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟'
NUM_RE = '[' + NUM_CHARS + ']{1,12}'
CHAP_MARK = re.compile(r'第?\s*(' + NUM_RE + r')\s*[章节回卷集部篇]')
DIG_ONLY = re.compile(r'^第\s*(' + NUM_RE + r')')
CN_DIGIT = {'零': 0, '〇': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4, '五': 5,
            '六': 6, '七': 7, '八': 8, '九': 9, '壹': 1, '贰': 2, '叁': 3, '肆': 4,
            '伍': 5, '陆': 6, '柒': 7, '捌': 8, '玖': 9}
CN_UNIT = {'十': 10, '拾': 10, '百': 100, '佰': 100, '千': 1000, '仟': 1000, '万': 10000}
SPECIAL_PREFIX = re.compile(r'^(?:序章|序言|序|楔子|前言|后记|尾声|终章|番外|正文|卷首语|扉页|引子)')
# 作者话/公告类标题关键词（只用于统计“疑似非章节标题”，不影响应用实际产出章节数）
NOISE_KW = ['感言', '总结', '单章', '求月票', '求推荐票', '求票', '求订阅', '求收藏', '求首订',
            '月票', '推荐票', '订阅', '打赏', '更新', '新书', '新想法', '感谢', '谢谢', '请假',
            '断更', '公告', '声明', '致歉', '说明', '活动', '选拔', '征稿', '名单', '明信片',
            '卖书', '上架', '封推', '完本', '拜年', '报表', '卡文', '唠叨', '说说', '聊天',
            '坚持', '众筹', '答疑', '全渠道', '目标', '让我们一起', '璀璨', '角色', '加更',
            '签到', '红包', '抽奖', '通知', '预告', '上传', '起点', '正版', '读者', '书评',
            '书友', '抱歉', '道歉', '申明', '错字', '捉虫', '崩溃', '停电', '断电', '剧情',
            '月底', '废话', '半年', '风雨', '推荐', '票']
NOISE_KW_RE = re.compile('|'.join(re.escape(k) for k in NOISE_KW))

NOISE_PATTERNS = [
    ('来源水印(本文件来自/本书来自)', re.compile(r'本文件来自|本书来自')),
    ('===标题行', None),  # 用 R1 判定
    ('免费阅读', re.compile(r'免费阅读')),
    ('求月票类(求[^，。！？]{0,6}月票)', re.compile(r'求[^，。！？\s]{0,6}月票')),
    ('ps行', re.compile(r'(?i)(?:^|[^a-zA-Z])ps[：: ]')),
    ('正在手打中', re.compile(r'正在手打中')),
    ('URL/下载站', re.compile(r'https?://|www\.|txt909')),
    ('其他水印(最快更新/最新章节等)', re.compile(r'最快更新|最新章节|内容更新后|请重新刷新')),
]


def cn2int(s):
    """中文/阿拉伯数字转 int，无法解析返回 None。"""
    if s.isdigit():
        return int(s)
    total = section = num = 0
    for ch in s:
        if ch in CN_DIGIT:
            num = CN_DIGIT[ch]
        elif ch in CN_UNIT:
            u = CN_UNIT[ch]
            if u == 10000:
                section = (section + num) * 10000
                total += section
                section = 0
                num = 0
            else:
                section += (num or 1) * u
                num = 0
        else:
            return None
    return total + section + num


def title_number(title):
    """从标题里解析第一处章号，解析不到返回 None。"""
    m = CHAP_MARK.search(title)
    if m:
        return cn2int(m.group(1))
    m = DIG_ONLY.match(title)
    if m:
        return cn2int(m.group(1))
    return None


def clean_title(s):
    """按应用补丁口径清洗章节标题。"""
    t = s.strip()
    t = t.strip('=').strip()                     # 1) 去首尾 '='
    m = re.match(r'^.*?《[^》]{1,30}》', t)        # 2) 去书名《…》前缀
    if m:
        rest = t[m.end():].lstrip()
        if rest and (CHAP_MARK.match(rest) or DIG_ONLY.match(rest) or SPECIAL_PREFIX.match(rest)):
            t = rest
    for marker in ('正在手打中', '免费阅读'):       # 3) 截断水印
        i = t.find(marker)
        if i >= 0:
            t = t[:i]
    t = re.sub(r'[ \t\u3000]+', ' ', t).strip()   # 4) 空白归一
    return t


CJK_RE = re.compile(r'[\u4e00-\u9fff]')


def decode_lines(raw):
    """逐行解码混合编码文本（GB18030 正文 + UTF-8 标题/水印行）。

    判定优先级：
      1) UTF-8 strict 成功且含汉字 -> 该行是 UTF-8 混入行（=== 标题/来源行），采用 UTF-8；
      2) 否则 GB18030 strict 成功且含汉字 -> GB18030 正文行；
      3) 否则回退 UTF-8 / GB18030 replace，仅统计用。
    （个别 GB18030 单字行的字节恰好也是合法 UTF-8，若不这样判定会解成非汉字字符。）
    """
    texts = []
    gb_lines = utf8_mixed_lines = ascii_lines = err_lines = 0
    for ln in raw.split(b'\n'):
        b = ln.rstrip(b'\r')
        if not b.strip():
            texts.append('')
            continue
        s_utf8 = None
        try:
            s_utf8 = b.decode('utf-8')
        except UnicodeDecodeError:
            pass
        if s_utf8 is not None and CJK_RE.search(s_utf8):
            texts.append(s_utf8)
            utf8_mixed_lines += 1
            continue
        try:
            s_gb = b.decode('gb18030')
        except UnicodeDecodeError:
            s_gb = None
        if s_gb is not None and any(ord(c) > 127 for c in s_gb):
            texts.append(s_gb)
            gb_lines += 1
        elif s_utf8 is not None and not any(ord(c) > 127 for c in s_utf8):
            texts.append(s_utf8)
            ascii_lines += 1
        elif s_gb is not None:
            texts.append(s_gb)
            ascii_lines += 1
        elif s_utf8 is not None:
            texts.append(s_utf8)
            ascii_lines += 1
        else:
            texts.append(b.decode('gb18030', 'replace'))
            err_lines += 1
    detail = {
        'strategy': '逐行：UTF-8 strict（须含汉字）优先，否则 GB18030 strict；仍失败才 replace 并计数',
        'gb18030_body_lines': gb_lines,
        'utf8_mixed_cjk_lines': utf8_mixed_lines,
        'ascii_only_lines': ascii_lines,
        'decode_error_lines': err_lines,
        'total_lines': len(texts),
    }
    return texts, detail


def decode_utf8_file(path):
    raw = open(path, 'rb').read()
    text = raw.decode('utf-8')
    lines = text.split('\n')
    if lines and lines[-1] == '':
        lines = lines[:-1]
    texts = [ln.rstrip('\r') for ln in lines]
    detail = {
        'strategy': '整文件 UTF-8 strict 解码（docx 转换产物，本身就是 UTF-8）',
        'utf8_mixed_cjk_lines': sum(1 for t in texts if t.strip() and re.search(r'[\u4e00-\u9fff]', t)),
        'ascii_only_lines': sum(1 for t in texts if t.strip() and not re.search(r'[\u4e00-\u9fff]', t)),
        'mojibake_lines': sum(1 for t in texts if re.search(r'[\ue000-\uf8ff\ufffd]', t)),
        'total_lines': len(texts),
    }
    return texts, detail


def scan_rule(texts, pattern):
    """按规则逐行扫描，返回命中行信息列表。"""
    hits = []
    for i, t in enumerate(texts):
        if t and pattern.match(t):
            raw = t.strip()
            hits.append({'line': i + 1, 'raw': raw, 'name': clean_title(raw)})
    return hits


def dedupe_hits(hits):
    """连续重复标题去重（清洗后标题与上一保留标题相同则合并）。"""
    out = []
    for h in hits:
        if out and h['name'] == out[-1]['name']:
            out[-1]['dup_lines'].append(h['line'])
            continue
        h['dup_lines'] = []
        out.append(h)
    return out


def collapsed_stats(deduped):
    """列出被连续去重折叠掉的标题（同名相邻出现）。"""
    out = []
    for h in deduped:
        if h['dup_lines']:
            out.append({'name': h['name'], 'kept_line': h['line'], 'collapsed_lines': h['dup_lines']})
    return out


def numbering_stats(names):
    """统计章节序号重置/重复/缺号（用于提示“章号不单调/有缺章”的风险）。"""
    nums = [title_number(n) for n in names]
    valid = [(i, v) for i, v in enumerate(nums) if v is not None]
    resets, gaps = [], []
    for (i0, a), (i1, b) in zip(valid, valid[1:]):
        if b <= a:
            resets.append({'prev': a, 'cur': b, 'name': names[i1][:60]})
        elif b > a + 1:
            gaps.append({'prev': a, 'cur': b, 'missing': b - a - 1, 'name': names[i1][:60]})
    return {
        'max_number': max((v for _i, v in valid), default=None),
        'parsed_count': len(valid),
        'seq_reset_or_dup_count': len(resets),
        'seq_reset_examples': resets[:10],
        'gap_count': len(gaps),
        'missing_numbers_total': sum(g['missing'] for g in gaps),
        'gap_examples': gaps[:10],
    }


def duplicate_stats(deduped):
    """非连续重复标题统计（同一清洗后标题出现多次）。"""
    counter = Counter(h['name'] for h in deduped)
    dups = [(name, cnt, [h['line'] for h in deduped if h['name'] == name])
            for name, cnt in counter.items() if cnt > 1]
    dups.sort(key=lambda x: (-x[1], x[0]))
    return {
        'duplicate_title_count': len(dups),
        'extra_occurrences': sum(cnt for _n, cnt, _l in dups) - len(dups),
        'top': [{'name': n, 'count': c, 'lines': ls[:6]} for n, c, ls in dups[:10]],
    }


def classify_noise_title(title, prev_num, next_num, prev_title_norm=None, prev_was_chapter=False):
    """判定 R1 标题是否为‘疑似非章节噪声’（作者话/公告）。返回 (is_noise, reason)。"""
    norm = re.sub(r'\s+', '', title)
    if CHAP_MARK.search(norm) or DIG_ONLY.match(norm) or SPECIAL_PREFIX.match(norm):
        return False, '含章号/特殊章节前缀'
    if (prev_was_chapter and prev_title_norm and re.match(r'^番外', prev_title_norm)
            and re.match(r'^[\u4e00-\u9fff（）()一二三四五六七八九十0-9]{1,20}$', norm)):
        return False, '承接上一“番外”标题（番外续篇）'
    if NOISE_KW_RE.search(norm):
        return True, '命中作者话关键词'
    if prev_num is not None and next_num is not None:
        if next_num == prev_num + 1:
            return True, '夹在连续章号之间（无缺章，判定为插入的作者话）'
        if next_num == prev_num + 2:
            return False, '填补缺失章号（判定为漏写章号的正文标题）'
    return False, '缺省按章节处理（人工复核项）'


def compute_avg_chars(texts, chapters, title_lines):
    """估算每章平均字数。"""
    total = 0
    for i, t in enumerate(texts):
        if i + 1 in title_lines:
            continue
        total += len(re.sub(r'\s', '', t))
    return (total // chapters) if chapters else 0, total


def scan_noise(texts):
    """统计各类噪声行与占比。"""
    counts = {name: 0 for name, _ in NOISE_PATTERNS}
    union = watermark_union = nonempty = 0
    noise_chars = total_chars = 0
    samples = {}
    for t in texts:
        s = t.strip()
        if not s:
            continue
        nonempty += 1
        nchars = len(re.sub(r'\s', '', t))
        total_chars += nchars
        hit = wm = False
        for name, pat in NOISE_PATTERNS:
            if name == '===标题行':
                if R1.match(s):
                    counts[name] += 1
                    hit = True
                    samples.setdefault(name, s[:80])
                continue
            if pat.search(s):
                counts[name] += 1
                hit = wm = True
                samples.setdefault(name, s[:80])
        if hit:
            union += 1
            noise_chars += nchars
        if wm:
            watermark_union += 1
    return {
        'nonempty_lines': nonempty,
        'counts': counts,
        'union_lines': union,
        'union_ratio': round(union * 100.0 / nonempty, 2) if nonempty else 0.0,
        'union_chars': noise_chars,
        'union_chars_ratio': round(noise_chars * 100.0 / total_chars, 2) if total_chars else 0.0,
        'watermark_lines_excluding_titles': watermark_union,
        'watermark_ratio_excluding_titles': round(watermark_union * 100.0 / nonempty, 2) if nonempty else 0.0,
        'samples': samples,
    }


def analyze_file(path, display_name, source_kind):
    raw = open(path, 'rb').read()
    texts, enc_detail = (decode_utf8_file(path) if source_kind == 'docx' else decode_lines(raw))
    nonempty = sum(1 for t in texts if t.strip())
    total_chars = sum(len(re.sub(r'\s', '', t)) for t in texts)
    enc_detail['nonempty_lines'] = nonempty
    result = {
        'name': display_name,
        'source': source_kind,
        'path': path,
        'file_size': len(raw),
        'sha256': hashlib.sha256(raw).hexdigest(),
        'line_count': len(texts),
        'nonempty_lines': nonempty,
        'chars': {'total': len(''.join(texts)), 'non_ws': total_chars},
        'encoding_detail': enc_detail,
        'rules': {},
    }
    deduped_map = {}
    for key, pattern, text in RULES:
        hits = scan_rule(texts, pattern)
        deduped = dedupe_hits(hits)
        deduped_map[key] = deduped
        title_lines = set(h['line'] for h in hits)
        avg, body_chars = compute_avg_chars(texts, len(deduped), title_lines)
        result['rules'][key] = {
            'pattern': text,
            'hits': len(hits),
            'hits_after_dedupe': len(deduped),
            'dup_collapsed': len(hits) - len(deduped),
            'first5': [h['name'] for h in deduped[:5]],
            'last5': [h['name'] for h in deduped[-5:]],
            'last_hit_line': deduped[-1]['line'] if deduped else 0,
            'avg_chars_per_chapter': avg,
            'body_chars': body_chars,
            'coverage_percent': round(deduped[-1]['line'] * 100.0 / len(texts), 2) if deduped else 0.0,
            'usable': False,
            'reason': '',
        }
        if key == 'R1':
            result['rules'][key]['collapsed_titles'] = collapsed_stats(deduped)
            result['rules'][key]['numbering'] = numbering_stats([h['name'] for h in deduped])
    # ---- R1 标题噪声分类（作者话/公告，只影响“有效章节数”参考值） ----
    deduped = deduped_map['R1']
    r1 = result['rules']['R1']
    noise_titles, unknown_titles, malformed_titles = [], [], []
    if source_kind == 'docx':
        # docx 的 === 标题行是乱码，无法解析章号/关键词，跳过噪声分类
        r1['title_encoding_broken'] = True
        r1['noise_titles'] = []
        r1['noise_title_count'] = 0
        r1['unknown_titles'] = []
        r1['unknown_title_count'] = 0
        r1['malformed_titles'] = []
        r1['duplicates'] = duplicate_stats(deduped)
        last_real = r1['last5'][-1] if r1['last5'] else ''
    else:
        r1['title_encoding_broken'] = False
        nums = [title_number(h['name']) for h in deduped]
        prev_was_chapter = False
        prev_title_norm = ''
        for idx, h in enumerate(deduped):
            prev_num = next((nums[j] for j in range(idx - 1, -1, -1) if nums[j] is not None), None)
            next_num = next((nums[j] for j in range(idx + 1, len(nums)) if nums[j] is not None), None)
            norm = re.sub(r'\s+', '', h['name'])
            is_noise, why = classify_noise_title(h['name'], prev_num, next_num,
                                                 prev_title_norm, prev_was_chapter)
            if is_noise:
                noise_titles.append({'line': h['line'], 'name': h['name'], 'reason': why})
                prev_was_chapter = False
            else:
                if why.startswith('缺省'):
                    unknown_titles.append({'line': h['line'], 'name': h['name']})
                if not (CHAP_MARK.search(norm) or DIG_ONLY.match(norm) or SPECIAL_PREFIX.match(norm)):
                    malformed_titles.append({'line': h['line'], 'name': h['name'],
                                             'prev_num': prev_num, 'next_num': next_num, 'reason': why})
                prev_was_chapter = True
            prev_title_norm = norm
        r1['noise_titles'] = noise_titles
        r1['noise_title_count'] = len(noise_titles)
        r1['unknown_titles'] = unknown_titles
        r1['unknown_title_count'] = len(unknown_titles)
        r1['malformed_titles'] = malformed_titles
        r1['duplicates'] = duplicate_stats(deduped)
        noise_lines = set(item['line'] for item in noise_titles)
        real = [h['name'] for h in deduped if h['line'] not in noise_lines]
        last_real = real[-1] if real else ''
    r1['unique_title_count'] = len(set(h['name'] for h in deduped))
    # ---- 可用性判定（R2/R3 还要求章节数与 R1 同量级，防止把正文水印当章节） ----
    r1_chapters = r1['hits_after_dedupe']
    for key, _p, _t in RULES:
        r = result['rules'][key]
        if key == 'R1':
            ok = r['hits_after_dedupe'] >= 20 and r['avg_chars_per_chapter'] >= 300
            r['usable'] = ok
            r['reason'] = ('覆盖全文（覆盖率 %.2f%%），标题格式统一，可作为主规则'
                           % r['coverage_percent']) if ok else '命中过少或分章不可信'
            continue
        ratio = round(r['hits_after_dedupe'] * 100.0 / r1_chapters, 2) if r1_chapters else 0.0
        r['chapter_ratio_vs_r1_percent'] = ratio
        ok = (r['hits_after_dedupe'] >= 20 and r['coverage_percent'] >= 95.0
              and r['avg_chars_per_chapter'] >= 300 and ratio >= 80.0)
        r['usable'] = ok
        if r['hits_after_dedupe'] == 0:
            r['reason'] = '全文 0 命中'
        elif r['hits_after_dedupe'] < 20:
            r['reason'] = '仅 %d 处命中（且均为正文水印/重复标题），不足以分章' % r['hits_after_dedupe']
        elif ratio < 80.0:
            r['reason'] = ('只命中 %d 个章节标题，仅相当于 R1 章节数的 %.1f%%；'
                           '这些命中是正文内重复标题/水印，不是章首标题'
                           % (r['hits_after_dedupe'], ratio))
        elif r['coverage_percent'] < 95.0:
            r['reason'] = ('仅覆盖到文件 %.2f%% 处（末次命中在第 %d 行），后半部分无法分章'
                           % (r['coverage_percent'], r['last_hit_line']))
        else:
            r['reason'] = '会漏掉 === 标题造成大量伪章节'
    # ---- 推荐结论 ----
    rec = {
        'rule': 'R1',
        'expected_chapters': r1['hits_after_dedupe'],
        'expected_chapters_excluding_noise_titles': r1['hits_after_dedupe'] - r1['noise_title_count'],
        'unique_chapter_titles': r1['unique_title_count'],
        'duplicate_title_extra_occurrences': r1['duplicates']['extra_occurrences'],
        'first_chapter': r1['first5'][0] if r1['first5'] else '',
        'last_chapter': r1['last5'][-1] if r1['last5'] else '',
        'last_chapter_excluding_noise_titles': last_real,
        'note': '',
    }
    if source_kind == 'docx':
        rec['note'] = ('docx 段落文本中的 === 标题行是乱码（含 PUA/替换符，不可逆），R1 仍可正确分章；'
                       '章节名不可用于名称断言，名称基准请用同名 txt 文件对应条目')
    else:
        rec['note'] = ('R1（=== 标题）覆盖全文；R2/R3 不可用。标题行是 UTF-8 字节混在 GB18030 文件中，'
                       '需逐行 UTF-8 解码才能得到正确章节名')
    result['recommendation'] = rec
    result['noise'] = scan_noise(texts)
    return result


def build_docx_conversion(docx_path, conv_path, docx_entry):
    """构造 docx 转换报告 + 与同名 txt 素材的逐行对比。"""
    meta = {}
    try:
        from docx import Document
        doc = Document(docx_path)
        paras = [p.text for p in doc.paragraphs]
        meta = {
            'paragraphs': len(paras),
            'nonempty_paragraphs': sum(1 for t in paras if t.strip()),
            'tables': len(doc.tables),
            'sections': len(doc.sections),
            'paragraphs_containing_free_read': sum(1 for t in paras if '免费阅读' in t),
            'inner_soft_breaks': sum(t.count('\n') for t in paras),
            'mojibake_paragraphs': sum(1 for t in paras if re.search(r'[\ue000-\uf8ff\ufffd]', t)),
        }
    except Exception as exc:  # pragma: no cover
        meta = {'error': repr(exc)}
    conv_texts, _conv_enc = decode_utf8_file(conv_path)
    conv_bytes = os.path.getsize(conv_path)
    src_txt = os.path.join(MAT, '《深海余烬TXT下载地址列表》.txt')
    txt_texts, _ = decode_lines(open(src_txt, 'rb').read())
    n = min(len(conv_texts), len(txt_texts))
    diff_lines, diff_other_samples = [], []
    diff_total = diff_eq = diff_source = diff_other = 0
    for i in range(n):
        a, b = conv_texts[i], txt_texts[i]
        if a == b:
            continue
        diff_total += 1
        if R1.match(a.strip()):
            diff_eq += 1
        elif '本文件来自' in b or '本书来自' in b:
            diff_source += 1
        else:
            diff_other += 1
            if len(diff_other_samples) < 5:
                diff_other_samples.append({'line': i + 1, 'converted': a[:70], 'source_txt': b[:70]})
        if len(diff_lines) < 5:
            diff_lines.append({'line': i + 1, 'converted': a[:70], 'source_txt': b[:70]})
    r1 = docx_entry['rules']['R1']
    r2 = docx_entry['rules']['R2']
    r3 = docx_entry['rules']['R3']
    return {
        'source_docx': docx_path,
        'output_txt': conv_path,
        'output_size_bytes': conv_bytes,
        'output_encoding': 'UTF-8（无 BOM），段落间以 \\n 分隔',
        'docx': meta,
        'converted': {
            'lines': len(conv_texts),
            'nonempty_lines': sum(1 for t in conv_texts if t.strip()),
            'chars': docx_entry['chars'],
        },
        'chapter_recognition': {
            'rule': 'R1',
            'hits': r1['hits'],
            'chapters_after_dedupe': r1['hits_after_dedupe'],
            'first5': r1['first5'],
            'last5': r1['last5'],
            'avg_chars_per_chapter': r1['avg_chars_per_chapter'],
            'r2_hits': r2['hits'],
            'r2_chapters_after_dedupe': r2['hits_after_dedupe'],
            'r3_hits': r3['hits'],
            'note': ('R1 仍能按 === 行正确分章（721 章，与同名 txt 一致）；'
                     'R2 的 108 处命中是 48 条“免费阅读：，！”等水印重复行 + 末章正文标题，'
                     '连续去重后只剩 56 个，不可用；标题文本本身乱码，不能做章节名断言'),
        },
        'compare_with_source_txt': {
            'source_txt': src_txt,
            'comparable_lines': n,
            'diff_line_count': diff_total,
            'diff_eq_title_line_count': diff_eq,
            'diff_source_line_count': diff_source,
            'diff_other_line_count': diff_other,
            'diff_other_samples': diff_other_samples,
            'samples': diff_lines,
            'note': ('转换文本与同名 txt 的行结构完全一致；差异仅出现在原 txt 中“UTF-8 字节混入 GB18030”的'
                     '标题/来源行——docx 内部这些字符已损坏为乱码，故转换后无法还原'),
        },
    }


def write_detail(data):
    """把关键数据写成人类可读明细（供撰写 md）。"""
    with open(OUT_DETAIL, 'w', encoding='utf-8') as fh:
        fh.write('章节基准明细（自动生成）\n')
        fh.write('=' * 100 + '\n')
        for f in data['files']:
            fh.write('\n### %s  [%s]  %.2f MB  行=%d 非空=%d  非空白字符=%d\n'
                     % (f['name'], f['source'], f['file_size'] / 1048576, f['line_count'],
                        f['nonempty_lines'], f['chars']['non_ws']))
            fh.write('  sha256=%s\n' % f['sha256'])
            fh.write('  编码明细: %r\n' % f['encoding_detail'])
            for k in ('R1', 'R2', 'R3'):
                r = f['rules'][k]
                fh.write('  [%s] 命中=%d 去重=%d 折叠=%d 均字数=%d 覆盖=%.2f%% 可用=%s\n'
                         % (k, r['hits'], r['hits_after_dedupe'], r['dup_collapsed'],
                            r['avg_chars_per_chapter'], r['coverage_percent'], r['usable']))
                fh.write('       首5=%r\n' % r['first5'])
                fh.write('       尾5=%r\n' % r['last5'])
                fh.write('       理由=%s\n' % r['reason'])
                if k == 'R1':
                    fh.write('       噪声标题=%d 未知=%d 异形标题=%d 唯一标题=%d 乱码标题=%s\n'
                             % (r['noise_title_count'], r['unknown_title_count'],
                                len(r['malformed_titles']), r['unique_title_count'],
                                r['title_encoding_broken']))
                    if r['collapsed_titles']:
                        fh.write('       连续去重折叠: %r\n' % r['collapsed_titles'])
                    fh.write('       章号序列: %r\n' % r['numbering'])
                    for item in r['noise_titles']:
                        fh.write('         NOISE L%-7d %r  <- %s\n' % (item['line'], item['name'], item['reason']))
                    for item in r['malformed_titles']:
                        fh.write('         MALFORMED L%-7d %r prev=%r next=%r <- %s\n'
                                 % (item['line'], item['name'], item['prev_num'],
                                    item['next_num'], item['reason']))
                    for item in r['unknown_titles']:
                        fh.write('         UNKNOWN L%-7d %r\n' % (item['line'], item['name']))
                    fh.write('       非连续重复标题: %r\n' % r['duplicates'])
            n = f['noise']
            fh.write('  噪声: nonempty=%d union=%d(%.2f%%) 水印(不含标题)=%d(%.2f%%) chars=%.2f%%\n'
                     % (n['nonempty_lines'], n['union_lines'], n['union_ratio'],
                        n['watermark_lines_excluding_titles'], n['watermark_ratio_excluding_titles'],
                        n['union_chars_ratio']))
            fh.write('       分类=%r\n' % n['counts'])
            fh.write('       样本=%r\n' % n['samples'])
            fh.write('  推荐=%r\n' % f['recommendation'])
        fh.write('\n### docx 转换报告\n')
        dc = data['docx_conversion']
        for k in ('source_docx', 'output_txt', 'output_size_bytes', 'output_encoding',
                  'docx', 'converted', 'chapter_recognition', 'compare_with_source_txt'):
            fh.write('  %s=%r\n' % (k, dc.get(k)))
        fh.write('\n总表:\n')
        for s in data['summary']:
            fh.write('  %-40s %-3s 预期=%-5d 有效=%-5d 唯一标题=%-5d 噪声标题=%-3d 均字=%d 末章=%r\n'
                     % (s['file'], s['rule'], s['expected_chapters'],
                        s['expected_chapters_excluding_noise_titles'], s['unique_chapter_titles'],
                        s['noise_titles'], s['avg_chars_per_chapter'],
                        s['last_chapter_excluding_noise_titles']))


def main():
    files = []
    txt_names = [n for n in sorted(os.listdir(MAT)) if n.lower().endswith('.txt')]
    for name in txt_names:
        files.append(analyze_file(os.path.join(MAT, name), name, 'txt'))
    files.append(analyze_file(CONV, '深海余烬-由docx转换.txt', 'docx'))
    summary = []
    for f in files:
        r = f['recommendation']
        r1 = f['rules']['R1']
        summary.append({
            'file': f['name'],
            'source': f['source'],
            'rule': r['rule'],
            'expected_chapters': r['expected_chapters'],
            'expected_chapters_excluding_noise_titles': r['expected_chapters_excluding_noise_titles'],
            'unique_chapter_titles': r['unique_chapter_titles'],
            'noise_titles': r1['noise_title_count'],
            'collapsed_duplicate_titles': r1['dup_collapsed'],
            'first_chapter': r['first_chapter'],
            'last_chapter': r['last_chapter'],
            'last_chapter_excluding_noise_titles': r['last_chapter_excluding_noise_titles'],
            'avg_chars_per_chapter': r1['avg_chars_per_chapter'],
            'chars_non_ws': f['chars']['non_ws'],
            'nonempty_lines': f['nonempty_lines'],
            'file_size': f['file_size'],
            'sha256': f['sha256'],
        })
    docx_conversion = build_docx_conversion(SRC_DOCX, CONV, files[-1])
    data = {
        'generated_at': datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S+08:00'),
        'generator': '工具/build_chapter_baseline.py',
        'method': {
            'encoding': ('GB18030 正文 + UTF-8 标题/水印行混合编码；逐行先 UTF-8 strict 再 GB18030 strict，'
                         '仍失败才 replace 并计数'),
            'rules': {k: t for k, _p, t in RULES},
            'cleaning': [
                '去标题首尾空白',
                "去标题首尾 '='",
                '去掉行首《书名》≤30 字前缀（仅当《…》后紧跟章号/序/番外等才去掉，避免正文引用误伤）',
                '在“正在手打中”或“免费阅读”处截断，丢弃其后内容',
                '连续空白归一为单个半角空格',
            ],
            'dedupe': '清洗后标题与上一保留标题完全相同（连续重复）则合并为一章（非连续重复不合并）',
            'chapter_boundary': '本章正文 = 标题行下一行起，至下一章标题行前止；末章到文件末尾',
            'avg_chars': '每章平均字数 = 全文去空白字符数（扣除 R1 标题行）/ 去重后章节数（估算口径）',
            'noise_title_classification': ('R1 标题中“疑似非章节噪声”= 作者话/公告类标题，'
                                           '按关键词 + 前后章号差值辅助判定，仅作为参考值，'
                                           '应用实际产出章节数不含此项过滤'),
        },
        'summary': summary,
        'files': files,
        'docx_conversion': docx_conversion,
    }
    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    write_detail(data)
    print('OK ->', OUT_JSON)
    print('OK ->', OUT_DETAIL)


if __name__ == '__main__':
    main()
