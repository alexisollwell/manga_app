"""
Manga API Routes — HTTP endpoint definitions.
Maps HTTP methods to service methods. No business logic here.
"""

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from database import get_db
from repositories.manga_repository import MangaRepository
from services.manga_service import MangaService
from schemas.manga import (
    MangaCreate,
    MangaUpdate,
    MangaResponse,
    TomoAdquirirRequest,
    TomoResponse,
)

router = APIRouter(prefix="/mangas", tags=["Mangas"])


def get_service(db: Session = Depends(get_db)) -> MangaService:
    """Dependency injection: creates MangaService with its repository."""
    repo = MangaRepository(db)
    return MangaService(repo)


# ──────────────────────────────────────────────
# CU-01: Dar de Alta un Manga
# ──────────────────────────────────────────────


@router.post(
    "",
    response_model=MangaResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear un nuevo manga",
    description="Agrega un nuevo manga a la biblioteca compartida (CU-01).",
)
def crear_manga(
    data: MangaCreate,
    service: MangaService = Depends(get_service),
):
    return service.crear_manga(data)


# ──────────────────────────────────────────────
# CU-02: Consultar Mangas
# ──────────────────────────────────────────────


@router.get(
    "",
    response_model=list[MangaResponse],
    summary="Listar todos los mangas",
    description="Obtiene la lista completa de mangas con sus tomos adquiridos (CU-02).",
)
def obtener_mangas(
    service: MangaService = Depends(get_service),
):
    return service.obtener_mangas()


@router.get(
    "/{manga_id}",
    response_model=MangaResponse,
    summary="Obtener detalle de un manga",
    description="Obtiene la información completa de un manga por su ID.",
)
def obtener_manga(
    manga_id: str,
    service: MangaService = Depends(get_service),
):
    return service.obtener_manga(manga_id)


# ──────────────────────────────────────────────
# CU-03: Marcar / Desmarcar Tomo
# ──────────────────────────────────────────────


@router.post(
    "/{manga_id}/tomos/{numero_tomo}/adquirir",
    response_model=TomoResponse,
    status_code=status.HTTP_200_OK,
    summary="Marcar tomo como adquirido",
    description="Marca un tomo específico como adquirido por un usuario (CU-03).",
)
def marcar_tomo(
    manga_id: str,
    numero_tomo: int,
    data: TomoAdquirirRequest,
    service: MangaService = Depends(get_service),
):
    return service.marcar_tomo(manga_id, numero_tomo, data.usuario_id)


@router.delete(
    "/{manga_id}/tomos/{numero_tomo}/adquirir",
    response_model=TomoResponse,
    summary="Desmarcar tomo adquirido",
    description="Desmarca un tomo previamente marcado como adquirido (CU-03 alternativo).",
)
def desmarcar_tomo(
    manga_id: str,
    numero_tomo: int,
    service: MangaService = Depends(get_service),
):
    return service.desmarcar_tomo(manga_id, numero_tomo)


# ──────────────────────────────────────────────
# CU-04 & CU-05: Editar Manga
# ──────────────────────────────────────────────


@router.put(
    "/{manga_id}",
    response_model=MangaResponse,
    summary="Editar un manga",
    description="Actualiza el título y/o la cantidad de tomos de un manga (CU-04, CU-05).",
)
def actualizar_manga(
    manga_id: str,
    data: MangaUpdate,
    service: MangaService = Depends(get_service),
):
    return service.actualizar_manga(manga_id, data)


# ──────────────────────────────────────────────
# CU-07: Eliminar Manga
# ──────────────────────────────────────────────


@router.delete(
    "/{manga_id}",
    status_code=status.HTTP_200_OK,
    summary="Eliminar un manga",
    description="Elimina un manga y todos sus tomos adquiridos de la biblioteca (CU-07).",
)
def eliminar_manga(
    manga_id: str,
    service: MangaService = Depends(get_service),
):
    return service.eliminar_manga(manga_id)
