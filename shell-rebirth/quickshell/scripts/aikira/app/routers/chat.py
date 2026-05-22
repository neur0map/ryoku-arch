"""
Chat router
===========
POST /chat/stream   — SSE streaming endpoint
POST /chat/send     — Non-streaming fallback (returns full response)

SSE event types emitted during streaming:
  data: {"type": "token",  "content": "..."}   — incremental token
  data: {"type": "done",   "message_id": "...","usage": {...}}  — stream finished
  data: {"type": "error",  "detail": "..."}    — something went wrong
"""

import json
import uuid

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.schemas import ChatRequest, MessageRead, RerollRequest
from app.services import conversation_service, persona_service, proxy_service

router = APIRouter(prefix="/chat", tags=["chat"])


async def _resolve_proxy(db: AsyncSession, proxy_id: uuid.UUID | None, character):
    """Pick proxy: explicit override > character's proxy > system default."""
    if proxy_id:
        p = await proxy_service.get_proxy(db, proxy_id)
        if not p:
            raise HTTPException(status_code=404, detail="Specified proxy not found")
        return p

    if character.proxy_id:
        p = await proxy_service.get_proxy(db, character.proxy_id)
        if p:
            return p

    p = await proxy_service.get_default_proxy(db)
    if not p:
        raise HTTPException(
            status_code=400,
            detail="No proxy configured. Add a proxy and set it as default.",
        )
    return p


#SSE Streaming

@router.post("/stream")
async def stream_chat(request: ChatRequest, db: AsyncSession = Depends(get_db)):
    """
    Stream an assistant response as Server-Sent Events.

    Connect with EventSource or any SSE-capable client.
    Send the ChatRequest body as a POST body (not a GET — use fetch + ReadableStream
    on the QML side or a helper script).
    """
    # 1. Load conversation with all relations
    conv = await conversation_service.get_conversation(db, request.conversation_id)
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")

    character = conv.character
    user_persona = conv.user_persona

    # 2. Resolve proxy
    proxy = await _resolve_proxy(db, request.proxy_id, character)

    # 3. Persist the user message
    user_msg = await conversation_service.add_message(
        db, conv.id, "user", request.content
    )
    await db.commit()

    # 4. Build history for the API (exclude the just-added message — it's appended below)
    history = await conversation_service.get_messages(db, conv.id)
    api_messages = conversation_service.build_api_messages(history)

    # 5. Stream
    async def event_generator():
        accumulated = []
        try:
            async for token in proxy_service.stream_chat(
                proxy, character, user_persona, api_messages
            ):
                accumulated.append(token)
                payload = json.dumps({"type": "token", "content": token})
                yield f"data: {payload}\n\n"

        except Exception as exc:
            err_payload = json.dumps({"type": "error", "detail": str(exc)})
            yield f"data: {err_payload}\n\n"
            return

        # 6. Persist assistant message after stream ends
        full_content = "".join(accumulated)
        async with db.begin_nested():
            asst_msg = await conversation_service.add_message(
                db,
                conv.id,
                "assistant",
                full_content,
                proxy_id=proxy.id,
            )
        await db.commit()

        done_payload = json.dumps(
            {
                "type": "done",
                "message_id": str(asst_msg.id),
                "conversation_id": str(conv.id),
            }
        )
        yield f"data: {done_payload}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",  # disable nginx buffering
        },
    )


@router.post("/reroll")
async def reroll_chat(request: RerollRequest, db: AsyncSession = Depends(get_db)):
    """
    Delete the most recent assistant message in the conversation and stream a
    new response using the same history up to that point.
    """
    conv = await conversation_service.get_conversation(db, request.conversation_id)
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")

    character = conv.character
    user_persona = conv.user_persona
    proxy = await _resolve_proxy(db, request.proxy_id, character)

    # Remove the last assistant turn so we regenerate from the user message
    await conversation_service.delete_last_assistant_message(db, conv.id)
    await db.commit()

    history = await conversation_service.get_messages(db, conv.id)
    api_messages = conversation_service.build_api_messages(history)

    async def event_generator():
        accumulated = []
        try:
            async for token in proxy_service.stream_chat(
                proxy, character, user_persona, api_messages
            ):
                accumulated.append(token)
                payload = json.dumps({"type": "token", "content": token})
                yield f"data: {payload}\n\n"

        except Exception as exc:
            err_payload = json.dumps({"type": "error", "detail": str(exc)})
            yield f"data: {err_payload}\n\n"
            return

        full_content = "".join(accumulated)
        async with db.begin_nested():
            asst_msg = await conversation_service.add_message(
                db,
                conv.id,
                "assistant",
                full_content,
                proxy_id=proxy.id,
            )
        await db.commit()

        done_payload = json.dumps(
            {
                "type": "done",
                "message_id": str(asst_msg.id),
                "conversation_id": str(conv.id),
            }
        )
        yield f"data: {done_payload}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )


@router.post("/send", response_model=MessageRead)
async def send_chat(request: ChatRequest, db: AsyncSession = Depends(get_db)):
    """
    Blocking send — collects the full response and returns it as a single Message.
    Useful for simple scripting or when SSE is not available.
    """
    conv = await conversation_service.get_conversation(db, request.conversation_id)
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")

    character = conv.character
    user_persona = conv.user_persona
    proxy = await _resolve_proxy(db, request.proxy_id, character)

    await conversation_service.add_message(db, conv.id, "user", request.content)
    await db.commit()

    history = await conversation_service.get_messages(db, conv.id)
    api_messages = conversation_service.build_api_messages(history)

    tokens: list[str] = []
    async for token in proxy_service.stream_chat(
        proxy, character, user_persona, api_messages
    ):
        tokens.append(token)

    full = "".join(tokens)
    msg = await conversation_service.add_message(
        db, conv.id, "assistant", full, proxy_id=proxy.id
    )
    await db.commit()
    return msg