"""
NovelBin provider  –  https://novelbin.com
Implements the NovelProvider interface using the original scraping logic.
"""

import re
from urllib.parse import quote, urlparse

from .base import NovelProvider
from .utils import fetch, fetch_bytes, cached, clean_text, AJAX_HEADERS

BASE = "https://novelbin.com"

# TTLs (seconds)
TTL_HOT    = 300
TTL_LATEST = 120
TTL_SEARCH = 600
TTL_INFO   = 1800
TTL_CHAP   = 86400


class NovelBinProvider(NovelProvider):
    name  = "novelbin"
    label = "NovelBin"

    # ── Internal helpers ──────────────────────────────────────────────────

    def _key(self, *parts) -> str:
        """Build a namespaced cache key: 'novelbin:part1:part2:...'"""
        return f"{self.name}:" + ":".join(str(p) for p in parts)

    @staticmethod
    def _proxy(img_url: str, port: int = 5151) -> str:
        from urllib.parse import quote
        return f"http://127.0.0.1:{port}/image?url={quote(img_url, safe='')}"

    @staticmethod
    def _slugify(text: str) -> str:
        """
        Convert any string to a novelbin-compatible slug.
          "Fantasy: God of War"  → "fantasy-god-of-war"
          "Re:Zero"              → "re-zero"
        """
        text = text.lower()
        text = re.sub(r"[^a-z0-9]+", "-", text)
        return text.strip("-")

    # ── NovelProvider interface ───────────────────────────────────────────

    def search(self, query: str, genre: str | None = None,
               status: str = "All", page: int = 1) -> dict:
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

    # ── Private scraping implementations ──────────────────────────────────

    def _search(self, query, genre, status, page) -> dict:
        params = f"keyword={quote(query)}&page={page}"
        if genre:
            params += f"&genre={quote(genre)}"
        if status and status != "All":
            params += f"&status={quote(status)}"

        html    = fetch(f"{BASE}/search?{params}")
        results = []

        for block in re.finditer(
            r'<div class="row">([\s\S]*?)(?=<div class="row">|<div class="pagination|<div id="pagination)',
            html, re.S
        ):
            b = block.group(1)
            if "novel-title" not in b:
                continue

            title  = re.search(r'class="novel-title"[^>]*>\s*<a[^>]*>([^<]+)</a>', b)
            slug_m = re.search(r'href="https://novelbin\.com(/b/[^/"]+)"', b)
            img    = re.search(r'(?:data-src|src)="(https://images\.novelbin\.com/[^"]+)"', b)
            author = re.search(r'class="author"[^>]*>(?:<[^>]+>)*([^<]+)', b)
            chap   = re.search(r'class="[^"]*chapter-title[^"]*"[^>]*>\s*([^<]+)', b)

            if not (title and slug_m):
                continue

            results.append({
                "id":            slug_m.group(1).strip("/"),
                "title":         clean_text(title.group(1)),
                "image":         self._proxy(img.group(1)) if img else "",
                "author":        clean_text(author.group(1)).strip() if author else "",
                "latestChapter": clean_text(chap.group(1)).strip() if chap else "",
            })

        has_next = bool(re.search(r'class="[^"]*next[^"]*"', html))
        return {"results": results, "hasMore": has_next, "nextPage": page + 1}

    def _info(self, novel_id: str) -> dict:
        url  = f"{BASE}/{novel_id}"
        html = fetch(url)

        title_m  = re.search(r'<meta property="og:title" content="([^"]+)"', html)
        cover_m  = re.search(r'<meta property="og:image" content="([^"]+)"', html)
        desc_m   = re.search(
            r'<div[^>]+class="[^"]*novel-detail-body[^"]*"[^>]*>([\s\S]*?)</div>', html
        )
        if not desc_m:
            desc_m = re.search(
                r'<div[^>]+id="novel-detail[^"]*"[^>]*>[\s\S]*?<p[^>]*>([\s\S]{40,}?)</p>', html
            )

        status_m  = re.search(
            r'<span[^>]*>\s*Status\s*</span>[^<]*<a[^>]*>([^<]+)</a>', html
        )
        author_m  = re.search(
            r'<span[^>]*>\s*Author[^<]*</span>[^<]*<a[^>]*>([^<]+)</a>', html
        )
        genres_raw = re.findall(
            r'<span[^>]*>\s*Genre[^<]*</span>[\s\S]*?(<ul[\s\S]*?</ul>)', html
        )
        genres = []
        if genres_raw:
            genres = [clean_text(g) for g in re.findall(r'<li[^>]*>([^<]+)</li>', genres_raw[0])]

        description = ""
        if desc_m:
            raw_desc = desc_m.group(1)
            paras    = re.findall(r"<p[^>]*>([\s\S]*?)</p>", raw_desc)
            if paras:
                description = "\n\n".join(clean_text(p) for p in paras if clean_text(p))
            else:
                description = clean_text(raw_desc)

        novel_slug = self._slugify(novel_id.split("/")[-1])
        ch_html    = fetch(
            f"{BASE}/ajax/chapter-archive?novelId={novel_slug}",
            extra_headers=AJAX_HEADERS,
        )

        chapters = []
        for m in re.finditer(
            r'<a\s+href="https://novelbin\.com(/b/[^"]+)"\s+title="([^"]*)"',
            ch_html, re.S
        ):
            full_path = m.group(1).strip("/")
            label     = clean_text(m.group(2))
            ch_num_m  = re.search(r'(?:Chapter|Ch\.?)\s*([\d.]+)', label, re.I)
            chapters.append({
                "id":      full_path,
                "title":   label,
                "chapter": ch_num_m.group(1) if ch_num_m else label,
            })

        seen, deduped = set(), []
        for c in chapters:
            if c["id"] not in seen:
                seen.add(c["id"])
                deduped.append(c)

        raw_cover = cover_m.group(1) if cover_m else ""
        return {
            "id":          novel_id,
            "title":       clean_text(title_m.group(1)) if title_m else "",
            "description": description,
            "status":      status_m.group(1).strip() if status_m else "",
            "author":      clean_text(author_m.group(1)) if author_m else "",
            "image":       self._proxy(raw_cover) if raw_cover else "",
            "genres":      genres,
            "chapters":    deduped,
        }

    def _chapter(self, chapter_id: str) -> dict:
        url  = chapter_id if chapter_id.startswith("http") else f"{BASE}/{chapter_id}"
        html = fetch(url)

        title_m = re.search(r'<span class="chr-text">\s*([\s\S]*?)\s*</span>', html)
        if not title_m:
            title_m = re.search(r'<title>([^<|]+)', html)

        content = ""
        start_m = re.search(r'<div[^>]+id="chr-content"[^>]*>', html)
        if start_m:
            after_open = html[start_m.end():]
            end_m      = re.search(r'<hr[^>]+class="[^"]*chr-end[^"]*"', after_open)
            content    = after_open[:end_m.start()] if end_m else after_open[:50000]

        paragraphs = []
        if content:
            for raw in re.findall(r"<p[^>]*>([\s\S]*?)</p>", content):
                if "<script" in raw or "data-format" in raw:
                    continue
                t = clean_text(raw)
                if t:
                    paragraphs.append(t)
        else:
            for raw in re.findall(r"<p[^>]*>([\s\S]{20,}?)</p>", html):
                if "<script" in raw or "data-format" in raw:
                    continue
                t = clean_text(raw)
                if t and "advertisement" not in t.lower():
                    paragraphs.append(t)

        def path_from_href(pattern):
            m = re.search(pattern, html)
            if not m:
                return ""
            return urlparse(m.group(1)).path.strip("/")

        return {
            "id":         chapter_id,
            "title":      clean_text(title_m.group(1)).strip() if title_m else "",
            "paragraphs": paragraphs,
            "wordCount":  sum(len(p.split()) for p in paragraphs),
            "prevId":     path_from_href(r'<a[^>]+id="prev_chap"[^>]+href="([^"]+)"'),
            "nextId":     path_from_href(r'<a[^>]+id="next_chap"[^>]+href="([^"]+)"'),
        }

    def _hot(self) -> list:
        html    = fetch(f"{BASE}/sort/top-hot-novel")
        results = []
        seen    = set()

        for block in re.finditer(
            r'<div class="row">([\s\S]*?)(?=<div class="row">|<div class="pagination|</div>\s*</div>\s*</div>)',
            html, re.S
        ):
            b = block.group(1)
            if "novel-title" not in b:
                continue

            href   = re.search(r'href="https://novelbin\.com(/b/[^"]+?)"[^>]*>\s*(?:<[^>]+>)*([^<]+)', b)
            img    = re.search(r'(?:data-src|src)="(https://images\.novelbin\.com/[^"]+)"', b)
            title  = re.search(r'class="novel-title"[^>]*>\s*<a[^>]*>([^<]+)</a>', b)
            author = re.search(r'class="author"[^>]*>(?:<[^>]+>)*([^<]+)', b)
            chap   = re.search(r'class="[^"]*chapter-title[^"]*"[^>]*>\s*([^<]+)', b)

            if not title:
                continue

            slug = ""
            if href:
                slug = href.group(1).strip("/")
            else:
                m = re.search(r'href="https://novelbin\.com(/b/[^/"]+)"', b)
                if m:
                    slug = m.group(1).strip("/")

            if not slug or slug in seen:
                continue
            seen.add(slug)

            results.append({
                "id":            slug,
                "title":         clean_text(title.group(1)),
                "image":         self._proxy(img.group(1)) if img else "",
                "author":        clean_text(author.group(1)).strip() if author else "",
                "latestChapter": clean_text(chap.group(1)).strip() if chap else "",
            })

        return results

    def _latest(self, page: int) -> dict:
        html    = fetch(f"{BASE}/sort/latest?page={page}")
        results = []

        for block in re.finditer(
            r'<div class="row">([\s\S]*?)(?=<div class="row">|<div class="pagination|</div>\s*</div>\s*</div>)',
            html, re.S
        ):
            b = block.group(1)
            if "novel-title" not in b:
                continue

            title  = re.search(r'class="novel-title"[^>]*>\s*<a[^>]*>([^<]+)</a>', b)
            img    = re.search(r'(?:data-src|src)="(https://images\.novelbin\.com/[^"]+)"', b)
            author = re.search(r'class="author"[^>]*>(?:<[^>]+>)*([^<]+)', b)
            chap   = re.search(r'class="[^"]*chapter-title[^"]*"[^>]*>\s*([^<]+)', b)
            upd    = re.search(r'<time[^>]+datetime="([^"]+)"', b)
            slug_m = re.search(r'href="https://novelbin\.com(/b/[^/"]+)"', b)

            if not (title and slug_m):
                continue

            results.append({
                "id":            slug_m.group(1).strip("/"),
                "title":         clean_text(title.group(1)),
                "image":         self._proxy(img.group(1)) if img else "",
                "author":        clean_text(author.group(1)).strip() if author else "",
                "latestChapter": clean_text(chap.group(1)).strip() if chap else "",
                "updatedAt":     upd.group(1) if upd else "",
            })

        has_next = bool(re.search(r'class="[^"]*next[^"]*"', html))
        return {"results": results, "hasMore": has_next, "nextPage": page + 1}