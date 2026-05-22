import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.models import Character
from app.schemas.schemas import CharacterCreate, CharacterUpdate


async def create_character(db: AsyncSession, data: CharacterCreate) -> Character:
    char = Character(**data.model_dump())
    db.add(char)
    await db.flush()
    await db.refresh(char)
    return char


async def get_character(
    db: AsyncSession, character_id: uuid.UUID
) -> Character | None:
    result = await db.execute(
        select(Character)
        .options(selectinload(Character.proxy))
        .where(Character.id == character_id)
    )
    return result.scalar_one_or_none()


async def list_characters(db: AsyncSession) -> list[Character]:
    result = await db.execute(
        select(Character)
        .options(selectinload(Character.proxy))
        .order_by(Character.created_at)
    )
    return list(result.scalars().all())


async def update_character(
    db: AsyncSession, character_id: uuid.UUID, data: CharacterUpdate
) -> Character | None:
    char = await get_character(db, character_id)
    if not char:
        return None
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(char, k, v)
    await db.flush()
    await db.refresh(char)
    return char


async def delete_character(db: AsyncSession, character_id: uuid.UUID) -> bool:
    char = await get_character(db, character_id)
    if not char:
        return False
    await db.delete(char)
    return True