import uuid

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.models import UserPersona
from app.schemas.schemas import UserPersonaCreate, UserPersonaUpdate


async def create_persona(db: AsyncSession, data: UserPersonaCreate) -> UserPersona:
    if data.is_default:
        await db.execute(update(UserPersona).values(is_default=False))

    persona = UserPersona(**data.model_dump())
    db.add(persona)
    await db.flush()
    await db.refresh(persona)
    return persona


async def get_persona(
    db: AsyncSession, persona_id: uuid.UUID
) -> UserPersona | None:
    result = await db.execute(
        select(UserPersona).where(UserPersona.id == persona_id)
    )
    return result.scalar_one_or_none()


async def list_personas(db: AsyncSession) -> list[UserPersona]:
    result = await db.execute(
        select(UserPersona).order_by(UserPersona.created_at)
    )
    return list(result.scalars().all())


async def update_persona(
    db: AsyncSession, persona_id: uuid.UUID, data: UserPersonaUpdate
) -> UserPersona | None:
    persona = await get_persona(db, persona_id)
    if not persona:
        return None

    patch = data.model_dump(exclude_unset=True)
    if patch.get("is_default"):
        await db.execute(
            update(UserPersona)
            .where(UserPersona.id != persona_id)
            .values(is_default=False)
        )

    for k, v in patch.items():
        setattr(persona, k, v)

    await db.flush()
    await db.refresh(persona)
    return persona


async def delete_persona(db: AsyncSession, persona_id: uuid.UUID) -> bool:
    persona = await get_persona(db, persona_id)
    if not persona:
        return False
    await db.delete(persona)
    return True


async def get_default_persona(db: AsyncSession) -> UserPersona | None:
    result = await db.execute(
        select(UserPersona).where(UserPersona.is_default.is_(True))
    )
    return result.scalar_one_or_none()