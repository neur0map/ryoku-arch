import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.schemas import (
    ConversationCreate,
    ConversationRead,
    ConversationUpdate,
    MessageRead,
    StatusResponse,
)
from app.services import conversation_service

router = APIRouter(prefix="/conversations", tags=["conversations"])


@router.get("/", response_model=list[ConversationRead])
async def list_conversations(
    character_id: uuid.UUID | None = None,
    db: AsyncSession = Depends(get_db),
):
    return await conversation_service.list_conversations(db, character_id=character_id)


@router.post("/", response_model=ConversationRead, status_code=status.HTTP_201_CREATED)
async def create_conversation(
    data: ConversationCreate, db: AsyncSession = Depends(get_db)
):
    conv = await conversation_service.create_conversation(db, data)
    if data.first_message:
        await conversation_service.add_message(db, conv.id, "assistant", data.first_message)
    return conv


@router.get("/{conv_id}", response_model=ConversationRead)
async def get_conversation(conv_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    conv = await conversation_service.get_conversation(db, conv_id)
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return conv


@router.patch("/{conv_id}", response_model=ConversationRead)
async def update_conversation(
    conv_id: uuid.UUID,
    data: ConversationUpdate,
    db: AsyncSession = Depends(get_db),
):
    conv = await conversation_service.update_conversation(db, conv_id, data)
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return conv


@router.delete("/{conv_id}", response_model=StatusResponse)
async def delete_conversation(conv_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    ok = await conversation_service.delete_conversation(db, conv_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return StatusResponse(ok=True, detail="Conversation deleted")


@router.get("/{conv_id}/messages", response_model=list[MessageRead])
async def get_messages(conv_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    conv = await conversation_service.get_conversation(db, conv_id)
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return await conversation_service.get_messages(db, conv_id)


@router.delete("/{conv_id}/messages/{msg_id}", response_model=StatusResponse)
async def delete_message(
    conv_id: uuid.UUID, msg_id: uuid.UUID, db: AsyncSession = Depends(get_db)
):
    ok = await conversation_service.delete_message(db, msg_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Message not found")
    return StatusResponse(ok=True, detail="Message deleted")