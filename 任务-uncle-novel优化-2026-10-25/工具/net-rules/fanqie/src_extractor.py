# -*- coding: utf-8 -*-
"""单章正文抽取：导航到 reader 页 → 等渲染 → 过验证 → 取正文 → 解密。

GATE 结论（见 PROGRESS.md）：
  正文 = PUA 密文，charset.json 还原率 100%，DOM innerText 即密文。
  干净选择器 = div.muye-reader-content.noselect（纯正文，不含标题/字数元信息）。
"""
import re
from typing import Optional, Tuple
import browser as B
from config import FANQIE_URL
from decoder import decode_best

# 阶段1 抽取选择器：干净单节点。降级候选仅在主选择器失效时兜底。
CONTENT_SELECTOR = 'div.muye-reader-content.noselect'
_FALLBACK_SELECTORS = [
    'div.muye-reader-content',
    '.muye-reader-content',
]

# 正文渲染判定：至少这么多字才算抓到，低于则视为未渲染完/异常。
_MIN_CONTENT_CHARS = 50
# 等 JS 渲染出正文节点的超时(ms)。
_RENDER_TIMEOUT_MS = 15000


class ChapterExtractError(RuntimeError):
    """单章抽取失败（未渲染出正文、疑似风控等）。"""


def reader_url(chapter_id: str) -> str:
    return f'{FANQIE_URL}/reader/{chapter_id}'


def _raw_content(page) -> Optional[str]:
    """按主选择器 + 降级候选取原始(密文)正文，段落用换行拼接。"""
    for sel in (CONTENT_SELECTOR, *_FALLBACK_SELECTORS):
        try:
            text = page.eval_on_selector(
                sel,
                '''el => {
                    const ps = el.querySelectorAll('p');
                    if (ps.length) {
                        return Array.from(ps)
                            .map(p => p.innerText.trim())
                            .filter(Boolean).join('\\n');
                    }
                    return el.innerText.trim();
                }''')
        except Exception:  # noqa: BLE001 选择器未命中，试下一个
            continue
        if text and len(text) >= _MIN_CONTENT_CHARS:
            return text
    return None


def chapter_id_from_url(url: str) -> Optional[str]:
    """从 reader URL 里解析 chapter_id。"""
    m = re.search(r'/reader/(\d+)', url or '')
    return m.group(1) if m else None


def novel_id_from_page(page) -> Optional[str]:
    """从 reader 页 HTML 里提取所属小说 id（book_id）。用于 --attach 接管模式。"""
    try:
        html = page.content()
    except Exception:  # noqa: BLE001
        return None
    m = re.search(r'book_?[iI]d["\'\s:=]+(\d{6,})', html)
    return m.group(1) if m else None


def _read_rendered(page, tag: str) -> str:
    """公共逻辑：等正文渲染 → 过验证 → 取原始密文 → 解密。tag 仅用于报错。"""
    try:
        page.wait_for_selector(CONTENT_SELECTOR, timeout=_RENDER_TIMEOUT_MS)
    except Exception:  # noqa: BLE001 未出现，先查是否被风控拦截
        pass

    # 命中验证码则轮询等人工过码（无人值守，不阻塞 stdin），过完再取。
    B.wait_verify_cleared(page)

    raw = _raw_content(page)
    if raw is None:
        # 可能验证码在渲染后才弹，再给一次机会。
        B.wait_verify_cleared(page)
        raw = _raw_content(page)
    if raw is None:
        raise ChapterExtractError(f'{tag} 未抽到正文（疑似风控/结构变更）。')

    decoded, _mode, _residual = decode_best(raw)
    return decoded


def extract_chapter(page, chapter_id: str) -> str:
    """整页导航到指定章节，返回解密后的正文。失败抛 ChapterExtractError。

    用于范围首章定位或断点续传（章节不连续）。连续抓取用 next_chapter 更快。
    """
    page.goto(reader_url(chapter_id), wait_until='domcontentloaded')
    return _read_rendered(page, f'章节 {chapter_id}')


def next_chapter(page) -> Tuple[str, str]:
    """点「下一章」在同一标签页内 SPA 切章（比整页导航快得多）。

    返回 (新 chapter_id, 解密正文)。已是最后一章 / 无下一章按钮时抛
    ChapterExtractError。
    """
    before_url = page.url
    before_head = ''
    try:
        before_head = page.eval_on_selector(
            CONTENT_SELECTOR, 'el => el.innerText.slice(0, 40)')
    except Exception:  # noqa: BLE001 当前页可能无正文，忽略
        pass

    try:
        page.click('button:has-text("下一章")', timeout=5000)
    except Exception as e:  # noqa: BLE001
        raise ChapterExtractError(f'找不到「下一章」按钮（可能是最后一章）：{e}')

    # 等 SPA 路由把 URL 换掉，确认切章生效。
    try:
        page.wait_for_function(
            'u => location.href !== u', arg=before_url, timeout=10000)
    except Exception as e:  # noqa: BLE001
        raise ChapterExtractError(f'点下一章后 URL 未变化（可能是最后一章）：{e}')

    # 等正文内容真正换掉（避免读到上一章残留）。
    if before_head:
        try:
            page.wait_for_function(
                '''t => { const e = document.querySelector(
                    "div.muye-reader-content.noselect");
                    return e && e.innerText.slice(0, 40) !== t; }''',
                arg=before_head, timeout=15000)
        except Exception:  # noqa: BLE001 内容或许恰好相同，交给下游判定
            pass

    new_id = chapter_id_from_url(page.url)
    if not new_id:
        raise ChapterExtractError(f'切章后无法解析 chapter_id：{page.url}')
    return new_id, _read_rendered(page, f'章节 {new_id}')
