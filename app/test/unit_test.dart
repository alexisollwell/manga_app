import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get/get.dart';

import 'package:manga_library/data/models/manga_model.dart';
import 'package:manga_library/data/models/pending_action.dart';
import 'package:manga_library/data/repositories/manga_repository.dart';
import 'package:manga_library/data/local/manga_local_source.dart';
import 'package:manga_library/data/remote/manga_remote_source.dart';
import 'package:manga_library/services/connectivity_service.dart';
import 'package:manga_library/services/sync_service.dart';

// Mocks
class MockMangaRemoteSource extends Mock implements MangaRemoteSource {}
class MockMangaLocalSource extends Mock implements MangaLocalSource {}
class MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  late MockMangaRemoteSource mockRemote;
  late MockMangaLocalSource mockLocal;
  late MockConnectivityService mockConnectivity;
  late MangaRepository repository;

  setUpAll(() {
    registerFallbackValue(const MangaModel(id: '', titulo: '', cantidadTomos: 1));
    registerFallbackValue(PendingAction.createManga(tempId: '', titulo: '', cantidadTomos: 1));
  });

  setUp(() {
    mockRemote = MockMangaRemoteSource();
    mockLocal = MockMangaLocalSource();
    mockConnectivity = MockConnectivityService();

    repository = MangaRepository(
      remote: mockRemote,
      local: mockLocal,
      connectivity: mockConnectivity,
    );
  });

  group('MangaModel & PendingAction Serialization', () {
    test('MangaModel fromJson / toJson', () {
      final json = {
        'id': 'uuid-123',
        'titulo': 'Chainsaw Man',
        'cantidad_tomos': 16,
        'tomos_adquiridos': [1, 2, 3]
      };

      final manga = MangaModel.fromJson(json);

      expect(manga.id, 'uuid-123');
      expect(manga.titulo, 'Chainsaw Man');
      expect(manga.cantidadTomos, 16);
      expect(manga.tomosAdquiridos, [1, 2, 3]);
      expect(manga.progress, 3 / 16);
      expect(manga.isComplete, false);

      final outJson = manga.toJson();
      expect(outJson['titulo'], 'Chainsaw Man');
      expect(outJson['cantidad_tomos'], 16);
    });

    test('PendingAction create and parse local db payload', () {
      final action = PendingAction.createManga(
        tempId: 'temp-123',
        titulo: 'Frieren',
        cantidadTomos: 12,
      );

      final dbMap = action.toDb();
      expect(dbMap['type'], PendingActionType.createManga.index);
      expect(dbMap['manga_id'], 'temp-123');
      expect(dbMap['payload'], 'titulo=Frieren|cantidad_tomos=12');

      final restored = PendingAction.fromDb({
        'id': 1,
        'type': dbMap['type'],
        'manga_id': dbMap['manga_id'],
        'payload': dbMap['payload'],
        'created_at': dbMap['created_at'],
      });

      expect(restored.dbId, 1);
      expect(restored.type, PendingActionType.createManga);
      expect(restored.mangaId, 'temp-123');
      expect(restored.payload['titulo'], 'Frieren');
      expect(restored.payload['cantidad_tomos'], 12);
    });
  });

  group('MangaRepository Operations', () {
    test('getMangas returns local cache and triggers background server update when online', () async {
      final localMangas = [
        const MangaModel(id: '1', titulo: 'Manga A', cantidadTomos: 5),
      ];
      final remoteMangas = [
        const MangaModel(id: '1', titulo: 'Manga A', cantidadTomos: 5),
        const MangaModel(id: '2', titulo: 'Manga B', cantidadTomos: 10),
      ];

      when(() => mockConnectivity.isOnline).thenReturn(true.obs);
      when(() => mockLocal.getAll()).thenAnswer((_) async => localMangas);
      when(() => mockRemote.getMangas()).thenAnswer((_) async => remoteMangas);
      when(() => mockLocal.syncAll(any())).thenAnswer((_) async {});

      final result = await repository.getMangas();

      expect(result, localMangas);
      verify(() => mockLocal.getAll()).called(1);
      // Wait for background refresh to finish in event loop
      await Future<void>.delayed(Duration.zero);
      verify(() => mockRemote.getMangas()).called(1);
      verify(() => mockLocal.syncAll(remoteMangas)).called(1);
    });

    test('createManga enqueues a PendingAction when offline', () async {
      when(() => mockConnectivity.isOnline).thenReturn(false.obs);
      when(() => mockLocal.upsert(any())).thenAnswer((_) async {});
      when(() => mockLocal.addPendingAction(any())).thenAnswer((_) async {});

      final result = await repository.createManga(
        titulo: 'Jujutsu Kaisen',
        cantidadTomos: 26,
      );

      expect(result.isTemporary, true);
      expect(result.titulo, 'Jujutsu Kaisen');
      expect(result.cantidadTomos, 26);

      verify(() => mockLocal.upsert(any())).called(1);
      verify(() => mockLocal.addPendingAction(any())).called(1);
    });

    test('createManga calls remote directly when online', () async {
      final remoteCreated = const MangaModel(id: 'real-id-789', titulo: 'Jujutsu Kaisen', cantidadTomos: 26);

      when(() => mockConnectivity.isOnline).thenReturn(true.obs);
      when(() => mockRemote.createManga(titulo: 'Jujutsu Kaisen', cantidadTomos: 26))
          .thenAnswer((_) async => remoteCreated);
      when(() => mockLocal.upsert(any())).thenAnswer((_) async {});

      final result = await repository.createManga(
        titulo: 'Jujutsu Kaisen',
        cantidadTomos: 26,
      );

      expect(result.id, 'real-id-789');
      expect(result.isTemporary, false);

      verify(() => mockRemote.createManga(titulo: 'Jujutsu Kaisen', cantidadTomos: 26)).called(1);
      verify(() => mockLocal.upsert(remoteCreated)).called(1);
    });
  });

  group('SyncService Syncing FIFO Queue', () {
    test('processes pending actions sequentially and replaces temp IDs', () async {
      final action1 = PendingAction.createManga(
        tempId: 'temp-id-123',
        titulo: 'Frieren 1',
        cantidadTomos: 10,
      );
      // Let's manually set a database ID for the action
      final action1WithDbId = PendingAction(
        dbId: 42,
        type: action1.type,
        mangaId: action1.mangaId,
        payload: action1.payload,
        createdAt: action1.createdAt,
      );

      final realManga = const MangaModel(
        id: 'real-id-123',
        titulo: 'Frieren 1',
        cantidadTomos: 10,
      );

      when(() => mockConnectivity.isOnline).thenReturn(true.obs);
      when(() => mockLocal.getPendingActions()).thenAnswer((_) async => [action1WithDbId]);
      when(() => mockRemote.createManga(titulo: 'Frieren 1', cantidadTomos: 10))
          .thenAnswer((_) async => realManga);
      when(() => mockLocal.replaceTempId('temp-id-123', 'real-id-123')).thenAnswer((_) async {});
      when(() => mockLocal.removePendingAction(42)).thenAnswer((_) async {});
      when(() => mockLocal.getPendingCount()).thenAnswer((_) async => 0);
      when(() => mockRemote.getMangas()).thenAnswer((_) async => [realManga]);
      when(() => mockLocal.syncAll(any())).thenAnswer((_) async {});

      final syncService = SyncService(
        remote: mockRemote,
        local: mockLocal,
        connectivity: mockConnectivity,
      );

      await syncService.syncPendingActions();

      verify(() => mockRemote.createManga(titulo: 'Frieren 1', cantidadTomos: 10)).called(1);
      verify(() => mockLocal.replaceTempId('temp-id-123', 'real-id-123')).called(1);
      verify(() => mockLocal.removePendingAction(42)).called(1);
    });
  });
}
