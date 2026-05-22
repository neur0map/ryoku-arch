import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.schemas import (
    ProxyCreate,
    ProxyRead,
    ProxyTestResult,
    ProxyUpdate,
    StatusResponse,
)
from app.services import proxy_service

router = APIRouter(prefix="/proxies", tags=["proxies"])


@router.get("/", response_model=list[ProxyRead])
async def list_proxies(db: AsyncSession = Depends(get_db)):
    proxies = await proxy_service.list_proxies(db)
    return [ProxyRead.from_orm_masked(p) for p in proxies]


@router.post("/", response_model=ProxyRead, status_code=status.HTTP_201_CREATED)
async def create_proxy(data: ProxyCreate, db: AsyncSession = Depends(get_db)):
    proxy = await proxy_service.create_proxy(db, data)
    return ProxyRead.from_orm_masked(proxy)


@router.get("/{proxy_id}", response_model=ProxyRead)
async def get_proxy(proxy_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    proxy = await proxy_service.get_proxy(db, proxy_id)
    if not proxy:
        raise HTTPException(status_code=404, detail="Proxy not found")
    return ProxyRead.from_orm_masked(proxy)


@router.patch("/{proxy_id}", response_model=ProxyRead)
async def update_proxy(
    proxy_id: uuid.UUID, data: ProxyUpdate, db: AsyncSession = Depends(get_db)
):
    proxy = await proxy_service.update_proxy(db, proxy_id, data)
    if not proxy:
        raise HTTPException(status_code=404, detail="Proxy not found")
    return ProxyRead.from_orm_masked(proxy)


@router.delete("/{proxy_id}", response_model=StatusResponse)
async def delete_proxy(proxy_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    ok = await proxy_service.delete_proxy(db, proxy_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Proxy not found")
    return StatusResponse(ok=True, detail="Proxy deleted")


@router.post("/{proxy_id}/test", response_model=ProxyTestResult)
async def test_proxy(proxy_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    proxy = await proxy_service.get_proxy(db, proxy_id)
    if not proxy:
        raise HTTPException(status_code=404, detail="Proxy not found")
    ok, latency, error = await proxy_service.test_proxy(proxy)
    return ProxyTestResult(ok=ok, latency_ms=latency, error=error)