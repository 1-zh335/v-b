"""通用 HTTP 探测 + MP3 帧解析工具（供各测试脚本复用，仅标准库）。"""
import hashlib
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

APP_UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0_1) AppleWebKit/537.36 "
          "(KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36")
BROWSER_UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
              "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def request(method, url, body=None, headers=None, timeout=12, follow=True,
            content_type="application/x-www-form-urlencoded"):
    """发一个请求，返回 status/content-type/bytes/耗时；不抛异常，错误也返回记录。

    content_type=None 表示不发送 Content-Type（复刻 app 的 POST：MediaType 为空）。
    """
    hdrs = {"User-Agent": APP_UA}
    if headers:
        hdrs.update(headers)
    data = None
    if body is not None:
        data = body.encode("utf-8") if isinstance(body, str) else body
        if content_type:
            hdrs.setdefault("Content-Type", content_type)
    req = urllib.request.Request(url, data=data, headers=hdrs, method=method)
    opener = urllib.request.build_opener() if follow else urllib.request.build_opener(NoRedirect)
    t0 = time.time()
    try:
        with opener.open(req, timeout=timeout) as r:
            payload = r.read()
            return {
                "ok": True, "status": r.status, "final_url": r.geturl(),
                "content_type": r.headers.get("Content-Type", ""),
                "len": len(payload), "bytes": payload, "ms": int((time.time() - t0) * 1000),
            }
    except urllib.error.HTTPError as e:
        payload = e.read()
        return {
            "ok": False, "status": e.code, "final_url": e.geturl(),
            "content_type": e.headers.get("Content-Type", "") if e.headers else "",
            "len": len(payload), "bytes": payload, "ms": int((time.time() - t0) * 1000),
            "err": "HTTPError",
        }
    except Exception as e:  # 超时/DNS/连接错误
        return {
            "ok": False, "status": None, "final_url": url, "content_type": "",
            "len": 0, "bytes": b"", "ms": int((time.time() - t0) * 1000),
            "err": "%s: %s" % (type(e).__name__, e),
        }


def sniff(data):
    """判断音频容器类型（MP3/NONE/WAV/AAC/OGG/文本）。"""
    if not data:
        return "EMPTY"
    head = data[:16]
    if head[:3] == b"ID3":
        return "MP3-ID3"
    if len(head) >= 2 and head[0] == 0xFF and (head[1] & 0xE0) == 0xE0:
        return "MP3-FRAME"
    if head[:4] == b"RIFF":
        return "WAV"
    if head[:3] == b"\x00\x00\x00" or _aac_ok(head):
        return "AAC?"
    if head[:4] == b"OggS":
        return "OGG"
    if data[:1] in (b"<", b"{", b"[") or data.lstrip()[:1] in (b"<", b"{", b"["):
        return "TEXT"
    return "UNKNOWN"


def _aac_ok(head):
    return len(head) > 1 and head[0] == 0xFF and (head[1] & 0xF6) == 0xF0


MPEG_BITRATES = {
    (1, 3): [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320],
    (2, 3): [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
}
MPEG_RATES = {1: [44100, 48000, 32000], 2: [22050, 24000, 16000], 25: [11025, 12000, 8000]}


def mp3_info(data):
    """粗略解析 MPEG 帧数/时长；返回 dict，无法解析返回 found=False。"""
    if data[:3] == b"ID3":
        size = 0
        if len(data) >= 10:
            s = data[6:10]
            size = (s[0] << 21) | (s[1] << 14) | (s[2] << 7) | s[3]
            off = 10 + size
        else:
            off = 0
    else:
        off = 0
    n, dur, sample_rate, bitrate, i = 0, 0.0, 0, 0, off
    first = None
    while i + 4 <= len(data):
        b0, b1, b2, b3 = data[i], data[i + 1], data[i + 2], data[i + 3]
        if b0 != 0xFF or (b1 & 0xE0) != 0xE0:
            i += 1
            continue
        version_bits = (b1 >> 3) & 0x03   # 0=MPEG2.5,1=保留,2=MPEG2,3=MPEG1
        layer_bits = (b1 >> 1) & 0x03     # 1=Layer3
        if version_bits == 1 or layer_bits != 1:
            i += 1
            continue
        ver = {0: 25, 2: 2, 3: 1}[version_bits]
        br_idx = (b2 >> 4) & 0x0F
        sr_idx = (b2 >> 2) & 0x03
        pad = (b2 >> 1) & 0x01
        if br_idx == 0 or br_idx == 15 or sr_idx == 3:
            i += 1
            continue
        rate = MPEG_RATES[ver][sr_idx]
        br = MPEG_BITRATES[(1 if ver == 1 else 2, 3)][br_idx] * 1000
        samples_per_frame = 1152 if ver == 1 else 576
        frame_len = int((samples_per_frame / 8 * br) / rate) + pad
        if frame_len < 20:
            i += 1
            continue
        if first is None:
            first = (ver, rate, br)
            sample_rate, bitrate = rate, br
        n += 1
        dur += samples_per_frame / float(rate)
        i += frame_len
    return {"found": n > 0, "frames": n, "duration": round(dur, 2),
            "sample_rate": sample_rate, "bitrate": bitrate}


def save(dirpath, name, data):
    os.makedirs(dirpath, exist_ok=True)
    ext = ".mp3" if sniff(data).startswith("MP3") else ".bin"
    path = os.path.join(dirpath, name + ext)
    with open(path, "wb") as f:
        f.write(data)
    return path


def summarize(res, save_dir=None, name=None):
    info = {
        "status": res.get("status"),
        "ok": res.get("ok"),
        "content_type": res.get("content_type"),
        "len": res.get("len"),
        "ms": res.get("ms"),
        "head_hex": res["bytes"][:16].hex(" ").upper() if res.get("bytes") else "",
        "sniff": sniff(res.get("bytes", b"")),
        "err": res.get("err", ""),
        "md5": hashlib.md5(res["bytes"]).hexdigest() if res.get("bytes") else "",
        "final_url": res.get("final_url", ""),
    }
    mp3 = mp3_info(res.get("bytes", b""))
    info.update({"mp3_frames": mp3["frames"], "mp3_duration": mp3["duration"]})
    if save_dir and name:
        info["saved"] = save(save_dir, name, res.get("bytes", b"")) if res.get("bytes") else ""
    if res.get("bytes") and sniff(res["bytes"]) == "TEXT":
        try:
            info["preview"] = res["bytes"][:220].decode("utf-8", "replace")
        except Exception:
            info["preview"] = ""
    return info
