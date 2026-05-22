from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    database_url: str = "postgresql+asyncpg://postgres:password@localhost:5432/aikira"
    sync_database_url: str = "postgresql+psycopg2://postgres:password@localhost:5432/aikira"
    host: str = "127.0.0.1"
    port: int = 7842
    default_proxy_name: str = ""


settings = Settings()