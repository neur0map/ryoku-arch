"""
FreeWebNovel provider  –  https://freewebnovel.com

Implemented:
  - hot()      → /most-popular/weekvisit
  - latest()   → /sort/latest-novel[/page]
  - info()     → /novel/<slug>
  - chapter()  → /novel/<slug>/<chapter-slug>
  - search()   → POST /search

"""

import re
from urllib.parse import quote, urlparse

from .base import NovelProvider
from .utils import fetch, fetch_bytes, cached, clean_text

BASE = "https://freewebnovel.com"

TTL_HOT    = 300
TTL_LATEST = 120
TTL_SEARCH = 600
TTL_INFO   = 1800
TTL_CHAP   = 86400


class FreeWebNovelProvider(NovelProvider):
    name  = "freewebnovel"
    label = "FreeWebNovel"

    # ── Internal helpers ──────────────────────────────────────────────────

    def _key(self, *parts) -> str:
        return f"{self.name}:" + ":".join(str(p) for p in parts)

    @staticmethod
    def _proxy(img_url: str, port: int = 5151) -> str:
        # Images can be relative (/files/...) or absolute
        full = img_url if img_url.startswith("http") else BASE + img_url
        return f"http://127.0.0.1:{port}/image?url={quote(full, safe='')}"

    # ── NovelProvider interface ───────────────────────────────────────────

    def search(self, query, genre=None, status="All", page=1) -> dict:
        key = self._key("search", query, genre, status, page)
        return cached(key, TTL_SEARCH, lambda: self._search(query, genre, status, page))

    def info(self, novel_id: str) -> dict:
        return cached(self._key("info", novel_id), TTL_INFO, lambda: self._info(novel_id))

    def chapter(self, chapter_id: str) -> dict:
        return cached(self._key("chapter", chapter_id), TTL_CHAP, lambda: self._chapter(chapter_id))

    def hot(self) -> list:
        return cached(self._key("hot"), TTL_HOT, self._hot)

    def latest(self, page: int = 1) -> dict:
        return cached(self._key("latest", page), TTL_LATEST, lambda: self._latest(page))

    def fetch_image(self, url: str) -> tuple[bytes, str]:
        return fetch_bytes(url)

    # ── Shared list-card parser ───────────────────────────────────────────
    # Both hot() and latest() use the same .li-row card structure.

    def _parse_li_rows(self, html: str) -> list:
        results = []
        seen    = set()

        for block in re.finditer(
            r'<div class="li-row">([\s\S]*?)(?=<div class="li-row">|$)',
            html, re.S
        ):
            b = block.group(1)

            # Novel slug from href="/novel/some-slug" (no sub-path)
            slug_m = re.search(r'href="/novel/([^"/?]+)"', b)
            if not slug_m:
                continue
            slug = slug_m.group(1)
            if slug in seen:
                continue
            seen.add(slug)

            title_m = re.search(r'<h3 class="tit">\s*<a[^>]*>([^<]+)</a>', b)
            img_m   = re.search(r'<img\s+src="(/files/article/image/[^"]+)"', b)
            genres  = re.findall(r'href="/genre/[^"]*"[^>]*>([^<]+)</a>', b)
            chap_m  = re.search(r'<a[^>]+class="chapter"[^>]*title="([^"]*)"', b)

            results.append({
                "id":            f"novel/{slug}",
                "title":         clean_text(title_m.group(1)) if title_m else slug,
                "image":         self._proxy(img_m.group(1)) if img_m else "",
                "author":        "",
                "latestChapter": clean_text(chap_m.group(1)) if chap_m else "",
                "genres":        genres,
            })

        return results

    # ── Hot (weekly popular) ──────────────────────────────────────────────

    def _hot(self) -> list:
        html = fetch(f"{BASE}/most-popular/weekvisit")
        return self._parse_li_rows(html)

    # ── Latest novels ─────────────────────────────────────────────────────

    def _latest(self, page: int) -> dict:
        url  = f"{BASE}/sort/latest-novel" if page == 1 else f"{BASE}/sort/latest-novel/{page}"
        html = fetch(url)

        results  = self._parse_li_rows(html)
        has_next = bool(
            re.search(r'<a[^>]+class="[^"]*next[^"]*"', html)
            or re.search(r'rel="next"', html)
            or re.search(r'href="[^"]*latest-novel/' + str(page + 1) + r'"', html)
        )

        return {"results": results, "hasMore": has_next, "nextPage": page + 1}

    # ── Novel info + full chapter list ────────────────────────────────────
    #
    # novel_id arrives as:  "novel/shadow-slave"
    # Page URL becomes:     https://freewebnovel.com/novel/shadow-slave
    #
    # Metadata lives in:    <div class="m-imgtxt">
    # Description lives in: <div class="inner"> inside <div class="m-desc">
    # Chapter list in:      <ul id="idData">

    def _info(self, novel_id: str) -> dict:
        url  = f"{BASE}/{novel_id}"
        html = fetch(url)

        # Cover — <meta name="image"> is more reliable than og:image on this site
        cover_m = re.search(r'<meta name="image" content="([^"]+)"', html)
        if not cover_m:
            cover_m = re.search(r'<meta property="og:image" content="([^"]+)"', html)

        # Title
        title_m = re.search(r'<meta property="og:title" content="([^"]+)"', html)

        # Author: <a href="/author/Guiltythree" class="a1" title="Guiltythree">
        author_m = re.search(r'<a href="/author/[^"]*"[^>]*title="([^"]*)"', html)

        # Status: <span class="s1 s2"><a ...>OnGoing</a></span>
        status_m = re.search(
            r'<span class="s1 s2">\s*<a[^>]*>([^<]+)</a>\s*</span>', html
        )

        # Genres — grab only from the .m-imgtxt block to avoid nav links
        genres = []
        imgtxt_m = re.search(r'<div class="m-imgtxt">([\s\S]*?)</div>\s*</div>', html)
        if imgtxt_m:
            genres = re.findall(
                r'<a href="/genre/[^"]*"[^>]*title="[^"]*">([^<]+)</a>',
                imgtxt_m.group(1)
            )

        # Description — <div class="inner"> … <p>…</p> … </div>
        description = ""
        desc_m = re.search(
            r'<div class="inner">([\s\S]*?)</div>\s*</div>\s*<div class="showheight"',
            html
        )
        if desc_m:
            paras = re.findall(r'<p[^>]*>([\s\S]*?)</p>', desc_m.group(1))
            description = "\n\n".join(clean_text(p) for p in paras if clean_text(p))

        # Chapter list — <ul id="idData">
        # <li>…<a href="/novel/shadow-slave/chapter-1" title="Chapter 1 Nightmare Begins" class="con">…</a></li>
        chapters = []
        chlist_m = re.search(r'<ul[^>]+id="idData"[^>]*>([\s\S]*?)</ul>', html)
        if chlist_m:
            for m in re.finditer(
                r'<a\s+href="/novel/[^/]+/([^"]+)"\s+title="([^"]*)"[^>]*class="con"',
                chlist_m.group(1)
            ):
                ch_slug  = m.group(1)          # e.g. "chapter-1"
                label    = clean_text(m.group(2))
                ch_num_m = re.search(r'[Cc]hapter[\s-]*([\d.]+)', label)
                chapters.append({
                    # full routable id passed back to /chapter?id=
                    "id":      f"{novel_id}/{ch_slug}",
                    "title":   label,
                    "chapter": ch_num_m.group(1) if ch_num_m else label,
                })

        raw_cover = cover_m.group(1) if cover_m else ""
        return {
            "id":          novel_id,
            "title":       clean_text(title_m.group(1)) if title_m else "",
            "description": description,
            "status":      clean_text(status_m.group(1)) if status_m else "",
            "author":      clean_text(author_m.group(1)) if author_m else "",
            "image":       self._proxy(raw_cover) if raw_cover else "",
            "genres":      genres,
            "chapters":    chapters,   # oldest-first, as returned by the page
        }

    # ── Chapter content ───────────────────────────────────────────────────
    #
    # chapter_id arrives as:  "novel/shadow-slave/chapter-1"
    # Page URL becomes:       https://freewebnovel.com/novel/shadow-slave/chapter-1
    #
    # Title:    <span class="chapter">Chapter 1 Nightmare Begins</span>
    # Content:  <div id="article"> … <p>…</p> … </div>
    #           Ad divs appear inline inside #article — skip any <p> that
    #           contains a nested <script> or <div>.
    # Prev:     <a href="…" id="prev_url">  (bottom nav, most reliable)
    # Next:     <a href="…" id="next_url">

    def _chapter(self, chapter_id: str) -> dict:
        url  = f"{BASE}/{chapter_id}"
        html = fetch(url)

        # Title — the <span class="chapter"> inside .top is the canonical source
        title_m = re.search(r'<span class="chapter">([^<]+)</span>', html)
        if not title_m:
            title_m = re.search(r'<meta property="og:title" content="([^"]+)"', html)

        # Content — everything inside <div id="article">…</div>
        # The closing marker <!--bg--> comes right after </div> so we use it
        # as a reliable end anchor instead of trying to match nested divs.
        paragraphs = []
        article_m  = re.search(
            r'<div[^>]+id="article"[^>]*>([\s\S]*?)<!--bg-->', html
        )
        if not article_m:
            # Fallback: grab up to 100 000 chars after the opening tag
            article_m = re.search(
                r'<div[^>]+id="article"[^>]*>([\s\S]{0,100000})', html
            )

        if article_m:
            content = article_m.group(1)
            for raw in re.findall(r'<p[^>]*>([\s\S]*?)</p>', content):
                # Ad blocks embed <script> or <div> inside <p> — skip them
                if '<script' in raw or '<div' in raw:
                    continue
                t = clean_text(raw)
                if t:
                    paragraphs.append(t)

        # Prev / Next — use id="prev_url" / id="next_url" on the bottom nav
        def _path(pattern: str) -> str:
            m = re.search(pattern, html)
            if not m:
                return ""
            return urlparse(m.group(1)).path.strip("/")

        prev_raw = _path(r'<a[^>]+id="prev_url"[^>]+href="([^"]+)"')
        next_raw = _path(r'<a[^>]+id="next_url"[^>]+href="([^"]+)"')

        # If prev/next href points at the novel page (2 segments) not a chapter
        # (3 segments: novel/slug/chapter-N), treat as absent.
        def _is_chapter(path: str) -> bool:
            return len(path.split("/")) >= 3

        return {
            "id":         chapter_id,
            "title":      clean_text(title_m.group(1)).strip() if title_m else "",
            "paragraphs": paragraphs,
            "wordCount":  sum(len(p.split()) for p in paragraphs),
            "prevId":     prev_raw if _is_chapter(prev_raw) else "",
            "nextId":     next_raw if _is_chapter(next_raw) else "",
        }

    # ── Search ────────────────────────────────────────────────────────────

    def _search(self, query, genre, status, page) -> dict:
        from .utils import BASE_HEADERS, _session, _USE_CFFI

        headers = {
            **BASE_HEADERS,
            "Content-Type": "application/x-www-form-urlencoded",
            "Referer":      BASE + "/",
            "Origin":       BASE,
        }
        body = f"searchkey={quote(query)}"

        if _USE_CFFI:
            r = _session.post(f"{BASE}/search", headers=headers, data=body, timeout=30)
        else:
            r = _session.post(f"{BASE}/search", headers=headers, data=body, timeout=30)
        r.raise_for_status()

        results = self._parse_li_rows(r.text)
        return {
            "results":  results,
            "hasMore":  False,   # FWN search is single-page
            "nextPage": 1,
        }