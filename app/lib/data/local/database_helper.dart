/// SQLite local database helper for offline cache.
/// Manages tables: mangas, tomos_adquiridos, pending_actions.
library;

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'manga_library_cache.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── Cached mangas table ──────────────────────
    await db.execute('''
      CREATE TABLE mangas (
        id TEXT PRIMARY KEY,
        titulo TEXT NOT NULL,
        cantidad_tomos INTEGER NOT NULL,
        is_temporary INTEGER DEFAULT 0
      )
    ''');

    // ── Cached acquired volumes ──────────────────
    await db.execute('''
      CREATE TABLE tomos_adquiridos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        manga_id TEXT NOT NULL,
        numero_tomo INTEGER NOT NULL,
        FOREIGN KEY (manga_id) REFERENCES mangas(id) ON DELETE CASCADE,
        UNIQUE(manga_id, numero_tomo)
      )
    ''');

    // ── Pending sync actions queue ───────────────
    await db.execute('''
      CREATE TABLE pending_actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type INTEGER NOT NULL,
        manga_id TEXT NOT NULL,
        payload TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Close the database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
