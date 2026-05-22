"""
Persistent storage: favorites and downloads.
Completely provider-agnostic — every stored ID is a PREFIXED ID
(e.g. "novelbin:b/some-slug") so records survive provider switches.
"""

import os
import re
import json
import shutil
import threading
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone


# ── Paths ──────────────────────────────────────────────────────────────────
DATA_DIR       = os.path.expanduser("~/.local/share/quickshell-novel")
FAVORITES_FILE = os.path.join(DATA_DIR, "favorites.json")
DOWNLOADS_DIR  = os.path.join(DATA_DIR, "downloads")
os.makedirs(DATA_DIR,      exist_ok=True)
os.makedirs(DOWNLOADS_DIR, exist_ok=True)


# ── Favorites ──────────────────────────────────────────────────────────────

_fav_lock = threading.Lock()


def _load_favs() -> list:
    with _fav_lock:
        if not os.path.exists(FAVORITES_FILE):
            return []
        with open(FAVORITES_FILE) as f:
            return json.load(f)


def _save_favs(favs: list) -> None:
    with _fav_lock:
        with open(FAVORITES_FILE, "w") as f:
            json.dump(favs, f, indent=2)


def fav_list(proxy_fn) -> list:
    """
    proxy_fn(raw_image_url) → proxied URL.
    Passed in from server.py to avoid a circular import.
    """
    favs = _load_favs()
    return [{**f, "image": proxy_fn(f["image"])} for f in favs]


def fav_add(prefixed_novel_id: str, title: str, raw_image_url: str) -> dict:
    favs = _load_favs()
    if any(f["id"] == prefixed_novel_id for f in favs):
        return {"ok": True}
    favs.append({
        "id":                    prefixed_novel_id,
        "title":                 title,
        "image":                 raw_image_url,
        "addedAt":               datetime.now(timezone.utc).isoformat(),
        "lastKnownChapterCount": 0,
        "latestSeenChapterId":   "",
        "hasNewChapters":        False,
    })
    _save_favs(favs)
    return {"ok": True}


def fav_remove(prefixed_novel_id: str) -> dict:
    favs = _load_favs()
    _save_favs([f for f in favs if f["id"] != prefixed_novel_id])
    return {"ok": True}


def fav_mark_seen(prefixed_novel_id: str, prefixed_chapter_id: str) -> dict:
    favs = _load_favs()
    for f in favs:
        if f["id"] == prefixed_novel_id:
            f["latestSeenChapterId"] = prefixed_chapter_id
            f["hasNewChapters"]      = False
    _save_favs(favs)
    return {"ok": True}


def fav_check(get_info_fn) -> dict:
    """
    get_info_fn(prefixed_novel_id) → info dict.
    The server passes providers.get_info (which handles prefix-stripping).
    """
    favs    = _load_favs()
    updated = []

    def _check_one(fav):
        try:
            data  = get_info_fn(fav["id"])
            count = len(data.get("chapters", []))
            if count > fav.get("lastKnownChapterCount", 0):
                fav["hasNewChapters"]        = True
                fav["lastKnownChapterCount"] = count
                updated.append({"id": fav["id"], "title": fav["title"], "newCount": count})
            elif not fav.get("hasNewChapters"):
                fav["lastKnownChapterCount"] = count
        except Exception:
            pass

    with ThreadPoolExecutor(max_workers=4) as ex:
        list(ex.map(_check_one, favs))
    _save_favs(favs)
    return {"checked": len(favs), "updated": updated}


# ── Downloads ──────────────────────────────────────────────────────────────

_dl_jobs: dict = {}
_dl_lock = threading.Lock()


def dl_list(proxy_fn) -> list:
    result = []
    if not os.path.exists(DOWNLOADS_DIR):
        return result
    for nid in sorted(os.listdir(DOWNLOADS_DIR)):
        novel_dir  = os.path.join(DOWNLOADS_DIR, nid)
        novel_meta = os.path.join(novel_dir, "novel_meta.json")
        if not os.path.isdir(novel_dir) or not os.path.exists(novel_meta):
            continue
        with open(novel_meta) as f:
            nm = json.load(f)
        chapters = []
        for cid in sorted(os.listdir(novel_dir)):
            ch_dir  = os.path.join(novel_dir, cid)
            ch_meta = os.path.join(ch_dir, "meta.json")
            if not os.path.isdir(ch_dir) or not os.path.exists(ch_meta):
                continue
            with open(ch_meta) as f:
                chapters.append(json.load(f))
        chapters.sort(key=lambda c: float(c.get("chapterNum", "0") or "0"))
        cover_path  = os.path.join(novel_dir, "cover.jpg")
        cover_local = (
            f"file://{cover_path}"
            if os.path.exists(cover_path)
            else proxy_fn(nm.get("rawCoverUrl", ""))
        )
        result.append({**nm, "image": cover_local, "chapters": chapters})
    return result


