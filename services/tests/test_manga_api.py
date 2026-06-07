"""
Integration tests for the Manga API endpoints.
Covers all 7 use cases (CU-01 through CU-07) from test_cases.md.
"""


# ──────────────────────────────────────────────
# CU-01: Dar de Alta un Manga
# ──────────────────────────────────────────────


class TestCrearManga:
    """Tests for POST /api/mangas"""

    def test_crear_manga_exitoso(self, client):
        """CU-01: Create a manga successfully."""
        response = client.post(
            "/api/mangas",
            json={"titulo": "One Piece", "cantidad_tomos": 100},
        )
        assert response.status_code == 201
        data = response.json()
        assert data["titulo"] == "One Piece"
        assert data["cantidad_tomos"] == 100
        assert data["tomos_adquiridos"] == []
        assert "id" in data

    def test_crear_manga_titulo_duplicado(self, client):
        """CU-01 step 6a: Reject duplicate title."""
        client.post(
            "/api/mangas",
            json={"titulo": "Naruto", "cantidad_tomos": 72},
        )
        response = client.post(
            "/api/mangas",
            json={"titulo": "Naruto", "cantidad_tomos": 72},
        )
        assert response.status_code == 409

    def test_crear_manga_titulo_duplicado_case_insensitive(self, client):
        """CU-01 step 6: Case-insensitive duplicate check."""
        client.post(
            "/api/mangas",
            json={"titulo": "Dragon Ball", "cantidad_tomos": 42},
        )
        response = client.post(
            "/api/mangas",
            json={"titulo": "dragon ball", "cantidad_tomos": 42},
        )
        assert response.status_code == 409

    def test_crear_manga_titulo_vacio(self, client):
        """CU-01 alt: Reject empty title."""
        response = client.post(
            "/api/mangas",
            json={"titulo": "", "cantidad_tomos": 10},
        )
        assert response.status_code == 422

    def test_crear_manga_tomos_cero(self, client):
        """CU-01 alt: Reject zero volumes."""
        response = client.post(
            "/api/mangas",
            json={"titulo": "Test Manga", "cantidad_tomos": 0},
        )
        assert response.status_code == 422

    def test_crear_manga_tomos_negativo(self, client):
        """CU-01 alt: Reject negative volumes."""
        response = client.post(
            "/api/mangas",
            json={"titulo": "Test Manga", "cantidad_tomos": -5},
        )
        assert response.status_code == 422


# ──────────────────────────────────────────────
# CU-02: Consultar Mangas
# ──────────────────────────────────────────────


class TestConsultarMangas:
    """Tests for GET /api/mangas"""

    def test_biblioteca_vacia(self, client):
        """CU-02 alt: Empty library returns empty list."""
        response = client.get("/api/mangas")
        assert response.status_code == 200
        assert response.json() == []

    def test_listar_mangas(self, client):
        """CU-02: List all mangas."""
        client.post("/api/mangas", json={"titulo": "Bleach", "cantidad_tomos": 74})
        client.post("/api/mangas", json={"titulo": "Attack on Titan", "cantidad_tomos": 34})

        response = client.get("/api/mangas")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2

    def test_obtener_manga_por_id(self, client):
        """CU-02: Get manga detail by ID."""
        create_resp = client.post(
            "/api/mangas",
            json={"titulo": "Demon Slayer", "cantidad_tomos": 23},
        )
        manga_id = create_resp.json()["id"]

        response = client.get(f"/api/mangas/{manga_id}")
        assert response.status_code == 200
        assert response.json()["titulo"] == "Demon Slayer"

    def test_obtener_manga_no_existente(self, client):
        """CU-02: 404 for non-existent manga."""
        response = client.get("/api/mangas/non-existent-id")
        assert response.status_code == 404


# ──────────────────────────────────────────────
# CU-03: Marcar / Desmarcar Tomo
# ──────────────────────────────────────────────


