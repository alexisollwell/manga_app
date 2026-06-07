import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:manga_library/data/local/database_helper.dart';
import 'package:manga_library/data/local/manga_local_source.dart';
import 'package:manga_library/data/remote/manga_remote_source.dart';
import 'package:manga_library/data/repositories/manga_repository.dart';
import 'package:manga_library/services/connectivity_service.dart';
import 'package:manga_library/services/sync_service.dart';

class MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  // Initialize FFI for SQLite in local test environment
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late MockConnectivityService mockConnectivity;
  late MangaLocalSource localSource;
  late MangaRemoteSource remoteSource;
  late MangaRepository repository;
  late SyncService syncService;

  setUpAll(() async {
    // Override base url to localhost for running in the host test environment
    // The Docker container is running on localhost:8050.
    // Let's create an instance of GetConnect or subclass and point to localhost.
  });

  setUp(() async {
    mockConnectivity = MockConnectivityService();
    
    // We will use an in-memory database by forcing SQLite ffi to open in-memory.
    // Let's mock or override database helper to use in-memory FFI database.
    // Wait, let's open an in-memory database and assign it to DatabaseHelper static field or similar.
    // To keep it simple, let's just let it open the default file on disk (manga_library_cache.db)
    // but delete it first to ensure a clean slate.
    final dbPath = await getDatabasesPath();
    final file = File('$dbPath/manga_library_cache.db');
    if (await file.exists()) {
      await file.delete();
    }

    localSource = MangaLocalSource();
    remoteSource = MangaRemoteSource();
    
    // Override baseUrl to localhost:8050
    remoteSource.httpClient.baseUrl = 'http://localhost:8050/api';

    repository = MangaRepository(
      remote: remoteSource,
      local: localSource,
      connectivity: mockConnectivity,
    );

    syncService = SyncService(
      remote: remoteSource,
      local: localSource,
      connectivity: mockConnectivity,
    );
  });

  tearDown(() async {
    await DatabaseHelper().close();
  });

  group('End-to-End Local + Remote Integration Test', () {
    test('Complete Manga Lifecycle (Create, Mark, Update, Delete) & Offline Sync Queue', () async {
      // ──────────────────────────────────────────────
      // 1. Initial State Check (Online)
      // ──────────────────────────────────────────────
      final isOnlineObs = true.obs;
      when(() => mockConnectivity.isOnline).thenReturn(isOnlineObs);

      // Clean server state before starting
      try {
        final existing = await remoteSource.getMangas();
        for (final m in existing) {
          if (m.titulo.startsWith('E2E_')) {
            await remoteSource.deleteManga(m.id);
          }
        }
      } catch (e) {
        fail('Server is not running or unreachable: $e');
      }

      // ──────────────────────────────────────────────
      // 2. Create Manga (Online)
      // ──────────────────────────────────────────────
      final manga = await repository.createManga(
        titulo: 'E2E_Test_Manga',
        cantidadTomos: 5,
      );

      expect(manga.isTemporary, false);
      expect(manga.titulo, 'E2E_Test_Manga');
      expect(manga.cantidadTomos, 5);

      // Verify it is cached locally
      final cachedManga = await localSource.getById(manga.id);
      expect(cachedManga, isNotNull);
      expect(cachedManga!.titulo, 'E2E_Test_Manga');

      // ──────────────────────────────────────────────
      // 3. Mark Tomo (Online)
      // ──────────────────────────────────────────────
      await repository.marcarTomo(
        mangaId: manga.id,
        numeroTomo: 1,
        usuarioId: 'Alexis',
      );

      // Verify locally cached
      var updatedCached = await localSource.getById(manga.id);
      expect(updatedCached!.tomosAdquiridos, contains(1));

      // Verify on remote server
      final remoteMangaDetail = await remoteSource.getMangaById(manga.id);
      expect(remoteMangaDetail.tomosAdquiridos, contains(1));

      // ──────────────────────────────────────────────
      // 4. Simulate Offline Mode & Offline Operations
      // ──────────────────────────────────────────────
      isOnlineObs.value = false;

      // Mark tomo 2 offline (should use optimistic update + queue)
      await repository.marcarTomo(
        mangaId: manga.id,
        numeroTomo: 2,
        usuarioId: 'Alexis',
      );

      // Verify local cache has both tomos 1 and 2
      updatedCached = await localSource.getById(manga.id);
      expect(updatedCached!.tomosAdquiridos, containsAll([1, 2]));

      // Verify server is NOT updated yet (since offline, it still only has tomo 1)
      final remoteMangaDetailOffline = await remoteSource.getMangaById(manga.id);
      expect(remoteMangaDetailOffline.tomosAdquiridos, [1]); // Only 1

      // Verify pending action was queued
      final pendingCount = await localSource.getPendingCount();
      expect(pendingCount, 1);

      // Create a second manga while offline
      final tempManga = await repository.createManga(
        titulo: 'E2E_Offline_Manga',
        cantidadTomos: 3,
      );

      expect(tempManga.isTemporary, true);

      // Queue should now have 2 actions
      expect(await localSource.getPendingCount(), 2);

      // ──────────────────────────────────────────────
      // 5. Restore Connection & Trigger Sync
      // ──────────────────────────────────────────────
      isOnlineObs.value = true;

      // Trigger sync
      await syncService.syncPendingActions();

      // Queue should be empty now
      expect(await localSource.getPendingCount(), 0);

      // Verify both actions synchronized to the server:
      // a) Tomo 2 should now be marked on server
      final finalRemoteMangaDetail = await remoteSource.getMangaById(manga.id);
      expect(finalRemoteMangaDetail.tomosAdquiridos, containsAll([1, 2]));

      // b) The offline manga should have been created on the server and its ID replaced
      final allRemoteMangas = await remoteSource.getMangas();
      final createdRemoteManga = allRemoteMangas.firstWhere((m) => m.titulo == 'E2E_Offline_Manga');
      expect(createdRemoteManga.isTemporary, false);

      // Verify local database ID was replaced (it is no longer temporary)
      final syncCachedManga = await localSource.getById(createdRemoteManga.id);
      expect(syncCachedManga, isNotNull);
      expect(syncCachedManga!.isTemporary, false);

      // ──────────────────────────────────────────────
      // 6. Cleanup (Delete created mangas)
      // ──────────────────────────────────────────────
      await repository.deleteManga(manga.id);
      await repository.deleteManga(createdRemoteManga.id);

      // Verify deleted from server
      final finalRemoteList = await remoteSource.getMangas();
      expect(finalRemoteList.any((m) => m.id == manga.id), isFalse);
      expect(finalRemoteList.any((m) => m.id == createdRemoteManga.id), isFalse);

      // Verify deleted from local cache
      expect(await localSource.getById(manga.id), isNull);
      expect(await localSource.getById(createdRemoteManga.id), isNull);
    });
  });
}
