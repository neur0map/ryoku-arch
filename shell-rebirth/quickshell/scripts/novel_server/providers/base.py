"""
Base provider interface.
Every scraping source must subclass NovelProvider and implement all abstract methods.
"""

from abc import ABC, abstractmethod


class NovelProvider(ABC):
    """
    Common interface for all novel-scraping backends.

    IDs passed into and returned from every method are always RAW
    (no provider prefix). The registry in __init__.py handles prefixing
    so the HTTP layer and storage layer stay provider-agnostic.
    """

    # ── Identity ──────────────────────────────────────────────────────────
    #  Set name = "novelbin" (or "novelfull", etc.) in each subclass.
    name: str = ""

    #  Human-readable label shown in the UI / /provider/list response.
    label: str = ""

    # ── Required endpoints ────────────────────────────────────────────────

    @abstractmethod
    def search(self, query: str, genre: str | None = None,
               status: str = "All", page: int = 1) -> dict:
        """
        Returns:
            {
                "results":  [ {id, title, image, author, latestChapter}, ... ],
                "hasMore":  bool,
                "nextPage": int,
            }
        """

    @abstractmethod
    def info(self, novel_id: str) -> dict:
        """
        Returns:
            {
                "id":          str,
                "title":       str,
                "description": str,
                "status":      str,
                "author":      str,
                "image":       str,   # proxied URL
                "genres":      [str],
                "chapters":    [ {id, title, chapter}, ... ],   # oldest-first
            }
        """

    @abstractmethod
    def chapter(self, chapter_id: str) -> dict:
        """
        Returns:
            {
                "id":         str,
                "title":      str,
                "paragraphs": [str],
                "wordCount":  int,
                "prevId":     str,
                "nextId":     str,
            }
        """

    @abstractmethod
    def hot(self) -> list:
        """
        Returns:
            [ {id, title, image, author, latestChapter}, ... ]
        """

    @abstractmethod
    def latest(self, page: int = 1) -> dict:
        """
        Returns:
            {
                "results":  [ {id, title, image, author, latestChapter, updatedAt}, ... ],
                "hasMore":  bool,
                "nextPage": int,
            }
        """

    # ── Optional: image proxy ─────────────────────────────────────────────
    # Override if the source needs special handling (auth headers, etc.).
    # Default: just fetch the URL with standard headers.
    def fetch_image(self, url: str) -> tuple[bytes, str]:
        """Returns (body_bytes, content_type)."""
        raise NotImplementedError