def dl_progress(chapter_id: str) -> dict:
    with _dl_lock:
        return _dl_jobs.get(chapter_id, {"status": "not_started"})


def dl_start(novel_id, chapter_id, chapter_num, chapter_title,
             novel_title, raw_cover_url, fetch_chapter_fn) -> dict:
    """
    fetch_chapter_fn(prefixed_chapter_id) → chapter dict.
    Passed in from server.py so storage never imports providers directly.
    """
    with _dl_lock:
        job = _dl_jobs.get(chapter_id, {})
        if job.get("status") in ("downloading", "done"):
            return {"ok": False, "message": job["status"]}
        _dl_jobs[chapter_id] = {"status": "pending", "done": False, "error": None}

    import threading as _t
    _t.Thread(
        target=_dl_worker,
        args=(novel_id, chapter_id, chapter_num, chapter_title,
              novel_title, raw_cover_url, fetch_chapter_fn),
        daemon=True,
    ).start()
    return {"ok": True}


def _dl_worker(novel_id, chapter_id, chapter_num, chapter_title,
               novel_title, raw_cover_url, fetch_chapter_fn):
    from providers.utils import fetch_bytes

    # Safe filesystem names — strip prefix too
    raw_nid  = novel_id.split(":")[-1]   # "novelbin:b/slug" → "b/slug"
    raw_cid  = chapter_id.split(":")[-1]
    safe_nid = re.sub(r"[^a-zA-Z0-9_-]", "_", raw_nid.split("/")[-1])
    safe_cid = re.sub(r"[^a-zA-Z0-9_-]", "_", raw_cid.split("/")[-1])
    ch_dir   = os.path.join(DOWNLOADS_DIR, safe_nid, safe_cid)
    os.makedirs(ch_dir, exist_ok=True)

    try:
        with _dl_lock:
            _dl_jobs[chapter_id]["status"] = "downloading"

        data = fetch_chapter_fn(chapter_id)

        with open(os.path.join(ch_dir, "content.json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

        with open(os.path.join(ch_dir, "meta.json"), "w") as f:
            json.dump({
                "chapterId":    chapter_id,    # prefixed
                "chapterNum":   chapter_num,
                "title":        chapter_title,
                "novelId":      novel_id,       # prefixed
                "novelTitle":   novel_title,
                "wordCount":    data.get("wordCount", 0),
                "downloadedAt": datetime.now(timezone.utc).isoformat(),
            }, f)

        novel_dir  = os.path.join(DOWNLOADS_DIR, safe_nid)
        with open(os.path.join(novel_dir, "novel_meta.json"), "w") as f:
            json.dump({
                "id":          novel_id,        # prefixed
                "title":       novel_title,
                "localId":     safe_nid,
                "rawCoverUrl": raw_cover_url,
            }, f)

        cover_path = os.path.join(novel_dir, "cover.jpg")
        if not os.path.exists(cover_path) and raw_cover_url:
            try:
                body, _ = fetch_bytes(raw_cover_url, timeout=15)
                with open(cover_path, "wb") as f:
                    f.write(body)
            except Exception:
                pass

        with _dl_lock:
            _dl_jobs[chapter_id]["status"] = "done"
            _dl_jobs[chapter_id]["done"]   = True

    except Exception as e:
        import traceback
        traceback.print_exc()
        with _dl_lock:
            _dl_jobs[chapter_id] = {"status": "error", "done": False, "error": str(e)}


def dl_chapter_offline(chapter_id: str):
    """Return offline chapter dict from disk, or None if not downloaded."""
    raw_cid  = chapter_id.split(":")[-1]
    safe_cid = re.sub(r"[^a-zA-Z0-9_-]", "_", raw_cid.split("/")[-1])
    for nid in os.listdir(DOWNLOADS_DIR):
        content_path = os.path.join(DOWNLOADS_DIR, nid, safe_cid, "content.json")
        if os.path.exists(content_path):
            with open(content_path, encoding="utf-8") as f:
                return json.load(f)
    return None


def dl_remove(chapter_id: str) -> dict:
    raw_cid  = chapter_id.split(":")[-1]
    safe_cid = re.sub(r"[^a-zA-Z0-9_-]", "_", raw_cid.split("/")[-1])
    for nid in os.listdir(DOWNLOADS_DIR):
        ch_dir = os.path.join(DOWNLOADS_DIR, nid, safe_cid)
        if os.path.isdir(ch_dir):
            shutil.rmtree(ch_dir)
            novel_dir = os.path.join(DOWNLOADS_DIR, nid)
            remaining = [d for d in os.listdir(novel_dir) if os.path.isdir(os.path.join(novel_dir, d))]
            if not remaining:
                shutil.rmtree(novel_dir)
            with _dl_lock:
                _dl_jobs.pop(chapter_id, None)
            return {"ok": True}
    return {"ok": False, "error": "not found"}