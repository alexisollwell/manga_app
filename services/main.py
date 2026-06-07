"""
Manga Library API — Main entry point.
Shared manga collection management server.
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import CORS_ORIGINS, CORS_ALLOW_METHODS, CORS_ALLOW_HEADERS
from database import init_db
from routes.manga_routes import router as manga_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize database tables on startup."""
    init_db()
    yield


app = FastAPI(
    title="Manga Library API",
    description=(
        "API para gestionar una biblioteca de mangas compartida. "
        "Permite crear, consultar, editar y eliminar mangas, "
        "así como marcar tomos como adquiridos."
    ),
    version="1.0.0",
    lifespan=lifespan,
)

# CORS middleware — allow connections from Flutter app on any local network IP
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=CORS_ALLOW_METHODS,
    allow_headers=CORS_ALLOW_HEADERS,
)

# Register routes
app.include_router(manga_router, prefix="/api")


@app.get("/", tags=["Health"])
def health_check():
    """Health check endpoint."""
    return {"status": "ok", "service": "Manga Library API", "version": "1.0.0"}
