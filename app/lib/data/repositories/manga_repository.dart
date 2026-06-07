/// Manga Repository — Orchestrates local and remote data sources.
/// Implements the local-first strategy with offline sync queue.
library;

import 'package:uuid/uuid.dart';

import '../../services/connectivity_service.dart';
import '../local/manga_local_source.dart';
import '../models/manga_model.dart';
import '../models/pending_action.dart';
import '../remote/manga_remote_source.dart';

export '../remote/manga_remote_source.dart' show ApiException;

class MangaRepository {
  final MangaRemoteSource remote;
  final MangaLocalSource local;
  final ConnectivityService connectivity;

  static const _uuid = Uuid();

  MangaRepository({
    required this.remote,
    required this.local,
    required this.connectivity,
  });

  // ──────────────────────────────────────────────
  // Read Operations (local-first)
  // ──────────────────────────────────────────────

  /// Get all mangas. Returns local cache immediately,
  /// then refreshes from server in background.
  Future<List<MangaModel>> getMangas({bool forceRefresh = false}) async {
    if (forceRefresh && connectivity.isOnline.value) {
      try {
        final remoteMangas = await remote.getMangas();
        await local.syncAll(remoteMangas);
        return remoteMangas;
      } catch (_) {
        return local.getAll();
      }
    }

    // Local-first
    final localMangas = await local.getAll();

    // Try to refresh from server if online
    if (connectivity.isOnline.value) {
      _refreshFromServer();
    }

    return localMangas;
  }

  /// Get a single manga by ID.
  Future<MangaModel?> getMangaById(String id) async {
    if (connectivity.isOnline.value) {
      try {
        final manga = await remote.getMangaById(id);
        await local.upsert(manga);
        return manga;
      } catch (_) {
        return local.getById(id);
      }
    }
    return local.getById(id);
  }

  // ──────────────────────────────────────────────
  // CU-01: Create Manga
  // ──────────────────────────────────────────────

  Future<MangaModel> createManga({
    required String titulo,
    required int cantidadTomos,
  }) async {
    if (connectivity.isOnline.value) {
      try {
        final manga = await remote.createManga(
          titulo: titulo,
          cantidadTomos: cantidadTomos,
        );
        await local.upsert(manga);
        return manga;
      } catch (e) {
        // If it's a conflict (duplicate), rethrow
        if (e is ApiException && e.isConflict) rethrow;
        // Otherwise, fall through to offline mode
      }
    }

    // Offline: create with temporary ID
    final tempId = _uuid.v4();
    final tempManga = MangaModel(
      id: tempId,
      titulo: titulo,
      cantidadTomos: cantidadTomos,
      isTemporary: true,
    );
    await local.upsert(tempManga);
    await local.addPendingAction(PendingAction.createManga(
      tempId: tempId,
      titulo: titulo,
      cantidadTomos: cantidadTomos,
    ));
    return tempManga;
  }

  // ──────────────────────────────────────────────
  // CU-03: Mark / Unmark Tomo
  // ──────────────────────────────────────────────

  Future<void> marcarTomo({
    required String mangaId,
    required int numeroTomo,
    required String usuarioId,
  }) async {
    // Optimistic update: apply locally first
    await local.addTomo(mangaId, numeroTomo);

    if (connectivity.isOnline.value) {
      try {
        await remote.marcarTomo(
          mangaId: mangaId,
          numeroTomo: numeroTomo,
          usuarioId: usuarioId,
        );
        return;
      } catch (e) {
        if (e is ApiException && !e.isNetworkError) {
          // Real server error: rollback local change
          await local.removeTomo(mangaId, numeroTomo);
          rethrow;
        }
        // Network error: keep local change, enqueue
      }
    }

    // Enqueue for sync
    await local.addPendingAction(PendingAction.markTomo(
      mangaId: mangaId,
      numeroTomo: numeroTomo,
      usuarioId: usuarioId,
    ));
  }

  Future<void> desmarcarTomo({
    required String mangaId,
    required int numeroTomo,
  }) async {
    // Optimistic update
    await local.removeTomo(mangaId, numeroTomo);

    if (connectivity.isOnline.value) {
      try {
        await remote.desmarcarTomo(
          mangaId: mangaId,
          numeroTomo: numeroTomo,
        );
        return;
      } catch (e) {
        if (e is ApiException && !e.isNetworkError) {
          await local.addTomo(mangaId, numeroTomo);
          rethrow;
        }
      }
    }

    await local.addPendingAction(PendingAction.unmarkTomo(
      mangaId: mangaId,
      numeroTomo: numeroTomo,
    ));
  }

  // ──────────────────────────────────────────────
  // CU-04 & CU-05: Update Manga
  // ──────────────────────────────────────────────

  Future<MangaModel> updateManga({
    required String id,
    String? titulo,
    int? cantidadTomos,
  }) async {
    if (connectivity.isOnline.value) {
      try {
        final manga = await remote.updateManga(
          id: id,
          titulo: titulo,
          cantidadTomos: cantidadTomos,
        );
        await local.upsert(manga);
        return manga;
      } catch (e) {
        if (e is ApiException && !e.isNetworkError) rethrow;
      }
    }

    // Offline: update local + enqueue
    final current = await local.getById(id);
    if (current == null) throw Exception('Manga no encontrado en caché local');

    final updated = current.copyWith(
      titulo: titulo ?? current.titulo,
      cantidadTomos: cantidadTomos ?? current.cantidadTomos,
    );
    await local.upsert(updated);
    await local.addPendingAction(PendingAction.updateManga(
      mangaId: id,
      titulo: titulo,
      cantidadTomos: cantidadTomos,
    ));
    return updated;
  }

  // ──────────────────────────────────────────────
  // CU-07: Delete Manga
  // ──────────────────────────────────────────────

  Future<void> deleteManga(String id) async {
    if (connectivity.isOnline.value) {
      try {
        await remote.deleteManga(id);
        await local.delete(id);
        return;
      } catch (e) {
        if (e is ApiException && !e.isNetworkError) rethrow;
      }
    }

    // Offline: delete local + enqueue
    await local.delete(id);
    await local.addPendingAction(PendingAction.deleteManga(mangaId: id));
  }

  // ──────────────────────────────────────────────
  // Background Refresh
  // ──────────────────────────────────────────────

  Future<void> _refreshFromServer() async {
    try {
      final remoteMangas = await remote.getMangas();
      await local.syncAll(remoteMangas);
    } catch (_) {
      // Silent fail — we already have local data
    }
  }
}

