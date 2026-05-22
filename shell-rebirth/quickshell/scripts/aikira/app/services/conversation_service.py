import uuid

from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.models import Conversation, Message
from app.schemas.schemas import ConversationCreate, ConversationUpdate

async def create_conversation(
    db: AsyncSession, data: ConversationCreate
) -> Conversation:
    conv = Conversation(**data.model_dump(exclude={"first_message"}))
    db.add(conv)
    await db.flush()
    await db.refresh(conv)
    return conv


async def get_conversation(
    db: AsyncSession, conv_id: uuid.UUID
) -> Conversation | None:
    result = await db.execute(
        select(Conversation)
        .options(
            selectinload(Conversation.character),
            selectinload(Conversation.user_persona),
            selectinload(Conversation.messages),
        )
        .where(Conversation.id == conv_id)
    )
    return result.scalar_one_or_none()


async def list_conversations(
    db: AsyncSession,
    character_id: uuid.UUID | None = None,
) -> list[Conversation]:
    q = select(Conversation).options(
        selectinload(Conversation.character),
        selectinload(Conversation.user_persona),
    )
    if character_id:
        q = q.where(Conversation.character_id == character_id)
    q = q.order_by(Conversation.updated_at.desc())
    result = await db.execute(q)
    return list(result.scalars().all())


async def update_conversation(
    db: AsyncSession, conv_id: uuid.UUID, data: ConversationUpdate
) -> Conversation | None:
    conv = await get_conversation(db, conv_id)
    if not conv:
        return None
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(conv, k, v)
    await db.flush()
    await db.refresh(conv)
    return conv


async def delete_conversation(db: AsyncSession, conv_id: uuid.UUID) -> bool:
    conv = await get_conversation(db, conv_id)
    if not conv:
        return False
    await db.delete(conv)
    return True

async def add_message(
    db: AsyncSession,
    conv_id: uuid.UUID,
    role: str,
    content: str,
    proxy_id: uuid.UUID | None = None,
    prompt_tokens: int | None = None,
    completion_tokens: int | None = None,
) -> Message:
    msg = Message(
        conversation_id=conv_id,
        role=role,
        content=content,
        proxy_id=proxy_id,
        prompt_tokens=prompt_tokens,
        completion_tokens=completion_tokens,
    )
    db.add(msg)
    await db.flush()
    await db.refresh(msg)
    return msg


async def get_messages(
    db: AsyncSession, conv_id: uuid.UUID
) -> list[Message]:
    result = await db.execute(
        select(Message)
        .where(Message.conversation_id == conv_id)
        .order_by(Message.created_at)
    )
    return list(result.scalars().all())


async def delete_last_assistant_message(db: AsyncSession, conv_id: uuid.UUID) -> bool:
    result = await db.execute(
        select(Message)
        .where(Message.conversation_id == conv_id, Message.role == "assistant")
        .order_by(Message.created_at.desc())
        .limit(1)
    )
    msg = result.scalar_one_or_none()
    if not msg:
        return False
    await db.delete(msg)
    await db.flush()
    return True


async def delete_message(db: AsyncSession, msg_id: uuid.UUID) -> bool:
    result = await db.execute(select(Message).where(Message.id == msg_id))
    msg = result.scalar_one_or_none()
    if not msg:
        return False
    # Delete this message and all subsequent ones in the same conversation
    await db.execute(
        delete(Message).where(
            Message.conversation_id == msg.conversation_id,
            Message.created_at >= msg.created_at,
        )
    )
    return True


def build_api_messages(messages: list[Message]) -> list[dict[str, str]]:
    """Convert stored Message rows into the list format expected by the LLM API."""
    return [{"role": m.role, "content": m.content} for m in messages]