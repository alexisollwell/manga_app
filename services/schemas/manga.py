"""
Pydantic schemas for request validation and response serialization.
"""

from pydantic import BaseModel, Field, field_validator
from typing import Optional


# ──────────────────────────────────────────────
# Request Schemas
# ──────────────────────────────────────────────


class MangaCreate(BaseModel):
    """Schema for creating a new manga (CU-01)."""

    titulo: str = Field(..., min_length=1, max_length=255, description="Título del manga")
    cantidad_tomos: int = Field(..., ge=1, description="Cantidad total de tomos (≥1)")

    @field_validator("titulo")
    @classmethod
    def titulo_not_blank(cls, v: str) -> str:
        stripped = v.strip()
        if not stripped:
            raise ValueError("El título no puede estar vacío")
        return stripped


class MangaUpdate(BaseModel):
    """Schema for updating a manga (CU-04, CU-05)."""

    titulo: Optional[str] = Field(None, min_length=1, max_length=255)
    cantidad_tomos: Optional[int] = Field(None, ge=1)

    @field_validator("titulo")
    @classmethod
    def titulo_not_blank(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            stripped = v.strip()
            if not stripped:
                raise ValueError("El título no puede estar vacío")
            return stripped
        return v


class TomoAdquirirRequest(BaseModel):
    """Schema for marking a volume as acquired (CU-03)."""

    usuario_id: str = Field(..., min_length=1, description="Alias del usuario que adquiere el tomo")


# ──────────────────────────────────────────────
# Response Schemas
# ──────────────────────────────────────────────


class MangaResponse(BaseModel):
    """Response schema for a manga with its acquired volumes."""

    id: str
    titulo: str
    cantidad_tomos: int
    tomos_adquiridos: list[int] = []

    model_config = {"from_attributes": True}


class TomoResponse(BaseModel):
    """Response schema for a volume toggle action."""

    id: str
    tomo: int
    estado: str  # "adquirido" | "no_adquirido"


class ErrorResponse(BaseModel):
    """Standard error response."""

    detail: str
    manga_id: Optional[str] = None  # Included when a duplicate manga is found (CU-01 step 6a)
