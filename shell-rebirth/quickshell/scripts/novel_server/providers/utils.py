"""
Shared utilities: HTTP session, fetch helpers, TTL cache, text cleaning.
Imported by providers — never by server.py directly.
"""

import re
import time
import threading
from urllib.parse import quote

# ── HTTP session (curl_cffi preferred for Cloudflare bypass) ───────────────

try:
    from curl_cffi.requests import Session as CffiSession
    _session = CffiSession(impersonate="firefox")
    _USE_CFFI = True
    print("[novel-utils] Using curl_cffi (Firefox impersonation)")
except ImportError:
    import requests as _req
    _session = _req.Session()
    _USE_CFFI = False
    print("[novel-utils] curl_cffi not found – falling back to requests")

BASE_HEADERS = {
    "User-Agent":                "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0",
    "Accept":                    "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language":           "en-US,en;q=0.5",
    "Accept-Encoding":           "gzip, deflate, br",
    "Connection":                "keep-alive",
    "Upgrade-Insecure-Requests": "1",
    "Sec-Fetch-Dest":            "document",
    "Sec-Fetch-Mode":            "navigate",
    "Sec-Fetch-Site":            "none",
    "Sec-Fetch-User":            "?1",
    "DNT":                       "1",
}

AJAX_HEADERS = {
    **BASE_HEADERS,
    "X-Requested-With": "XMLHttpRequest",
    "Sec-Fetch-Dest":   "empty",
    "Sec-Fetch-Mode":   "cors",
    "Sec-Fetch-Site":   "same-origin",
}

if not _USE_CFFI:
    _session.headers.update(BASE_HEADERS)


def fetch(url: str, extra_headers: dict | None = None, timeout: int = 30) -> str:
    """GET url, return response text. Raises on non-2xx."""
    headers = {**BASE_HEADERS, **(extra_headers or {})}
    r = _session.get(url, headers=headers, timeout=timeout)
    r.raise_for_status()
    return r.text


def fetch_bytes(url: str, timeout: int = 30) -> tuple[bytes, str]:
    """GET url, return (body_bytes, content_type). Used for image proxy."""
    r = _session.get(url, headers=BASE_HEADERS, timeout=timeout)
    r.raise_for_status()
    return r.content, r.headers.get("Content-Type", "image/jpeg")


# ── TTL cache (shared across all providers) ────────────────────────────────
# Keys are namespaced per provider: "{provider_name}:{endpoint}:{id}"

_cache:      dict = {}
_cache_lock: threading.Lock = threading.Lock()


def cached(key: str, ttl: int, fn):
    """Return cached value for key, or call fn() and cache the result."""
    with _cache_lock:
        entry = _cache.get(key)
    if entry:
        val, expires = entry
        if time.monotonic() < expires:
            return val
    val = fn()
    with _cache_lock:
        _cache[key] = (val, time.monotonic() + ttl)
    return val


def cache_invalidate(key: str):
    with _cache_lock:
        _cache.pop(key, None)


# ── Text cleaning ──────────────────────────────────────────────────────────

def clean_text(html: str) -> str:
    """Strip all HTML tags and normalise whitespace."""
    text = re.sub(r"<[^>]+>", " ", html)
    text = re.sub(r"&nbsp;",  " ",  text)
    text = re.sub(r"&amp;",   "&",  text)
    text = re.sub(r"&lt;",    "<",  text)
    text = re.sub(r"&gt;",    ">",  text)
    text = re.sub(r"&quot;",  '"',  text)
    text = re.sub(r"&#\d+;",  "",   text)
    return re.sub(r"\s+", " ", text).strip()