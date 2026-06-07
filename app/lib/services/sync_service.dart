/// Sync service — processes pending offline actions when connectivity is restored.
library;

import 'dart:async';

import 'package:get/get.dart';

import '../data/local/manga_local_source.dart';
import '../data/models/pending_action.dart';
import '../data/remote/manga_remote_source.dart';
import 'connectivity_service.dart';

class SyncService extends GetxService {
  final MangaRemoteSource remote;
  final MangaLocalSource local;
  final ConnectivityService connectivity;

  final isSyncing = false.obs;
  final pendingCount = 0.obs;

  Worker? _connectivityWorker;

  SyncService({
    required this.remote,
    required this.local,
    required this.connectivity,
  });

  @override
  void onInit() {
    super.onInit();
    _updatePendingCount();

    // Watch for connectivity changes
    _connectivityWorker = ever(connectivity.isOnline, (bool online) {
      if (online) {
        syncPendingActions();
      }
    });
  }

  /// Process all pending actions in FIFO order.
  Future<void> syncPendingActions() async {
    if (isSyncing.value) return;
    if (!connectivity.isOnline.value) return;

    final actions = await local.getPendingActions();
    if (actions.isEmpty) return;

    isSyncing.value = true;
    // ignore: avoid_print
    print('[Sync] Processing ${actions.length} pending actions...');

    for (final action in actions) {
      try {
        await _processAction(action);
        if (action.dbId != null) {
          await local.removePendingAction(action.dbId!);
        }
        // ignore: avoid_print
        print('[Sync] ✓ ${action.type.name} for ${action.mangaId}');
      } catch (e) {
        // ignore: avoid_print
        print('[Sync] ✗ ${action.type.name} failed: $e');
        // Stop processing on network errors to avoid out-of-order execution
        if (e is ApiException && e.isNetworkError) break;
        // For conflict/not-found errors, remove the action (unresolvable)
        if (e is ApiException && (e.isConflict || e.isNotFound)) {
          if (action.dbId != null) {
            await local.removePendingAction(action.dbId!);
          }
        }
      }
    }

    isSyncing.value = false;
    await _updatePendingCount();

    // Refresh data from server after sync
    if (connectivity.isOnline.value) {
      try {
        final freshData = await remote.getMangas();
        await local.syncAll(freshData);
      } catch (_) {}
    }
  }

  Future<void> _processAction(PendingAction action) async {
    switch (action.type) {
      case PendingActionType.createManga:
        final manga = await remote.createManga(
          titulo: action.payload['titulo'] as String,
          cantidadTomos: action.payload['cantidad_tomos'] as int,
        );
        // Replace temporary ID with real server ID
        await local.replaceTempId(action.mangaId, manga.id);
        break;

      case PendingActionType.updateManga:
        await remote.updateManga(
          id: action.mangaId,
          titulo: action.payload['titulo'] as String?,
          cantidadTomos: action.payload['cantidad_tomos'] as int?,
        );
        break;

      case PendingActionType.deleteManga:
        await remote.deleteManga(action.mangaId);
        break;

      case PendingActionType.markTomo:
        await remote.marcarTomo(
          mangaId: action.mangaId,
          numeroTomo: action.payload['numero_tomo'] as int,
          usuarioId: action.payload['usuario_id'] as String,
        );
        break;

      case PendingActionType.unmarkTomo:
        await remote.desmarcarTomo(
          mangaId: action.mangaId,
          numeroTomo: action.payload['numero_tomo'] as int,
        );
        break;
    }
  }

  Future<void> _updatePendingCount() async {
    pendingCount.value = await local.getPendingCount();
  }

  @override
  void onClose() {
    _connectivityWorker?.dispose();
    super.onClose();
  }
}
