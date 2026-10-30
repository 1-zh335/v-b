# -*- coding: utf-8 -*-
"""正文解密：把番茄私用区(PUA)码位按 charset 映射回真实汉字。

移植自旧项目 _decode_content，并加入 charset 健康自检：
若解密后仍残留大量 PUA 码位，说明字体映射表已过期，需重建。
"""
import json
from config import CHARSET_PATH, CODE

with open(CHARSET_PATH, 'r', encoding='UTF-8') as _f:
    CHARSET = json.load(_f)


def decode_content(content: str, mode: int = 0) -> str:
    """按指定 mode 的 charset 映射解密。"""
    result = []
    for char in content:
        uni = ord(char)
        if CODE[mode][0] <= uni <= CODE[mode][1]:
            bias = uni - CODE[mode][0]
            if 0 <= bias < len(CHARSET[mode]) and CHARSET[mode][bias] != '?':
                result.append(CHARSET[mode][bias])
            else:
                result.append(char)
        else:
            result.append(char)
    return ''.join(result)


def _count_pua(text: str) -> int:
    """统计文本里落在番茄 PUA 范围内的字符数（即未解密的密文字符）。"""
    lo = min(CODE[0][0], CODE[1][0])
    hi = max(CODE[0][1], CODE[1][1])
    return sum(1 for ch in text if lo <= ord(ch) <= hi)


def decode_best(content: str) -> tuple:
    """两套 mode 都试，返回(解密文本, mode, 残留PUA数)。选残留最少的。"""
    candidates = []
    for mode in (0, 1):
        decoded = decode_content(content, mode)
        candidates.append((decoded, mode, _count_pua(decoded)))
    return min(candidates, key=lambda x: x[2])


def charset_health(raw: str) -> dict:
    """对一段原始密文做健康自检，判断 charset 是否还准。"""
    raw_pua = _count_pua(raw)
    decoded, mode, left = decode_best(raw)
    recovered = raw_pua - left
    rate = (recovered / raw_pua) if raw_pua else 1.0
    return {
        'raw_pua': raw_pua,
        'best_mode': mode,
        'residual_pua': left,
        'recover_rate': round(rate, 4),
        'healthy': raw_pua > 0 and rate >= 0.95,
        'no_pua': raw_pua == 0,
        'sample': decoded[:120],
    }

