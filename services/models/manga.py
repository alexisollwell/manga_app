"""
SQLAlchemy models for the manga library database.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Column,
    String,
    Integer,
    DateTime,
    ForeignKey,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from database import Base


def generate_uuid():
    """Generate a new UUID4 string."""
    return str(uuid.uuid4())


def utc_now():
    """Get current UTC datetime."""
    return datetime.now(timezone.utc)


class Manga(Base):
    """
    Represents a manga in the shared library.
    Stores title, total volume count, and timestamps.
    Cover images are NOT stored on the server (local-only on each device).
    """

    __tablename__ = "mangas"

    id = Column(String, primary_key=True, default=generate_uuid)
    titulo = Column(String, nullable=False, unique=True)
    cantidad_tomos = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=utc_now)
    updated_at = Column(DateTime, default=utc_now, onupdate=utc_now)

    # Relationship to acquired volumes
    tomos_adquiridos = relationship(
        "TomoAdquirido",
        back_populates="manga",
        cascade="all, delete-orphan",
        lazy="joined",
    )

    def __repr__(self):
        return f"<Manga(id={self.id}, titulo='{self.titulo}', tomos={self.cantidad_tomos})>"


class TomoAdquirido(Base):
    """
    Represents a volume that has been acquired/marked by a user.
    Each volume can only be marked once per manga (shared ownership model).
    """

    __tablename__ = "tomos_adquiridos"

    id = Column(Integer, primary_key=True, autoincrement=True)
    manga_id = Column(
        String,
        ForeignKey("mangas.id", ondelete="CASCADE"),
        nullable=False,
    )
    numero_tomo = Column(Integer, nullable=False)
    usuario_id = Column(String, nullable=False)
    adquirido_at = Column(DateTime, default=utc_now)

    # Relationship back to manga
    manga = relationship("Manga", back_populates="tomos_adquiridos")

    # A volume can only be acquired once per manga
    __table_args__ = (
        UniqueConstraint("manga_id", "numero_tomo", name="uq_manga_tomo"),
    )

    def __repr__(self):
        return f"<TomoAdquirido(manga_id={self.manga_id}, tomo={self.numero_tomo}, usuario={self.usuario_id})>"
