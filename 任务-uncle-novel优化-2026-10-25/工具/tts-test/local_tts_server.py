"""本地 TTS 服务（edge-tts 版，可选方案）。

为什么需要它：
Uncle小说 5.0.44 的 TTSConfig 会把 {{text}} 二次百分号编码，服务端必须解码两次才能拿到原文。
百度/思必驰恰好能容忍（实测），但限流/长度上限明显；本地服务可以：
  1) 用 unquote(unquote(text)) 解出 app 的二次编码原文；
  2) 调 edge-tts（微软在线，免费无 key）或 Windows SAPI（离线）合成 MP3；
  3) 直接返回 audio/mpeg 字节，供 app 的 Http.bytes + JavaFX MediaPlayer 播放。

用法:
  .venv\\Scripts\\python.exe local_tts_server.py [--port 18523] [--backend edge|sapi] [--voice zh-CN-XiaoxiaoNeural]
接口:
  GET /tts?text=<app二次编码文本>   -> audio/mpeg
  GET /health                        -> ok
"""
import argparse
import asyncio
import json
import os
import subprocess
import sys
import tempfile
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BACKEND = "edge"
VOICE = "zh-CN-XiaoxiaoNeural"
SAPI_VOICE = "Microsoft Huihui Desktop"
LOG_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "local_tts_requests.jsonl")


def decode_app_text(raw):
    """app 发来的是二次百分号编码，解码两次得到原文（最多两次，避免误伤正常 GET）。"""
    once = urllib.parse.unquote(raw)
    twice = urllib.parse.unquote(once)
    # app 编码后必然是一串 %XX；若二次解码出现中文/正常字符则采用二次结果
    return twice if twice != once or "%" in once else once


def synth_edge(text):
    """edge-tts 合成 MP3 字节；网络失败抛异常。"""
    import edge_tts

    async def _run():
        com = edge_tts.Communicate(text, VOICE)
        buf = bytearray()
        async for chunk in com.stream():
            if chunk["type"] == "audio":
                buf.extend(chunk["data"])
        return bytes(buf)

    return asyncio.run(_run())


def synth_sapi(text):
    """Windows SAPI 离线合成 WAV 字节（JavaFX 支持 WAV）。"""
    script = (
        "Add-Type -AssemblyName System.Speech;"
        "$s=New-Object System.Speech.Synthesis.SpeechSynthesizer;"
        "$s.SelectVoice('%s');"
        "$ms=New-Object System.IO.MemoryStream;"
        "$s.SetOutputToWaveStream($ms);"
        "$s.Speak([Console]::In.ReadToEnd());"
        "$s.Dispose();"
        "[Convert]::ToBase64String($ms.ToArray())" % SAPI_VOICE
    )
    out = subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script],
        input=text.encode("utf-8"), stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
    if out.returncode != 0 or not out.stdout.strip():
        raise RuntimeError("SAPI failed: " + out.stderr.decode("utf-8", "replace")[:200])
    import base64
    return base64.b64decode(out.stdout.strip())


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _send(self, code, ctype, payload):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        parts = urllib.parse.urlsplit(self.path)
        q = urllib.parse.parse_qs(parts.query, keep_blank_values=True)
        raw = q.get("text", [""])[0]
        rec = {"path": self.path[:300], "echo": q.get("echo", [""])[0]}
        if parts.path == "/health":
            self._send(200, "text/plain", b"ok")
            return
        if parts.path != "/tts":
            self._send(404, "text/plain", b"not found")
            return
        text = decode_app_text(raw)
        rec["text"] = text
        try:
            audio = synth_edge(text) if BACKEND == "edge" else synth_sapi(text)
            ctype = "audio/mpeg" if BACKEND == "edge" else "audio/wav"
            rec.update({"ok": True, "bytes": len(audio), "ctype": ctype})
            self._send(200, ctype, audio)
        except Exception as e:
            rec.update({"ok": False, "err": "%s: %s" % (type(e).__name__, str(e)[:200])})
            self._send(500, "text/plain", ("TTS failed: " + str(e)[:200]).encode("utf-8"))
        with open(LOG_PATH, "a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")

    def log_message(self, fmt, *args):
        pass


def main():
    global BACKEND, VOICE, SAPI_VOICE
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=18523)
    ap.add_argument("--backend", default="edge", choices=["edge", "sapi"])
    ap.add_argument("--voice", default=VOICE)
    ap.add_argument("--sapi-voice", default=SAPI_VOICE)
    a = ap.parse_args()
    BACKEND, VOICE, SAPI_VOICE = a.backend, a.voice, a.sapi_voice
    srv = ThreadingHTTPServer(("127.0.0.1", a.port), Handler)
    print("local tts server on http://127.0.0.1:%d/tts?text=... backend=%s voice=%s"
          % (a.port, BACKEND, VOICE), flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
