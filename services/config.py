"""
Application configuration.
Uses pydantic-settings to load configuration from environment variables or a .env file.
"""

import os
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    DATABASE_DIR: str = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    
    # CORS
    CORS_ORIGINS: list[str] = ["*"]
    CORS_ALLOW_METHODS: list[str] = ["*"]
    CORS_ALLOW_HEADERS: list[str] = ["*"]

# Instantiate settings
settings = Settings()

# Backwards compatibility imports
DATABASE_DIR = settings.DATABASE_DIR
DATABASE_URL = f"sqlite:///{DATABASE_DIR}/manga_library.db"
HOST = settings.HOST
PORT = settings.PORT
CORS_ORIGINS = settings.CORS_ORIGINS
CORS_ALLOW_METHODS = settings.CORS_ALLOW_METHODS
CORS_ALLOW_HEADERS = settings.CORS_ALLOW_HEADERS
