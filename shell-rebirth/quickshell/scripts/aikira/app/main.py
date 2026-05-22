from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.db.session import engine, Base
from app.routers import characters, chat, conversations, personas, proxies


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create tables on startup (Alembic handles migrations in production;
    # this is a convenience for fresh installs)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()


def create_app() -> FastAPI:
    app = FastAPI(
        title="Aikira",
        description="Local AI chat backend — OpenAI-compatible proxy, characters, personas, PostgreSQL storage.",
        version="1.0.0",
        lifespan=lifespan,
    )

    # Allow QuickShell / local frontends to call the API
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # tighten in production
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(proxies.router, prefix="/api/v1")
    app.include_router(characters.router, prefix="/api/v1")
    app.include_router(personas.router, prefix="/api/v1")
    app.include_router(conversations.router, prefix="/api/v1")
    app.include_router(chat.router, prefix="/api/v1")

    @app.get("/health", tags=["health"])
    async def health():
        return {"status": "ok"}

    return app


app = create_app()