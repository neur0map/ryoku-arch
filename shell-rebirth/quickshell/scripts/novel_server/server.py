#!/usr/bin/env python3
"""
Novel backend server for QuickShell ServiceNovel.
Serves clean JSON on http://127.0.0.1:5151

Endpoints (unchanged from original):
  GET  /search?q=<query>&genre=<genre>&status=<All|Ongoing|Completed>&page=<n>
  GET  /info?id=<novel-id>
  GET  /chapter?id=<chapter-id>
  GET  /hot
  GET  /latest?page=<n>
  GET  /image?url=<encoded-url>
  GET  /favorites
  POST /favorites/add         body: {id, title, imageUrl}
  POST /favorites/remove      body: {id}
  POST /favorites/mark-seen   body: {id, chapterId}
  GET  /favorites/check
  GET  /dl/list
  GET  /dl/progress?chapterId=<id>
  GET  /dl/chapter?chapterId=<id>
  POST /dl/start              body: {novelId, chapterId, chapterNum, chapterTitle, novelTitle, rawCoverUrl}
  POST /dl/delete             body: {chapterId}
  GET  /health

Provider-switching endpoints (new):
  GET  /provider/list         → [{name, label}, ...]
  GET  /provider/active       → {name, label}
  POST /provider/switch       body: {provider: "novelbin"}

All novel/chapter IDs crossing the HTTP boundary are PREFIXED:
  "novelbin:b/some-slug"
  "novelbin:b/some-slug/chapter-5-title"
The providers package handles stripping/adding prefixes transparently.
"""

import json
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ThreadingMixIn
from urllib.parse import urlparse, parse_qs, quote, unquote

import providers
import storage

PORT = 5151


# ── Image byte cache ───────────────────────────────────────────────────────

_img_cache:     dict         = {}
_img_cache_lock              = threading.Lock()
_img_cache_max               = 400
_img_sem                     = threading.Semaphore(8)


def _img_get(url):
    with _img_cache_lock:
        return _img_cache.get(url)


def _img_put(url, body, ctype):
    with _img_cache_lock:
        if len(_img_cache) >= _img_cache_max:
            _img_cache.pop(next(iter(_img_cache)))
        _img_cache[url] = (body, ctype)


def proxy_url(img_url: str) -> str:
    return f"http://127.0.0.1:{PORT}/image?url={quote(img_url, safe='')}"


# ── Provider-aware ID helpers ──────────────────────────────────────────────

def _get_info(prefixed_id: str) -> dict:
    """Fetch novel info using whichever provider owns this prefixed ID."""
    pname, raw_id = providers.strip_prefix(prefixed_id)
    p             = providers.provider_for(prefixed_id)
    data          = p.info(raw_id)
    # Re-prefix every chapter id before returning to client
    data["id"]       = providers.prefix_id(data["id"], pname)
    data["chapters"] = [
        {**c, "id": providers.prefix_id(c["id"], pname)}
        for c in data["chapters"]
    ]
    return data


def _get_chapter(prefixed_id: str) -> dict:
    pname, raw_id = providers.strip_prefix(prefixed_id)
    p             = providers.provider_for(prefixed_id)
    data          = p.chapter(raw_id)
    # Re-prefix prev/next so the client can pass them straight back
    data["id"]     = providers.prefix_id(data["id"], pname)
    data["prevId"] = providers.prefix_id(data["prevId"], pname) if data.get("prevId") else ""
    data["nextId"] = providers.prefix_id(data["nextId"], pname) if data.get("nextId") else ""
    return data


def _prefix_results(results: list, pname: str) -> list:
    """Add provider prefix to every id in a list of novel cards."""
    return [{**r, "id": providers.prefix_id(r["id"], pname)} for r in results]


# ── HTTP Server ────────────────────────────────────────────────────────────

