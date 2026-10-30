"""本地回声服务：记录 app(OkHttp) 实际发出的请求行/查询串/正文/头，用于验证 TTSConfig 的编码行为。

用法: py -3 echo_server.py <port> <logfile>
运行后任意请求都会以 200 返回文本 OK，并把请求原样写入 JSONL 日志。
"""
import sys
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit, parse_qs

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 18923
LOGFILE = sys.argv[2] if len(sys.argv) > 2 else "echo_log.jsonl"


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _handle(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b""
        try:
            body_text = body.decode("utf-8", "replace")
        except Exception:
            body_text = ""
        parts = urlsplit(self.path)
        rec = {
            "ts": time.strftime("%Y-%m-%d %H:%M:%S"),
            "method": self.command,
            "path_raw": self.path,
            "query_raw": parts.query,
            "query_parsed": {k: v for k, v in parse_qs(parts.query, keep_blank_values=True).items()},
            "body_raw": body_text,
            "body_parsed": {k: v for k, v in parse_qs(body_text, keep_blank_values=True).items()},
            "headers": {k: v for k, v in self.headers.items()},
        }
        with open(LOGFILE, "a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
        payload = b"OK"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    do_GET = _handle
    do_POST = _handle

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    srv = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print("listening on 127.0.0.1:%d log=%s" % (PORT, LOGFILE), flush=True)
    srv.serve_forever()
