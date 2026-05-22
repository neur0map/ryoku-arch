"""
Proxy service
=============
Handles CRUD for proxy configs and owns the httpx client used for LLM calls.
All LLM calls go through `stream_chat` which yields raw text chunks.
"""

import time
import uuid
from collections.abc import AsyncGenerator
from typing import Any

import httpx
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.models import Proxy
from app.schemas.schemas import ProxyCreate, ProxyUpdate

async def create_proxy(db: AsyncSession, data: ProxyCreate) -> Proxy:
    if data.is_default:
        await db.execute(update(Proxy).values(is_default=False))

    proxy = Proxy(**data.model_dump())
    db.add(proxy)
    await db.flush()
    await db.refresh(proxy)
    return proxy


async def get_proxy(db: AsyncSession, proxy_id: uuid.UUID) -> Proxy | None:
    result = await db.execute(select(Proxy).where(Proxy.id == proxy_id))
    return result.scalar_one_or_none()


async def list_proxies(db: AsyncSession) -> list[Proxy]:
    result = await db.execute(select(Proxy).order_by(Proxy.created_at))
    return list(result.scalars().all())


async def update_proxy(
    db: AsyncSession, proxy_id: uuid.UUID, data: ProxyUpdate
) -> Proxy | None:
    proxy = await get_proxy(db, proxy_id)
    if not proxy:
        return None

    patch = data.model_dump(exclude_unset=True)

    if patch.get("is_default"):
        await db.execute(
            update(Proxy).where(Proxy.id != proxy_id).values(is_default=False)
        )

    for k, v in patch.items():
        setattr(proxy, k, v)

    await db.flush()
    await db.refresh(proxy)
    return proxy


async def delete_proxy(db: AsyncSession, proxy_id: uuid.UUID) -> bool:
    proxy = await get_proxy(db, proxy_id)
    if not proxy:
        return False
    await db.delete(proxy)
    return True


async def get_default_proxy(db: AsyncSession) -> Proxy | None:
    result = await db.execute(select(Proxy).where(Proxy.is_default.is_(True)))
    return result.scalar_one_or_none()


def _build_system_prompt(character, user_persona) -> str:
    """
    Assemble the system prompt from character fields.
    {{user}} and {{char}} are standard SillyTavern-style placeholders.
    """
    user_name = user_persona.name if user_persona else "User"
    char_name = character.name

    parts: list[str] = []

    if character.description:
        desc = (
            character.description
            .replace("{{char}}", char_name)
            .replace("{{user}}", user_name)
        )
        parts.append(f"[Description]\n{desc}")

    if character.personality:
        pers = (
            character.personality
            .replace("{{char}}", char_name)
            .replace("{{user}}", user_name)
        )
        parts.append(f"[Personality]\n{pers}")

    if character.scenario:
        scen = (
            character.scenario
            .replace("{{char}}", char_name)
            .replace("{{user}}", user_name)
        )
        parts.append(f"[Scenario]\n{scen}")

    if user_persona and user_persona.description:
        parts.append(f"[User / {user_name}]\n{user_persona.description}")

    return "\n\n".join(parts)


def _resolve_params(proxy: Proxy, character) -> tuple[float, int]:
    """Return (temperature, max_tokens) — character overrides proxy defaults."""
    temperature = (
        character.temperature
        if character.temperature is not None
        else proxy.temperature
    )
    max_tokens = (
        character.max_tokens
        if character.max_tokens is not None
        else proxy.max_tokens
    )
    return temperature, max_tokens


async def stream_chat(
    proxy: Proxy,
    character,
    user_persona,
    messages: list[dict[str, str]],
) -> AsyncGenerator[str, None]:
    """
    Yield raw text delta chunks from the OpenAI-compatible streaming endpoint.
    Raises httpx.HTTPStatusError on non-2xx responses.
    """
    system_prompt = _build_system_prompt(character, user_persona)
    temperature, max_tokens = _resolve_params(proxy, character)

    # Build message list: system first, then history
    api_messages: list[dict[str, str]] = []
    if system_prompt:
        api_messages.append({"role": "system", "content": system_prompt})
    api_messages.extend(messages)

    payload: dict[str, Any] = {
        "model": proxy.model_name,
        "messages": api_messages,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "stream": True,
    }

    headers = {
        "Authorization": f"Bearer {proxy.api_key}",
        "Content-Type": "application/json",
        "Accept": "text/event-stream",
    }

    # Normalise base URL — strip trailing slash
    base = proxy.endpoint_url.rstrip("/")

    async with httpx.AsyncClient(timeout=120.0) as client:
        async with client.stream(
            "POST",
            f"{base}/chat/completions",
            json=payload,
            headers=headers,
        ) as response:
            response.raise_for_status()

            async for line in response.aiter_lines():
                if not line.startswith("data:"):
                    continue
                raw = line[5:].strip()
                if raw == "[DONE]":
                    break

                import json  # local import to keep top clean

                try:
                    chunk = json.loads(raw)
                except json.JSONDecodeError:
                    continue

                delta = (
                    chunk.get("choices", [{}])[0]
                    .get("delta", {})
                    .get("content", "")
                )
                if delta:
                    yield delta


async def test_proxy(proxy: Proxy) -> tuple[bool, float | None, str | None]:
    """
    Send a tiny non-streaming ping to check connectivity & auth.
    Returns (ok, latency_ms, error_message).
    """
    headers = {
        "Authorization": f"Bearer {proxy.api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": proxy.model_name,
        "messages": [{"role": "user", "content": "Hi"}],
        "max_tokens": 1,
        "stream": False,
    }
    base = proxy.endpoint_url.rstrip("/")
    t0 = time.perf_counter()
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            r = await client.post(
                f"{base}/chat/completions",
                json=payload,
                headers=headers,
            )
            r.raise_for_status()
        latency = (time.perf_counter() - t0) * 1000
        return True, round(latency, 1), None
    except httpx.HTTPStatusError as exc:
        return False, None, f"HTTP {exc.response.status_code}: {exc.response.text[:200]}"
    except Exception as exc:
        return False, None, str(exc)