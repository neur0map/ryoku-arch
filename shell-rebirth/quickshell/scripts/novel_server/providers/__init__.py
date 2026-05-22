"""
Provider registry.

Usage (in server.py):
    import providers
    providers.get()          → active NovelProvider instance
    providers.switch("novelbin")
    providers.list_all()     → [{"name": "novelbin", "label": "NovelBin"}, ...]
    providers.active_name()  → "novelbin"

ID namespacing
──────────────
Every novel/chapter ID that crosses the HTTP boundary is prefixed with the
provider name so that favorites and downloads never collide across sources:

    Internal (provider sees):   "b/some-slug"
    External (client sees):     "novelbin:b/some-slug"

Helper functions strip/add the prefix transparently.
"""

import threading

from .novelbin import NovelBinProvider
from .freewebnovel import FreeWebNovelProvider

from .base import NovelProvider

# ── Registry ───────────────────────────────────────────────────────────────
# Add new providers here: name → class
_REGISTRY: dict[str, type[NovelProvider]] = {
    "novelbin":     NovelBinProvider,
    "freewebnovel": FreeWebNovelProvider,
}

_lock   = threading.Lock()
_active: NovelProvider = NovelBinProvider()   # default on startup


# ── Public API ─────────────────────────────────────────────────────────────

def get() -> NovelProvider:
    """Return the currently active provider instance."""
    with _lock:
        return _active


def switch(name: str) -> None:
    """Switch the active provider. Raises ValueError for unknown names."""
    global _active
    if name not in _REGISTRY:
        raise ValueError(f"Unknown provider '{name}'. Available: {list(_REGISTRY)}")
    with _lock:
        _active = _REGISTRY[name]()
    print(f"[providers] Switched to '{name}'")


def active_name() -> str:
    with _lock:
        return _active.name


def list_all() -> list[dict]:
    return [
        {"name": cls.name, "label": cls.label}
        for cls in _REGISTRY.values()
    ]


# ── ID namespacing helpers ─────────────────────────────────────────────────

def prefix_id(raw_id: str, provider_name: str | None = None) -> str:
    """
    Add a provider prefix to a raw ID.
    "b/some-slug"  →  "novelbin:b/some-slug"
    """
    pname = provider_name or active_name()
    if raw_id.startswith(f"{pname}:"):
        return raw_id          # already prefixed
    return f"{pname}:{raw_id}"


def strip_prefix(prefixed_id: str) -> tuple[str, str]:
    """
    Split a prefixed ID into (provider_name, raw_id).
    "novelbin:b/some-slug"  →  ("novelbin", "b/some-slug")
    Raises ValueError if the prefix is not a registered provider.
    """
    parts = prefixed_id.split(":", 1)
    if len(parts) != 2 or parts[0] not in _REGISTRY:
        raise ValueError(
            f"ID '{prefixed_id}' has no valid provider prefix. "
            f"Expected one of {list(_REGISTRY)} followed by ':'."
        )
    return parts[0], parts[1]


def provider_for(prefixed_id: str) -> NovelProvider:
    """
    Return the provider instance that owns this prefixed ID.
    Instantiates a fresh instance each call so the active provider is unaffected.
    """
    pname, _ = strip_prefix(prefixed_id)
    return _REGISTRY[pname]()