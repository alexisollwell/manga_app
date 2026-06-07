/// Local data source for cached manga data.
/// All CRUD operations against the local SQLite database.
library;

import 'package:sqflite/sqflite.dart';

import '../models/manga_model.dart';
import '../models/pending_action.dart';
import 'database_helper.dart';

class MangaLocalSource {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ──────────────────────────────────────────────
  // Manga Cache Operations
  // ──────────────────────────────────────────────

  /// Get all cached mangas with their tomos.
  Future<List<MangaModel>> getAll() async {
    final db = await _dbHelper.database;
    final mangaRows = await db.query('mangas', orderBy: 'titulo');
    final mangas = <MangaModel>[];

    for (final row in mangaRows) {
      final tomos = await _getTomosForManga(row['id'] as String);
      mangas.add(MangaModel.fromDb(row, tomos));
    }

    return mangas;
  }

  /// Get a single cached manga by ID.
  Future<MangaModel?> getById(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('mangas', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;

    final tomos = await _getTomosForManga(id);
    return MangaModel.fromDb(rows.first, tomos);
  }

  /// Insert or replace a manga in cache.
  Future<void> upsert(MangaModel manga) async {
    final db = await _dbHelper.database;

    await db.insert(
      'mangas',
      manga.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Sync tomos: delete all then re-insert
    await db.delete('tomos_adquiridos', where: 'manga_id = ?', whereArgs: [manga.id]);
    for (final tomo in manga.tomosAdquiridos) {
      await db.insert('tomos_adquiridos', {
        'manga_id': manga.id,
        'numero_tomo': tomo,
      });
    }
  }

  /// Sync all mangas from server data (replace entire cache).
  Future<void> syncAll(List<MangaModel> mangas) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // Get IDs of non-temporary local mangas
      await txn.delete('tomos_adquiridos',
          where: 'manga_id IN (SELECT id FROM mangas WHERE is_temporary = 0)');
      await txn.delete('mangas', where: 'is_temporary = 0');

      for (final manga in mangas) {
        await txn.insert(
          'mangas',
          manga.toDb(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (final tomo in manga.tomosAdquiridos) {
          await txn.insert('tomos_adquiridos', {
            'manga_id': manga.id,
            'numero_tomo': tomo,
          });
        }
      }
    });
  }

  /// Delete a manga from cache.
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete('mangas', where: 'id = ?', whereArgs: [id]);
  }

  /// Add a tomo to the local cache.
  Future<void> addTomo(String mangaId, int numeroTomo) async {
    final db = await _dbHelper.database;
    await db.insert(
      'tomos_adquiridos',
      {'manga_id': mangaId, 'numero_tomo': numeroTomo},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Remove a tomo from the local cache.
  Future<void> removeTomo(String mangaId, int numeroTomo) async {
    final db = await _dbHelper.database;
    await db.delete(
      'tomos_adquiridos',
      where: 'manga_id = ? AND numero_tomo = ?',
      whereArgs: [mangaId, numeroTomo],
    );
  }

  /// Replace a temporary ID with the real server ID.
  Future<void> replaceTempId(String tempId, String realId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update('mangas', {'id': realId, 'is_temporary': 0},
          where: 'id = ?', whereArgs: [tempId]);
      await txn.update('tomos_adquiridos', {'manga_id': realId},
          where: 'manga_id = ?', whereArgs: [tempId]);
    });
  }

  // ──────────────────────────────────────────────
  // Pending Actions Queue
  // ──────────────────────────────────────────────

  /// Add a pending action to the sync queue.
  Future<void> addPendingAction(PendingAction action) async {
    final db = await _dbHelper.database;
    await db.insert('pending_actions', action.toDb());
  }

  /// Get all pending actions in FIFO order.
  Future<List<PendingAction>> getPendingActions() async {
    final db = await _dbHelper.database;
    final rows = await db.query('pending_actions', orderBy: 'id ASC');
    return rows.map(PendingAction.fromDb).toList();
  }

  /// Remove a pending action after successful sync.
  Future<void> removePendingAction(int id) async {
    final db = await _dbHelper.database;
    await db.delete('pending_actions', where: 'id = ?', whereArgs: [id]);
  }

  /// Get count of pending actions.
  Future<int> getPendingCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM pending_actions');
    return result.first['count'] as int;
  }

  /// Clear all pending actions.
  Future<void> clearPendingActions() async {
    final db = await _dbHelper.database;
    await db.delete('pending_actions');
  }

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────

  Future<List<int>> _getTomosForManga(String mangaId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'tomos_adquiridos',
      where: 'manga_id = ?',
      whereArgs: [mangaId],
      orderBy: 'numero_tomo ASC',
    );
    return rows.map((r) => r['numero_tomo'] as int).toList();
  }

  /// Get all cached manga IDs (for orphan cover cleanup).
  Future<List<String>> getAllMangaIds() async {
    final db = await _dbHelper.database;
    final rows = await db.query('mangas', columns: ['id']);
    return rows.map((r) => r['id'] as String).toList();
  }
}
