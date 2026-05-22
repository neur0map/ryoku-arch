import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.schemas import CharacterCreate, CharacterRead, CharacterUpdate, StatusResponse
from app.services import character_service

router = APIRouter(prefix="/characters", tags=["characters"])


@router.get("/", response_model=list[CharacterRead])
async def list_characters(db: AsyncSession = Depends(get_db)):
    return await character_service.list_characters(db)


@router.post("/", response_model=CharacterRead, status_code=status.HTTP_201_CREATED)
async def create_character(data: CharacterCreate, db: AsyncSession = Depends(get_db)):
    return await character_service.create_character(db, data)


@router.get("/{character_id}", response_model=CharacterRead)
async def get_character(character_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    char = await character_service.get_character(db, character_id)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    return char


@router.patch("/{character_id}", response_model=CharacterRead)
async def update_character(
    character_id: uuid.UUID, data: CharacterUpdate, db: AsyncSession = Depends(get_db)
):
    char = await character_service.update_character(db, character_id, data)
    if not char:
        raise HTTPException(status_code=404, detail="Character not found")
    return char


@router.delete("/{character_id}", response_model=StatusResponse)
async def delete_character(
    character_id: uuid.UUID, db: AsyncSession = Depends(get_db)
):
    ok = await character_service.delete_character(db, character_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Character not found")
    return StatusResponse(ok=True, detail="Character deleted")