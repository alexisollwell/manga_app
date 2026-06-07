"""
Manga Repository — Pure data access layer.
All database queries live here. No business logic.
"""

from typing import Optional
from sqlalchemy.orm import Session
from sqlalchemy import func

from models.manga import Manga, TomoAdquirido


class MangaRepository:
    """Handles all database operations for mangas and acquired volumes."""

    def __init__(self, db: Session):
        self.db = db

    # ──────────────────────────────────────────────
    # Manga CRUD
    # ──────────────────────────────────────────────

    def create(self, titulo: str, cantidad_tomos: int) -> Manga:
        """Create a new manga entry."""
        manga = Manga(titulo=titulo, cantidad_tomos=cantidad_tomos)
        self.db.add(manga)
        self.db.commit()
        self.db.refresh(manga)
        return manga

    def get_all(self) -> list[Manga]:
        """Get all mangas with their acquired volumes."""
        return self.db.query(Manga).order_by(Manga.titulo).all()

    def get_by_id(self, manga_id: str) -> Optional[Manga]:
        """Get a manga by its UUID."""
        return self.db.query(Manga).filter(Manga.id == manga_id).first()

    def get_by_titulo(self, titulo: str) -> Optional[Manga]:
        """
        Find a manga by title (case-insensitive, ignoring leading/trailing spaces).
        Used for duplicate validation (CU-01 step 6).
        """
        return (
            self.db.query(Manga)
            .filter(func.lower(func.trim(Manga.titulo)) == func.lower(titulo.strip()))
            .first()
        )

    def get_by_titulo_excluding(self, titulo: str, exclude_id: str) -> Optional[Manga]:
        """
        Find a manga by title excluding a specific ID.
        Used for rename validation (CU-05 step 6).
        """
        return (
            self.db.query(Manga)
            .filter(
                func.lower(func.trim(Manga.titulo)) == func.lower(titulo.strip()),
                Manga.id != exclude_id,
            )
            .first()
        )

    def update(self, manga: Manga, **kwargs) -> Manga:
        """Update manga fields."""
        for key, value in kwargs.items():
            if value is not None:
                setattr(manga, key, value)
        self.db.commit()
        self.db.refresh(manga)
        return manga

    def delete(self, manga: Manga) -> bool:
        """Delete a manga and all its acquired volumes (cascade)."""
        self.db.delete(manga)
        self.db.commit()
        return True

    # ──────────────────────────────────────────────
    # Tomos Adquiridos
    # ──────────────────────────────────────────────

    def get_tomo_adquirido(
        self, manga_id: str, numero_tomo: int
    ) -> Optional[TomoAdquirido]:
        """Check if a specific volume is already acquired."""
        return (
            self.db.query(TomoAdquirido)
            .filter(
                TomoAdquirido.manga_id == manga_id,
                TomoAdquirido.numero_tomo == numero_tomo,
            )
            .first()
        )

    def add_tomo_adquirido(
        self, manga_id: str, numero_tomo: int, usuario_id: str
    ) -> TomoAdquirido:
        """Mark a volume as acquired by a user."""
        tomo = TomoAdquirido(
            manga_id=manga_id,
            numero_tomo=numero_tomo,
            usuario_id=usuario_id,
        )
        self.db.add(tomo)
        self.db.commit()
        self.db.refresh(tomo)
        return tomo

    def remove_tomo_adquirido(self, tomo: TomoAdquirido) -> bool:
        """Remove an acquired volume record."""
        self.db.delete(tomo)
        self.db.commit()
        return True

    def get_tomos_adquiridos(self, manga_id: str) -> list[int]:
        """Get list of acquired volume numbers for a manga."""
        tomos = (
            self.db.query(TomoAdquirido.numero_tomo)
            .filter(TomoAdquirido.manga_id == manga_id)
            .order_by(TomoAdquirido.numero_tomo)
            .all()
        )
        return [t[0] for t in tomos]
