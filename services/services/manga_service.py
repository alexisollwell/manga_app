"""
Manga Service — Business logic layer.
Handles validation rules defined in the use cases (CU-01 through CU-07).
"""

from fastapi import HTTPException, status

from repositories.manga_repository import MangaRepository
from schemas.manga import MangaCreate, MangaUpdate, MangaResponse, TomoResponse


class MangaService:
    """
    Business logic for manga operations.
    Each method maps to one or more use cases from test_cases.md.
    """

    def __init__(self, repo: MangaRepository):
        self.repo = repo

    # ──────────────────────────────────────────────
    # CU-01: Dar de Alta un Manga
    # ──────────────────────────────────────────────

    def crear_manga(self, data: MangaCreate) -> MangaResponse:
        """
        Create a new manga. Validates that no manga with the same title exists
        (case-insensitive comparison, CU-01 step 6).
        """
        # Check for duplicate title
        existing = self.repo.get_by_titulo(data.titulo)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "message": "Ya existe un manga con este título",
                    "manga_id": existing.id,
                },
            )

        manga = self.repo.create(
            titulo=data.titulo,
            cantidad_tomos=data.cantidad_tomos,
        )

        return self._to_response(manga)

    # ──────────────────────────────────────────────
    # CU-02: Consultar Mangas con Filtros
    # ──────────────────────────────────────────────

    def obtener_mangas(self) -> list[MangaResponse]:
        """
        Get all mangas with their acquired volumes.
        Filtering is handled client-side per CU-02 step 5a.
        """
        mangas = self.repo.get_all()
        return [self._to_response(m) for m in mangas]

    def obtener_manga(self, manga_id: str) -> MangaResponse:
        """Get a single manga by ID."""
        manga = self._get_manga_or_404(manga_id)
        return self._to_response(manga)

    # ──────────────────────────────────────────────
    # CU-03: Marcar / Desmarcar Tomo
    # ──────────────────────────────────────────────

    def marcar_tomo(
        self, manga_id: str, numero_tomo: int, usuario_id: str
    ) -> TomoResponse:
        """
        Mark a volume as acquired (CU-03).
        Validates that the volume number is within range.
        """
        manga = self._get_manga_or_404(manga_id)

        # Validate volume number is within range
        if numero_tomo < 1 or numero_tomo > manga.cantidad_tomos:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"El número de tomo debe estar entre 1 y {manga.cantidad_tomos}",
            )

        # Check if already acquired
        existing = self.repo.get_tomo_adquirido(manga_id, numero_tomo)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"El tomo {numero_tomo} ya está marcado como adquirido",
            )

        self.repo.add_tomo_adquirido(manga_id, numero_tomo, usuario_id)

        return TomoResponse(id=manga_id, tomo=numero_tomo, estado="adquirido")

    def desmarcar_tomo(self, manga_id: str, numero_tomo: int) -> TomoResponse:
        """
        Unmark a volume as acquired (CU-03 alternative flow).
        """
        self._get_manga_or_404(manga_id)

        tomo = self.repo.get_tomo_adquirido(manga_id, numero_tomo)
        if not tomo:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"El tomo {numero_tomo} no está marcado como adquirido",
            )

        self.repo.remove_tomo_adquirido(tomo)

        return TomoResponse(id=manga_id, tomo=numero_tomo, estado="no_adquirido")

    # ──────────────────────────────────────────────
    # CU-04 & CU-05: Editar Manga (tomos / título)
    # ──────────────────────────────────────────────

    def actualizar_manga(self, manga_id: str, data: MangaUpdate) -> MangaResponse:
        """
        Update a manga's title and/or volume count.
        - Title: validates no duplicate exists (CU-05 step 6).
        - Volume count: must be >= current count (CU-04 step 4a).
        """
        manga = self._get_manga_or_404(manga_id)

        # Validate title uniqueness if changing title
        if data.titulo is not None:
            existing = self.repo.get_by_titulo_excluding(data.titulo, manga_id)
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Ya existe un manga con este título",
                )

        # Validate volume count doesn't decrease (CU-04 step 4a)
        if data.cantidad_tomos is not None:
            if data.cantidad_tomos < manga.cantidad_tomos:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=(
                        f"La cantidad de tomos no puede ser menor a la actual "
                        f"({manga.cantidad_tomos})"
                    ),
                )

        # Apply updates
        update_fields = {}
        if data.titulo is not None:
            update_fields["titulo"] = data.titulo
        if data.cantidad_tomos is not None:
            update_fields["cantidad_tomos"] = data.cantidad_tomos

        if update_fields:
            manga = self.repo.update(manga, **update_fields)

        return self._to_response(manga)

    # ──────────────────────────────────────────────
    # CU-07: Eliminar un Manga
    # ──────────────────────────────────────────────

    def eliminar_manga(self, manga_id: str) -> dict:
        """
        Delete a manga and all its acquired volumes (cascade).
        Returns 404 if manga doesn't exist (CU-07 step 6a).
        """
        manga = self._get_manga_or_404(manga_id)
        self.repo.delete(manga)
        return {"message": "Manga eliminado correctamente"}

    # ──────────────────────────────────────────────
    # Helpers
    # ──────────────────────────────────────────────

    def _get_manga_or_404(self, manga_id: str):
        """Get a manga by ID or raise 404."""
        manga = self.repo.get_by_id(manga_id)
        if not manga:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Manga no encontrado",
            )
        return manga

    def _to_response(self, manga) -> MangaResponse:
        """Convert a Manga ORM object to a MangaResponse schema."""
        tomos = sorted([t.numero_tomo for t in manga.tomos_adquiridos])
        return MangaResponse(
            id=manga.id,
            titulo=manga.titulo,
            cantidad_tomos=manga.cantidad_tomos,
            tomos_adquiridos=tomos,
        )
