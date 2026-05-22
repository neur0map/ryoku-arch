import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.schemas import (
    StatusResponse,
    UserPersonaCreate,
    UserPersonaRead,
    UserPersonaUpdate,
)
from app.services import persona_service

router = APIRouter(prefix="/personas", tags=["personas"])


@router.get("/", response_model=list[UserPersonaRead])
async def list_personas(db: AsyncSession = Depends(get_db)):
    return await persona_service.list_personas(db)


@router.post("/", response_model=UserPersonaRead, status_code=status.HTTP_201_CREATED)
async def create_persona(data: UserPersonaCreate, db: AsyncSession = Depends(get_db)):
    return await persona_service.create_persona(db, data)


@router.get("/{persona_id}", response_model=UserPersonaRead)
async def get_persona(persona_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    p = await persona_service.get_persona(db, persona_id)
    if not p:
        raise HTTPException(status_code=404, detail="Persona not found")
    return p


@router.patch("/{persona_id}", response_model=UserPersonaRead)
async def update_persona(
    persona_id: uuid.UUID, data: UserPersonaUpdate, db: AsyncSession = Depends(get_db)
):
    p = await persona_service.update_persona(db, persona_id, data)
    if not p:
        raise HTTPException(status_code=404, detail="Persona not found")
    return p


@router.delete("/{persona_id}", response_model=StatusResponse)
async def delete_persona(persona_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    ok = await persona_service.delete_persona(db, persona_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Persona not found")
    return StatusResponse(ok=True, detail="Persona deleted")