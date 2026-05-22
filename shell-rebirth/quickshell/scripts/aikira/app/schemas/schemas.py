import uuid
from datetime import datetime

from pydantic import BaseModel, Field, HttpUrl, field_validator

class ProxyBase(BaseModel):
    name: str = Field(..., max_length=120)
    endpoint_url: str = Field(..., description="OpenAI-compatible base URL, e.g. https://openrouter.ai/api/v1")
    model_name: str = Field(..., max_length=256, description="Model string passed to the API, e.g. mistralai/mistral-7b-instruct")
    api_key: str = Field(..., description="Bearer token / API key for this proxy")
    is_default: bool = False
    temperature: float = Field(0.8, ge=0.0, le=2.0)
    max_tokens: int = Field(2048, ge=1, le=128000)


class ProxyCreate(ProxyBase):
    pass


class ProxyUpdate(BaseModel):
    name: str | None = Field(None, max_length=120)
    endpoint_url: str | None = None
    model_name: str | None = None
    api_key: str | None = None
    is_default: bool | None = None
    temperature: float | None = Field(None, ge=0.0, le=2.0)
    max_tokens: int | None = Field(None, ge=1, le=128000)


class ProxyRead(ProxyBase):
    id: uuid.UUID
    created_at: datetime
    updated_at: datetime

    # Never expose the raw key — mask it
    api_key: str = ""

    model_config = {"from_attributes": True}

    @classmethod
    def from_orm_masked(cls, obj) -> "ProxyRead":
        d = {c.name: getattr(obj, c.name) for c in obj.__table__.columns}
        raw: str = d.get("api_key", "")
        if len(raw) > 8:
            d["api_key"] = raw[:4] + "•" * (len(raw) - 8) + raw[-4:]
        else:
            d["api_key"] = "••••••••"
        return cls(**d)


class CharacterBase(BaseModel):
    name: str = Field(..., max_length=120)
    description: str = ""
    personality: str = ""
    scenario: str = ""
    first_message: str = ""
    avatar_path: str | None = None
    temperature: float | None = Field(None, ge=0.0, le=2.0)
    max_tokens: int | None = Field(None, ge=1, le=128000)
    proxy_id: uuid.UUID | None = None


class CharacterCreate(CharacterBase):
    pass


class CharacterUpdate(BaseModel):
    name: str | None = Field(None, max_length=120)
    description: str | None = None
    personality: str | None = None
    scenario: str | None = None
    first_message: str | None = None
    avatar_path: str | None = None
    temperature: float | None = Field(None, ge=0.0, le=2.0)
    max_tokens: int | None = Field(None, ge=1, le=128000)
    proxy_id: uuid.UUID | None = None


class CharacterRead(CharacterBase):
    id: uuid.UUID
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

class UserPersonaBase(BaseModel):
    name: str = Field(..., max_length=120)
    description: str = ""
    is_default: bool = False
    avatar_path: str | None = None


class UserPersonaCreate(UserPersonaBase):
    pass


class UserPersonaUpdate(BaseModel):
    name: str | None = Field(None, max_length=120)
    description: str | None = None
    is_default: bool | None = None
    avatar_path: str | None = None


class UserPersonaRead(UserPersonaBase):
    id: uuid.UUID
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ConversationCreate(BaseModel):
    character_id: uuid.UUID
    user_persona_id: uuid.UUID | None = None
    title: str = "New Chat"
    first_message: str | None = None


class ConversationUpdate(BaseModel):
    title: str | None = None
    user_persona_id: uuid.UUID | None = None


class ConversationRead(BaseModel):
    id: uuid.UUID
    title: str
    character_id: uuid.UUID
    user_persona_id: uuid.UUID | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Message schemas
# ---------------------------------------------------------------------------

class MessageRead(BaseModel):
    id: uuid.UUID
    role: str
    content: str
    prompt_tokens: int | None
    completion_tokens: int | None
    proxy_id: uuid.UUID | None
    conversation_id: uuid.UUID
    created_at: datetime

    model_config = {"from_attributes": True}


class ChatRequest(BaseModel):
    conversation_id: uuid.UUID
    content: str = Field(..., min_length=1, description="The user's message text")
    # Optionally override which proxy to use for this single turn
    proxy_id: uuid.UUID | None = None


class RerollRequest(BaseModel):
    conversation_id: uuid.UUID
    proxy_id: uuid.UUID | None = None


class StatusResponse(BaseModel):
    ok: bool
    detail: str = ""


class ProxyTestResult(BaseModel):
    ok: bool
    latency_ms: float | None = None
    error: str | None = None