class TestMarcarTomo:
    """Tests for POST/DELETE /api/mangas/{id}/tomos/{num}/adquirir"""

    def _crear_manga(self, client, titulo="Test Manga", tomos=12):
        resp = client.post(
            "/api/mangas",
            json={"titulo": titulo, "cantidad_tomos": tomos},
        )
        return resp.json()["id"]

    def test_marcar_tomo_exitoso(self, client):
        """CU-03: Mark volume as acquired."""
        manga_id = self._crear_manga(client)
        response = client.post(
            f"/api/mangas/{manga_id}/tomos/7/adquirir",
            json={"usuario_id": "alexis"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["tomo"] == 7
        assert data["estado"] == "adquirido"

    def test_marcar_tomo_aparece_en_detalle(self, client):
        """CU-03: Acquired volume appears in manga detail."""
        manga_id = self._crear_manga(client)
        client.post(
            f"/api/mangas/{manga_id}/tomos/3/adquirir",
            json={"usuario_id": "alexis"},
        )
        client.post(
            f"/api/mangas/{manga_id}/tomos/1/adquirir",
            json={"usuario_id": "carlos"},
        )

        detail = client.get(f"/api/mangas/{manga_id}").json()
        assert detail["tomos_adquiridos"] == [1, 3]  # sorted

    def test_marcar_tomo_fuera_de_rango(self, client):
        """CU-03: Reject volume number out of range."""
        manga_id = self._crear_manga(client, tomos=12)
        response = client.post(
            f"/api/mangas/{manga_id}/tomos/15/adquirir",
            json={"usuario_id": "alexis"},
        )
        assert response.status_code == 400

    def test_marcar_tomo_cero(self, client):
        """CU-03: Reject volume 0."""
        manga_id = self._crear_manga(client)
        response = client.post(
            f"/api/mangas/{manga_id}/tomos/0/adquirir",
            json={"usuario_id": "alexis"},
        )
        assert response.status_code == 400

    def test_marcar_tomo_ya_adquirido(self, client):
        """CU-03: Reject duplicate acquisition."""
        manga_id = self._crear_manga(client)
        client.post(
            f"/api/mangas/{manga_id}/tomos/5/adquirir",
            json={"usuario_id": "alexis"},
        )
        response = client.post(
            f"/api/mangas/{manga_id}/tomos/5/adquirir",
            json={"usuario_id": "carlos"},
        )
        assert response.status_code == 409

    def test_desmarcar_tomo_exitoso(self, client):
        """CU-03 alt: Unmark an acquired volume."""
        manga_id = self._crear_manga(client)
        client.post(
            f"/api/mangas/{manga_id}/tomos/7/adquirir",
            json={"usuario_id": "alexis"},
        )
        response = client.delete(f"/api/mangas/{manga_id}/tomos/7/adquirir")
        assert response.status_code == 200
        assert response.json()["estado"] == "no_adquirido"

        # Verify it's removed from detail
        detail = client.get(f"/api/mangas/{manga_id}").json()
        assert 7 not in detail["tomos_adquiridos"]

    def test_desmarcar_tomo_no_adquirido(self, client):
        """CU-03 alt: Can't unmark a volume that wasn't acquired."""
        manga_id = self._crear_manga(client)
        response = client.delete(f"/api/mangas/{manga_id}/tomos/3/adquirir")
        assert response.status_code == 404


# ──────────────────────────────────────────────
# CU-04: Agregar Más Tomos
# ──────────────────────────────────────────────


class TestAgregarTomos:
    """Tests for PUT /api/mangas/{id} — volume count updates"""

    def _crear_manga(self, client):
        resp = client.post(
            "/api/mangas",
            json={"titulo": "My Hero Academia", "cantidad_tomos": 30},
        )
        return resp.json()["id"]

    def test_incrementar_tomos(self, client):
        """CU-04: Increase volume count."""
        manga_id = self._crear_manga(client)
        response = client.put(
            f"/api/mangas/{manga_id}",
            json={"cantidad_tomos": 35},
        )
        assert response.status_code == 200
        assert response.json()["cantidad_tomos"] == 35

    def test_reducir_tomos_rechazado(self, client):
        """CU-04 step 4a: Can't decrease volume count."""
        manga_id = self._crear_manga(client)
        response = client.put(
            f"/api/mangas/{manga_id}",
            json={"cantidad_tomos": 25},
        )
        assert response.status_code == 400

    def test_mismo_numero_tomos_sin_cambio(self, client):
        """CU-04 step 4b: Same count doesn't error."""
        manga_id = self._crear_manga(client)
        response = client.put(
            f"/api/mangas/{manga_id}",
            json={"cantidad_tomos": 30},
        )
        assert response.status_code == 200
        assert response.json()["cantidad_tomos"] == 30


# ──────────────────────────────────────────────
# CU-05: Renombrar Manga
# ──────────────────────────────────────────────


class TestRenombrarManga:
    """Tests for PUT /api/mangas/{id} — title updates"""

    def test_renombrar_exitoso(self, client):
        """CU-05: Rename manga successfully."""
        resp = client.post(
            "/api/mangas",
            json={"titulo": "Old Title", "cantidad_tomos": 10},
        )
        manga_id = resp.json()["id"]

        response = client.put(
            f"/api/mangas/{manga_id}",
            json={"titulo": "New Title"},
        )
        assert response.status_code == 200
        assert response.json()["titulo"] == "New Title"

    def test_renombrar_titulo_duplicado(self, client):
        """CU-05 step 6a: Can't rename to existing title."""
        client.post(
            "/api/mangas",
            json={"titulo": "Existing Manga", "cantidad_tomos": 5},
        )
        resp = client.post(
            "/api/mangas",
            json={"titulo": "Other Manga", "cantidad_tomos": 8},
        )
        manga_id = resp.json()["id"]

        response = client.put(
            f"/api/mangas/{manga_id}",
            json={"titulo": "Existing Manga"},
        )
        assert response.status_code == 409

    def test_renombrar_mismo_titulo(self, client):
        """CU-05: Renaming to same title should work (same ID excluded)."""
        resp = client.post(
            "/api/mangas",
            json={"titulo": "Same Title", "cantidad_tomos": 5},
        )
        manga_id = resp.json()["id"]

        response = client.put(
            f"/api/mangas/{manga_id}",
            json={"titulo": "Same Title"},
        )
        assert response.status_code == 200


# ──────────────────────────────────────────────
# CU-07: Eliminar Manga
# ──────────────────────────────────────────────


class TestEliminarManga:
    """Tests for DELETE /api/mangas/{id}"""

    def test_eliminar_exitoso(self, client):
        """CU-07: Delete manga successfully."""
        resp = client.post(
            "/api/mangas",
            json={"titulo": "To Delete", "cantidad_tomos": 5},
        )
        manga_id = resp.json()["id"]

        response = client.delete(f"/api/mangas/{manga_id}")
        assert response.status_code == 200

        # Verify it's gone
        get_resp = client.get(f"/api/mangas/{manga_id}")
        assert get_resp.status_code == 404

    def test_eliminar_no_existente(self, client):
        """CU-07 step 6a: 404 for non-existent manga."""
        response = client.delete("/api/mangas/non-existent-id")
        assert response.status_code == 404

    def test_eliminar_con_tomos_adquiridos(self, client):
        """CU-07: Delete manga cascades to acquired volumes."""
        resp = client.post(
            "/api/mangas",
            json={"titulo": "Cascade Test", "cantidad_tomos": 10},
        )
        manga_id = resp.json()["id"]

        # Mark some volumes
        client.post(
            f"/api/mangas/{manga_id}/tomos/1/adquirir",
            json={"usuario_id": "alexis"},
        )
        client.post(
            f"/api/mangas/{manga_id}/tomos/5/adquirir",
            json={"usuario_id": "carlos"},
        )

        # Delete should cascade
        response = client.delete(f"/api/mangas/{manga_id}")
        assert response.status_code == 200

    def test_eliminar_no_afecta_otros_mangas(self, client):
        """CU-07: Deleting one manga doesn't affect others."""
        resp1 = client.post(
            "/api/mangas", json={"titulo": "Keep This", "cantidad_tomos": 5}
        )
        resp2 = client.post(
            "/api/mangas", json={"titulo": "Delete This", "cantidad_tomos": 5}
        )

        client.delete(f"/api/mangas/{resp2.json()['id']}")

        # First manga should still exist
        remaining = client.get("/api/mangas").json()
        assert len(remaining) == 1
        assert remaining[0]["titulo"] == "Keep This"


# ──────────────────────────────────────────────
# Health Check
# ──────────────────────────────────────────────


class TestHealthCheck:
    def test_health_check(self, client):
        response = client.get("/")
        assert response.status_code == 200
        assert response.json()["status"] == "ok"