class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads      = True
    allow_reuse_address = True


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[novel-server] {fmt % args}")

    def _json(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type",   "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _error(self, msg, status=500):
        self._json({"error": msg}, status)

    def _send_image(self, body, ctype):
        self.send_response(200)
        self.send_header("Content-Type",   ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control",  "public, max-age=86400")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _proxy_image(self, img_url: str):
        cached = _img_get(img_url)
        if cached:
            self._send_image(*cached)
            return
        with _img_sem:
            body, ctype = providers.get().fetch_image(img_url)
        _img_put(img_url, body, ctype)
        self._send_image(body, ctype)

    # ── GET ────────────────────────────────────────────────────────────────

    def do_HEAD(self):
        parsed = urlparse(self.path)
        if parsed.path == "/image":
            self.send_response(200)
            self.send_header("Content-Type", "image/jpeg")
            self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        qs     = parse_qs(parsed.query)

        def param(key, default=""):
            return (qs.get(key) or [default])[0]

        try:
            p   = parsed.path
            prv = providers.get()           # active provider
            pn  = prv.name                  # its name, for prefixing

            # ── Provider management ──────────────────────────────────────
            if p == "/provider/list":
                self._json(providers.list_all())

            elif p == "/provider/active":
                self._json({"name": prv.name, "label": prv.label})

            # ── Novel browsing ───────────────────────────────────────────
            elif p == "/hot":
                data = prv.hot()
                self._json(_prefix_results(data, pn))

            elif p == "/latest":
                data = prv.latest(int(param("page", "1")))
                data["results"] = _prefix_results(data["results"], pn)
                self._json(data)

            elif p == "/search":
                q = param("q")
                if not q:
                    return self._error("missing q", 400)
                data = prv.search(
                    q,
                    param("genre") or None,
                    param("status", "All"),
                    int(param("page", "1")),
                )
                data["results"] = _prefix_results(data["results"], pn)
                self._json(data)

            elif p == "/info":
                nid = param("id")
                if not nid:
                    return self._error("missing id", 400)
                self._json(_get_info(nid))

            elif p == "/chapter":
                cid = param("id")
                if not cid:
                    return self._error("missing id", 400)
                # Offline-first
                offline = storage.dl_chapter_offline(cid)
                if offline:
                    self._json(offline)
                else:
                    self._json(_get_chapter(cid))

            elif p == "/image":
                img_url = unquote(param("url"))
                if not img_url:
                    return self._error("missing url", 400)
                self._proxy_image(img_url)

            # ── Favorites ────────────────────────────────────────────────
            elif p == "/favorites":
                self._json(storage.fav_list(proxy_url))

            elif p == "/favorites/check":
                self._json(storage.fav_check(_get_info))

            # ── Downloads ────────────────────────────────────────────────
            elif p == "/dl/list":
                self._json(storage.dl_list(proxy_url))

            elif p == "/dl/progress":
                cid = param("chapterId")
                if not cid:
                    return self._error("missing chapterId", 400)
                self._json(storage.dl_progress(cid))

            elif p == "/dl/chapter":
                cid = param("chapterId")
                if not cid:
                    return self._error("missing chapterId", 400)
                data = storage.dl_chapter_offline(cid)
                if data is None:
                    return self._error("not downloaded", 404)
                self._json(data)

            elif p == "/health":
                self._json({"ok": True, "provider": pn})

            else:
                self._error("not found", 404)

        except (BrokenPipeError, ConnectionResetError):
            pass
        except ValueError as e:
            self._error(str(e), 400)
        except Exception as e:
            import traceback
            traceback.print_exc()
            self._error(str(e))

    # ── POST ───────────────────────────────────────────────────────────────

    def do_POST(self):
        parsed = urlparse(self.path)
        try:
            length = int(self.headers.get("Content-Length", 0))
            body   = json.loads(self.rfile.read(length)) if length else {}
        except Exception:
            return self._error("bad request body", 400)

        try:
            p = parsed.path

            # ── Provider switching ───────────────────────────────────────
            if p == "/provider/switch":
                name = body.get("provider", "")
                if not name:
                    return self._error("missing provider", 400)
                providers.switch(name)
                self._json({"ok": True, "active": name})

            # ── Favorites ────────────────────────────────────────────────
            elif p == "/favorites/add":
                nid = body.get("id", "")
                if not nid:
                    return self._error("missing id", 400)
                self._json(storage.fav_add(nid, body.get("title", ""), body.get("imageUrl", "")))

            elif p == "/favorites/remove":
                nid = body.get("id", "")
                if not nid:
                    return self._error("missing id", 400)
                self._json(storage.fav_remove(nid))

            elif p == "/favorites/mark-seen":
                nid = body.get("id", "")
                if not nid:
                    return self._error("missing id", 400)
                self._json(storage.fav_mark_seen(nid, body.get("chapterId", "")))

            # ── Downloads ────────────────────────────────────────────────
            elif p == "/dl/start":
                nid = body.get("novelId", "")
                cid = body.get("chapterId", "")
                if not (nid and cid):
                    return self._error("missing novelId or chapterId", 400)
                self._json(storage.dl_start(
                    nid, cid,
                    body.get("chapterNum", ""),
                    body.get("chapterTitle", ""),
                    body.get("novelTitle", ""),
                    body.get("rawCoverUrl", ""),
                    _get_chapter,          # provider-aware fetch function
                ))

            elif p == "/dl/delete":
                cid = body.get("chapterId", "")
                if not cid:
                    return self._error("missing chapterId", 400)
                self._json(storage.dl_remove(cid))

            else:
                self._error("not found", 404)

        except (BrokenPipeError, ConnectionResetError):
            pass
        except ValueError as e:
            self._error(str(e), 400)
        except Exception as e:
            import traceback
            traceback.print_exc()
            self._error(str(e))


# ── Entry point ────────────────────────────────────────────────────────────

def run():
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"[novel-server] Listening on http://127.0.0.1:{PORT}")
    print(f"[novel-server] Active provider: {providers.active_name()}")
    server.serve_forever()


if __name__ == "__main__":
    run()